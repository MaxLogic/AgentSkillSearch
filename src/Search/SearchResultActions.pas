unit SearchResultActions;

interface

uses
  System.Generics.Collections,
  SkillSearchService;

type
  TSearchSortMode = (
    ssmScore,
    ssmNameAsc,
    ssmNameDesc,
    ssmPathAsc,
    ssmPathDesc,
    ssmDateIndexedDesc,
    ssmDateIndexedAsc
  );

function BuildResultsMarkdownList(const aResults: TArray<TSkillSearchResult>): string;
function BuildResultsMarkdownListForSkillRoots(const aResults: TArray<TSkillSearchResult>): string;
function DefaultSearchSortMode: TSearchSortMode;
function SearchSortModeToString(const aSortMode: TSearchSortMode): string;
function ShouldShowDuplicateDetails(const aDuplicateCount: Integer): Boolean;
procedure SortSearchResults(var aResults: TArray<TSkillSearchResult>; const aSortMode: TSearchSortMode);
function TryBuildResultsMarkdownList(const aResults: TArray<TSkillSearchResult>; out aMarkdown: string): Boolean;
function TryBuildResultsMarkdownListForSkillRoots(const aResults: TArray<TSkillSearchResult>; out aMarkdown: string): Boolean;
function TryParseSearchSortMode(const aValue: string; out aSortMode: TSearchSortMode): Boolean;

implementation

uses
  System.Classes, System.Generics.Defaults, System.IOUtils, System.NetEncoding, System.StrUtils, System.SysUtils;

function CompareNullableText(const aLeft, aRight: string): Integer;
begin
  if (aLeft = '') and (aRight = '') then
  begin
    Exit(0);
  end;
  if aLeft = '' then
  begin
    Exit(-1);
  end;
  if aRight = '' then
  begin
    Exit(1);
  end;

  Result := CompareText(aLeft, aRight);
end;

function CompareScoreDescending(const aLeft, aRight: TSkillSearchResult): Integer;
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
  if Result = 0 then
  begin
    Result := CompareText(aLeft.SkillRoot, aRight.SkillRoot);
  end;
end;

function EncodeUrlPathSegment(const aValue: string): string;
begin
  Result := TNetEncoding.URL.Encode(aValue);
end;

function NormalizeGitWebBaseUrl(const aRemoteUrl: string): string;
var
  lColonIndex: Integer;
  lValue: string;
begin
  lValue := Trim(aRemoteUrl);
  if lValue = '' then
  begin
    Exit('');
  end;

  if StartsText('git@', lValue) then
  begin
    lColonIndex := Pos(':', lValue);
    if lColonIndex > 0 then
    begin
      lValue := 'https://' + Copy(lValue, 5, lColonIndex - 5) + '/' + Copy(lValue, lColonIndex + 1, MaxInt);
    end;
  end else if StartsText('ssh://', lValue) then
  begin
    lValue := 'https://' + Copy(lValue, Length('ssh://') + 1, MaxInt);
  end else if StartsText('git://', lValue) then
  begin
    lValue := 'https://' + Copy(lValue, Length('git://') + 1, MaxInt);
  end;

  if not (StartsText('http://', lValue) or StartsText('https://', lValue)) then
  begin
    lValue := 'https://' + lValue;
  end;

  if (Length(lValue) >= 4) and SameText(Copy(lValue, Length(lValue) - 3, 4), '.git') then
  begin
    Delete(lValue, Length(lValue) - 3, 4);
  end;

  while (lValue <> '') and (lValue[Length(lValue)] = '/') do
  begin
    Delete(lValue, Length(lValue), 1);
  end;

  Result := lValue;
end;

function TryGetGitDirectory(const aWorkingTreeRoot: string; out aGitDirectory: string): Boolean;
var
  lDotGitPath: string;
  lGitDirValue: string;
  lGitFile: TStringList;
  lLine: string;
  lValue: string;
