unit PipelineTests;

interface

procedure RunPipelineTests;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  AppPaths, DatabaseManager, PipelineCoordinator;

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

procedure TestPipelineCancellationAndBatchWrites;
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
  CreateSyntheticRepoFixture(lScanRoot, 30, 20);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    lOptions := DefaultPipelineOptions;
    lOptions.DbBatchSize := 20;
    lOptions.PullEnabled := False;
    lOptions.SimulationDelayMs := 2;
    lOptions.AutoCancelAfterMs := 800;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lResult := lCoordinator.Run([lScanRoot], nil);
    finally
      lCoordinator.Free;
    end;

    AssertTrue(lResult.Cancelled, 'Expected pipeline cancellation flag to be set');
    AssertTrue(lResult.ErrorCount = 0, 'Expected no pipeline processing errors when pull is disabled');
    AssertTrue(lResult.ReposWritten > 0, 'Expected partial repo writes before cancellation');
    AssertTrue(lResult.SkillsWritten >= 0, 'Expected deterministic skill write count');
    AssertTrue(lDbManager.GetRepoCount = lResult.ReposWritten, 'Repo write counter mismatch');
    AssertTrue(lDbManager.GetSkillCount = lResult.SkillsWritten, 'Skill write counter mismatch');
  finally
    lDbManager.Free;
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
  TestPipelineCancellationAndBatchWrites;
  TestGitPullIsThrottledOnSecondRun;
  TestGitPullFailureDoesNotBlockOtherRepos;
  TestGitPullRunsInNonInteractiveMode;
end;

end.
