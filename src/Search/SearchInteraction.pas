unit SearchInteraction;

interface

uses
  System.Classes,
  SettingsModel;

type
  TMainFormFocusTarget = (
    mfftSearch,
    mfftResults
  );

  TPreparedSearchProc = reference to procedure(const aQuery: string);

procedure ExecuteHistorySelection(const aQuery: string; var aHistory: TSearchHistorySettings;
  const aApplySelectedQuery, aOnPrepared: TPreparedSearchProc);
procedure ExecuteImmediateSearch(const aQuery: string; var aHistory: TSearchHistorySettings;
  const aOnPrepared: TPreparedSearchProc);
function AppendTagFilterQuery(const aQuery, aTag: string): string;
function BuildSelectedTagsQuery(const aTags: TArray<string>): string;
function PrepareImmediateSearchQuery(const aQuery: string; var aHistory: TSearchHistorySettings): string;
function TryResolveMainFormFocusShortcut(const aKey: Word; const aShift: TShiftState;
  out aTarget: TMainFormFocusTarget): Boolean;
function ScaleStoredUiValue(const aValue, aStoredPPI, aCurrentPPI: Integer): Integer;

implementation

uses
  System.StrUtils, System.SysUtils,
  Winapi.Windows,
  Settings;

procedure ExecuteImmediateSearch(const aQuery: string; var aHistory: TSearchHistorySettings;
  const aOnPrepared: TPreparedSearchProc);
var
  lPreparedQuery: string;
begin
  lPreparedQuery := PrepareImmediateSearchQuery(aQuery, aHistory);
  if Assigned(aOnPrepared) then
  begin
    aOnPrepared(lPreparedQuery);
  end;
end;

procedure ExecuteHistorySelection(const aQuery: string; var aHistory: TSearchHistorySettings;
  const aApplySelectedQuery, aOnPrepared: TPreparedSearchProc);
begin
  if Assigned(aApplySelectedQuery) then
  begin
    aApplySelectedQuery(aQuery);
  end;
  ExecuteImmediateSearch(aQuery, aHistory, aOnPrepared);
end;

function AppendTagFilterQuery(const aQuery, aTag: string): string;
var
  lQuery: string;
  lTag: string;
  lTagToken: string;
begin
  lQuery := Trim(aQuery);
  lTag := Trim(aTag);
  if lTag = '' then
  begin
    Exit(lQuery);
  end;

  if ContainsText(lTag, ' ') then
  begin
    lTagToken := 'tag:"' + StringReplace(lTag, '"', '', [rfReplaceAll]) + '"';
  end else begin
    lTagToken := 'tag:' + lTag;
  end;

  if lQuery = '' then
  begin
    Exit(lTagToken);
  end;
  Result := lQuery + ' ' + lTagToken;
end;

function BuildSelectedTagsQuery(const aTags: TArray<string>): string;
var
  lClauses: TStringList;
  lTag: string;
  lTagToken: string;
  lJoined: string;
begin
  lClauses := TStringList.Create;
  try
    lClauses.CaseSensitive := False;

    for lTag in aTags do
    begin
      lTagToken := AppendTagFilterQuery('', lTag);
      if (lTagToken <> '') and (lClauses.IndexOf(lTagToken) < 0) then
      begin
        lClauses.Add(lTagToken);
      end;
    end;

    case lClauses.Count of
      0:
        Result := '';
      1:
        Result := lClauses[0];
    else
      begin
        lJoined := TrimRight(lClauses.Text);
        lJoined := StringReplace(lJoined, sLineBreak, ' OR ', [rfReplaceAll]);
        Result := '(' + lJoined + ')';
      end;
    end;
  finally
    lClauses.Free;
  end;
end;

function PrepareImmediateSearchQuery(const aQuery: string; var aHistory: TSearchHistorySettings): string;
begin
  Result := Trim(aQuery);
  PushSearchHistoryEntry(aHistory, Result);
end;

function TryResolveMainFormFocusShortcut(const aKey: Word; const aShift: TShiftState;
  out aTarget: TMainFormFocusTarget): Boolean;
begin
  Result := True;
  if (aKey = Ord('L')) and (aShift = [ssCtrl]) then
  begin
    aTarget := TMainFormFocusTarget.mfftSearch;
    Exit;
  end;

  if (aKey = Ord('R')) and (aShift = [ssCtrl]) then
  begin
    aTarget := TMainFormFocusTarget.mfftResults;
    Exit;
  end;

  aTarget := TMainFormFocusTarget.mfftSearch;
  Result := False;
end;

function ScaleStoredUiValue(const aValue, aStoredPPI, aCurrentPPI: Integer): Integer;
begin
  if (aValue = 0) or (aStoredPPI <= 0) or (aCurrentPPI <= 0) or (aStoredPPI = aCurrentPPI) then
  begin
    Exit(aValue);
  end;

  Result := MulDiv(aValue, aCurrentPPI, aStoredPPI);
end;

end.
