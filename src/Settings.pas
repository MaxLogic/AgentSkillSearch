unit Settings;

interface

uses
  SettingsModel;

type
  TSettingsLoadResult = record
    RestoredKeys: TArray<string>;
    Settings: TAppSettings;
    SettingsPath: string;
  end;

function GetSettingsFilePath: string;
function LoadOrCreateSettings(const aSettingsPath: string): TSettingsLoadResult;
function NormalizeSearchHistory(const aItems: TArray<string>; const aMaxItems: Integer): TArray<string>;
procedure PushSearchHistoryEntry(var aHistory: TSearchHistorySettings; const aQuery: string);
function ResolveSettingsPath(const aValue, aBaseDirectory: string): string;
procedure SaveSearchHistory(const aSettingsPath: string; const aSearchHistory: TSearchHistorySettings);
procedure SaveUiState(const aSettingsPath: string; const aUiState: TUiStateSettings);

implementation

uses
  System.Classes, System.IOUtils, System.IniFiles, System.SysUtils,
  AppPaths, AutoFree, ExternalTools;

function ResolveSettingsPath(const aValue, aBaseDirectory: string): string;
begin
  if TPath.IsPathRooted(aValue) then
  begin
    Result := TPath.GetFullPath(aValue);
  end else begin
    Result := TPath.GetFullPath(TPath.Combine(aBaseDirectory, aValue));
  end;
end;

function GetSettingsFilePath: string;
begin
  Result := TPath.Combine(GetExeDirectory, 'settings.ini');
end;

function GetDefaultSourcesListTemplate: string;
begin
  Result :=
    '# Agent Skill Search sources list' + sLineBreak +
    '# One path per line. Supported comments: # ; //' + sLineBreak +
    '# Example: C:\projects\MaxLogic' + sLineBreak +
    '# Example: \\server\share\skills' + sLineBreak;
end;

function GetDefaultExcludesListTemplate: string;
begin
  Result :=
    '# Agent Skill Search exclusion patterns' + sLineBreak +
    '# Lines are case-insensitive substring or wildcard (*, ?) matches against full paths.' + sLineBreak +
    '# Seeded from diagnostics scan report 2026-02-11 (OpenClaw harness fixtures).' + sLineBreak +
    '*\OpenClaw\skills\skills\oakencore\skillvet\tests\fixtures\*' + sLineBreak +
    '*\OpenClaw\skills\skills\*\tmp\credentials-backup-*\*' + sLineBreak;
end;

procedure EnsureSourcesListTemplate(const aSourcesListPath: string);
begin
  if TFile.Exists(aSourcesListPath) then
  begin
    Exit;
  end;

  ForceDirectories(ExtractFilePath(aSourcesListPath));
  TFile.WriteAllText(aSourcesListPath, GetDefaultSourcesListTemplate, TEncoding.UTF8);
end;

procedure EnsureExcludesListTemplate(const aExcludesListPath: string);
begin
  if TFile.Exists(aExcludesListPath) then
  begin
    Exit;
  end;

  ForceDirectories(ExtractFilePath(aExcludesListPath));
  TFile.WriteAllText(aExcludesListPath, GetDefaultExcludesListTemplate, TEncoding.UTF8);
end;

procedure AddRestoredKey(var aResult: TSettingsLoadResult; const aSection, aKey: string);
var
  lLen: Integer;
begin
  lLen := Length(aResult.RestoredKeys);
  SetLength(aResult.RestoredKeys, lLen + 1);
  aResult.RestoredKeys[lLen] := aSection + '.' + aKey;
end;

procedure AddStringItem(var aItems: TArray<string>; const aValue: string);
var
  lLen: Integer;
begin
  lLen := Length(aItems);
  SetLength(aItems, lLen + 1);
  aItems[lLen] := aValue;
end;

procedure AddExternalTool(var aTools: TArray<TExternalToolSettings>; const aName, aCommandTemplate: string);
var
  lLen: Integer;
begin
  lLen := Length(aTools);
  SetLength(aTools, lLen + 1);
  aTools[lLen].Name := aName;
  aTools[lLen].CommandTemplate := aCommandTemplate;
end;

