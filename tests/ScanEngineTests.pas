unit ScanEngineTests;

interface

procedure RunScanEngineTests;

implementation

uses
  System.IOUtils, System.SysUtils,
  ScanEngine;

procedure AssertEqualInt(const aExpected, aActual: Integer; const aMessage: string);
begin
  if aExpected <> aActual then
  begin
    raise Exception.CreateFmt('%s | expected=%d actual=%d', [aMessage, aExpected, aActual]);
  end;
end;

procedure AssertTrue(const aCondition: Boolean; const aMessage: string);
begin
  if not aCondition then
  begin
    raise Exception.Create(aMessage);
  end;
end;

procedure BuildFixture(const aRootPath: string);
var
  lPath: string;
begin
  ForceDirectories(TPath.Combine(aRootPath, 'repo-normal\.git'));
  ForceDirectories(TPath.Combine(aRootPath, 'repo-normal\skill-one'));
  TFile.WriteAllText(TPath.Combine(aRootPath, 'repo-normal\skill-one\SKILL.md'), '# Skill one', TEncoding.UTF8);

  ForceDirectories(TPath.Combine(aRootPath, 'repo-worktree'));
  TFile.WriteAllText(TPath.Combine(aRootPath, 'repo-worktree\.git'), 'gitdir: C:\\dummy\\worktree', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(aRootPath, 'repo-worktree\SKILL.md'), '# Skill two', TEncoding.UTF8);

  lPath := TPath.Combine(aRootPath, 'node_modules\ignored\repo-hidden\.git');
  ForceDirectories(lPath);
  ForceDirectories(TPath.Combine(aRootPath, 'node_modules\ignored\repo-hidden\skill-hidden'));
  TFile.WriteAllText(TPath.Combine(aRootPath, 'node_modules\ignored\repo-hidden\skill-hidden\SKILL.md'), '# Hidden', TEncoding.UTF8);
end;

procedure TestScannerHonorsSkipFoldersAndFindsReposAndSkills;
var
  i: Integer;
  lFixtureRoot: string;
  lOptions: TScanOptions;
  lResult: TScanResult;
  lScanEngine: TScanEngine;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchScanFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);
  BuildFixture(lFixtureRoot);

  lOptions := DefaultScanOptions;
  lOptions.MaxScanThreads := 4;
  lOptions.TreatWorktreesAsRepos := True;
  lScanEngine := TScanEngine.Create(lOptions);
  try
    lResult := lScanEngine.Scan([lFixtureRoot]);
  finally
    lScanEngine.Free;
  end;

  AssertEqualInt(2, Length(lResult.RepoRoots), 'Repo count mismatch');
  AssertEqualInt(2, Length(lResult.SkillFiles), 'Skill count mismatch');
  for i := 0 to Pred(Length(lResult.SkillFiles)) do
  begin
    AssertTrue(Pos('node_modules', LowerCase(lResult.SkillFiles[i])) = 0, 'Scanner entered skipped folder');
  end;
  AssertTrue(lResult.ScannedDirectoryCount > 0, 'Scanner did not visit any directories');
end;

procedure RunScanEngineTests;
begin
  TestScannerHonorsSkipFoldersAndFindsReposAndSkills;
end;

end.
