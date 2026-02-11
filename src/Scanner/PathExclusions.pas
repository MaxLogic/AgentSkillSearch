unit PathExclusions;

interface

type
  TPathExclusionIssue = record
    LineNumber: Integer;
    RawLine: string;
    Reason: string;
  end;

  TPathExclusionsParseResult = record
    Issues: TArray<TPathExclusionIssue>;
    Patterns: TArray<string>;
  end;

function IsPathExcluded(const aPath: string; const aPatterns: TArray<string>): Boolean;
function ParsePathExclusionsFile(const aFilePath: string): TPathExclusionsParseResult;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.Masks, System.StrUtils, System.SysUtils;

function NormalizeForMatch(const aValue: string): string;
begin
  Result := LowerCase(Trim(StringReplace(aValue, '/', '\', [rfReplaceAll])));
end;

function IsCommentOrEmpty(const aLine: string): Boolean;
var
  lTrimmed: string;
begin
  lTrimmed := TrimLeft(aLine);
  Result := (lTrimmed = '') or StartsStr('#', lTrimmed) or StartsStr(';', lTrimmed) or StartsStr('//', lTrimmed);
end;

procedure AddIssue(var aResult: TPathExclusionsParseResult; const aLineNumber: Integer; const aRawLine, aReason: string);
var
  lLen: Integer;
begin
  lLen := Length(aResult.Issues);
  SetLength(aResult.Issues, lLen + 1);
  aResult.Issues[lLen].LineNumber := aLineNumber;
  aResult.Issues[lLen].RawLine := aRawLine;
  aResult.Issues[lLen].Reason := aReason;
end;

procedure AddPattern(var aResult: TPathExclusionsParseResult; const aPattern: string);
var
  lLen: Integer;
begin
  lLen := Length(aResult.Patterns);
  SetLength(aResult.Patterns, lLen + 1);
  aResult.Patterns[lLen] := aPattern;
end;

function ParsePathExclusionsFile(const aFilePath: string): TPathExclusionsParseResult;
var
  i: Integer;
  lDedup: TDictionary<string, Byte>;
  lLine: string;
  lLines: TStringList;
  lPattern: string;
begin
  if not TFile.Exists(aFilePath) then
  begin
    Exit;
  end;

  lDedup := TDictionary<string, Byte>.Create;
  lLines := TStringList.Create;
  try
    lLines.LoadFromFile(aFilePath, TEncoding.UTF8);
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i];
      if IsCommentOrEmpty(lLine) then
      begin
        Continue;
      end;

      lPattern := NormalizeForMatch(lLine);
      if lPattern = '' then
      begin
        AddIssue(Result, i + 1, lLine, 'Pattern is empty after normalization');
        Continue;
      end;

      if not lDedup.ContainsKey(lPattern) then
      begin
        lDedup.Add(lPattern, 1);
        AddPattern(Result, lPattern);
      end;
    end;
  finally
    lLines.Free;
    lDedup.Free;
  end;
end;

function BuildWildcardMask(const aPattern: string): string;
begin
  Result := aPattern;
  if not StartsStr('*', Result) then
  begin
    Result := '*' + Result;
  end;
  if not EndsStr('*', Result) then
  begin
    Result := Result + '*';
  end;
end;

function IsPathExcluded(const aPath: string; const aPatterns: TArray<string>): Boolean;
var
  i: Integer;
  lMask: string;
  lPath: string;
  lPattern: string;
begin
  lPath := NormalizeForMatch(aPath);
  if lPath = '' then
  begin
    Exit(False);
  end;

  for i := 0 to Pred(Length(aPatterns)) do
  begin
    lPattern := NormalizeForMatch(aPatterns[i]);
    if lPattern = '' then
    begin
      Continue;
    end;

    if (Pos('*', lPattern) > 0) or (Pos('?', lPattern) > 0) then
    begin
      lMask := BuildWildcardMask(lPattern);
      if MatchesMask(lPath, lMask) then
      begin
        Exit(True);
      end;
      Continue;
    end;

    if Pos(lPattern, lPath) > 0 then
    begin
      Exit(True);
    end;
  end;

  Result := False;
end;

end.
