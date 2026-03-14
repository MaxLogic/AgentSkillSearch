unit PipelineTests;

interface

procedure RunPipelineTests;

implementation

uses
  System.Classes, System.Diagnostics, System.IniFiles, System.IOUtils, System.StrUtils, System.SyncObjs, System.SysUtils,
  Winapi.Messages, Winapi.Windows,
  Vcl.Forms, Vcl.Menus, Vcl.StdCtrls,
  AppPaths, DatabaseManager, DockerHealthMonitor, DockerStatusUi, ExternalTools, Logging, PipelineCoordinator, Settings,
  RelatedSkillActions, ScanActivityUi, ScanProgressBuffer, SettingsModel, SkillSearchService, SkillTypes,
  TagBrowserActions, TrayActions;

var
  gPartialEmbeddingRequestCount: Integer;

procedure AssertEqualInt(const aExpected, aActual: Integer; const aMessage: string);
begin
  if aExpected <> aActual then
  begin
    raise Exception.CreateFmt('%s | expected=%d actual=%d', [aMessage, aExpected, aActual]);
  end;
end;

procedure AssertEqualText(const aExpected, aActual: string; const aMessage: string);
begin
  if not SameText(aExpected, aActual) then
  begin
    raise Exception.CreateFmt('%s | expected="%s" actual="%s"', [aMessage, aExpected, aActual]);
  end;
end;

procedure AssertTrue(const aCondition: Boolean; const aMessage: string);
begin
  if not aCondition then
  begin
    raise Exception.Create(aMessage);
  end;
end;

function QuoteArg(const aValue: string): string;
begin
  Result := '"' + aValue + '"';
end;

function BuildPipelineOptionsFromSettings(const aSettings: TAppSettings): TPipelineOptions;
begin
  Result := DefaultPipelineOptions;
  Result.GitExePath := aSettings.Git.GitExePath;
  Result.GitPullArgs := aSettings.Git.GitPullArgs;
  Result.GitPullTimeoutSeconds := aSettings.Git.GitPullTimeoutSeconds;
  Result.IndexOptions.ComputeHasScripts := aSettings.Index.ComputeHasScripts;
  Result.IndexOptions.HasScriptsMaxFilesToScan := aSettings.Index.HasScriptsMaxFilesToScan;
  Result.IndexOptions.HasScriptsSkipFolders := aSettings.Index.HasScriptsSkipFolders;
  Result.IndexOptions.ScriptExtensions := aSettings.Index.ScriptExtensions;
  Result.MaxGitPullThreads := aSettings.General.MaxGitPullThreads;
  Result.MaxIndexThreads := aSettings.General.MaxIndexThreads;
  Result.MaxScanThreads := aSettings.General.MaxScanThreads;
  Result.MinPullIntervalMinutes := aSettings.Git.MinPullIntervalMinutes;
  Result.PullEnabled := aSettings.Git.PullEnabled;
  Result.SkipFolders := aSettings.Git.SkipFolders;
  Result.SkillFileName := aSettings.Index.SkillFileName;
  Result.TreatWorktreesAsRepos := aSettings.Git.TreatWorktreesAsRepos;
end;

function BuildIndexedSkill(const aSkillRoot, aTags: string): TIndexedSkill;
begin
  Result := Default(TIndexedSkill);
  Result.BodyHash := aSkillRoot;
  Result.BodyMarkdown := '# Skill' + sLineBreak + sLineBreak + 'Fixture body';
  Result.Description := 'Fixture';
  Result.FileMtimeUtc := '2026-03-12T00:00:00Z';
  Result.HasScripts := 0;
  Result.IndexedUtc := '2026-03-12T00:00:00Z';
  Result.Name := ExtractFileName(aSkillRoot);
  Result.RepoId := 0;
  Result.SkillFile := TPath.Combine(aSkillRoot, 'SKILL.md');
  Result.SkillRoot := aSkillRoot;
  Result.SourceId := 1;
  Result.Tags := aTags;
end;

function TryBuildTestEmbedding(const aText: string; out aVector: TArray<Single>): Boolean;
begin
  SetLength(aVector, 3);
  aVector[0] := Length(aText);
  aVector[1] := Length(Trim(aText));
  aVector[2] := 1.0;
  Result := True;
end;

function TryBuildUnavailableEmbedding(const aText: string; out aVector: TArray<Single>): Boolean;
begin
  aVector := nil;
  Result := False;
end;

function TryBuildPartialEmbedding(const aText: string; out aVector: TArray<Single>): Boolean;
begin
  Inc(gPartialEmbeddingRequestCount);
  if gPartialEmbeddingRequestCount = 1 then
  begin
    Exit(TryBuildTestEmbedding(aText, aVector));
  end;

  aVector := nil;
  Result := False;
end;

procedure RunShellOrFail(const aWorkingDir, aCommand: string);
var
  lCmdLine: string;
  lExitCode: Cardinal;
  lProcessInfo: TProcessInformation;
  lStartInfo: TStartupInfo;
  lWaitResult: Cardinal;
begin
  lStartInfo := Default(TStartupInfo);
  lStartInfo.cb := SizeOf(TStartupInfo);
  lStartInfo.dwFlags := STARTF_USESHOWWINDOW;
  lStartInfo.wShowWindow := SW_HIDE;

  lProcessInfo := Default(TProcessInformation);
  lCmdLine := 'cmd.exe /d /s /c "' + aCommand + '"';
  UniqueString(lCmdLine);

  if not CreateProcess(nil, PChar(lCmdLine), nil, nil, False, CREATE_NO_WINDOW, nil, PChar(aWorkingDir), lStartInfo,
    lProcessInfo) then
  begin
    RaiseLastOSError;
  end;

  try
    lWaitResult := WaitForSingleObject(lProcessInfo.hProcess, 120000);
    if lWaitResult = WAIT_TIMEOUT then
    begin
      TerminateProcess(lProcessInfo.hProcess, 124);
      raise Exception.CreateFmt('Command timed out: %s', [aCommand]);
    end;

    if not GetExitCodeProcess(lProcessInfo.hProcess, lExitCode) then
    begin
      RaiseLastOSError;
    end;

    if lExitCode <> 0 then
    begin
      raise Exception.CreateFmt('Command failed (%d): %s', [lExitCode, aCommand]);
    end;
  finally
    CloseHandle(lProcessInfo.hThread);
    CloseHandle(lProcessInfo.hProcess);
  end;
end;

procedure CreateRemoteBackedRepo(const aInfraRoot, aScanRoot, aRepoName: string; out aRepoPath: string);
var
  lRemotePath: string;
  lSeedPath: string;
  lSkillDir: string;
begin
  lRemotePath := TPath.Combine(aInfraRoot, aRepoName + '-remote.git');
  lSeedPath := TPath.Combine(aInfraRoot, aRepoName + '-seed');
  aRepoPath := TPath.Combine(aScanRoot, aRepoName);

  RunShellOrFail(aInfraRoot, 'git init --bare ' + QuoteArg(lRemotePath));
  RunShellOrFail(aInfraRoot, 'git clone ' + QuoteArg(lRemotePath) + ' ' + QuoteArg(lSeedPath));

  lSkillDir := TPath.Combine(lSeedPath, 'skill-' + aRepoName);
  ForceDirectories(lSkillDir);
  TFile.WriteAllText(TPath.Combine(lSkillDir, 'SKILL.md'), '# ' + aRepoName + sLineBreak + sLineBreak +
    'Pipeline test fixture skill', TEncoding.UTF8);

  RunShellOrFail(lSeedPath, 'git config user.email "tests@example.com"');
  RunShellOrFail(lSeedPath, 'git config user.name "Pipeline Tests"');
  RunShellOrFail(lSeedPath, 'git add .');
  RunShellOrFail(lSeedPath, 'git commit -m "seed"');
  RunShellOrFail(lSeedPath, 'git push origin HEAD');

  RunShellOrFail(aScanRoot, 'git clone ' + QuoteArg(lRemotePath) + ' ' + QuoteArg(aRepoPath));
