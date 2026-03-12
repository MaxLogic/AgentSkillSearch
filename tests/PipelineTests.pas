unit PipelineTests;

interface

procedure RunPipelineTests;

implementation

uses
  System.Classes, System.Diagnostics, System.IOUtils, System.StrUtils, System.SyncObjs, System.SysUtils,
  Winapi.Windows,
  AppPaths, DatabaseManager, DockerHealthMonitor, Logging, PipelineCoordinator, Settings, SettingsModel;

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
  TestPipelineAutoCancelStopsBeforeDbWrites;
  TestGitPullIsThrottledOnSecondRun;
  TestGitPullFailureDoesNotBlockOtherRepos;
  TestGitPullRunsInNonInteractiveMode;
  TestDockerHealthMonitorStopDropsQueuedCallbacks;
end;

end.
