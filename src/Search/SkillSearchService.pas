unit SkillSearchService;

interface

uses
  System.SysUtils, FireDAC.Comp.Client, FireDAC.Phys.SQLite;

type
  TSemanticSearchOptions = record
    Enabled: Boolean;
    CandidateRerankCount: Integer;
    Model: string;
    OllamaBaseUrl: string;
  end;

  TSkillSearchResult = record
    Description: string;
    DuplicateCount: Integer;
    DuplicatePaths: string;
    FinalScore: Double;
    HasScripts: Integer;
    LexScore: Double;
    Name: string;
    SemanticScore: Double;
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
    fDefaultMaxResults: Integer;
    fSemanticOptions: TSemanticSearchOptions;
    fSnippetMaxChars: Integer;
    fSqliteDllPath: string;
    procedure ApplySemanticRerank(const aQuery: string; var aResults: TArray<TSkillSearchResult>);
    procedure AppendSemanticCandidates(const aQueryVector: TArray<Single>; const aPositiveTerms, aNameFilters,
      aTagFilters, aPathFilters, aExcludedTerms: TArray<string>; const aHasScriptsFilter, aMaxAppend: Integer;
      var aResults: TArray<TSkillSearchResult>);
    function BuildFallbackSnippet(const aBody: string; const aTerms: TArray<string>): string;
    function CosineSimilarity(const aLeft, aRight: TArray<Single>): Double;
    function ClampSnippet(const aValue: string): string;
    procedure ConfigureConnection;
    function DecodeVectorBlob(const aBlob: TBytes): TArray<Single>;
    function EncodeVectorBlob(const aVector: TArray<Single>): TBytes;
    function GetCurrentUtcIso8601: string;
    function NormalizeScore(const aValue, aMin, aMax: Double): Double;
    procedure PersistChunkVector(const aChunkId: Integer; const aVector: TArray<Single>);
    function TryComputeSkillSemanticScore(const aSkillFile: string; const aQueryVector: TArray<Single>;
      out aScore: Double): Boolean;
    function TryExtractEmbedding(const aJsonText: string; out aVector: TArray<Single>): Boolean;
    function TryLoadChunkVector(const aModel: string; aQuery: TFDQuery; out aVector: TArray<Single>): Boolean;
    function TryRequestEmbedding(const aText: string; out aVector: TArray<Single>): Boolean;
  public
    constructor Create(const aDatabasePath, aSqliteDllPath: string; const aSnippetMaxChars: Integer;
      const aSemanticOptions: TSemanticSearchOptions); overload;
    constructor Create(const aDatabasePath, aSqliteDllPath: string; const aSnippetMaxChars, aDefaultMaxResults: Integer;
      const aSemanticOptions: TSemanticSearchOptions); overload;
    constructor Create(const aDatabasePath, aSqliteDllPath: string); overload;
    constructor Create(const aDatabasePath, aSqliteDllPath: string; const aSnippetMaxChars: Integer); overload;
    destructor Destroy; override;
    function Search(const aRawQuery: string): TArray<TSkillSearchResult>;
  end;

function DefaultSemanticSearchOptions: TSemanticSearchOptions;

implementation

uses
  System.Classes, System.DateUtils, System.Generics.Collections, System.Generics.Defaults, System.JSON,
  System.Math, System.Net.HttpClient, System.Net.URLClient, System.StrUtils, Data.DB,
  FireDAC.DApt, FireDAC.Stan.Async, FireDAC.Stan.Def, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  QueryParser;

function DefaultSemanticSearchOptions: TSemanticSearchOptions;
begin
  Result.Enabled := False;
  Result.CandidateRerankCount := 300;
  Result.Model := 'mxbai-embed-large';
  Result.OllamaBaseUrl := 'http://localhost:11434';
end;

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
  Create(aDatabasePath, aSqliteDllPath, 600, 200, DefaultSemanticSearchOptions);
end;

constructor TSkillSearchService.Create(const aDatabasePath, aSqliteDllPath: string; const aSnippetMaxChars: Integer);
begin
  Create(aDatabasePath, aSqliteDllPath, aSnippetMaxChars, 200, DefaultSemanticSearchOptions);