end;

procedure CreateSyntheticRepoFixture(const aRootPath: string; const aRepoCount, aSkillsPerRepo: Integer);
var
  i: Integer;
  j: Integer;
  lRepoPath: string;
  lSkillPath: string;
  lSkillText: string;
begin
  for i := 1 to aRepoCount do
  begin
    lRepoPath := TPath.Combine(aRootPath, Format('repo-%d', [i]));
    ForceDirectories(TPath.Combine(lRepoPath, '.git'));

    for j := 1 to aSkillsPerRepo do
    begin
      lSkillPath := TPath.Combine(lRepoPath, Format('skill-%d', [j]));
      ForceDirectories(lSkillPath);
      lSkillText := '# Skill ' + IntToStr(i) + '-' + IntToStr(j) + sLineBreak + sLineBreak +
        'Description paragraph for pipeline cancellation test.' + sLineBreak;
      TFile.WriteAllText(TPath.Combine(lSkillPath, 'SKILL.md'), lSkillText, TEncoding.UTF8);
    end;
  end;
end;

procedure PrepareFixtureDirectory(const aRootName: string; out aFixtureRoot, aInfraRoot, aScanRoot: string);
begin
  aFixtureRoot := TPath.Combine(TPath.GetTempPath, aRootName);
  if TDirectory.Exists(aFixtureRoot) then
  begin
    TDirectory.Delete(aFixtureRoot, True);
  end;

  aInfraRoot := TPath.Combine(aFixtureRoot, 'infra');
  aScanRoot := TPath.Combine(aFixtureRoot, 'scan');
  ForceDirectories(aInfraRoot);
  ForceDirectories(aScanRoot);
end;

procedure TestPipelineHonorsComputeHasScriptsSetting;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lOptions: TPipelineOptions;
  lResult: TPipelineRunResult;
  lScanRoot: string;
  lSettings: TSettingsLoadResult;
  lSettingsPath: string;
  lSkillFile: string;
  lSkillRoot: string;
  lState: TSkillState;
  lUnusedInfraRoot: string;
  lUtf8: TStringList;