function BoolToIniValue(const aValue: Boolean): string;
begin
  if aValue then
  begin
    Result := '1';
  end else begin
    Result := '0';
  end;
end;

function IniValueToBool(const aValue: string; const aDefault: Boolean; out aValid: Boolean): Boolean;
var
  lBoolValue: Boolean;
  lIntValue: Integer;
  lTrimmed: string;
begin
  lTrimmed := Trim(aValue);
  if lTrimmed = '' then
  begin
    aValid := False;
    Exit(aDefault);
  end;

  if TryStrToInt(lTrimmed, lIntValue) then
  begin
    if (lIntValue = 0) or (lIntValue = 1) then
    begin
      aValid := True;
      Exit(lIntValue = 1);
    end;
    aValid := False;
    Exit(aDefault);
  end;

  if TryStrToBool(lTrimmed, lBoolValue) then
  begin
    aValid := True;
    Exit(lBoolValue);
  end;

  aValid := False;
  Result := aDefault;
end;

function NormalizeSearchHistory(const aItems: TArray<string>; const aMaxItems: Integer): TArray<string>;
var
  i: Integer;
  lLimit: Integer;
  lTrimmed: string;
begin
  lLimit := aMaxItems;
  if lLimit <= 0 then
  begin
    lLimit := 20;
  end;

  Result := nil;
  for i := 0 to Pred(Length(aItems)) do
  begin
    lTrimmed := Trim(aItems[i]);
    if lTrimmed = '' then
    begin
      Continue;
    end;
    if (Length(Result) > 0) and SameText(Result[High(Result)], lTrimmed) then
    begin
      Continue;
    end;

    AddStringItem(Result, lTrimmed);
    if Length(Result) >= lLimit then
    begin
      Break;
    end;
  end;
end;

procedure PushSearchHistoryEntry(var aHistory: TSearchHistorySettings; const aQuery: string);
var
  i: Integer;
  lItems: TArray<string>;
  lTrimmed: string;
begin
  aHistory.Items := NormalizeSearchHistory(aHistory.Items, aHistory.MaxItems);

  lTrimmed := Trim(aQuery);
  if lTrimmed = '' then
  begin
    Exit;
  end;
  if (Length(aHistory.Items) > 0) and SameText(aHistory.Items[0], lTrimmed) then
  begin
    Exit;
  end;

  AddStringItem(lItems, lTrimmed);
  for i := 0 to Pred(Length(aHistory.Items)) do
  begin
    if SameText(aHistory.Items[i], lTrimmed) then
    begin
      Continue;
    end;
    AddStringItem(lItems, aHistory.Items[i]);
  end;

  aHistory.Items := NormalizeSearchHistory(lItems, aHistory.MaxItems);
end;

function ReadRequiredString(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey, aDefault: string): string;
begin
  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, aDefault);
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  Result := Trim(aIni.ReadString(aSection, aKey, aDefault));
  if Result = '' then
  begin
    aIni.WriteString(aSection, aKey, aDefault);
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;
end;

function ReadRequiredStringAllowEmpty(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey,
  aDefault: string): string;
begin
  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, aDefault);
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  Result := aIni.ReadString(aSection, aKey, aDefault);
end;

function ReadRequiredInteger(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey: string;
  const aDefault: Integer): Integer;
var
  lRaw: string;
begin
  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, IntToStr(aDefault));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  lRaw := Trim(aIni.ReadString(aSection, aKey, IntToStr(aDefault)));
  if (not TryStrToInt(lRaw, Result)) then
  begin
    aIni.WriteString(aSection, aKey, IntToStr(aDefault));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;
end;

function ReadRequiredFloat(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey: string;
  const aDefault: Double): Double;
var
  lRaw: string;
  lInvariant: TFormatSettings;
begin
  lInvariant := TFormatSettings.Invariant;

  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, FloatToStr(aDefault, lInvariant));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  lRaw := Trim(aIni.ReadString(aSection, aKey, FloatToStr(aDefault, lInvariant)));
  if (not TryStrToFloat(lRaw, Result, lInvariant)) then
  begin
    aIni.WriteString(aSection, aKey, FloatToStr(aDefault, lInvariant));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;
end;

function ReadRequiredBool(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey: string;
  const aDefault: Boolean): Boolean;