end;

constructor TSkillSearchService.Create(const aDatabasePath, aSqliteDllPath: string; const aSnippetMaxChars: Integer;
  const aSemanticOptions: TSemanticSearchOptions);
begin
  Create(aDatabasePath, aSqliteDllPath, aSnippetMaxChars, 200, aSemanticOptions);
end;

constructor TSkillSearchService.Create(const aDatabasePath, aSqliteDllPath: string;
  const aSnippetMaxChars, aDefaultMaxResults: Integer; const aSemanticOptions: TSemanticSearchOptions);
begin
  inherited Create;
  fDatabasePath := aDatabasePath;
  fSqliteDllPath := aSqliteDllPath;
  fDefaultMaxResults := Max(1, aDefaultMaxResults);
  fSnippetMaxChars := Max(64, aSnippetMaxChars);
  fSemanticOptions := aSemanticOptions;
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

function TSkillSearchService.EncodeVectorBlob(const aVector: TArray<Single>): TBytes;
begin
  SetLength(Result, Length(aVector) * SizeOf(Single));
  if Length(Result) > 0 then
  begin
    Move(aVector[0], Result[0], Length(Result));
  end;
end;

function TSkillSearchService.DecodeVectorBlob(const aBlob: TBytes): TArray<Single>;
var
  lCount: Integer;
begin
  if Length(aBlob) = 0 then
  begin
    Exit(nil);
  end;

  lCount := Length(aBlob) div SizeOf(Single);
  if lCount <= 0 then
  begin
    Exit(nil);
  end;

  SetLength(Result, lCount);
  Move(aBlob[0], Result[0], lCount * SizeOf(Single));
end;

function TSkillSearchService.GetCurrentUtcIso8601: string;
var
  lUtcNow: TDateTime;
begin
  lUtcNow := TTimeZone.Local.ToUniversalTime(Now);
  Result := FormatDateTime('yyyy-mm-dd\"T\"hh:nn:ss\"Z\"', lUtcNow, TFormatSettings.Invariant);
end;

function TSkillSearchService.TryExtractEmbedding(const aJsonText: string; out aVector: TArray<Single>): Boolean;
var
  i: Integer;
  lArray: TJSONArray;
  lJsonValue: TJSONValue;
  lNumber: TJSONNumber;
  lObject: TJSONObject;
begin
  aVector := nil;
  lJsonValue := TJSONObject.ParseJSONValue(aJsonText);
  if not Assigned(lJsonValue) then
  begin
    Exit(False);
  end;

  try
    if not (lJsonValue is TJSONObject) then
    begin
      Exit(False);
    end;

    lObject := TJSONObject(lJsonValue);
    lArray := lObject.Values['embedding'] as TJSONArray;
    if not Assigned(lArray) then
    begin
      Exit(False);
    end;

    SetLength(aVector, lArray.Count);
    for i := 0 to Pred(lArray.Count) do
    begin
      if lArray.Items[i] is TJSONNumber then
      begin
        lNumber := TJSONNumber(lArray.Items[i]);
        aVector[i] := lNumber.AsDouble;
      end else begin
        aVector[i] := StrToFloatDef(lArray.Items[i].Value, 0.0, TFormatSettings.Invariant);
      end;
    end;

    Result := Length(aVector) > 0;
  finally
    lJsonValue.Free;
  end;
end;

function TSkillSearchService.TryRequestEmbedding(const aText: string; out aVector: TArray<Single>): Boolean;
var
  lClient: THTTPClient;
  lHeaders: TNetHeaders;
  lRequestJson: string;
  lRequestObject: TJSONObject;
  lRequestStream: TStringStream;
  lResponse: IHTTPResponse;
  lResponseText: string;
  lUrl: string;
