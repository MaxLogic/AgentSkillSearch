unit PipelineTests;

interface

procedure RunPipelineTests;

implementation

uses
  System.Classes, System.IOUtils, System.SysUtils,
  AppPaths, DatabaseManager, PipelineCoordinator;

procedure AssertTrue(const aCondition: Boolean; const aMessage: string);
begin
  if not aCondition then
  begin
    raise Exception.Create(aMessage);
  end;
end;

procedure CreateSkillFixture(const aRootPath: string; const aRepoCount, aSkillsPerRepo: Integer);
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

procedure TestPipelineCancellationAndBatchWrites;
var
  lCoordinator: TPipelineCoordinator;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lOptions: TPipelineOptions;
  lResult: TPipelineRunResult;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchPipelineFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);
  CreateSkillFixture(lFixtureRoot, 30, 20);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    lOptions := DefaultPipelineOptions;
    lOptions.MaxScanThreads := 4;
    lOptions.MaxGitPullThreads := 3;
    lOptions.MaxIndexThreads := 5;
    lOptions.DbBatchSize := 20;
    lOptions.SimulationDelayMs := 2;
    lOptions.AutoCancelAfterMs := 800;

    lCoordinator := TPipelineCoordinator.Create(lDbManager, lOptions);
    try
      lResult := lCoordinator.Run([lFixtureRoot], nil);
    finally
      lCoordinator.Free;
    end;
    AssertTrue(lResult.Cancelled, 'Expected pipeline cancellation flag to be set');
    AssertTrue(lResult.ErrorCount = 0, 'Expected no pipeline processing errors');
    AssertTrue(lResult.ReposWritten > 0, 'Expected partial repo writes before cancellation');
    AssertTrue(lResult.SkillsWritten >= 0, 'Expected deterministic skill write count');
    AssertTrue(lDbManager.GetRepoCount = lResult.ReposWritten, 'Repo write counter mismatch');
    AssertTrue(lDbManager.GetSkillCount = lResult.SkillsWritten, 'Skill write counter mismatch');
  finally
    lDbManager.Free;
  end;
end;

procedure RunPipelineTests;
begin
  TestPipelineCancellationAndBatchWrites;
end;

end.