var
  lRaw: string;
  lValid: Boolean;
begin
  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, BoolToIniValue(aDefault));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  lRaw := aIni.ReadString(aSection, aKey, BoolToIniValue(aDefault));
  Result := IniValueToBool(lRaw, aDefault, lValid);
  if not lValid then
  begin
    aIni.WriteString(aSection, aKey, BoolToIniValue(aDefault));
    AddRestoredKey(aResult, aSection, aKey);
    Result := aDefault;
  end;
end;

procedure WriteSettingsRecoveryLog(const aSettings: TAppSettings; const aBaseDirectory: string;
  const aRestoredKeys: TArray<string>);
var
  i: Integer;
  lLine: string;
  lLogPath: string;
begin
  if Length(aRestoredKeys) = 0 then
  begin
    Exit;
  end;

  lLogPath := ResolveSettingsPath(aSettings.General.LogPath, aBaseDirectory);
  ForceDirectories(ExtractFilePath(lLogPath));

  for i := 0 to Pred(Length(aRestoredKeys)) do
  begin
    lLine := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' [settings] restored missing key: ' + aRestoredKeys[i] + sLineBreak;
    TFile.AppendAllText(lLogPath, lLine, TEncoding.UTF8);
  end;
end;

procedure SaveUiState(const aSettingsPath: string; const aUiState: TUiStateSettings);
var
  lIni: TMemIniFile;
begin
  ForceDirectories(ExtractFilePath(aSettingsPath));
  lIni := TMemIniFile.Create(aSettingsPath, TEncoding.UTF8);
  try
    lIni.WriteInteger('UIState', 'CurrentPPI', aUiState.CurrentPPI);
    lIni.WriteInteger('UIState', 'DuplicateInfoWidth', aUiState.DuplicateInfoWidth);
    lIni.WriteString('UIState', 'LastQuery', aUiState.LastQuery);
    lIni.WriteString('UIState', 'ResultSortMode', aUiState.ResultSortMode);
    lIni.WriteString('UIState', 'ResultsColumnWidths', aUiState.ResultsColumnWidths);
    lIni.WriteInteger('UIState', 'ResultsPaneWidth', aUiState.ResultsPaneWidth);
    lIni.WriteString('UIState', 'SearchAsYouType', BoolToIniValue(aUiState.SearchAsYouType));
    lIni.WriteInteger('UIState', 'WindowHeight', aUiState.WindowHeight);
    lIni.WriteInteger('UIState', 'WindowLeft', aUiState.WindowLeft);
    lIni.WriteInteger('UIState', 'WindowTop', aUiState.WindowTop);
    lIni.WriteInteger('UIState', 'WindowWidth', aUiState.WindowWidth);
    lIni.UpdateFile;
  finally
    lIni.Free;
  end;
end;

procedure SaveSearchHistory(const aSettingsPath: string; const aSearchHistory: TSearchHistorySettings);
var
  i: Integer;
  lHistory: TSearchHistorySettings;
  lIni: TMemIniFile;
begin
  ForceDirectories(ExtractFilePath(aSettingsPath));
  lHistory := aSearchHistory;
  if lHistory.MaxItems <= 0 then
  begin
    lHistory.MaxItems := 20;
  end;
  lHistory.Items := NormalizeSearchHistory(lHistory.Items, lHistory.MaxItems);

  lIni := TMemIniFile.Create(aSettingsPath, TEncoding.UTF8);
  try
    lIni.EraseSection('SearchHistory');
    lIni.WriteInteger('SearchHistory', 'MaxItems', lHistory.MaxItems);
    for i := 0 to Pred(Length(lHistory.Items)) do
    begin
      lIni.WriteString('SearchHistory', Format('Item%d', [i]), lHistory.Items[i]);
    end;
    lIni.UpdateFile;
  finally
    lIni.Free;
  end;
end;

function LoadOrCreateSettings(const aSettingsPath: string): TSettingsLoadResult;
var
  i: Integer;
  lDefault: TAppSettings;
  lIni: TMemIniFile;
  lItemKey: string;
  lItemValue: string;
  lName: string;
  lSectionValues: TStringList;
  lSettingsDir: string;