begin
  aVector := nil;
  if not fSemanticOptions.Enabled then
  begin
    Exit(False);
  end;

  lUrl := Trim(fSemanticOptions.OllamaBaseUrl);
  if lUrl = '' then
  begin
    Exit(False);
  end;

  lUrl := ExcludeTrailingPathDelimiter(lUrl) + '/api/embeddings';

  lRequestObject := TJSONObject.Create;
  try
    lRequestObject.AddPair('model', fSemanticOptions.Model);
    lRequestObject.AddPair('prompt', aText);
    lRequestJson := lRequestObject.ToJSON;
  finally
    lRequestObject.Free;
  end;

  lClient := THTTPClient.Create;
  lRequestStream := TStringStream.Create(lRequestJson, TEncoding.UTF8);
  try
    lClient.ConnectionTimeout := 500;
    lClient.ResponseTimeout := 1200;
    SetLength(lHeaders, 1);
    lHeaders[0] := TNetHeader.Create('Content-Type', 'application/json');
    lResponse := lClient.Post(lUrl, lRequestStream, nil, lHeaders);
    if not Assigned(lResponse) then
    begin
      Exit(False);
    end;

    if lResponse.StatusCode < 200 then
    begin
      Exit(False);
    end;
    if lResponse.StatusCode >= 300 then
    begin
      Exit(False);
    end;

    lResponseText := lResponse.ContentAsString(TEncoding.UTF8);
    Result := TryExtractEmbedding(lResponseText, aVector);
  except
    Result := False;
  end;
  lRequestStream.Free;
  lClient.Free;
end;

procedure TSkillSearchService.PersistChunkVector(const aChunkId: Integer; const aVector: TArray<Single>);
var
  lBlob: TBytes;
  lQuery: TFDQuery;
  lStream: TBytesStream;
begin
  lBlob := EncodeVectorBlob(aVector);
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text :=
      'INSERT INTO chunk_vec(chunk_id, model, dim, vec, updated_utc) ' +
      'VALUES (:chunk_id, :model, :dim, :vec, :updated_utc) ' +
      'ON CONFLICT(chunk_id) DO UPDATE SET ' +
      '  model=excluded.model, ' +
      '  dim=excluded.dim, ' +
      '  vec=excluded.vec, ' +
      '  updated_utc=excluded.updated_utc';
    lQuery.ParamByName('chunk_id').AsInteger := aChunkId;
    lQuery.ParamByName('model').AsString := fSemanticOptions.Model;
    lQuery.ParamByName('dim').AsInteger := Length(aVector);
    lQuery.ParamByName('vec').DataType := ftBlob;
    lStream := TBytesStream.Create(lBlob);
    try
      lQuery.ParamByName('vec').LoadFromStream(lStream, ftBlob);
    finally
      lStream.Free;
    end;
    lQuery.ParamByName('updated_utc').AsString := GetCurrentUtcIso8601;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
end;

function TSkillSearchService.TryLoadChunkVector(const aModel: string; aQuery: TFDQuery; out aVector: TArray<Single>)
  : Boolean;
var
  lBlob: TBytes;
  lBlobField: TBlobField;
  lStream: TBytesStream;
begin
  aVector := nil;
  if aQuery.FieldByName('vec').IsNull then
  begin
    Exit(False);
  end;
  if not SameText(aModel, aQuery.FieldByName('model').AsString) then
  begin
    Exit(False);
  end;
  if not (aQuery.FieldByName('vec') is TBlobField) then
  begin
    Exit(False);
  end;

  lBlobField := TBlobField(aQuery.FieldByName('vec'));
  lStream := TBytesStream.Create;
  try
    lBlobField.SaveToStream(lStream);
    SetLength(lBlob, lStream.Size);
    if lStream.Size > 0 then
    begin
      Move(lStream.Bytes[0], lBlob[0], lStream.Size);
    end;
    aVector := DecodeVectorBlob(lBlob);
    Result := Length(aVector) > 0;
  finally
    lStream.Free;
  end;
end;

function TSkillSearchService.CosineSimilarity(const aLeft, aRight: TArray<Single>): Double;
var
  i: Integer;
  lCount: Integer;
  lDot: Double;
  lLeftNorm: Double;
  lRightNorm: Double;