begin
  Result := False;
  aGitDirectory := '';

  lDotGitPath := TPath.Combine(aWorkingTreeRoot, '.git');
  if TDirectory.Exists(lDotGitPath) then
  begin
    aGitDirectory := lDotGitPath;
    Exit(True);
  end;

  if not TFile.Exists(lDotGitPath) then
  begin
    Exit(False);
  end;

  lGitFile := TStringList.Create;
  try
    lGitFile.LoadFromFile(lDotGitPath, TEncoding.UTF8);
    if lGitFile.Count = 0 then
    begin
      Exit(False);
    end;

    lLine := Trim(lGitFile[0]);
    if not StartsText('gitdir:', LowerCase(lLine)) then
    begin
      Exit(False);
    end;

    lValue := Trim(Copy(lLine, Pos(':', lLine) + 1, MaxInt));
    if lValue = '' then
    begin
      Exit(False);
    end;

    if TPath.IsPathRooted(lValue) then
    begin
      lGitDirValue := TPath.GetFullPath(lValue);
    end else begin
      lGitDirValue := TPath.GetFullPath(TPath.Combine(aWorkingTreeRoot, lValue));
    end;

    if not TDirectory.Exists(lGitDirValue) then
    begin
      Exit(False);
    end;

    aGitDirectory := lGitDirValue;
    Result := True;
  finally
    lGitFile.Free;
  end;
end;

function TryReadGitRemoteUrl(const aGitDirectory: string; out aRemoteUrl: string): Boolean;
var
  lConfigFile: string;
  lConfigLines: TStringList;
  lCurrentSection: string;
  lLine: string;
  lEqualsIndex: Integer;
  lKey: string;
  lValue: string;
  i: Integer;
begin
  Result := False;
  aRemoteUrl := '';
  lConfigFile := TPath.Combine(aGitDirectory, 'config');
  if not TFile.Exists(lConfigFile) then
  begin
    Exit(False);
  end;

  lConfigLines := TStringList.Create;
  try
    lConfigLines.LoadFromFile(lConfigFile, TEncoding.UTF8);
    lCurrentSection := '';
    for i := 0 to Pred(lConfigLines.Count) do
    begin
      lLine := Trim(lConfigLines[i]);
      if lLine = '' then
      begin
        Continue;
      end;
      if (lLine[1] = ';') or (lLine[1] = '#') then
      begin
        Continue;
      end;
      if (lLine[1] = '[') and (lLine[Length(lLine)] = ']') then
      begin
        lCurrentSection := LowerCase(Trim(Copy(lLine, 2, Length(lLine) - 2)));
        Continue;
      end;

      lEqualsIndex := Pos('=', lLine);
      if lEqualsIndex <= 0 then
      begin
        Continue;
      end;

      lKey := LowerCase(Trim(Copy(lLine, 1, lEqualsIndex - 1)));
      if not StartsText('remote ', lCurrentSection) then
      begin
        Continue;
      end;
      if lKey <> 'url' then
      begin
        Continue;
      end;

      lValue := Trim(Copy(lLine, lEqualsIndex + 1, MaxInt));
      if lValue <> '' then
      begin
        aRemoteUrl := lValue;
        Exit(True);
      end;
    end;
  finally
    lConfigLines.Free;
  end;
end;

function TryReadGitRemoteDefaultBranch(const aGitDirectory: string; out aBranch: string): Boolean;
var
  lHeadFile: string;
  lHeadText: string;
  lRefPrefix: string;
begin
  Result := False;
  aBranch := '';
  lHeadFile := TPath.Combine(aGitDirectory, 'refs\remotes\origin\HEAD');
  if not TFile.Exists(lHeadFile) then
  begin
    Exit(False);
  end;

  lHeadText := Trim(TFile.ReadAllText(lHeadFile, TEncoding.UTF8));
  lRefPrefix := 'ref: refs/remotes/origin/';
  if not StartsText(lRefPrefix, LowerCase(lHeadText)) then
  begin
    Exit(False);
  end;

  aBranch := Trim(Copy(lHeadText, Length(lRefPrefix) + 1, MaxInt));
  Result := aBranch <> '';
end;

function TryReadGitHeadBranch(const aGitDirectory: string; out aBranch: string): Boolean;
var
  lHeadFile: string;
  lHeadText: string;
  lRefPrefix: string;
begin
  Result := False;
  aBranch := '';
  lHeadFile := TPath.Combine(aGitDirectory, 'HEAD');
  if not TFile.Exists(lHeadFile) then
  begin
    Exit(False);
  end;

  lHeadText := Trim(TFile.ReadAllText(lHeadFile, TEncoding.UTF8));
  lRefPrefix := 'ref: refs/heads/';
  if not StartsText(lRefPrefix, LowerCase(lHeadText)) then
  begin
    Exit(TryReadGitRemoteDefaultBranch(aGitDirectory, aBranch));
  end;

  aBranch := Trim(Copy(lHeadText, Length(lRefPrefix) + 1, MaxInt));
  Result := aBranch <> '';