begin
  lDefault := DefaultAppSettings;
  Result.SettingsPath := aSettingsPath;

  lSettingsDir := IncludeTrailingPathDelimiter(ExtractFilePath(aSettingsPath));
  ForceDirectories(lSettingsDir);

  lIni := TMemIniFile.Create(aSettingsPath, TEncoding.UTF8);
  try
    Result.Settings.General.SourcesListPath := ReadRequiredString(lIni, Result, 'General', 'SourcesListPath',
      lDefault.General.SourcesListPath);
    Result.Settings.General.CacheDbPath := ReadRequiredString(lIni, Result, 'General', 'CacheDbPath',
      lDefault.General.CacheDbPath);
    Result.Settings.General.ExcludesListPath := ReadRequiredString(lIni, Result, 'General', 'ExcludesListPath',
      lDefault.General.ExcludesListPath);
    Result.Settings.General.LogPath := ReadRequiredString(lIni, Result, 'General', 'LogPath',
      lDefault.General.LogPath);
    Result.Settings.General.MaxScanThreads := ReadRequiredInteger(lIni, Result, 'General', 'MaxScanThreads',
      lDefault.General.MaxScanThreads);
    Result.Settings.General.MaxGitPullThreads := ReadRequiredInteger(lIni, Result, 'General', 'MaxGitPullThreads',
      lDefault.General.MaxGitPullThreads);
    Result.Settings.General.MaxIndexThreads := ReadRequiredInteger(lIni, Result, 'General', 'MaxIndexThreads',
      lDefault.General.MaxIndexThreads);
    Result.Settings.General.MaxSearchThreads := ReadRequiredInteger(lIni, Result, 'General', 'MaxSearchThreads',
      lDefault.General.MaxSearchThreads);

    Result.Settings.Git.GitExePath := ReadRequiredString(lIni, Result, 'Git', 'GitExePath', lDefault.Git.GitExePath);
    Result.Settings.Git.PullEnabled := ReadRequiredBool(lIni, Result, 'Git', 'PullEnabled', lDefault.Git.PullEnabled);
    Result.Settings.Git.MinPullIntervalMinutes := ReadRequiredInteger(lIni, Result, 'Git',
      'MinPullIntervalMinutes', lDefault.Git.MinPullIntervalMinutes);
    Result.Settings.Git.GitPullTimeoutSeconds := ReadRequiredInteger(lIni, Result, 'Git',
      'GitPullTimeoutSeconds', lDefault.Git.GitPullTimeoutSeconds);
    Result.Settings.Git.GitPullArgs := ReadRequiredString(lIni, Result, 'Git', 'GitPullArgs',
      lDefault.Git.GitPullArgs);
    Result.Settings.Git.SkipFolders := ReadRequiredString(lIni, Result, 'Git', 'SkipFolders',
      lDefault.Git.SkipFolders);
    Result.Settings.Git.TreatWorktreesAsRepos := ReadRequiredBool(lIni, Result, 'Git', 'TreatWorktreesAsRepos',
      lDefault.Git.TreatWorktreesAsRepos);

    Result.Settings.Index.SkillFileName := ReadRequiredString(lIni, Result, 'Index', 'SkillFileName',
      lDefault.Index.SkillFileName);
    Result.Settings.Index.MaxSkillFileBytes := ReadRequiredInteger(lIni, Result, 'Index', 'MaxSkillFileBytes',
      lDefault.Index.MaxSkillFileBytes);
    Result.Settings.Index.ComputeHasScripts := ReadRequiredBool(lIni, Result, 'Index', 'ComputeHasScripts',
      lDefault.Index.ComputeHasScripts);
    Result.Settings.Index.ScriptExtensions := ReadRequiredString(lIni, Result, 'Index', 'ScriptExtensions',
      lDefault.Index.ScriptExtensions);
    Result.Settings.Index.HasScriptsMaxFilesToScan := ReadRequiredInteger(lIni, Result, 'Index',
      'HasScriptsMaxFilesToScan', lDefault.Index.HasScriptsMaxFilesToScan);
    Result.Settings.Index.HasScriptsSkipFolders := ReadRequiredString(lIni, Result, 'Index',
      'HasScriptsSkipFolders', lDefault.Index.HasScriptsSkipFolders);
    Result.Settings.Index.NormalizeLineEndings := ReadRequiredBool(lIni, Result, 'Index', 'NormalizeLineEndings',
      lDefault.Index.NormalizeLineEndings);

    Result.Settings.Docker.StartGpuCommand := ReadRequiredString(lIni, Result, 'Docker', 'StartGpuCommand',
      lDefault.Docker.StartGpuCommand);
    Result.Settings.Docker.HealthCheckCommand := ReadRequiredString(lIni, Result, 'Docker', 'HealthCheckCommand',
      lDefault.Docker.HealthCheckCommand);

    Result.Settings.Search.SearchAsYouType := ReadRequiredBool(lIni, Result, 'Search', 'SearchAsYouType',
      lDefault.Search.SearchAsYouType);
    Result.Settings.Search.SearchDebounceMs := ReadRequiredInteger(lIni, Result, 'Search', 'SearchDebounceMs',
      lDefault.Search.SearchDebounceMs);
    Result.Settings.Search.MaxResults := ReadRequiredInteger(lIni, Result, 'Search', 'MaxResults',
      lDefault.Search.MaxResults);
    Result.Settings.Search.RecentQueryLimit := ReadRequiredInteger(lIni, Result, 'Search', 'RecentQueryLimit',
      lDefault.Search.RecentQueryLimit);
    if Result.Settings.Search.RecentQueryLimit <= 0 then
    begin
      Result.Settings.Search.RecentQueryLimit := lDefault.Search.RecentQueryLimit;
      lIni.WriteString('Search', 'RecentQueryLimit', IntToStr(Result.Settings.Search.RecentQueryLimit));
      AddRestoredKey(Result, 'Search', 'RecentQueryLimit');
    end;
    Result.Settings.Search.SnippetMaxChars := ReadRequiredInteger(lIni, Result, 'Search', 'SnippetMaxChars',
      lDefault.Search.SnippetMaxChars);

    Result.Settings.Semantic.Enabled := ReadRequiredBool(lIni, Result, 'Semantic', 'Enabled',
      lDefault.Semantic.Enabled);
    Result.Settings.Semantic.Provider := ReadRequiredString(lIni, Result, 'Semantic', 'Provider',
      lDefault.Semantic.Provider);
    Result.Settings.Semantic.OllamaBaseUrl := ReadRequiredString(lIni, Result, 'Semantic', 'OllamaBaseUrl',
      lDefault.Semantic.OllamaBaseUrl);
    Result.Settings.Semantic.Model := ReadRequiredString(lIni, Result, 'Semantic', 'Model', lDefault.Semantic.Model);
    Result.Settings.Semantic.CandidateRerankCount := ReadRequiredInteger(lIni, Result, 'Semantic',
      'CandidateRerankCount', lDefault.Semantic.CandidateRerankCount);
    Result.Settings.Semantic.MinScoreToShow := ReadRequiredFloat(lIni, Result, 'Semantic', 'MinScoreToShow',
      lDefault.Semantic.MinScoreToShow);
    Result.Settings.Semantic.EmbeddingCache := ReadRequiredBool(lIni, Result, 'Semantic', 'EmbeddingCache',
      lDefault.Semantic.EmbeddingCache);

    Result.Settings.Ui.ShowPreviewPane := ReadRequiredBool(lIni, Result, 'UI', 'ShowPreviewPane',
      lDefault.Ui.ShowPreviewPane);
    Result.Settings.Ui.OpenFileOnEnter := ReadRequiredBool(lIni, Result, 'UI', 'OpenFileOnEnter',
      lDefault.Ui.OpenFileOnEnter);
    Result.Settings.Ui.TrayHotkey := ReadRequiredStringAllowEmpty(lIni, Result, 'UI', 'TrayHotkey',
      lDefault.Ui.TrayHotkey);

    lSectionValues := TStringList.Create;
    try
      lIni.ReadSectionValues('ExternalTools', lSectionValues);
      Result.Settings.ExternalTools := nil;
      for i := 0 to Pred(lSectionValues.Count) do
      begin
        lName := Trim(lSectionValues.Names[i]);
        lItemValue := Trim(lSectionValues.ValueFromIndex[i]);
        if (lName = '') or not IsExternalToolTemplateValid(lItemValue) then
        begin
          Continue;
        end;
        AddExternalTool(Result.Settings.ExternalTools, lName, lItemValue);
      end;
    finally
      lSectionValues.Free;
    end;

    Result.Settings.UiState.CurrentPPI := ReadRequiredInteger(lIni, Result, 'UIState', 'CurrentPPI',
      lDefault.UiState.CurrentPPI);
    Result.Settings.UiState.DuplicateInfoWidth := ReadRequiredInteger(lIni, Result, 'UIState', 'DuplicateInfoWidth',
      lDefault.UiState.DuplicateInfoWidth);
    Result.Settings.UiState.LastQuery := ReadRequiredStringAllowEmpty(lIni, Result, 'UIState', 'LastQuery',
      lDefault.UiState.LastQuery);
    Result.Settings.UiState.ResultSortMode := ReadRequiredStringAllowEmpty(lIni, Result, 'UIState',
      'ResultSortMode', lDefault.UiState.ResultSortMode);
    Result.Settings.UiState.ResultsColumnWidths := ReadRequiredStringAllowEmpty(lIni, Result, 'UIState',
      'ResultsColumnWidths',
      lDefault.UiState.ResultsColumnWidths);
    Result.Settings.UiState.ResultsPaneWidth := ReadRequiredInteger(lIni, Result, 'UIState', 'ResultsPaneWidth',
      lDefault.UiState.ResultsPaneWidth);
    Result.Settings.UiState.SearchAsYouType := ReadRequiredBool(lIni, Result, 'UIState', 'SearchAsYouType',
      lDefault.UiState.SearchAsYouType);
    Result.Settings.UiState.WindowHeight := ReadRequiredInteger(lIni, Result, 'UIState', 'WindowHeight',
      lDefault.UiState.WindowHeight);
    Result.Settings.UiState.WindowLeft := ReadRequiredInteger(lIni, Result, 'UIState', 'WindowLeft',
      lDefault.UiState.WindowLeft);
    Result.Settings.UiState.WindowTop := ReadRequiredInteger(lIni, Result, 'UIState', 'WindowTop',
      lDefault.UiState.WindowTop);
    Result.Settings.UiState.WindowWidth := ReadRequiredInteger(lIni, Result, 'UIState', 'WindowWidth',
      lDefault.UiState.WindowWidth);

    Result.Settings.SearchHistory.MaxItems := ReadRequiredInteger(lIni, Result, 'SearchHistory', 'MaxItems',
      Result.Settings.Search.RecentQueryLimit);
    if Result.Settings.SearchHistory.MaxItems <= 0 then
    begin
      Result.Settings.SearchHistory.MaxItems := Result.Settings.Search.RecentQueryLimit;
      lIni.WriteString('SearchHistory', 'MaxItems', IntToStr(Result.Settings.SearchHistory.MaxItems));
      AddRestoredKey(Result, 'SearchHistory', 'MaxItems');
    end;
    Result.Settings.SearchHistory.Items := nil;
    for i := 0 to Pred(Result.Settings.SearchHistory.MaxItems) do
    begin
      lItemKey := Format('Item%d', [i]);
      if not lIni.ValueExists('SearchHistory', lItemKey) then
      begin
        Continue;
      end;

      lItemValue := Trim(lIni.ReadString('SearchHistory', lItemKey, ''));
      if lItemValue = '' then
      begin
        Continue;
      end;
      AddStringItem(Result.Settings.SearchHistory.Items, lItemValue);
    end;
    Result.Settings.SearchHistory.Items := NormalizeSearchHistory(
      Result.Settings.SearchHistory.Items,
      Result.Settings.SearchHistory.MaxItems
    );

    lIni.UpdateFile;
  finally
    lIni.Free;
  end;

  EnsureSourcesListTemplate(ResolveSettingsPath(Result.Settings.General.SourcesListPath, lSettingsDir));
  EnsureExcludesListTemplate(ResolveSettingsPath(Result.Settings.General.ExcludesListPath, lSettingsDir));
  WriteSettingsRecoveryLog(Result.Settings, lSettingsDir, Result.RestoredKeys);
end;

end.
