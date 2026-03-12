unit SourcesList;

interface

type
  TSourcePathEntry = record
    LineNumber: Integer;
    NormalizedPath: string;
    RawLine: string;
  end;

  TSourcePathIssue = record
    LineNumber: Integer;
    RawLine: string;
    Reason: string;
  end;

  TSourcesListParseResult = record
    Entries: TArray<TSourcePathEntry>;
    Issues: TArray<TSourcePathIssue>;
    ValidPaths: TArray<string>;
  end;

function ParseSourcesListFile(const aFilePath, aBaseDirectory: string): TSourcesListParseResult;
function LoadUsableSourcesListFile(const aFilePath, aBaseDirectory: string): TSourcesListParseResult;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils;

function IsAbsolutePath(const aPath: string): Boolean;
begin
  Result := ((Length(aPath) >= 2) and (aPath[1] = '\') and (aPath[2] = '\')) or
    ((Length(aPath) >= 3) and CharInSet(aPath[1], ['A'..'Z', 'a'..'z']) and (aPath[2] = ':') and
    ((aPath[3] = '\') or (aPath[3] = '/')));
end;

function IsCommentOrEmpty(const aLine: string): Boolean;
var
  lTrimmed: string;
begin
  lTrimmed := TrimLeft(aLine);
  Result := (lTrimmed = '') or StartsStr('#', lTrimmed) or StartsStr(';', lTrimmed) or StartsStr('//', lTrimmed);
end;

function ContainsInvalidPathChars(const aPath: string): Boolean;
const
  cInvalidChars: array[0..5] of Char = ('*', '?', '"', '<', '>', '|');
var
  i: Integer;
begin
  Result := False;
  for i := Low(cInvalidChars) to High(cInvalidChars) do
  begin
    if Pos(cInvalidChars[i], aPath) > 0 then
    begin
      Exit(True);
    end;
  end;
end;

procedure AddIssue(var aResult: TSourcesListParseResult; const aLineNumber: Integer; const aRawLine, aReason: string);
var
  lLen: Integer;
begin
  lLen := Length(aResult.Issues);
  SetLength(aResult.Issues, lLen + 1);
  aResult.Issues[lLen].LineNumber := aLineNumber;
  aResult.Issues[lLen].RawLine := aRawLine;
  aResult.Issues[lLen].Reason := aReason;
end;

procedure AddValidPath(var aResult: TSourcesListParseResult; const aLineNumber: Integer; const aRawLine, aPath: string);
var
  lLen: Integer;
begin
  lLen := Length(aResult.Entries);
  SetLength(aResult.Entries, lLen + 1);
  aResult.Entries[lLen].LineNumber := aLineNumber;
  aResult.Entries[lLen].RawLine := aRawLine;
  aResult.Entries[lLen].NormalizedPath := aPath;

  lLen := Length(aResult.ValidPaths);
  SetLength(aResult.ValidPaths, lLen + 1);
  aResult.ValidPaths[lLen] := aPath;
end;

function BuildBaseDirectory(const aFilePath, aBaseDirectory: string): string;
begin
  if aBaseDirectory = '' then
  begin
    Result := ExtractFilePath(aFilePath);
  end else begin
    Result := aBaseDirectory;
  end;

  Result := TPath.GetFullPath(Result);
end;

function NormalizePath(const aInput, aBaseDirectory: string; out aOutput: string; out aError: string): Boolean;
var
  lCandidate: string;
begin
  aError := '';
  aOutput := '';

  lCandidate := Trim(aInput);
  lCandidate := StringReplace(lCandidate, '/', '\', [rfReplaceAll]);

  if ContainsInvalidPathChars(lCandidate) then
  begin
    aError := 'Path contains invalid characters';
    Exit(False);
  end;

  if not IsAbsolutePath(lCandidate) then
  begin
    lCandidate := TPath.Combine(aBaseDirectory, lCandidate);
  end;

  try
    aOutput := TPath.GetFullPath(lCandidate);
  except
    on E: Exception do
    begin
      aError := 'Path normalization failed: ' + E.Message;
      Exit(False);
    end;
  end;

  if not IsAbsolutePath(aOutput) then
  begin
    aError := 'Path is not absolute after normalization';
    Exit(False);
  end;

  Result := True;
end;

function ParseSourcesListFile(const aFilePath, aBaseDirectory: string): TSourcesListParseResult;
var
  i: Integer;
  lBaseDirectory: string;
  lIssue: string;
  lLines: TStringList;
  lNormalizedPath: string;
  lRawLine: string;
begin
  lBaseDirectory := BuildBaseDirectory(aFilePath, aBaseDirectory);

  lLines := TStringList.Create;
  try
    lLines.LoadFromFile(aFilePath, TEncoding.UTF8);

    for i := 0 to Pred(lLines.Count) do
    begin
      lRawLine := lLines[i];

      if IsCommentOrEmpty(lRawLine) then
      begin
        Continue;
      end;

      if NormalizePath(lRawLine, lBaseDirectory, lNormalizedPath, lIssue) then
      begin
        AddValidPath(Result, i + 1, lRawLine, lNormalizedPath);
      end else begin
        AddIssue(Result, i + 1, lRawLine, lIssue);
      end;
    end;
  finally
    lLines.Free;
  end;
end;

function LoadUsableSourcesListFile(const aFilePath, aBaseDirectory: string): TSourcesListParseResult;
var
  i: Integer;
  lParsedResult: TSourcesListParseResult;
begin
  lParsedResult := ParseSourcesListFile(aFilePath, aBaseDirectory);
  Result.Issues := lParsedResult.Issues;

  for i := 0 to Pred(Length(lParsedResult.Entries)) do
  begin
    if TDirectory.Exists(lParsedResult.Entries[i].NormalizedPath) then
    begin
      AddValidPath(
        Result,
        lParsedResult.Entries[i].LineNumber,
        lParsedResult.Entries[i].RawLine,
        lParsedResult.Entries[i].NormalizedPath
      );
    end else begin
      AddIssue(
        Result,
        lParsedResult.Entries[i].LineNumber,
        lParsedResult.Entries[i].RawLine,
        'Source directory does not exist'
      );
    end;
  end;
end;

end.