end;

function TryResolveGitSkillUrl(const aSkillFile: string; out aGitUrl: string): Boolean;
var
  lGitDirectory: string;
  lRepoRoot: string;
  lParentRoot: string;
  lRemoteUrl: string;
  lBranch: string;
  lBaseUrl: string;
  lRelativePath: string;
  lSegments: TArray<string>;
  i: Integer;
begin
  Result := False;
  aGitUrl := '';
  lRepoRoot := ExcludeTrailingPathDelimiter(TPath.GetDirectoryName(TPath.GetFullPath(aSkillFile)));
  while lRepoRoot <> '' do
  begin
    if TryGetGitDirectory(lRepoRoot, lGitDirectory) then
    begin
      Break;
    end;

    lParentRoot := ExtractFileDir(lRepoRoot);
    if SameText(lParentRoot, lRepoRoot) then
    begin
      lRepoRoot := '';
      Break;
    end;
    lRepoRoot := lParentRoot;
  end;

  if (lRepoRoot = '') or (lGitDirectory = '') then
  begin
    Exit(False);
  end;

  if not TryReadGitRemoteUrl(lGitDirectory, lRemoteUrl) then
  begin
    Exit(False);
  end;
  if not TryReadGitHeadBranch(lGitDirectory, lBranch) then
  begin
    Exit(False);
  end;

  lBaseUrl := NormalizeGitWebBaseUrl(lRemoteUrl);
  if lBaseUrl = '' then
  begin
    Exit(False);
  end;

  lRelativePath := ExtractRelativePath(IncludeTrailingPathDelimiter(lRepoRoot), TPath.GetFullPath(aSkillFile));
  lRelativePath := StringReplace(lRelativePath, '/', PathDelim, [rfReplaceAll]);
  lSegments := SplitString(lRelativePath, PathDelim);

  aGitUrl := lBaseUrl + '/blob/' + EncodeUrlPathSegment(lBranch);
  for i := 0 to Pred(Length(lSegments)) do
  begin
    if lSegments[i] = '' then
    begin
      Continue;
    end;
    aGitUrl := aGitUrl + '/' + EncodeUrlPathSegment(lSegments[i]);
  end;

  Result := True;
end;

function BuildResultMarkdownLine(const aResult: TSkillSearchResult; const aTargetPath: string): string;
var
  lDescription: string;