begin
  PrepareFixtureDirectory('SkillSearchPipelineSettingsFixture', lFixtureRoot, lUnusedInfraRoot, lScanRoot);

  lSkillRoot := TPath.Combine(lScanRoot, 'skill-settings');
  ForceDirectories(TPath.Combine(lSkillRoot, '.git'));
  ForceDirectories(TPath.Combine(lSkillRoot, 'scripts'));
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  TFile.WriteAllText(lSkillFile, '# Settings Fixture' + sLineBreak + sLineBreak + 'Body text', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lSkillRoot, 'scripts\runner.py'), 'print("ok")', TEncoding.UTF8);

  lSettingsPath := TPath.Combine(lFixtureRoot, 'runtime\settings.ini');
  ForceDirectories(ExtractFilePath(lSettingsPath));
  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('[Index]');
    lUtf8.Add('ComputeHasScripts=0');
    lUtf8.SaveToFile(lSettingsPath, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lSettings := LoadOrCreateSettings(lSettingsPath);
  AssertTrue(not lSettings.Settings.Index.ComputeHasScripts,
    'Expected test fixture settings to disable has-scripts computation');

  lOptions := BuildPipelineOptionsFromSettings(lSettings.Settings);
  lOptions.PullEnabled := False;
  lOptions.MaxGitPullThreads := 1;
  lOptions.MaxIndexThreads := 1;
  lOptions.MaxScanThreads := 1;

  lDbPath := ResolveSettingsPath(lSettings.Settings.General.CacheDbPath, ExtractFilePath(lSettings.SettingsPath));
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lResult := lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertEqualInt(0, lResult.ErrorCount, 'Pipeline run should not report errors');
    AssertTrue(lDbManager.TryGetSkillState(TPath.GetFullPath(lSkillFile), lState), 'Expected indexed skill row');
    AssertEqualInt(0, lState.HasScripts, 'Pipeline should honor ComputeHasScripts=0 from settings');
    AssertEqualInt(0, lState.ScriptsCount, 'Disabled script computation should keep scripts_count=0');
    AssertEqualText('', lState.ScriptsExts, 'Disabled script computation should keep scripts_exts empty');
  finally
    lDbManager.Free;
  end;
end;

procedure TestSettingsCreateUiStateAndSearchHistoryDefaults;
var
  lFixtureRoot: string;
  lIni: TMemIniFile;
  lLoadResult: TSettingsLoadResult;
  lSettingsPath: string;
  lUnusedInfraRoot: string;
  lUnusedScanRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchUiStateFixture', lFixtureRoot, lUnusedInfraRoot, lUnusedScanRoot);

  lSettingsPath := TPath.Combine(lFixtureRoot, 'runtime\settings.ini');
  ForceDirectories(ExtractFilePath(lSettingsPath));

  lLoadResult := LoadOrCreateSettings(lSettingsPath);
  AssertTrue(TFile.Exists(lSettingsPath), 'Expected settings.ini to be created');
  AssertEqualText(lSettingsPath, lLoadResult.SettingsPath, 'Expected load result to keep settings path');

  lIni := TMemIniFile.Create(lSettingsPath, TEncoding.UTF8);
  try
    AssertTrue(lIni.ValueExists('UIState', 'SearchAsYouType'),
      'Expected UIState.SearchAsYouType key to be created');
    AssertTrue(lIni.ValueExists('UIState', 'LastQuery'), 'Expected UIState.LastQuery key to be created');
    AssertTrue(lIni.ValueExists('UIState', 'ResultSortMode'), 'Expected UIState.ResultSortMode key to be created');
    AssertTrue(lIni.ValueExists('UIState', 'ResultsColumnWidths'),
      'Expected UIState.ResultsColumnWidths key to be created');
    AssertTrue(lIni.ValueExists('SearchHistory', 'MaxItems'),
      'Expected SearchHistory.MaxItems key to be created');
    AssertTrue(lIni.ValueExists('UI', 'SearchAsYouType'),
      'Expected UI.SearchAsYouType key to be created');
    AssertTrue(lIni.ValueExists('UI', 'TrayHotkey'),
      'Expected UI.TrayHotkey key to be created');
    AssertEqualInt(20, lIni.ReadInteger('SearchHistory', 'MaxItems', 0),
      'Expected SearchHistory.MaxItems default');
    AssertEqualText('', lIni.ReadString('UI', 'TrayHotkey', 'missing'),
      'Expected UI.TrayHotkey default to be empty');
  finally
    lIni.Free;
  end;
end;

procedure TestSettingsPersistUiStateAndSearchHistory;
var
  lFixtureRoot: string;
  lHistory: TSearchHistorySettings;
  lLoadResult: TSettingsLoadResult;
  lSettingsPath: string;
  lUiState: TUiStateSettings;
  lUnusedInfraRoot: string;
  lUnusedScanRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchUiStatePersistFixture', lFixtureRoot, lUnusedInfraRoot, lUnusedScanRoot);

  lSettingsPath := TPath.Combine(lFixtureRoot, 'runtime\settings.ini');
  ForceDirectories(ExtractFilePath(lSettingsPath));

  lLoadResult := LoadOrCreateSettings(lSettingsPath);

  lUiState := lLoadResult.Settings.UiState;
  lUiState.CurrentPPI := 144;
  lUiState.DuplicateInfoWidth := 260;
  lUiState.LastQuery := 'retry tag:docker';
  lUiState.ResultSortMode := 'name-desc';
  lUiState.ResultsColumnWidths := '220;90;250;540';
  lUiState.ResultsPaneWidth := 720;
  lUiState.SearchAsYouType := True;
  lUiState.WindowHeight := 900;
  lUiState.WindowLeft := 140;
  lUiState.WindowTop := 80;
  lUiState.WindowWidth := 1500;
  SaveUiState(lSettingsPath, lUiState);

  lHistory.MaxItems := 3;
  lHistory.Items := nil;
  PushSearchHistoryEntry(lHistory, 'retry');
  PushSearchHistoryEntry(lHistory, 'retry');
  PushSearchHistoryEntry(lHistory, 'backoff');
  PushSearchHistoryEntry(lHistory, 'jwt');
  PushSearchHistoryEntry(lHistory, 'retry');
  SaveSearchHistory(lSettingsPath, lHistory);

  lLoadResult := LoadOrCreateSettings(lSettingsPath);
  AssertEqualInt(144, lLoadResult.Settings.UiState.CurrentPPI, 'Expected saved UIState.CurrentPPI');
  AssertEqualInt(260, lLoadResult.Settings.UiState.DuplicateInfoWidth, 'Expected saved duplicate-info width');
  AssertEqualText('retry tag:docker', lLoadResult.Settings.UiState.LastQuery, 'Expected saved last query');
  AssertEqualText('name-desc', lLoadResult.Settings.UiState.ResultSortMode, 'Expected saved result sort mode');
  AssertEqualText('220;90;250;540', lLoadResult.Settings.UiState.ResultsColumnWidths,
    'Expected saved results column widths');
  AssertEqualInt(720, lLoadResult.Settings.UiState.ResultsPaneWidth, 'Expected saved results pane width');
  AssertTrue(lLoadResult.Settings.Ui.SearchAsYouType, 'Expected saved UI.SearchAsYouType preference');
  AssertTrue(lLoadResult.Settings.UiState.SearchAsYouType, 'Expected saved SearchAsYouType state');
  AssertEqualInt(900, lLoadResult.Settings.UiState.WindowHeight, 'Expected saved window height');
  AssertEqualInt(140, lLoadResult.Settings.UiState.WindowLeft, 'Expected saved window left');
  AssertEqualInt(80, lLoadResult.Settings.UiState.WindowTop, 'Expected saved window top');
  AssertEqualInt(1500, lLoadResult.Settings.UiState.WindowWidth, 'Expected saved window width');

  AssertEqualInt(3, lLoadResult.Settings.SearchHistory.MaxItems, 'Expected saved search history max items');
  AssertEqualInt(3, Length(lLoadResult.Settings.SearchHistory.Items), 'Expected trimmed search history length');
  AssertEqualText('retry', lLoadResult.Settings.SearchHistory.Items[0], 'Expected most recent query first');
  AssertEqualText('jwt', lLoadResult.Settings.SearchHistory.Items[1], 'Expected second-most recent query');
  AssertEqualText('backoff', lLoadResult.Settings.SearchHistory.Items[2], 'Expected oldest retained query last');
end;

procedure TestSettingsLoadExternalTools;
var
  lFixtureRoot: string;
  lLoadResult: TSettingsLoadResult;
  lSettingsPath: string;
  lUnusedInfraRoot: string;
  lUnusedScanRoot: string;
  lUtf8: TStringList;
begin
  PrepareFixtureDirectory('SkillSearchExternalToolsFixture', lFixtureRoot, lUnusedInfraRoot, lUnusedScanRoot);

  lSettingsPath := TPath.Combine(lFixtureRoot, 'runtime\settings.ini');
  ForceDirectories(ExtractFilePath(lSettingsPath));

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('[ExternalTools]');
    lUtf8.Add('Code=code {path}');
    lUtf8.Add('Explorer=explorer.exe {path}');
    lUtf8.Add('Broken=code');
    lUtf8.Add('Empty=');
    lUtf8.SaveToFile(lSettingsPath, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lLoadResult := LoadOrCreateSettings(lSettingsPath);
  AssertEqualInt(2, Length(lLoadResult.Settings.ExternalTools), 'Expected only valid external tools to load');
  AssertEqualText('Code', lLoadResult.Settings.ExternalTools[0].Name, 'Expected Code external tool name');
  AssertEqualText('code {path}', lLoadResult.Settings.ExternalTools[0].CommandTemplate,
    'Expected Code external tool template');
  AssertEqualText('Explorer', lLoadResult.Settings.ExternalTools[1].Name, 'Expected Explorer external tool name');
end;

procedure TestSettingsLoadTrayHotkey;
var
  lFixtureRoot: string;
  lLoadResult: TSettingsLoadResult;
  lSettingsPath: string;
  lUnusedInfraRoot: string;
  lUnusedScanRoot: string;
  lUtf8: TStringList;
begin
  PrepareFixtureDirectory('SkillSearchTrayHotkeyFixture', lFixtureRoot, lUnusedInfraRoot, lUnusedScanRoot);

  lSettingsPath := TPath.Combine(lFixtureRoot, 'runtime\settings.ini');
  ForceDirectories(ExtractFilePath(lSettingsPath));

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('[UI]');
    lUtf8.Add('TrayHotkey=Win+Shift+K');
    lUtf8.SaveToFile(lSettingsPath, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lLoadResult := LoadOrCreateSettings(lSettingsPath);
  AssertEqualText('Win+Shift+K', lLoadResult.Settings.Ui.TrayHotkey, 'Expected configured tray hotkey to load');
end;

procedure TestSettingsLoadSearchAsYouTypeUiPreference;
var
  lFixtureRoot: string;
  lLoadResult: TSettingsLoadResult;
  lSettingsPath: string;
  lUnusedInfraRoot: string;
  lUnusedScanRoot: string;
  lUtf8: TStringList;
begin
  PrepareFixtureDirectory('SkillSearchSearchAsYouTypeUiFixture', lFixtureRoot, lUnusedInfraRoot, lUnusedScanRoot);

  lSettingsPath := TPath.Combine(lFixtureRoot, 'runtime\settings.ini');
  ForceDirectories(ExtractFilePath(lSettingsPath));

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('[UI]');
    lUtf8.Add('SearchAsYouType=1');
    lUtf8.SaveToFile(lSettingsPath, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lLoadResult := LoadOrCreateSettings(lSettingsPath);
  AssertTrue(lLoadResult.Settings.Ui.SearchAsYouType,
    'Expected UI.SearchAsYouType preference to load into the UI settings record');
  AssertTrue(lLoadResult.Settings.UiState.SearchAsYouType,
    'Expected UI.SearchAsYouType preference to drive the restored search-as-you-type state');
end;

procedure TestExternalToolCommandFormatting;
var
  lCommandLine: string;
  lFixtureRoot: string;
  lLaunch: TExternalToolLaunch;
  lLaunchCommandLine: string;
  lLaunchName: string;
  lMenuItem: TMenuItem;
  lSearchPath: string;
  lShimPath: string;
  lPopupMenu: TPopupMenu;
  lTools: TArray<TExternalToolSettings>;
  lUnusedInfraRoot: string;
  lUnusedScanRoot: string;
begin
  AssertTrue(TryBuildExternalToolCommandLine('code {path}', 'C:\skills\retry patterns', lCommandLine),
    'Expected valid external tool command line');
  AssertEqualText('code "C:\skills\retry patterns"', lCommandLine,
    'Expected external tool path placeholder to be quoted');
  AssertTrue(TryBuildExternalToolCommandLine('cmd /c type {path}\readme.txt', 'C:\skills\retry patterns',
    lCommandLine), 'Expected placeholder replacement inside command arguments');
  AssertEqualText('cmd /c type "C:\skills\retry patterns"\readme.txt', lCommandLine,
    'Expected placeholder replacement inside command arguments');
  AssertTrue(not TryBuildExternalToolCommandLine('code', 'C:\skills\retry patterns', lCommandLine),
    'Expected missing {path} placeholder to be rejected');

  SetLength(lTools, 2);
  lTools[0].Name := 'Code';
  lTools[0].CommandTemplate := 'code {path}';
  lTools[1].Name := 'Explorer';
  lTools[1].CommandTemplate := 'explorer.exe {path}';

  AssertTrue(TryResolveExternalTool(lTools, 0, 'C:\skills\retry patterns', lLaunchName, lLaunchCommandLine),
    'Expected selected external tool to resolve from settings');
  AssertEqualText('Code', lLaunchName, 'Expected selected external tool caption');
  AssertEqualText('code "C:\skills\retry patterns"', lLaunchCommandLine,
    'Expected selected skill root to be substituted into external tool command');
  AssertTrue(not TryResolveExternalTool(lTools, 3, 'C:\skills\retry patterns', lLaunchName, lLaunchCommandLine),
    'Expected invalid tool index to be rejected');

  lPopupMenu := TPopupMenu.Create(nil);
  try
    lPopupMenu.Items.Add(TMenuItem.Create(lPopupMenu));
    lPopupMenu.Items[0].Caption := 'Copy Results as Markdown List';
    lPopupMenu.Items.Add(TMenuItem.Create(lPopupMenu));
    lPopupMenu.Items[1].Caption := 'Open File';

    PopulateExternalToolsPopupMenu(lPopupMenu, lTools, nil, 1);
    AssertEqualInt(5, lPopupMenu.Items.Count, 'Expected popup menu separator and two external tools');
    AssertEqualText('-', lPopupMenu.Items[1].Caption, 'Expected separator before external tools');
    AssertEqualText('Code', lPopupMenu.Items[2].Caption, 'Expected first external tool menu caption');
    AssertEqualInt(0, lPopupMenu.Items[2].Tag, 'Expected first external tool menu tag');
    AssertEqualText('Explorer', lPopupMenu.Items[3].Caption, 'Expected second external tool menu caption');
    AssertEqualInt(1, lPopupMenu.Items[3].Tag, 'Expected second external tool menu tag');
    AssertEqualText('Open File', lPopupMenu.Items[4].Caption, 'Expected existing menu items to stay after tool entries');
  finally
    lPopupMenu.Free;
  end;

  lMenuItem := TMenuItem.Create(nil);
  try
    lMenuItem.Tag := 1;
    AssertTrue(TryResolveExternalToolMenuClick(lMenuItem, lTools, 'C:\skills\retry patterns', lLaunchName,
      lLaunchCommandLine), 'Expected menu click resolution to use the selected skill root');
    AssertEqualText('Explorer', lLaunchName, 'Expected clicked menu caption to resolve to tool name');
    AssertEqualText('explorer.exe "C:\skills\retry patterns"', lLaunchCommandLine,
      'Expected menu click resolution to build launch command from selected skill root');
  finally
    lMenuItem.Free;
  end;

  PrepareFixtureDirectory('SkillSearchExternalToolsLaunchFixture', lFixtureRoot, lUnusedInfraRoot, lUnusedScanRoot);
  lShimPath := TPath.Combine(lFixtureRoot, 'bin\code.cmd');
  ForceDirectories(ExtractFilePath(lShimPath));
  TFile.WriteAllText(lShimPath, '@echo off' + sLineBreak + 'exit /b 0' + sLineBreak, TEncoding.ASCII);
  lSearchPath := ExtractFilePath(lShimPath);

  AssertTrue(TryPrepareExternalToolLaunch(lTools, 0, 'C:\skills\retry patterns', lSearchPath, '.CMD;.EXE', lLaunch),
    'Expected external tool launch preparation to resolve PATH shims');
  AssertEqualText(TPath.GetFullPath(lShimPath), lLaunch.ExecutablePath,
    'Expected PATH-based command to resolve to the shim file');
  AssertEqualText('"C:\skills\retry patterns"', lLaunch.Parameters,
    'Expected resolved launch to keep the selected skill root as parameters');
end;

procedure TestDatabaseSkillTagCounts;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lTags: TArray<TSkillTagInfo>;
  lUnusedInfraRoot: string;
  lUnusedScanRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchTagBrowserFixture', lFixtureRoot, lUnusedInfraRoot, lUnusedScanRoot);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;
    lDbManager.WriteBatch(
      nil,
      [
        BuildIndexedSkill('C:\skills\docker-delphi', 'docker;delphi'),
        BuildIndexedSkill('C:\skills\docker-only', 'docker'),
        BuildIndexedSkill('C:\skills\git-delphi', 'git;Delphi')
      ]
    );

    lTags := lDbManager.GetSkillTagCounts;
    AssertEqualInt(3, Length(lTags), 'Expected unique tags from the skill database');
    AssertEqualText('delphi', lTags[0].Name, 'Expected tag list to sort alphabetically');
    AssertEqualInt(2, lTags[0].SkillCount, 'Expected case-insensitive delphi tag count');
    AssertEqualText('docker', lTags[1].Name, 'Expected docker tag in second position');
    AssertEqualInt(2, lTags[1].SkillCount, 'Expected docker tag count');
    AssertEqualText('git', lTags[2].Name, 'Expected git tag in third position');
    AssertEqualInt(1, lTags[2].SkillCount, 'Expected git tag count');
  finally
    lDbManager.Free;
  end;
end;

procedure TestTagBrowserActions;
var
  lForm: TForm;
  lListBox: TListBox;
  lSelectedTag: string;
  lTags: TArray<TSkillTagInfo>;
begin
  SetLength(lTags, 2);
  lTags[0].Name := 'docker';
  lTags[0].SkillCount := 2;
  lTags[1].Name := 'git';
  lTags[1].SkillCount := 1;

  lForm := TForm.Create(nil);
  try
    lListBox := TListBox.Create(lForm);
    lListBox.Parent := lForm;
    PopulateTagListBox(lListBox, lTags);
    AssertEqualInt(2, lListBox.Items.Count, 'Expected one list-box row per tag');
    AssertEqualText('docker (2)', lListBox.Items[0], 'Expected formatted tag count text');
    AssertEqualText('git (1)', lListBox.Items[1], 'Expected formatted tag count text');

    lListBox.ItemIndex := 1;
    AssertTrue(TryGetSelectedTag(lListBox, lTags, lSelectedTag), 'Expected selected tag lookup from the list box');
    AssertEqualText('git', lSelectedTag, 'Expected selected tag name to map from the clicked row');
  finally
    lForm.Free;
  end;
end;

procedure TestRelatedSkillActions;
var
  lForm: TForm;
  lItems: TArray<TRelatedSkillResult>;
  lListBox: TListBox;
  lSelectedItem: TRelatedSkillResult;
begin
  SetLength(lItems, 2);
  lItems[0].Name := 'Retry Patterns Copy';
  lItems[0].SkillRoot := 'C:\skills\repo-delta\retry-patterns-copy';
  lItems[1].Name := 'Backoff Strategy';
  lItems[1].SkillRoot := 'C:\skills\repo-epsilon\backoff-basics';

  lForm := TForm.Create(nil);
  try
    lListBox := TListBox.Create(lForm);
    lListBox.Parent := lForm;

    PopulateRelatedSkillsListBox(lListBox, lItems);
    AssertEqualInt(2, lListBox.Items.Count, 'Expected one list-box row per related skill');
    AssertTrue(ContainsText(lListBox.Items[0], 'Retry Patterns Copy'),
      'Expected first related skill caption in the list box');

    lListBox.ItemIndex := 1;
    AssertTrue(TryGetSelectedRelatedSkill(lListBox, lItems, lSelectedItem),
      'Expected related-skill selection lookup from the list box');
    AssertEqualText('Backoff Strategy', lSelectedItem.Name, 'Expected selected related skill to match list row');
  finally
    lForm.Free;
  end;
end;

procedure TestResolveRelatedSkillNavigation;
var
  lItems: TArray<TRelatedSkillResult>;
  lNavigation: TRelatedSkillNavigation;
  lResults: TArray<TSkillSearchResult>;
begin
  SetLength(lItems, 1);
  lItems[0].Name := 'Retry Patterns Copy';
  lItems[0].SkillFile := 'C:\skills\repo-delta\retry-patterns-copy\SKILL.md';
  lItems[0].SkillRoot := 'C:\skills\repo-delta\retry-patterns-copy';

  SetLength(lResults, 2);
  lResults[0] := Default(TSkillSearchResult);
  lResults[0].Name := 'Retry Patterns';
  lResults[0].SkillFile := 'C:\skills\repo-alpha\retry-patterns\SKILL.md';
  lResults[1] := Default(TSkillSearchResult);
  lResults[1].Name := 'Retry Patterns Copy';
  lResults[1].SkillFile := lItems[0].SkillFile;

  lNavigation := ResolveRelatedSkillNavigation(lItems[0], lResults);
  AssertTrue(lNavigation.Action = TRelatedSkillAction.rsaSelectResult,
    'Expected in-result related skill to request list selection');
  AssertEqualInt(1, lNavigation.ResultIndex, 'Expected related-skill navigation to point at the matching result');
  AssertEqualText(lItems[0].SkillFile, lNavigation.SkillFile, 'Expected related-skill navigation to keep skill file');

  SetLength(lResults, 1);
  lResults[0] := Default(TSkillSearchResult);
  lResults[0].Name := 'Different Skill';
  lResults[0].SkillFile := 'C:\skills\repo-other\different\SKILL.md';

  lNavigation := ResolveRelatedSkillNavigation(lItems[0], lResults);
  AssertTrue(lNavigation.Action = TRelatedSkillAction.rsaOpenFile,
    'Expected missing related skill to request direct file open');
  AssertEqualInt(-1, lNavigation.ResultIndex,
    'Expected direct-open navigation to avoid selecting a result list row');
  AssertEqualText(lItems[0].SkillFile, lNavigation.SkillFile, 'Expected direct-open navigation to target skill file');
end;

procedure TestPipelineReportsEmbeddingProgress;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lOptions: TPipelineOptions;
  lProgressEvents: TStringList;
  lScanRoot: string;
  lUnusedInfraRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchEmbeddingProgressFixture', lFixtureRoot, lUnusedInfraRoot, lScanRoot);
  CreateSyntheticRepoFixture(lScanRoot, 1, 2);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  lProgressEvents := TStringList.Create;
  try
    lDbManager.Initialize;

    lOptions := DefaultPipelineOptions;
    lOptions.MaxGitPullThreads := 1;
    lOptions.MaxIndexThreads := 1;
    lOptions.MaxScanThreads := 1;
    lOptions.PullEnabled := False;
    lOptions.SemanticOptions.Enabled := True;
    lOptions.SemanticOptions.Model := 'mxbai-embed-large';
    lOptions.SemanticOptions.EmbeddingRequester := TryBuildTestEmbedding;
    lOptions.OnEmbeddingProgress :=
      procedure(const aCurrent, aTotal: Integer; const aStatusText: string)
      begin
        lProgressEvents.Add(aStatusText);
      end;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertTrue(lProgressEvents.Count > 0, 'Expected embedding progress callbacks during pipeline run');
    AssertTrue(ContainsText(lProgressEvents.Text, 'Embedding 1 /'),
      'Expected progress text to include an embedding count');
  finally
    lProgressEvents.Free;
    lDbManager.Free;
  end;
end;

procedure TestPipelineReportsEmbeddingUnavailable;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lOptions: TPipelineOptions;
  lProgressEvents: TStringList;
  lScanRoot: string;
  lUnusedInfraRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchEmbeddingUnavailableFixture', lFixtureRoot, lUnusedInfraRoot, lScanRoot);
  CreateSyntheticRepoFixture(lScanRoot, 1, 1);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  lProgressEvents := TStringList.Create;
  try
    lDbManager.Initialize;

    lOptions := DefaultPipelineOptions;
    lOptions.MaxGitPullThreads := 1;
    lOptions.MaxIndexThreads := 1;
    lOptions.MaxScanThreads := 1;
    lOptions.PullEnabled := False;
    lOptions.SemanticOptions.Enabled := True;
    lOptions.SemanticOptions.Model := 'mxbai-embed-large';
    lOptions.SemanticOptions.EmbeddingRequester := TryBuildUnavailableEmbedding;
    lOptions.OnEmbeddingProgress :=
      procedure(const aCurrent, aTotal: Integer; const aStatusText: string)
      begin
        lProgressEvents.Add(aStatusText);
      end;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertTrue(ContainsText(lProgressEvents.Text, 'Embedding unavailable'),
      'Expected embedding-unavailable notice when embeddings cannot be requested');
  finally
    lProgressEvents.Free;
    lDbManager.Free;
  end;
end;

procedure TestPipelineReportsEmbeddingUnavailableWhenSkillRemainsPartial;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lOptions: TPipelineOptions;
  lProgressEvents: TStringList;
  lScanRoot: string;
  lSkillFile: string;
  lSkillRoot: string;
  lUnusedInfraRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchEmbeddingPartialFixture', lFixtureRoot, lUnusedInfraRoot, lScanRoot);
  lSkillRoot := TPath.Combine(lScanRoot, 'repo-partial');
  ForceDirectories(TPath.Combine(lSkillRoot, '.git'));
  ForceDirectories(TPath.Combine(lSkillRoot, 'skill-partial'));
  lSkillFile := TPath.Combine(lSkillRoot, 'skill-partial\SKILL.md');
  TFile.WriteAllText(
    lSkillFile,
    '# Partial Skill' + sLineBreak + sLineBreak + StringOfChar('A', 700) + sLineBreak + sLineBreak +
      StringOfChar('B', 700),
    TEncoding.UTF8
  );

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  lProgressEvents := TStringList.Create;
  try
    lDbManager.Initialize;

    gPartialEmbeddingRequestCount := 0;
    lOptions := DefaultPipelineOptions;
    lOptions.MaxGitPullThreads := 1;
    lOptions.MaxIndexThreads := 1;
    lOptions.MaxScanThreads := 1;
    lOptions.PullEnabled := False;
    lOptions.SemanticOptions.Enabled := True;
    lOptions.SemanticOptions.Model := 'mxbai-embed-large';
    lOptions.SemanticOptions.EmbeddingRequester := TryBuildPartialEmbedding;
    lOptions.OnEmbeddingProgress :=
      procedure(const aCurrent, aTotal: Integer; const aStatusText: string)
      begin
        lProgressEvents.Add(aStatusText);
      end;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertTrue(ContainsText(lProgressEvents.Text, 'Embedding unavailable'),
      'Expected embedding-unavailable notice when any chunk embedding still fails');
  finally
    lProgressEvents.Free;
    lDbManager.Free;
  end;
end;

procedure TestTrayActions;
var
  lError: string;
  lHotkey: TTrayHotkey;
  lState: TTrayWindowState;
begin
  lState := DefaultTrayWindowState;
  AssertTrue(lState.WindowVisible, 'Expected default tray state to start with the window visible');
  AssertTrue(not lState.TrayIconVisible, 'Expected default tray state to start without a tray icon');
  AssertTrue(not lState.ExitRequested, 'Expected default tray state to start without an exit request');

  lState := ApplyHideToTray(lState);
  AssertTrue(lState.TrayIconVisible, 'Expected hide-to-tray transition to set the tray icon visible');
  AssertTrue(not lState.WindowVisible, 'Expected hide-to-tray transition to hide the window');

  lState := ApplyRestoreFromTray(lState);
  AssertTrue(not lState.TrayIconVisible, 'Expected restore transition to remove the tray icon');
  AssertTrue(lState.WindowVisible, 'Expected restore transition to show the window');

  lState := ApplyTrayExitRequest(lState);
  AssertTrue(lState.ExitRequested, 'Expected tray Exit transition to mark an explicit exit request');
  AssertTrue(ShouldHideToTrayOnClose(False), 'Expected normal window close to hide to tray');
  AssertTrue(not ShouldHideToTrayOnClose(True), 'Expected explicit exit request to bypass tray hiding');

  AssertTrue(ResolveTrayMessageAction(WM_LBUTTONDBLCLK) = TTrayMessageAction.tmaRestore,
    'Expected tray double-click to restore the main window');
  AssertTrue(ResolveTrayMessageAction(WM_CONTEXTMENU) = TTrayMessageAction.tmaShowMenu,
    'Expected tray context menu message to open the tray menu');
  AssertTrue(ResolveTrayMessageAction(WM_RBUTTONUP) = TTrayMessageAction.tmaShowMenu,
    'Expected tray right-button release to open the tray menu');

  AssertTrue(TryParseTrayHotkey('Win+Shift+K', lHotkey, lError), 'Expected Win+Shift+K to parse as a tray hotkey');
  AssertEqualInt(MOD_WIN or MOD_SHIFT, lHotkey.Modifiers, 'Expected tray hotkey modifiers to match the setting');
  AssertEqualInt(Ord('K'), lHotkey.VirtualKey, 'Expected tray hotkey virtual key to match the setting');

  AssertTrue(not TryParseTrayHotkey('Win+Shift', lHotkey, lError),
    'Expected tray hotkey without a primary key to be rejected');
  AssertTrue(Pos('primary key', LowerCase(lError)) > 0, 'Expected missing-key tray hotkey parse message');

  AssertTrue(not TryParseTrayHotkey('Win+Nope+K', lHotkey, lError),
    'Expected unknown tray hotkey token to be rejected');
  AssertTrue(Pos('unknown', LowerCase(lError)) > 0, 'Expected unknown-token tray hotkey parse message');

  AssertTrue(not TryParseTrayHotkey('K', lHotkey, lError),
    'Expected tray hotkey without modifiers to be rejected');
  AssertTrue(Pos('modifier', LowerCase(lError)) > 0, 'Expected modifier-required tray hotkey parse message');

  AssertTrue(not TryParseTrayHotkey('', lHotkey, lError), 'Expected empty tray hotkey to mean not configured');
  AssertEqualText('', lError, 'Expected empty tray hotkey to return no parse error');
end;

procedure TestPipelineAutoCancelStopsBeforeDbWrites;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lOptions: TPipelineOptions;
  lResult: TPipelineRunResult;
  lScanRoot: string;
  lUnusedInfraRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchPipelineFixture', lFixtureRoot, lUnusedInfraRoot, lScanRoot);
  CreateSyntheticRepoFixture(lScanRoot, 1, 0);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    lOptions := DefaultPipelineOptions;
    lOptions.AutoCancelAfterMs := 1;
    lOptions.DbBatchSize := 20;
    lOptions.MaxScanThreads := 1;
    lOptions.PullEnabled := False;
    lOptions.SimulationDelayMs := 25;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lResult := lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertTrue(lResult.Cancelled, 'Expected pipeline cancellation flag to be set');
    AssertTrue(lResult.ReposQueued > 0, 'Fixture should discover a repo before auto-cancel triggers');
    AssertTrue(lResult.ErrorCount = 0, 'Expected no pipeline processing errors when pull is disabled');
    AssertEqualInt(0, lResult.ReposWritten, 'Cancelled pipeline should not write repo batches');
    AssertEqualInt(0, lDbManager.GetRepoCount, 'Repo writes should remain at zero after cancellation');
  finally
    lDbManager.Free;
  end;
end;

procedure TestDockerHealthMonitorStopDropsQueuedCallbacks;
var
  lCallbackCount: Integer;
  lMonitor: TDockerHealthMonitor;
begin
  lCallbackCount := 0;
  lMonitor := TDockerHealthMonitor.Create(
    'ver',
    1000,
    procedure(const aState: TDockerHealthState; const aDetail: string)
    begin
      TInterlocked.Increment(lCallbackCount);
    end
  );
  try
    lMonitor.Start;
    Sleep(600);
    lMonitor.Stop;
  finally
    lMonitor.Free;
  end;

  CheckSynchronize(200);
  AssertEqualInt(0, TInterlocked.CompareExchange(lCallbackCount, 0, 0),
    'Stopped docker monitor should not dispatch queued callbacks');
end;

procedure TestDockerStatusUiStateHidesAlertWhenHealthy;
var
  lUiState: TDockerStatusUiState;
begin
  lUiState := BuildDockerStatusUiState(TDockerHealthState.dhsHealthy, 'ollama container running', '', False);

  AssertEqualText('Ollama: running', lUiState.StatusText, 'Healthy docker status text mismatch');
  AssertTrue(not lUiState.ShowAlert, 'Healthy docker state should hide alert panel');
  AssertEqualText('', lUiState.AlertText, 'Healthy docker state should clear alert text');
end;

procedure TestDockerStatusUiStateShowsDockerAlert;
var
  lUiState: TDockerStatusUiState;
begin
  lUiState := BuildDockerStatusUiState(
    TDockerHealthState.dhsUnhealthy,
    'docker is not available: error during connect',
    '',
    False
  );

  AssertEqualText('Docker: unavailable', lUiState.StatusText, 'Docker-unavailable status text mismatch');
  AssertTrue(lUiState.ShowAlert, 'Docker outage should show the alert panel');
  AssertEqualText('Docker is not running. Start the local stack to enable Ollama.', lUiState.AlertText,
    'Docker outage alert text mismatch');
end;

procedure TestDockerStatusUiStateShowsOllamaAlert;
var
  lUiState: TDockerStatusUiState;
begin
  lUiState := BuildDockerStatusUiState(
    TDockerHealthState.dhsUnhealthy,
    'ollama container is not running',
    '',
    False
  );

  AssertEqualText('Ollama: unavailable', lUiState.StatusText, 'Ollama-unavailable status text mismatch');
  AssertTrue(lUiState.ShowAlert, 'Stopped Ollama container should show the alert panel');
  AssertEqualText('Ollama is not running. Start the local stack to enable semantic search.', lUiState.AlertText,
    'Ollama outage alert text mismatch');
end;

procedure TestDockerStatusUiStateHidesAlertWhileStarting;
var
  lUiState: TDockerStatusUiState;
begin
  lUiState := BuildDockerStatusUiState(TDockerHealthState.dhsUnhealthy, 'docker is not available', '', True);

  AssertEqualText('Ollama: starting...', lUiState.StatusText, 'Starting docker status text mismatch');
  AssertTrue(not lUiState.ShowAlert, 'Startup-in-progress should hide the alert panel');
end;

procedure TestDockerStatusUiStateShowsExplicitStartFailure;
var
  lUiState: TDockerStatusUiState;
begin
  lUiState := BuildDockerStatusUiState(
    TDockerHealthState.dhsUnknown,
    '',
    'Docker or Ollama is not running. Start the local stack now.',
    False
  );

  AssertEqualText('Ollama: unavailable', lUiState.StatusText, 'Explicit start failure should surface unavailable status');
  AssertTrue(lUiState.ShowAlert, 'Explicit start failure should show the alert panel');
  AssertEqualText('Docker or Ollama is not running. Start the local stack now.', lUiState.AlertText,
    'Explicit start failure alert text mismatch');
end;

procedure TestScanActivitySummaryIncludesCountsAndElapsed;
var
  lSnapshot: TScanActivitySnapshot;
  lSummary: string;
begin
  lSnapshot := Default(TScanActivitySnapshot);
  lSnapshot.ElapsedMs := 83000;
  lSnapshot.ReposFound := 4;
  lSnapshot.ReposPulled := 2;
  lSnapshot.ReposThrottled := 1;
  lSnapshot.SkillsFound := 37;
  lSnapshot.SkillsWritten := 21;
  lSnapshot.StatusText := 'Embedding 3 / 10 skills...';

  lSummary := BuildScanActivitySummary(lSnapshot);

  AssertTrue(ContainsText(lSummary, 'Repos: 4 found'), 'Summary should include repo count');
  AssertTrue(ContainsText(lSummary, '2 pulled'), 'Summary should include pulled repo count');
  AssertTrue(ContainsText(lSummary, '1 throttled'), 'Summary should include throttled repo count');
  AssertTrue(ContainsText(lSummary, 'Skills: 37 found'), 'Summary should include discovered skill count');
  AssertTrue(ContainsText(lSummary, '21 written'), 'Summary should include written skill count');
  AssertTrue(ContainsText(lSummary, 'Elapsed: 00:01:23'), 'Summary should include formatted elapsed time');
  AssertTrue(ContainsText(lSummary, 'Stage: Embedding 3 / 10 skills...'), 'Summary should include the stage text');
end;

procedure TestPipelineReportsProgressCounts;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lLastProgress: TPipelineProgress;
  lProgressCalls: Integer;
  lOptions: TPipelineOptions;
  lScanRoot: string;
  lUnusedInfraRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchPipelineProgressFixture', lFixtureRoot, lUnusedInfraRoot, lScanRoot);
  CreateSyntheticRepoFixture(lScanRoot, 1, 2);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    lProgressCalls := 0;
    lLastProgress := Default(TPipelineProgress);
    lOptions := DefaultPipelineOptions;
    lOptions.MaxGitPullThreads := 1;
    lOptions.MaxIndexThreads := 1;
    lOptions.MaxScanThreads := 1;
    lOptions.PullEnabled := False;
    lOptions.OnProgress :=
      procedure(const aProgress: TPipelineProgress)
      begin
        Inc(lProgressCalls);
        lLastProgress := aProgress;
      end;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertTrue(lProgressCalls > 0, 'Expected pipeline progress callbacks');
    AssertTrue(lLastProgress.ReposFound > 0, 'Expected progress to report discovered repos');
    AssertTrue(lLastProgress.SkillsFound > 0, 'Expected progress to report discovered skills');
  finally
    lDbManager.Free;
  end;
end;

procedure TestScanProgressBufferCoalescesToLatestProgress;
var
  lBuffer: TScanProgressBuffer;
  lConsumed: TPipelineProgress;
  lFirst: TPipelineProgress;
  lSecond: TPipelineProgress;
begin
  lBuffer := TScanProgressBuffer.Create;
  try
    lFirst := Default(TPipelineProgress);
    lFirst.ReposFound := 2;
    lFirst.SkillsFound := 10;
    lFirst.StatusText := 'Scanning source folders...';

    lSecond := Default(TPipelineProgress);
    lSecond.ReposFound := 7;
    lSecond.SkillsFound := 42;
    lSecond.StatusText := 'Indexing skills...';

    lBuffer.Publish(lFirst);
    lBuffer.Publish(lSecond);

    AssertTrue(lBuffer.TryConsume(lConsumed), 'Expected latest progress snapshot to be available');
    AssertEqualInt(7, lConsumed.ReposFound, 'Expected latest repo count to win');
    AssertEqualInt(42, lConsumed.SkillsFound, 'Expected latest skill count to win');
    AssertEqualText('Indexing skills...', lConsumed.StatusText, 'Expected latest status text to win');
    AssertTrue(not lBuffer.TryConsume(lConsumed), 'Expected progress buffer to drain after one consume');
  finally
    lBuffer.Free;
  end;
end;

procedure TestScanProgressBufferKeepsCountsWhenOnlyStatusChanges;
var
  lBuffer: TScanProgressBuffer;
  lConsumed: TPipelineProgress;
  lProgress: TPipelineProgress;
begin
  lBuffer := TScanProgressBuffer.Create;
  try
    lProgress := Default(TPipelineProgress);
    lProgress.ReposFound := 5;
    lProgress.SkillsFound := 19;
    lProgress.SkillsWritten := 11;
    lProgress.StatusText := 'Writing skill cache...';

    lBuffer.Publish(lProgress);
    lBuffer.PublishStatus('Warming embeddings...');

    AssertTrue(lBuffer.TryConsume(lConsumed), 'Expected status-only update to remain consumable');
    AssertEqualInt(5, lConsumed.ReposFound, 'Status-only update should preserve repo count');
    AssertEqualInt(19, lConsumed.SkillsFound, 'Status-only update should preserve discovered skill count');
    AssertEqualInt(11, lConsumed.SkillsWritten, 'Status-only update should preserve written skill count');
    AssertEqualText('Warming embeddings...', lConsumed.StatusText, 'Status-only update should replace the stage text');
  finally
    lBuffer.Free;
  end;
end;

procedure TestGitPullIsThrottledOnSecondRun;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lFirstState: TRepoState;
  lInfraRoot: string;
  lOptions: TPipelineOptions;
  lRepoPath: string;
  lResult: TPipelineRunResult;
  lScanRoot: string;
  lSecondState: TRepoState;
begin
  PrepareFixtureDirectory('SkillSearchPipelineGitThrottle', lFixtureRoot, lInfraRoot, lScanRoot);
  CreateRemoteBackedRepo(lInfraRoot, lScanRoot, 'repo-throttle', lRepoPath);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    lOptions := DefaultPipelineOptions;
    lOptions.MinPullIntervalMinutes := 120;
    lOptions.GitPullTimeoutSeconds := 60;
    lOptions.MaxGitPullThreads := 1;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lResult := lCoordinator.Run([lScanRoot], nil);
      AssertEqualInt(0, lResult.ErrorCount, 'First run should not report git errors');
      AssertEqualInt(1, lResult.ReposPulled, 'First run should pull one repo');

      AssertTrue(lDbManager.TryGetRepoState(lRepoPath, lFirstState), 'Repo state missing after first run');
      AssertEqualText('pulled', lFirstState.LastPullStatus, 'First run pull status mismatch');

      lResult := lCoordinator.Run([lScanRoot], nil);
      AssertEqualInt(1, lResult.ReposThrottled, 'Second run should throttle one repo');
      AssertTrue(lDbManager.TryGetRepoState(lRepoPath, lSecondState), 'Repo state missing after second run');
      AssertEqualText('skipped (throttled)', lSecondState.LastPullStatus, 'Second run pull status mismatch');
      AssertEqualText(lFirstState.LastPullUtc, lSecondState.LastPullUtc,
        'Throttled run must not change last pull timestamp');
    finally
      lCoordinator.Free;
    end;
  finally
    lDbManager.Free;
  end;
end;

procedure TestGitPullFailureDoesNotBlockOtherRepos;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDiagnostics: string;
  lDbPath: string;
  lFixtureRoot: string;
  lGoodRepoPath: string;
  lGoodState: TRepoState;
  lInfraRoot: string;
  lOptions: TPipelineOptions;
  lBadRepoPath: string;
  lBadState: TRepoState;
  lResult: TPipelineRunResult;
  lScanRoot: string;
begin
  PrepareFixtureDirectory('SkillSearchPipelineGitFailure', lFixtureRoot, lInfraRoot, lScanRoot);
  CreateRemoteBackedRepo(lInfraRoot, lScanRoot, 'repo-good', lGoodRepoPath);
  CreateRemoteBackedRepo(lInfraRoot, lScanRoot, 'repo-bad', lBadRepoPath);
  RunShellOrFail(lBadRepoPath, 'git remote set-url origin https://127.0.0.1:9/invalid/repo.git');

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    lOptions := DefaultPipelineOptions;
    lOptions.MinPullIntervalMinutes := 0;
    lOptions.GitPullTimeoutSeconds := 20;
    lOptions.MaxGitPullThreads := 2;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lResult := lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertTrue(lResult.ReposFailed >= 1, 'Expected at least one failed pull');
    AssertTrue(lResult.SkillsWritten >= 2, 'Skill indexing should continue despite failed pull');

    AssertTrue(lDbManager.TryGetRepoState(lGoodRepoPath, lGoodState), 'Good repo state missing');
    AssertEqualText('pulled', lGoodState.LastPullStatus, 'Good repo pull status mismatch');

    AssertTrue(lDbManager.TryGetRepoState(lBadRepoPath, lBadState), 'Bad repo state missing');
    AssertTrue(AnsiStartsText('failed', lBadState.LastPullStatus), 'Bad repo should be marked failed');

    lDiagnostics := BuildDiagnosticsText;
    AssertTrue(ContainsText(lDiagnostics, 'Git pull failed for "'), 'Diagnostics should include git failure details');
    AssertTrue(ContainsText(lDiagnostics, 'repo-bad'), 'Diagnostics should mention failed repo path');
  finally
    lDbManager.Free;
  end;
end;

procedure TestGitPullRunsInNonInteractiveMode;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lInfraRoot: string;
  lOptions: TPipelineOptions;
  lRepoPath: string;
  lResult: TPipelineRunResult;
  lScanRoot: string;
  lState: TRepoState;
begin
  PrepareFixtureDirectory('SkillSearchPipelineGitNonInteractive', lFixtureRoot, lInfraRoot, lScanRoot);
  CreateRemoteBackedRepo(lInfraRoot, lScanRoot, 'repo-noninteractive', lRepoPath);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    lOptions := DefaultPipelineOptions;
    lOptions.MinPullIntervalMinutes := 0;
    lOptions.GitExePath := 'cmd.exe';
    lOptions.GitPullArgs :=
      '/d /s /c "if ""%GIT_TERMINAL_PROMPT%""==""0"" (echo terminal prompts disabled&& exit /b 1) else (echo prompt enabled&& exit /b 0)"';

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lResult := lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertEqualInt(1, lResult.ReposFailed, 'Expected non-interactive guard command to fail once');
    AssertTrue(lDbManager.TryGetRepoState(lRepoPath, lState), 'Repo state missing for non-interactive test');
    AssertEqualText('failed', lState.LastPullStatus, 'Repo should be marked failed');
    AssertTrue(ContainsText(lState.LastPullOutput, 'terminal prompts disabled'),
      'Expected non-interactive error marker in pull output');
  finally
    lDbManager.Free;
  end;
end;

procedure RunPipelineTests;
begin
  TestPipelineHonorsComputeHasScriptsSetting;
  TestSettingsCreateUiStateAndSearchHistoryDefaults;
  TestSettingsPersistUiStateAndSearchHistory;
  TestSettingsLoadExternalTools;
  TestSettingsLoadTrayHotkey;
  TestSettingsLoadSearchAsYouTypeUiPreference;
  TestExternalToolCommandFormatting;
  TestDatabaseSkillTagCounts;
  TestTagBrowserActions;
  TestRelatedSkillActions;
  TestResolveRelatedSkillNavigation;
  TestPipelineReportsEmbeddingProgress;
  TestPipelineReportsEmbeddingUnavailable;
  TestPipelineReportsEmbeddingUnavailableWhenSkillRemainsPartial;
  TestTrayActions;
  TestPipelineAutoCancelStopsBeforeDbWrites;
  TestGitPullIsThrottledOnSecondRun;
  TestGitPullFailureDoesNotBlockOtherRepos;
  TestGitPullRunsInNonInteractiveMode;
  TestDockerHealthMonitorStopDropsQueuedCallbacks;
  TestDockerStatusUiStateHidesAlertWhenHealthy;
  TestDockerStatusUiStateShowsDockerAlert;
  TestDockerStatusUiStateShowsOllamaAlert;
  TestDockerStatusUiStateHidesAlertWhileStarting;
  TestDockerStatusUiStateShowsExplicitStartFailure;
  TestScanActivitySummaryIncludesCountsAndElapsed;
  TestPipelineReportsProgressCounts;
  TestScanProgressBufferCoalescesToLatestProgress;
  TestScanProgressBufferKeepsCountsWhenOnlyStatusChanges;
end;

end.
