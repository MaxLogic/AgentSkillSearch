unit SearchInteraction;

interface

uses
  SettingsModel;

type
  TPreparedSearchProc = reference to procedure(const aQuery: string);

procedure ExecuteHistorySelection(const aQuery: string; var aHistory: TSearchHistorySettings;
  const aApplySelectedQuery, aOnPrepared: TPreparedSearchProc);
procedure ExecuteImmediateSearch(const aQuery: string; var aHistory: TSearchHistorySettings;
  const aOnPrepared: TPreparedSearchProc);
function AppendTagFilterQuery(const aQuery, aTag: string): string;
function PrepareImmediateSearchQuery(const aQuery: string; var aHistory: TSearchHistorySettings): string;
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

function PrepareImmediateSearchQuery(const aQuery: string; var aHistory: TSearchHistorySettings): string;
begin
  Result := Trim(aQuery);
  PushSearchHistoryEntry(aHistory, Result);
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