begin
  Result := Format('- [%s](%s)', [aResult.Name, aTargetPath]);
  lDescription := Trim(aResult.Description);
  if lDescription = '' then
  begin
    Exit;
  end;

  lDescription := StringReplace(lDescription, sLineBreak, ' ', [rfReplaceAll]);
  lDescription := StringReplace(lDescription, #13, ' ', [rfReplaceAll]);
  lDescription := StringReplace(lDescription, #10, ' ', [rfReplaceAll]);
  Result := Result + ' - ' + lDescription;
end;

function BuildResultsMarkdownList(const aResults: TArray<TSkillSearchResult>): string;
var
  i: Integer;
  lGitUrl: string;
  lTargetPath: string;
begin
  Result := '';
  for i := 0 to Pred(Length(aResults)) do
  begin
    if Result <> '' then
    begin
      Result := Result + sLineBreak;
    end;

    lTargetPath := aResults[i].SkillFile;
    if TryResolveGitSkillUrl(aResults[i].SkillFile, lGitUrl) then
    begin
      lTargetPath := lGitUrl;
    end;
    Result := Result + BuildResultMarkdownLine(aResults[i], lTargetPath);
  end;
end;

function BuildResultsMarkdownListForSkillRoots(const aResults: TArray<TSkillSearchResult>): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Pred(Length(aResults)) do
  begin
    if Result <> '' then
    begin
      Result := Result + sLineBreak;
    end;
    Result := Result + BuildResultMarkdownLine(aResults[i], aResults[i].SkillRoot);
  end;
end;

function DefaultSearchSortMode: TSearchSortMode;
begin
  Result := TSearchSortMode.ssmScore;
end;

function SearchSortModeToString(const aSortMode: TSearchSortMode): string;
begin
  case aSortMode of
    TSearchSortMode.ssmScore:
      Result := 'score';
    TSearchSortMode.ssmNameAsc:
      Result := 'name-asc';
    TSearchSortMode.ssmNameDesc:
      Result := 'name-desc';
    TSearchSortMode.ssmPathAsc:
      Result := 'path-asc';
    TSearchSortMode.ssmPathDesc:
      Result := 'path-desc';
    TSearchSortMode.ssmDateIndexedDesc:
      Result := 'date-indexed-desc';
  else
    Result := 'date-indexed-asc';
  end;
end;

function ShouldShowDuplicateDetails(const aDuplicateCount: Integer): Boolean;
begin
  Result := aDuplicateCount > 1;
end;

procedure SortSearchResults(var aResults: TArray<TSkillSearchResult>; const aSortMode: TSearchSortMode);
begin
  TArray.Sort<TSkillSearchResult>(
    aResults,
    TComparer<TSkillSearchResult>.Construct(
      function(const aLeft, aRight: TSkillSearchResult): Integer
      begin
        case aSortMode of
          TSearchSortMode.ssmScore:
            Result := CompareScoreDescending(aLeft, aRight);
          TSearchSortMode.ssmNameAsc:
            begin
              Result := CompareText(aLeft.Name, aRight.Name);
              if Result = 0 then
              begin
                Result := CompareText(aLeft.SkillRoot, aRight.SkillRoot);
              end;
            end;
          TSearchSortMode.ssmNameDesc:
            begin
              Result := CompareText(aRight.Name, aLeft.Name);
              if Result = 0 then
              begin
                Result := CompareText(aLeft.SkillRoot, aRight.SkillRoot);
              end;
            end;
          TSearchSortMode.ssmPathAsc:
            begin
              Result := CompareText(aLeft.SkillRoot, aRight.SkillRoot);
              if Result = 0 then
              begin
                Result := CompareText(aLeft.Name, aRight.Name);
              end;
            end;
          TSearchSortMode.ssmPathDesc:
            begin
              Result := CompareText(aRight.SkillRoot, aLeft.SkillRoot);
              if Result = 0 then
              begin
                Result := CompareText(aLeft.Name, aRight.Name);
              end;
            end;
          TSearchSortMode.ssmDateIndexedDesc:
            begin
              Result := CompareNullableText(aRight.IndexedUtc, aLeft.IndexedUtc);
              if Result = 0 then
              begin
                Result := CompareScoreDescending(aLeft, aRight);
              end;
            end;
        else
          begin
            Result := CompareNullableText(aLeft.IndexedUtc, aRight.IndexedUtc);
            if Result = 0 then
            begin
              Result := CompareScoreDescending(aLeft, aRight);
            end;
          end;
        end;
      end
    )
  );
end;

function TryBuildResultsMarkdownList(const aResults: TArray<TSkillSearchResult>; out aMarkdown: string): Boolean;
begin
  aMarkdown := BuildResultsMarkdownList(aResults);
  Result := aMarkdown <> '';
end;

function TryBuildResultsMarkdownListForSkillRoots(const aResults: TArray<TSkillSearchResult>;
  out aMarkdown: string): Boolean;
begin
  aMarkdown := BuildResultsMarkdownListForSkillRoots(aResults);
  Result := aMarkdown <> '';
end;

function TryParseSearchSortMode(const aValue: string; out aSortMode: TSearchSortMode): Boolean;
var
  lValue: string;
begin
  lValue := LowerCase(Trim(aValue));
  if lValue = 'score' then
  begin
    aSortMode := TSearchSortMode.ssmScore;
    Exit(True);
  end;
  if lValue = 'name-asc' then
  begin
    aSortMode := TSearchSortMode.ssmNameAsc;
    Exit(True);
  end;
  if lValue = 'name-desc' then
  begin
    aSortMode := TSearchSortMode.ssmNameDesc;
    Exit(True);
  end;
  if lValue = 'path-asc' then
  begin
    aSortMode := TSearchSortMode.ssmPathAsc;
    Exit(True);
  end;
  if lValue = 'path-desc' then
  begin
    aSortMode := TSearchSortMode.ssmPathDesc;
    Exit(True);
  end;
  if lValue = 'date-indexed-desc' then
  begin
    aSortMode := TSearchSortMode.ssmDateIndexedDesc;
    Exit(True);
  end;
  if lValue = 'date-indexed-asc' then
  begin
    aSortMode := TSearchSortMode.ssmDateIndexedAsc;
    Exit(True);
  end;

  aSortMode := DefaultSearchSortMode;
  Result := False;
end;

end.
