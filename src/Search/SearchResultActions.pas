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
function DefaultSearchSortMode: TSearchSortMode;
function SearchSortModeToString(const aSortMode: TSearchSortMode): string;
function ShouldShowDuplicateDetails(const aDuplicateCount: Integer): Boolean;
procedure SortSearchResults(var aResults: TArray<TSkillSearchResult>; const aSortMode: TSearchSortMode);
function TryBuildResultsMarkdownList(const aResults: TArray<TSkillSearchResult>; out aMarkdown: string): Boolean;
function TryParseSearchSortMode(const aValue: string; out aSortMode: TSearchSortMode): Boolean;

implementation

uses
  System.Generics.Defaults, System.SysUtils;

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

function BuildResultsMarkdownList(const aResults: TArray<TSkillSearchResult>): string;
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
    Result := Result + Format('- [%s](%s)', [aResults[i].Name, aResults[i].SkillFile]);
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
