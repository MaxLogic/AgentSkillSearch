unit SkillSearchService;

interface

uses
  FireDAC.Comp.Client, FireDAC.Phys.SQLite;

type
  TSkillSearchResult = record
    Description: string;
    DuplicateCount: Integer;
    DuplicatePaths: string;
    HasScripts: Integer;
    LexScore: Double;
    Name: string;
    Snippet: string;
    ScriptsCount: Integer;
    ScriptsExts: string;
    SkillFile: string;
    SkillRoot: string;
    Tags: string;
  end;

  TSkillSearchService = class
  private
    fConnection: TFDConnection;
    fDatabasePath: string;
    fDriverLink: TFDPhysSQLiteDriverLink;
    fSnippetMaxChars: Integer;
    fSqliteDllPath: string;
    function BuildFallbackSnippet(const aBody: string; const aTerms: TArray<string>): string;
    function ClampSnippet(const aValue: string): string;
    procedure ConfigureConnection;
  public
    constructor Create(const aDatabasePath, aSqliteDllPath: string); overload;
    constructor Create(const aDatabasePath, aSqliteDllPath: string; const aSnippetMaxChars: Integer); overload;
    destructor Destroy; override;
    function Search(const aRawQuery: string): TArray<TSkillSearchResult>;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.Math, System.StrUtils, System.SysUtils, Data.DB,
  FireDAC.DApt, FireDAC.Stan.Async, FireDAC.Stan.Def, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  QueryParser;

function EscapeLike(const aValue: string): string;
begin
  Result := StringReplace(aValue, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '%', '\%', [rfReplaceAll]);
  Result := StringReplace(Result, '_', '\_', [rfReplaceAll]);
end;

function LowerLikePattern(const aValue: string): string;
begin
  Result := '%' + LowerCase(EscapeLike(aValue)) + '%';
end;

function TSkillSearchService.ClampSnippet(const aValue: string): string;
begin
  if fSnippetMaxChars <= 0 then
  begin
    Exit(aValue);
  end;

  if Length(aValue) <= fSnippetMaxChars then
  begin
    Exit(aValue);
  end;

  if fSnippetMaxChars <= 3 then
  begin
    Exit(Copy(aValue, 1, fSnippetMaxChars));
  end;

  Result := Copy(aValue, 1, fSnippetMaxChars - 3) + '...';
end;

function TSkillSearchService.BuildFallbackSnippet(const aBody: string; const aTerms: TArray<string>): string;
var
  i: Integer;
  lBodyLower: string;
  lEndPos: Integer;
  lPos: Integer;
  lStartPos: Integer;
  lTerm: string;
begin
  if Trim(aBody) = '' then
  begin
    Exit('');
  end;

  lPos := 0;
  lBodyLower := LowerCase(aBody);
  for i := 0 to Pred(Length(aTerms)) do
  begin
    lTerm := Trim(aTerms[i]);
    if lTerm = '' then
    begin
      Continue;
    end;

    lPos := Pos(LowerCase(lTerm), lBodyLower);
    if lPos > 0 then
    begin
      Break;
    end;
  end;

  if lPos = 0 then
  begin
    Result := ClampSnippet(aBody);
    Exit;
  end;

  lStartPos := Max(1, lPos - (fSnippetMaxChars div 3));
  lEndPos := Min(Length(aBody), lStartPos + fSnippetMaxChars - 1);
  Result := Copy(aBody, lStartPos, lEndPos - lStartPos + 1);
  if lStartPos > 1 then
  begin
    Result := '... ' + Result;
  end;
  if lEndPos < Length(aBody) then
  begin
    Result := Result + ' ...';
  end;

  for i := 0 to Pred(Length(aTerms)) do
  begin
    lTerm := Trim(aTerms[i]);
    if lTerm = '' then
    begin
      Continue;
    end;

    Result := StringReplace(Result, lTerm, '[[' + lTerm + ']]', [rfIgnoreCase, rfReplaceAll]);
  end;

  Result := ClampSnippet(Result);
end;

constructor TSkillSearchService.Create(const aDatabasePath, aSqliteDllPath: string);
begin
  Create(aDatabasePath, aSqliteDllPath, 600);
end;

constructor TSkillSearchService.Create(const aDatabasePath, aSqliteDllPath: string; const aSnippetMaxChars: Integer);
begin
  inherited Create;
  fDatabasePath := aDatabasePath;
  fSqliteDllPath := aSqliteDllPath;
  fSnippetMaxChars := Max(64, aSnippetMaxChars);
  ConfigureConnection;
