unit IndexerTests;

interface

procedure RunIndexerTests;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  AppPaths, DatabaseManager, SkillIndexer, SkillTypes;

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

procedure IndexSkillFile(aDbManager: TDatabaseManager; const aSkillFilePath: string);
var
  lError: string;
  lSkill: TIndexedSkill;
begin
  AssertTrue(TryBuildIndexedSkill(aSkillFilePath, lSkill, lError), 'Index build failed: ' + lError);
  aDbManager.WriteBatch(nil, [lSkill]);
end;

procedure TestIndexerUpsertAndSkipUnchanged;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lFtsBody: string;
  lSkillFile: string;
  lSkillRoot: string;
  lStateFirst: TSkillState;
  lStateSecond: TSkillState;
  lStateThird: TSkillState;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchIndexerFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-one');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  ForceDirectories(TPath.Combine(lSkillRoot, 'scripts'));
  TFile.WriteAllText(TPath.Combine(lSkillRoot, 'scripts\build.ps1'), 'Write-Output "ok"', TEncoding.UTF8);

  TFile.WriteAllText(
    lSkillFile,
    '---' + sLineBreak +
    'name: Deterministic Skill' + sLineBreak +
    'description: Initial deterministic description' + sLineBreak +
    'tags: [delphi,git]' + sLineBreak +
    '---' + sLineBreak +
    '# Ignored Heading' + sLineBreak +
    sLineBreak +
    'Initial body paragraph for indexing.' + sLineBreak,
    TEncoding.UTF8
  );

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    IndexSkillFile(lDbManager, lSkillFile);
    AssertEqualInt(1, lDbManager.GetSkillCount, 'Expected one indexed skill after first run');

    AssertTrue(lDbManager.TryGetSkillState(TPath.GetFullPath(lSkillFile), lStateFirst), 'Missing skill state after first run');
    AssertEqualText('Deterministic Skill', lStateFirst.Name, 'Name parse mismatch');
    AssertEqualText('Initial deterministic description', lStateFirst.Description, 'Description parse mismatch');
    AssertEqualText('delphi;git', lStateFirst.Tags, 'Tags parse mismatch');
    AssertEqualInt(1, lStateFirst.HasScripts, 'Expected has_scripts=1');
    AssertEqualInt(1, lStateFirst.ScriptsCount, 'Expected one discovered script');
    AssertEqualText('ps1', lStateFirst.ScriptsExts, 'Expected discovered script extension set');

    Sleep(1200);
    IndexSkillFile(lDbManager, lSkillFile);

    AssertTrue(lDbManager.TryGetSkillState(TPath.GetFullPath(lSkillFile), lStateSecond), 'Missing skill state after second run');
    AssertEqualText(lStateFirst.BodyHash, lStateSecond.BodyHash, 'Body hash should remain unchanged');
    AssertEqualText(lStateFirst.IndexedUtc, lStateSecond.IndexedUtc,
      'Unchanged skill should skip reindex and preserve indexed timestamp');

    Sleep(1200);
    TFile.WriteAllText(
      lSkillFile,
      '---' + sLineBreak +
      'name: Deterministic Skill Updated' + sLineBreak +
      'description: Updated deterministic description' + sLineBreak +
      'tags: [delphi,sqlite]' + sLineBreak +
      '---' + sLineBreak +
      '# Ignored Heading' + sLineBreak +
      sLineBreak +
      'Updated body paragraph for indexing.' + sLineBreak,
      TEncoding.UTF8
    );

    IndexSkillFile(lDbManager, lSkillFile);

    AssertTrue(lDbManager.TryGetSkillState(TPath.GetFullPath(lSkillFile), lStateThird), 'Missing skill state after update run');
    AssertTrue(not SameText(lStateSecond.BodyHash, lStateThird.BodyHash), 'Body hash should change after file update');
    AssertTrue(not SameText(lStateSecond.IndexedUtc, lStateThird.IndexedUtc),
      'Indexed timestamp should change for updated file');
    AssertEqualText('Deterministic Skill Updated', lStateThird.Name, 'Updated name mismatch');
    AssertEqualText('Updated deterministic description', lStateThird.Description, 'Updated description mismatch');

    lFtsBody := lDbManager.GetSkillFtsBodyBySkillFile(TPath.GetFullPath(lSkillFile));
    AssertTrue(ContainsText(lFtsBody, 'Updated body paragraph for indexing.'),
      'FTS body should reflect updated skill content');
  finally
    lDbManager.Free;
  end;
end;

procedure TestIndexerDetectsScriptChangesEvenWhenSkillMarkdownIsUnchanged;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lSkillFile: string;
  lSkillRoot: string;
  lStateFirst: TSkillState;
  lStateSecond: TSkillState;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchIndexerScriptsFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-scripts');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');

  TFile.WriteAllText(lSkillFile, '# Script Detection Skill' + sLineBreak + sLineBreak + 'Body text', TEncoding.UTF8);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;

    IndexSkillFile(lDbManager, lSkillFile);
    AssertTrue(lDbManager.TryGetSkillState(TPath.GetFullPath(lSkillFile), lStateFirst), 'Missing first script skill state');
    AssertEqualInt(0, lStateFirst.HasScripts, 'Expected no scripts before script file is added');

    Sleep(1200);
    ForceDirectories(TPath.Combine(lSkillRoot, 'scripts'));
    TFile.WriteAllText(TPath.Combine(lSkillRoot, 'scripts\runner.py'), 'print("ok")', TEncoding.UTF8);

    IndexSkillFile(lDbManager, lSkillFile);
    AssertTrue(lDbManager.TryGetSkillState(TPath.GetFullPath(lSkillFile), lStateSecond),
      'Missing second script skill state');
    AssertEqualInt(1, lStateSecond.HasScripts, 'Expected script detection to flip to true');
    AssertEqualInt(1, lStateSecond.ScriptsCount, 'Expected one detected script after script file was added');
    AssertEqualText('py', lStateSecond.ScriptsExts, 'Expected detected script extension py');
    AssertTrue(not SameText(lStateFirst.IndexedUtc, lStateSecond.IndexedUtc),
      'Indexed timestamp should change when script detection fields change');
  finally
    lDbManager.Free;
  end;
end;

procedure RunIndexerTests;
begin
  TestIndexerUpsertAndSkipUnchanged;
  TestIndexerDetectsScriptChangesEvenWhenSkillMarkdownIsUnchanged;
end;

end.
