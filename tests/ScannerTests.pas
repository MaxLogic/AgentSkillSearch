unit ScannerTests;

interface

procedure RunScannerTests;

implementation

uses
  System.Classes, System.IOUtils, System.SysUtils,
  AppPaths, DatabaseManager, RepoScanner;

procedure AssertEqualInt(const aExpected, aActual: Integer; const aMessage: string);
begin
  if aExpected <> aActual then
  begin
    raise Exception.CreateFmt('%s | expected=%d actual=%d', [aMessage, aExpected, aActual]);
  end;
end;

procedure BuildFixture(const aRootPath: string);
var
  lNormalRepoPath: string;
  lWorktreeRepoPath: string;
begin
  lNormalRepoPath := TPath.Combine(aRootPath, 'normal-repo');
  lWorktreeRepoPath := TPath.Combine(aRootPath, 'worktree-repo');

  ForceDirectories(TPath.Combine(lNormalRepoPath, '.git'));
  ForceDirectories(lWorktreeRepoPath);
  TFile.WriteAllText(TPath.Combine(lWorktreeRepoPath, '.git'), 'gitdir: C:\\dummy\\worktree', TEncoding.UTF8);
end;

procedure TestWorktreeEnabled;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lRepos: TArray<string>;
  lScanner: TRepoScanner;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchScannerFixtureEnabled');
  ForceDirectories(lFixtureRoot);
  BuildFixture(lFixtureRoot);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;
    lScanner := TRepoScanner.Create(True, '.git;node_modules;bin;obj', lDbManager);
    try
      lRepos := lScanner.ScanForRepoRoots(lFixtureRoot);
    finally
      lScanner.Free;
    end;

    AssertEqualInt(2, Length(lRepos), 'Expected normal + worktree repositories when worktrees are enabled');
    AssertEqualInt(2, lDbManager.GetRepoCount, 'Expected both repositories persisted in DB');
  finally
    lDbManager.Free;
  end;
end;

procedure TestWorktreeDisabled;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lRepos: TArray<string>;
  lScanner: TRepoScanner;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchScannerFixtureDisabled');
  ForceDirectories(lFixtureRoot);
  BuildFixture(lFixtureRoot);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;
    lScanner := TRepoScanner.Create(False, '.git;node_modules;bin;obj', lDbManager);
    try
      lRepos := lScanner.ScanForRepoRoots(lFixtureRoot);
    finally
      lScanner.Free;
    end;

    AssertEqualInt(1, Length(lRepos), 'Expected only standard repositories when worktrees are disabled');
    AssertEqualInt(1, lDbManager.GetRepoCount, 'Expected only one repository persisted in DB');
  finally
    lDbManager.Free;
  end;
end;

procedure RunScannerTests;
begin
  TestWorktreeEnabled;
  TestWorktreeDisabled;
end;

end.