end;

destructor TSkillSearchService.Destroy;
begin
  fConnection.Free;
  fDriverLink.Free;
  inherited Destroy;
end;

procedure TSkillSearchService.ConfigureConnection;
begin
  fDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  fDriverLink.VendorLib := fSqliteDllPath;

  fConnection := TFDConnection.Create(nil);
  fConnection.LoginPrompt := False;
  fConnection.Params.Clear;
  fConnection.Params.Add('DriverID=SQLite');
  fConnection.Params.Add('Database=' + fDatabasePath);
  fConnection.Params.Add('OpenMode=ReadWrite');
  fConnection.Params.Add('LockingMode=Normal');
  fConnection.Params.Add('BusyTimeout=5000');
  fConnection.Connected := True;
end;

function TSkillSearchService.Search(const aRawQuery: string): TArray<TSkillSearchResult>;
var
  lCanonicalResult: TSkillSearchResult;
  lDuplicateByBodyHash: TDictionary<string, Integer>;
  lBodyHash: string;
  lCanonicalIndex: Integer;
  i: Integer;
  lFtsMatch: string;
  lQuery: TFDQuery;
  lResult: TSkillSearchResult;
  lSearchQuery: TSearchQuery;
  lSql: TStringBuilder;
begin
  Result := nil;
  lDuplicateByBodyHash := TDictionary<string, Integer>.Create;
  lSearchQuery := ParseSearchQuery(aRawQuery);
  lFtsMatch := BuildFtsMatchExpression(lSearchQuery);

  lSql := TStringBuilder.Create;
  lQuery := TFDQuery.Create(nil);
  try
    if lFtsMatch <> '' then
    begin
      lSql.AppendLine('SELECT s.name, s.description, s.tags, s.skill_file, s.skill_root, s.body_hash, s.has_scripts,');
      lSql.AppendLine('  s.scripts_count,');
      lSql.AppendLine('  s.scripts_exts, s.body_md, snippet(skills_fts, 3, ''[['', '']]'', '' ... '', 32) AS snippet,');
      lSql.AppendLine('  (-bm25(skills_fts, 10.0, 5.0, 4.0, 1.0)) AS lex_score');
      lSql.AppendLine('FROM skills_fts');
      lSql.AppendLine('JOIN skills s ON s.id = skills_fts.rowid');
      lSql.AppendLine('WHERE skills_fts MATCH :match');
    end else begin
      lSql.AppendLine('SELECT s.name, s.description, s.tags, s.skill_file, s.skill_root, s.body_hash, s.has_scripts,');
      lSql.AppendLine('  s.scripts_count,');
      lSql.AppendLine('  s.scripts_exts, s.body_md, '''' AS snippet,');
      lSql.AppendLine('  0.0 AS lex_score');
      lSql.AppendLine('FROM skills s');
      lSql.AppendLine('WHERE 1=1');
    end;

    for i := 0 to Pred(Length(lSearchQuery.NameFilters)) do
    begin
      lSql.AppendLine(Format('AND LOWER(s.name) LIKE :name_filter_%d ESCAPE ''\''', [i]));
    end;

    for i := 0 to Pred(Length(lSearchQuery.TagFilters)) do
    begin
      lSql.AppendLine(Format('AND LOWER(COALESCE(s.tags, '''')) LIKE :tag_filter_%d ESCAPE ''\''', [i]));
    end;

    for i := 0 to Pred(Length(lSearchQuery.PathFilters)) do
    begin
      lSql.AppendLine(Format('AND LOWER(s.skill_root) LIKE :path_filter_%d ESCAPE ''\''', [i]));
    end;

    if lSearchQuery.HasScriptsFilter = 1 then
    begin
      lSql.AppendLine('AND s.has_scripts = 1');
    end else if lSearchQuery.HasScriptsFilter = 0 then
    begin
      lSql.AppendLine('AND s.has_scripts = 0');
    end;

    for i := 0 to Pred(Length(lSearchQuery.ExcludedTerms)) do
    begin
      lSql.AppendLine(Format('AND (LOWER(s.name) NOT LIKE :exclude_%d ESCAPE ''\''', [i]));
      lSql.AppendLine(Format('  AND LOWER(COALESCE(s.description, '''')) NOT LIKE :exclude_%d ESCAPE ''\''', [i]));
      lSql.AppendLine(Format('  AND LOWER(COALESCE(s.tags, '''')) NOT LIKE :exclude_%d ESCAPE ''\''', [i]));
      lSql.AppendLine(Format('  AND LOWER(COALESCE(s.body_md, '''')) NOT LIKE :exclude_%d ESCAPE ''\'')', [i]));
    end;

    if lFtsMatch <> '' then
    begin
      lSql.AppendLine('ORDER BY lex_score DESC, s.name ASC');
    end else begin
      lSql.AppendLine('ORDER BY s.name ASC');
    end;

    lSql.AppendLine('LIMIT :query_limit');

    lQuery.Connection := fConnection;
    lQuery.SQL.Text := lSql.ToString;

    if lFtsMatch <> '' then
    begin
      lQuery.ParamByName('match').AsString := lFtsMatch;
    end;

    for i := 0 to Pred(Length(lSearchQuery.NameFilters)) do
    begin
      lQuery.ParamByName(Format('name_filter_%d', [i])).AsString := LowerLikePattern(lSearchQuery.NameFilters[i]);
    end;

    for i := 0 to Pred(Length(lSearchQuery.TagFilters)) do
    begin
      lQuery.ParamByName(Format('tag_filter_%d', [i])).AsString := LowerLikePattern(lSearchQuery.TagFilters[i]);
    end;

    for i := 0 to Pred(Length(lSearchQuery.PathFilters)) do
    begin
      lQuery.ParamByName(Format('path_filter_%d', [i])).AsString := LowerLikePattern(lSearchQuery.PathFilters[i]);
    end;

    for i := 0 to Pred(Length(lSearchQuery.ExcludedTerms)) do
    begin
      lQuery.ParamByName(Format('exclude_%d', [i])).AsString := LowerLikePattern(lSearchQuery.ExcludedTerms[i]);
    end;

    lQuery.ParamByName('query_limit').AsInteger := lSearchQuery.Limit;
    lQuery.Open;

    while not lQuery.Eof do
    begin
      lResult.Name := lQuery.FieldByName('name').AsString;
      lResult.Description := lQuery.FieldByName('description').AsString;
      lResult.Tags := lQuery.FieldByName('tags').AsString;
      lResult.SkillFile := lQuery.FieldByName('skill_file').AsString;
      lResult.SkillRoot := lQuery.FieldByName('skill_root').AsString;
      lResult.DuplicateCount := 1;
      lResult.DuplicatePaths := '';
      lResult.HasScripts := lQuery.FieldByName('has_scripts').AsInteger;
      lResult.ScriptsCount := lQuery.FieldByName('scripts_count').AsInteger;
      lResult.ScriptsExts := lQuery.FieldByName('scripts_exts').AsString;
      lResult.LexScore := lQuery.FieldByName('lex_score').AsFloat;
      lResult.Snippet := lQuery.FieldByName('snippet').AsString;
      if Trim(lResult.Snippet) = '' then
      begin
        lResult.Snippet := BuildFallbackSnippet(lQuery.FieldByName('body_md').AsString, lSearchQuery.PositiveTerms);
      end else begin
        lResult.Snippet := ClampSnippet(lResult.Snippet);
      end;

      lBodyHash := Trim(lQuery.FieldByName('body_hash').AsString);
      if lBodyHash = '' then
      begin
        lBodyHash := lResult.SkillFile;
      end;

      if lDuplicateByBodyHash.TryGetValue(lBodyHash, lCanonicalIndex) then
      begin
        lCanonicalResult := Result[lCanonicalIndex];
        Inc(lCanonicalResult.DuplicateCount);
        if lCanonicalResult.DuplicatePaths = '' then
        begin
          lCanonicalResult.DuplicatePaths := lResult.SkillFile;
        end else begin
          lCanonicalResult.DuplicatePaths := lCanonicalResult.DuplicatePaths + sLineBreak + lResult.SkillFile;
        end;
        Result[lCanonicalIndex] := lCanonicalResult;
        lQuery.Next;
        Continue;
      end;

      SetLength(Result, Length(Result) + 1);
      lDuplicateByBodyHash.Add(lBodyHash, Length(Result) - 1);
      Result[High(Result)] := lResult;
      lQuery.Next;
    end;
  finally
    lDuplicateByBodyHash.Free;
    lQuery.Free;
    lSql.Free;
  end;
end;

end.