begin
  lCount := Min(Length(aLeft), Length(aRight));
  if lCount <= 0 then
  begin
    Exit(0.0);
  end;

  lDot := 0.0;
  lLeftNorm := 0.0;
  lRightNorm := 0.0;
  for i := 0 to Pred(lCount) do
  begin
    lDot := lDot + (aLeft[i] * aRight[i]);
    lLeftNorm := lLeftNorm + (aLeft[i] * aLeft[i]);
    lRightNorm := lRightNorm + (aRight[i] * aRight[i]);
  end;

  if (lLeftNorm <= 0.0) or (lRightNorm <= 0.0) then
  begin
    Exit(0.0);
  end;
  Result := lDot / (Sqrt(lLeftNorm) * Sqrt(lRightNorm));
end;

function TSkillSearchService.TryComputeSkillSemanticScore(const aSkillFile: string; const aQueryVector: TArray<Single>;
  out aScore: Double): Boolean;
var
  lChunkId: Integer;
  lChunkVector: TArray<Single>;
  lCurrentScore: Double;
  lHasAnyScore: Boolean;
  lQuery: TFDQuery;
begin
  aScore := 0.0;
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text :=
      'SELECT c.id AS chunk_id, c.chunk_text, COALESCE(v.model, '''') AS model, v.vec ' +
      'FROM skill_chunks c ' +
      'JOIN skills s ON s.id = c.skill_id ' +
      'LEFT JOIN chunk_vec v ON v.chunk_id = c.id ' +
      'WHERE s.skill_file = :skill_file ' +
      'ORDER BY c.chunk_index;';
    lQuery.ParamByName('skill_file').AsString := aSkillFile;
    lQuery.Open;

    lHasAnyScore := False;
    while not lQuery.Eof do
    begin
      if not TryLoadChunkVector(fSemanticOptions.Model, lQuery, lChunkVector) then
      begin
        if not TryRequestEmbedding(lQuery.FieldByName('chunk_text').AsString, lChunkVector) then
        begin
          lQuery.Next;
          Continue;
        end;

        lChunkId := lQuery.FieldByName('chunk_id').AsInteger;
        PersistChunkVector(lChunkId, lChunkVector);
      end;

      lCurrentScore := CosineSimilarity(aQueryVector, lChunkVector);
      if (not lHasAnyScore) or (lCurrentScore > aScore) then
      begin
        aScore := lCurrentScore;
        lHasAnyScore := True;
      end;

      lQuery.Next;
    end;

    Result := lHasAnyScore;
  finally
    lQuery.Free;
  end;
end;

function TSkillSearchService.NormalizeScore(const aValue, aMin, aMax: Double): Double;
begin
  if SameValue(aMin, aMax, 1.0e-9) then
  begin
    Exit(1.0);
  end;
  Result := (aValue - aMin) / (aMax - aMin);
end;

procedure TSkillSearchService.AppendSemanticCandidates(const aQueryVector: TArray<Single>; const aPositiveTerms,
  aNameFilters, aTagFilters, aPathFilters, aExcludedTerms: TArray<string>; const aHasScriptsFilter, aMaxAppend: Integer;
  var aResults: TArray<TSkillSearchResult>);
var
  i: Integer;
  lAppendCount: Integer;
  lCandidate: TSkillSearchResult;
  lCandidates: TArray<TSkillSearchResult>;
  lCandidatesByHash: TDictionary<string, Integer>;
  lCurrent: TSkillSearchResult;
  lCurrentIndex: Integer;
  lDuplicatePaths: TArray<string>;
  lKnownFile: string;
  lScore: Double;
  lSemanticQuery: TFDQuery;
  lSemanticSql: TStringBuilder;
  lSkillFileSet: TDictionary<string, Boolean>;
  lTermVector: TArray<Single>;
  lBodyHash: string;
begin
  if (aMaxAppend <= 0) or (Length(aQueryVector) = 0) then
  begin
    Exit;
  end;

  lSkillFileSet := TDictionary<string, Boolean>.Create;
  lCandidatesByHash := TDictionary<string, Integer>.Create;
  lSemanticSql := TStringBuilder.Create;
  lSemanticQuery := TFDQuery.Create(nil);
  try
    for i := 0 to Pred(Length(aResults)) do
    begin
      lKnownFile := Trim(aResults[i].SkillFile);
      if lKnownFile <> '' then
      begin
        lSkillFileSet.AddOrSetValue(lKnownFile, True);
      end;

      if Trim(aResults[i].DuplicatePaths) = '' then
      begin
        Continue;
      end;

      lDuplicatePaths := SplitString(aResults[i].DuplicatePaths, sLineBreak);
      for lKnownFile in lDuplicatePaths do
      begin
        if Trim(lKnownFile) = '' then
        begin
          Continue;
        end;
        lSkillFileSet.AddOrSetValue(Trim(lKnownFile), True);
      end;
    end;

    lSemanticSql.AppendLine(
      'SELECT s.name, s.description, s.tags, s.skill_file, s.skill_root, s.body_hash, s.has_scripts, s.scripts_count,'
    );
    lSemanticSql.AppendLine(
      '  s.scripts_exts, s.body_md, COALESCE(v.model, '''') AS model, v.vec'
    );
    lSemanticSql.AppendLine('FROM skills s');
    lSemanticSql.AppendLine('JOIN skill_chunks c ON c.skill_id = s.id AND c.chunk_index = 0');
    lSemanticSql.AppendLine('JOIN chunk_vec v ON v.chunk_id = c.id');
    lSemanticSql.AppendLine('WHERE v.model = :semantic_model');

    for i := 0 to Pred(Length(aNameFilters)) do
    begin
      lSemanticSql.AppendLine(Format('AND LOWER(s.name) LIKE :semantic_name_filter_%d ESCAPE ''\''', [i]));
    end;

    for i := 0 to Pred(Length(aTagFilters)) do
    begin
      lSemanticSql.AppendLine(Format('AND LOWER(COALESCE(s.tags, '''')) LIKE :semantic_tag_filter_%d ESCAPE ''\''', [i]));
    end;

    for i := 0 to Pred(Length(aPathFilters)) do
    begin
      lSemanticSql.AppendLine(Format('AND LOWER(s.skill_root) LIKE :semantic_path_filter_%d ESCAPE ''\''', [i]));
    end;

    if aHasScriptsFilter = 1 then
    begin
      lSemanticSql.AppendLine('AND s.has_scripts = 1');
    end else if aHasScriptsFilter = 0 then
    begin
      lSemanticSql.AppendLine('AND s.has_scripts = 0');
    end;

    for i := 0 to Pred(Length(aExcludedTerms)) do
    begin
      lSemanticSql.AppendLine(Format('AND (LOWER(s.name) NOT LIKE :semantic_exclude_%d ESCAPE ''\''', [i]));
      lSemanticSql.AppendLine(Format('  AND LOWER(COALESCE(s.description, '''')) NOT LIKE :semantic_exclude_%d ESCAPE ''\''', [i]));
      lSemanticSql.AppendLine(Format('  AND LOWER(COALESCE(s.tags, '''')) NOT LIKE :semantic_exclude_%d ESCAPE ''\''', [i]));
      lSemanticSql.AppendLine(Format('  AND LOWER(COALESCE(s.body_md, '''')) NOT LIKE :semantic_exclude_%d ESCAPE ''\'')', [i]));
    end;

    lSemanticSql.AppendLine('ORDER BY s.id ASC');

    lSemanticQuery.Connection := fConnection;
    lSemanticQuery.SQL.Text := lSemanticSql.ToString;
    lSemanticQuery.ParamByName('semantic_model').AsString := fSemanticOptions.Model;

    for i := 0 to Pred(Length(aNameFilters)) do
    begin
      lSemanticQuery.ParamByName(Format('semantic_name_filter_%d', [i])).AsString := LowerLikePattern(aNameFilters[i]);
    end;

    for i := 0 to Pred(Length(aTagFilters)) do
    begin
      lSemanticQuery.ParamByName(Format('semantic_tag_filter_%d', [i])).AsString := LowerLikePattern(aTagFilters[i]);
    end;

    for i := 0 to Pred(Length(aPathFilters)) do
    begin
      lSemanticQuery.ParamByName(Format('semantic_path_filter_%d', [i])).AsString := LowerLikePattern(aPathFilters[i]);
    end;

    for i := 0 to Pred(Length(aExcludedTerms)) do
    begin
      lSemanticQuery.ParamByName(Format('semantic_exclude_%d', [i])).AsString := LowerLikePattern(aExcludedTerms[i]);
    end;

    lSemanticQuery.Open;
    while not lSemanticQuery.Eof do
    begin
      lKnownFile := Trim(lSemanticQuery.FieldByName('skill_file').AsString);
      if (lKnownFile = '') or lSkillFileSet.ContainsKey(lKnownFile) then
      begin
        lSemanticQuery.Next;
        Continue;
      end;

      if not TryLoadChunkVector(fSemanticOptions.Model, lSemanticQuery, lTermVector) then
      begin
        lSemanticQuery.Next;
        Continue;
      end;

      lScore := CosineSimilarity(aQueryVector, lTermVector);
      if lScore <= 0.0 then
      begin
        lSemanticQuery.Next;
        Continue;
      end;

      lBodyHash := Trim(lSemanticQuery.FieldByName('body_hash').AsString);
      if lBodyHash = '' then
      begin
        lBodyHash := lKnownFile;
      end;

      if lCandidatesByHash.TryGetValue(lBodyHash, lCurrentIndex) then
      begin
        lCurrent := lCandidates[lCurrentIndex];
        Inc(lCurrent.DuplicateCount);
        if lCurrent.DuplicatePaths = '' then
        begin
          lCurrent.DuplicatePaths := lKnownFile;
        end else begin
          lCurrent.DuplicatePaths := lCurrent.DuplicatePaths + sLineBreak + lKnownFile;
        end;
        if lScore > lCurrent.SemanticScore then
        begin
          lCurrent.SemanticScore := lScore;
          lCurrent.FinalScore := lScore;
        end;
        lCandidates[lCurrentIndex] := lCurrent;
        lSemanticQuery.Next;
        Continue;
      end;

      lCandidate.Name := lSemanticQuery.FieldByName('name').AsString;
      lCandidate.Description := lSemanticQuery.FieldByName('description').AsString;
      lCandidate.Tags := lSemanticQuery.FieldByName('tags').AsString;
      lCandidate.SkillFile := lKnownFile;
      lCandidate.SkillRoot := lSemanticQuery.FieldByName('skill_root').AsString;
      lCandidate.DuplicateCount := 1;
      lCandidate.DuplicatePaths := '';
      lCandidate.HasScripts := lSemanticQuery.FieldByName('has_scripts').AsInteger;
      lCandidate.ScriptsCount := lSemanticQuery.FieldByName('scripts_count').AsInteger;
      lCandidate.ScriptsExts := lSemanticQuery.FieldByName('scripts_exts').AsString;
      lCandidate.LexScore := 0.0;
      lCandidate.SemanticScore := lScore;
      lCandidate.FinalScore := lScore;
      lCandidate.Snippet := BuildFallbackSnippet(lSemanticQuery.FieldByName('body_md').AsString, aPositiveTerms);

      SetLength(lCandidates, Length(lCandidates) + 1);
      lCandidates[High(lCandidates)] := lCandidate;
      lCandidatesByHash.Add(lBodyHash, High(lCandidates));
      lSemanticQuery.Next;
    end;

    TArray.Sort<TSkillSearchResult>(
      lCandidates,
      TComparer<TSkillSearchResult>.Construct(
        function(const aLeft, aRight: TSkillSearchResult): Integer
        begin
          if aLeft.SemanticScore > aRight.SemanticScore then
          begin
            Exit(-1);
          end;
          if aLeft.SemanticScore < aRight.SemanticScore then
          begin
            Exit(1);
          end;
          Result := CompareText(aLeft.Name, aRight.Name);
        end
      )
    );

    lAppendCount := 0;
    for i := 0 to Pred(Length(lCandidates)) do
    begin
      if lAppendCount >= aMaxAppend then
      begin
        Break;
      end;

      if lSkillFileSet.ContainsKey(lCandidates[i].SkillFile) then
      begin
        Continue;
      end;

      SetLength(aResults, Length(aResults) + 1);
      aResults[High(aResults)] := lCandidates[i];
      lSkillFileSet.AddOrSetValue(lCandidates[i].SkillFile, True);
      Inc(lAppendCount);
    end;
  finally
    lSemanticQuery.Free;
    lSemanticSql.Free;
    lCandidatesByHash.Free;
    lSkillFileSet.Free;
  end;
end;

procedure TSkillSearchService.ApplySemanticRerank(const aQuery: string; var aResults: TArray<TSkillSearchResult>);
var
  i: Integer;
  lCandidateCount: Integer;
  lLexMax: Double;
  lLexMin: Double;
  lNormLex: Double;
  lNormSem: Double;
  lQueryVector: TArray<Single>;
  lSearchQuery: TSearchQuery;
  lSemMax: Double;
  lSemMin: Double;
  lSemanticAppendLimit: Integer;
begin
  if not fSemanticOptions.Enabled then
  begin
    Exit;
  end;
  if Trim(aQuery) = '' then
  begin
    Exit;
  end;
  if Length(aResults) = 0 then
  begin
    Exit;
  end;
  if fSemanticOptions.CandidateRerankCount <= 0 then
  begin
    Exit;
  end;

  if not TryRequestEmbedding(aQuery, lQueryVector) then
  begin
    Exit;
  end;

  lSearchQuery := ParseSearchQuery(aQuery, fDefaultMaxResults);
  lCandidateCount := Min(Length(aResults), fSemanticOptions.CandidateRerankCount);
  for i := 0 to Pred(lCandidateCount) do
  begin
    if not TryComputeSkillSemanticScore(aResults[i].SkillFile, lQueryVector, aResults[i].SemanticScore) then
    begin
      aResults[i].SemanticScore := 0.0;
    end;
  end;

  for i := lCandidateCount to Pred(Length(aResults)) do
  begin
    aResults[i].SemanticScore := 0.0;
  end;

  lSemanticAppendLimit := Max(1, Min(fSemanticOptions.CandidateRerankCount, lSearchQuery.Limit));
  AppendSemanticCandidates(
    lQueryVector,
    lSearchQuery.PositiveTerms,
    lSearchQuery.NameFilters,
    lSearchQuery.TagFilters,
    lSearchQuery.PathFilters,
    lSearchQuery.ExcludedTerms,
    lSearchQuery.HasScriptsFilter,
    lSemanticAppendLimit,
    aResults
  );

  lLexMin := MaxDouble;
  lLexMax := -MaxDouble;
  lSemMin := MaxDouble;
  lSemMax := -MaxDouble;
  for i := 0 to Pred(Length(aResults)) do
  begin
    lLexMin := Min(lLexMin, aResults[i].LexScore);
    lLexMax := Max(lLexMax, aResults[i].LexScore);
    lSemMin := Min(lSemMin, aResults[i].SemanticScore);
    lSemMax := Max(lSemMax, aResults[i].SemanticScore);
  end;

  for i := 0 to Pred(Length(aResults)) do
  begin
    lNormLex := NormalizeScore(aResults[i].LexScore, lLexMin, lLexMax);
    lNormSem := NormalizeScore(aResults[i].SemanticScore, lSemMin, lSemMax);
    aResults[i].FinalScore := (0.35 * lNormLex) + (0.65 * lNormSem);
    aResults[i].LexScore := aResults[i].FinalScore;
  end;

  TArray.Sort<TSkillSearchResult>(
    aResults,
    TComparer<TSkillSearchResult>.Construct(
      function(const aLeft, aRight: TSkillSearchResult): Integer
      begin
        if aLeft.FinalScore > aRight.FinalScore then
        begin
          Exit(-1);
        end;
        if aLeft.FinalScore < aRight.FinalScore then
        begin
          Exit(1);
        end;
        Result := CompareText(aLeft.Name, aRight.Name);
      end
    )
  );

  if Length(aResults) > lSearchQuery.Limit then
  begin
    SetLength(aResults, lSearchQuery.Limit);
  end;
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
  lSearchQuery := ParseSearchQuery(aRawQuery, fDefaultMaxResults);
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
      lResult.SemanticScore := 0.0;
      lResult.FinalScore := lResult.LexScore;
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

    ApplySemanticRerank(aRawQuery, Result);
  finally
    lDuplicateByBodyHash.Free;
    lQuery.Free;
    lSql.Free;
  end;
end;

end.
