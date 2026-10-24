unit IndexerTests;

interface

procedure RunIndexerTests;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite,
  AppPaths, DatabaseManager, Logging, SkillIndexer, SkillTypes;

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

procedure CreateLegacyContentlessFtsDatabase(const aDbPath: string);
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
begin
  ForceDirectories(ExtractFilePath(aDbPath));
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lDriverLink.VendorLib := GetSqliteDllPath;
    lConnection.LoginPrompt := False;
    lConnection.Params.Add('DriverID=SQLite');
    lConnection.Params.Add('Database=' + aDbPath);
    lConnection.Params.Add('OpenMode=CreateUTF8');
    lConnection.Connected := True;
    lConnection.ExecSQL('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);');
    lConnection.ExecSQL('INSERT INTO meta(key, value) VALUES(''schema_version'', ''1'');');
    lConnection.ExecSQL(
      'CREATE TABLE sources (' +
      'id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, enabled INTEGER NOT NULL DEFAULT 1, last_scan_utc TEXT);'
    );
    lConnection.ExecSQL(
      'CREATE TABLE repos (' +
      'id INTEGER PRIMARY KEY, root_path TEXT NOT NULL UNIQUE, last_pull_utc TEXT, last_pull_status TEXT, ' +
      'last_pull_output TEXT, last_pull_duration_ms INTEGER, head_commit TEXT, last_seen_utc TEXT);'
    );
    lConnection.ExecSQL(
      'CREATE TABLE skills (' +
      'id INTEGER PRIMARY KEY, source_id INTEGER NOT NULL, repo_id INTEGER, skill_root TEXT NOT NULL UNIQUE, ' +
      'skill_file TEXT NOT NULL UNIQUE, name TEXT NOT NULL, description TEXT, tags TEXT, body_md TEXT NOT NULL, ' +
      'body_hash TEXT NOT NULL, file_mtime_utc TEXT NOT NULL, indexed_utc TEXT NOT NULL, ' +
      'has_scripts INTEGER NOT NULL DEFAULT 0, scripts_count INTEGER NOT NULL DEFAULT 0, scripts_exts TEXT);'
    );
    lConnection.ExecSQL(
      'INSERT INTO sources(id, path, enabled, last_scan_utc) VALUES(1, ''(auto)'', 1, NULL);'
    );
    lConnection.ExecSQL(
      'INSERT INTO skills(id, source_id, skill_root, skill_file, name, description, tags, body_md, body_hash, ' +
      'file_mtime_utc, indexed_utc, has_scripts, scripts_count, scripts_exts) ' +
      'VALUES(1, 1, ''C:\legacy\skill'', ''C:\legacy\skill\SKILL.md'', ''Legacy Row'', ' +
      '''Legacy description'', ''legacy'', ''Original legacy body text'', ''hash-legacy'', ' +
      '''2026-01-01T00:00:00Z'', ''2026-01-01T00:00:00Z'', 0, 0, '''');'
    );
    lConnection.ExecSQL(
      'CREATE VIRTUAL TABLE skills_fts USING fts5(' +
      'name, description, tags, body_md, content='''', tokenize=''unicode61'');'
    );
    lConnection.ExecSQL(
      'CREATE TABLE skill_chunks (' +
      'id INTEGER PRIMARY KEY, skill_id INTEGER NOT NULL, chunk_index INTEGER NOT NULL, chunk_text TEXT NOT NULL, ' +
      'chunk_hash TEXT NOT NULL, UNIQUE(skill_id, chunk_index));'
    );
    lConnection.ExecSQL(
      'CREATE TABLE chunk_vec (' +
      'chunk_id INTEGER PRIMARY KEY, model TEXT NOT NULL, dim INTEGER NOT NULL, vec BLOB NOT NULL, updated_utc TEXT NOT NULL);'
    );
    lConnection.ExecSQL(
      'INSERT INTO skills_fts(rowid, name, description, tags, body_md) ' +
      'SELECT id, name, description, tags, body_md FROM skills;'
    );
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure CreateFutureSchemaDatabase(const aDbPath: string);
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
begin
  ForceDirectories(ExtractFilePath(aDbPath));
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lDriverLink.VendorLib := GetSqliteDllPath;
    lConnection.LoginPrompt := False;
    lConnection.Params.Add('DriverID=SQLite');
    lConnection.Params.Add('Database=' + aDbPath);
    lConnection.Params.Add('OpenMode=CreateUTF8');
    lConnection.Connected := True;
    lConnection.ExecSQL('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);');
    lConnection.ExecSQL('INSERT INTO meta(key, value) VALUES(''schema_version'', ''99'');');
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

function QueryTestDbScalarText(const aDbPath, aSql: string): string;
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lQuery: TFDQuery;
begin
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  lQuery := TFDQuery.Create(nil);
  try
    lDriverLink.VendorLib := GetSqliteDllPath;
    lConnection.LoginPrompt := False;
    lConnection.Params.Add('DriverID=SQLite');
    lConnection.Params.Add('Database=' + aDbPath);
    lConnection.Params.Add('OpenMode=ReadWrite');
    lConnection.Connected := True;
    lQuery.Connection := lConnection;
    lQuery.SQL.Text := aSql;
    lQuery.Open;
    if lQuery.IsEmpty then
    begin
      Exit('');
    end;

    Result := lQuery.Fields[0].AsString;
  finally
    lQuery.Free;
    lConnection.Free;
    lDriverLink.Free;
  end;
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

procedure TestInitializeMigratesLegacyContentlessFtsTable;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lFtsBody: string;
  lInitialSkillCount: string;
  lSkillFile: string;
  lSkillRoot: string;
  lState: TSkillState;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchLegacyContentlessFtsFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  CreateLegacyContentlessFtsDatabase(lDbPath);
  lInitialSkillCount := QueryTestDbScalarText(lDbPath, 'SELECT COUNT(1) FROM skills;');

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-legacy-fts');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  TFile.WriteAllText(
    lSkillFile,
    '# Legacy FTS Migration' + sLineBreak +
    sLineBreak +
    'Migrated body text should be searchable and stored for snippets.' + sLineBreak,
    TEncoding.UTF8
  );

  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;
    IndexSkillFile(lDbManager, lSkillFile);

    AssertTrue(lDbManager.TryGetSkillState(TPath.GetFullPath(lSkillFile), lState),
      'Missing skill state after legacy FTS migration');
    AssertEqualText('Legacy FTS Migration', lState.Name, 'Legacy migration skill name mismatch');

    lFtsBody := lDbManager.GetSkillFtsBodyBySkillFile(TPath.GetFullPath(lSkillFile));
    AssertTrue(ContainsText(lFtsBody, 'Migrated body text should be searchable'),
      'Migrated FTS table should store updated body text');
  finally
    lDbManager.Free;
  end;

  AssertEqualText('2', QueryTestDbScalarText(lDbPath, 'SELECT value FROM meta WHERE key = ''schema_version'';'),
    'Expected migration runner to persist schema version 2');
  AssertEqualText('2', QueryTestDbScalarText(lDbPath, 'SELECT COUNT(1) FROM skills;'),
    'Expected legacy row plus newly indexed row after migration');
  AssertEqualText('2', QueryTestDbScalarText(lDbPath, 'SELECT COUNT(1) FROM skills_fts;'),
    'Expected FTS rows to match migrated skills');
  AssertTrue(not ContainsText(
    QueryTestDbScalarText(lDbPath, 'SELECT sql FROM sqlite_master WHERE type = ''table'' AND name = ''skills_fts'';'),
    'content='
  ), 'Expected migrated FTS table to be ordinary, not contentless');

  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;
  finally
    lDbManager.Free;
  end;

  AssertEqualText('2', QueryTestDbScalarText(lDbPath, 'SELECT COUNT(1) FROM skills;'),
    'Second Initialize should not lose skill rows');
  AssertEqualText('2', QueryTestDbScalarText(lDbPath, 'SELECT COUNT(1) FROM skills_fts;'),
    'Second Initialize should not duplicate or lose FTS rows');
  AssertEqualText('1', lInitialSkillCount, 'Legacy fixture should start with one skill row');
end;

procedure TestInitializeRejectsFutureSchemaVersion;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lError: string;
  lFixtureRoot: string;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchFutureSchemaFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  CreateFutureSchemaDatabase(lDbPath);

  lError := '';
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    try
      lDbManager.Initialize;
    except
      on E: Exception do
      begin
        lError := E.Message;
      end;
    end;
  finally
    lDbManager.Free;
  end;

  AssertTrue(ContainsText(lError, 'newer schema version'),
    'Future schema version should be rejected instead of overwritten');
  AssertEqualText('99', QueryTestDbScalarText(lDbPath, 'SELECT value FROM meta WHERE key = ''schema_version'';'),
    'Rejected future DB version should remain untouched');
end;

procedure TestIndexerRepairsMissingClosingFrontMatterFence;
var
  lFixtureRoot: string;
  lDiagnostics: string;
  lSkill: TIndexedSkill;
  lSkillFile: string;
  lSkillRoot: string;
  lError: string;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchIndexerFrontmatterRepairFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-invalid-frontmatter');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  TFile.WriteAllText(
    lSkillFile,
    '---' + sLineBreak +
    'name: Repaired Skill' + sLineBreak +
    'description: missing terminating fence' + sLineBreak +
    'tags: [repair,test]' + sLineBreak +
    '# Heading that should parse after repair' + sLineBreak + sLineBreak +
    'Body line after repaired fence.' + sLineBreak,
    TEncoding.UTF8
  );

  AssertTrue(
    TryBuildIndexedSkill(lSkillFile, lSkill, lError),
    'Recoverable frontmatter should index successfully: ' + lError
  );
  AssertEqualText('Repaired Skill', lSkill.Name, 'Expected repaired frontmatter to preserve name');
  AssertEqualText('repair;test', lSkill.Tags, 'Expected repaired frontmatter tags');
  AssertTrue(ContainsText(lSkill.BodyMarkdown, '# Heading that should parse after repair'),
    'Expected markdown body to remain intact');

  lDiagnostics := BuildDiagnosticsText;
  AssertTrue(ContainsText(lDiagnostics, 'frontmatter repaired'),
    'Diagnostics should include non-fatal frontmatter repair notice');
end;

procedure TestIndexerRepairsLooseFrontMatterFences;
var
  lError: string;
  lSkill: TIndexedSkill;
  lSkillFile: string;
  lSkillRoot: string;
  lFixtureRoot: string;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchIndexerLooseFenceFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-loose-fence');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  TFile.WriteAllText(
    lSkillFile,
    '---' + #$00A0 + sLineBreak +
    'name: Loose Fence Skill' + sLineBreak +
    'description: fence with nbsp' + sLineBreak +
    '---`' + sLineBreak +
    '# Loose fence heading' + sLineBreak,
    TEncoding.UTF8
  );

  AssertTrue(TryBuildIndexedSkill(lSkillFile, lSkill, lError),
    'Loose frontmatter fences should be repaired: ' + lError);
  AssertEqualText('Loose Fence Skill', lSkill.Name, 'Expected loose-fence frontmatter name');
  AssertTrue(ContainsText(lSkill.Description, 'fence with nbsp'), 'Expected loose-fence description');
end;

procedure TestIndexerRepairsLiteralBackslashNewlineFrontMatter;
var
  lError: string;
  lSkill: TIndexedSkill;
  lSkillFile: string;
  lSkillRoot: string;
  lFixtureRoot: string;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchIndexerLiteralNewlineFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-literal-newlines');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  TFile.WriteAllText(
    lSkillFile,
    '---\nname: Literal Newline Skill\ndescription: escaped newline frontmatter\n---\n\n# Literal heading',
    TEncoding.UTF8
  );

  AssertTrue(TryBuildIndexedSkill(lSkillFile, lSkill, lError),
    'Literal backslash-n frontmatter should be repaired: ' + lError);
  AssertEqualText('Literal Newline Skill', lSkill.Name, 'Expected literal-newline frontmatter name');
  AssertTrue(ContainsText(lSkill.Description, 'escaped newline'), 'Expected literal-newline description');
end;

procedure TestIndexerRepairsSingleLineFrontMatter;
var
  lError: string;
  lSkill: TIndexedSkill;
  lSkillFile: string;
  lSkillRoot: string;
  lFixtureRoot: string;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchIndexerSingleLineFrontMatterFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-single-line-frontmatter');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  TFile.WriteAllText(
    lSkillFile,
    '--- name: File-Repair description: Repair damaged files user-invocable: true ---' + sLineBreak +
    '# File repair' + sLineBreak,
    TEncoding.UTF8
  );

  AssertTrue(TryBuildIndexedSkill(lSkillFile, lSkill, lError),
    'Single-line frontmatter should be repaired: ' + lError);
  AssertEqualText('File-Repair', lSkill.Name, 'Expected single-line frontmatter name');
  AssertTrue(ContainsText(lSkill.Description, 'Repair damaged files'), 'Expected single-line description');
end;

procedure TestIndexerRejectsUnrecoverableFrontMatter;
var
  lError: string;
  lFixtureRoot: string;
  lSkill: TIndexedSkill;
  lSkillFile: string;
  lSkillRoot: string;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchIndexerMalformedFrontmatterFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-invalid-frontmatter');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  TFile.WriteAllText(
    lSkillFile,
    '---' + sLineBreak +
    'name: Broken Skill' + sLineBreak +
    'description: missing terminating fence' + sLineBreak +
    'tags: [invalid,test]' + sLineBreak,
    TEncoding.UTF8
  );

  AssertTrue(
    not TryBuildIndexedSkill(lSkillFile, lSkill, lError),
    'Unrecoverable frontmatter should fail deterministic indexing'
  );
  AssertTrue(ContainsText(lError, 'Malformed frontmatter'), 'Expected explicit frontmatter parse error');
end;

procedure TestChunkVectorsAreUpdatedIncrementallyByChunkHash;
var
  lChunkStatesFirst: TArray<TSkillChunkState>;
  lChunkStatesSecond: TArray<TSkillChunkState>;
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lSkillFile: string;
  lSkillRoot: string;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchIndexerChunkVectorFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lSkillRoot := TPath.Combine(lFixtureRoot, 'skill-semantic');
  ForceDirectories(lSkillRoot);
  lSkillFile := TPath.Combine(lSkillRoot, 'SKILL.md');
  TFile.WriteAllText(
    lSkillFile,
    '# Section A' + sLineBreak + sLineBreak +
    'Alpha paragraph stays stable.' + sLineBreak + sLineBreak +
    '# Section B' + sLineBreak + sLineBreak +
    'Beta paragraph version one.' + sLineBreak,
    TEncoding.UTF8
  );

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;
    IndexSkillFile(lDbManager, lSkillFile);
    lChunkStatesFirst := lDbManager.GetChunkStatesBySkillFile(TPath.GetFullPath(lSkillFile));
    AssertEqualInt(2, Length(lChunkStatesFirst), 'Expected two semantic chunks after first index');
    AssertEqualInt(16, lChunkStatesFirst[0].VectorDim, 'Expected deterministic vector dimension for first chunk');
    AssertEqualInt(16, lChunkStatesFirst[1].VectorDim, 'Expected deterministic vector dimension for second chunk');

    Sleep(1200);
    TFile.WriteAllText(
      lSkillFile,
      '# Section A' + sLineBreak + sLineBreak +
      'Alpha paragraph stays stable.' + sLineBreak + sLineBreak +
      '# Section B' + sLineBreak + sLineBreak +
      'Beta paragraph version two with changed wording.' + sLineBreak,
      TEncoding.UTF8
    );

    IndexSkillFile(lDbManager, lSkillFile);
    lChunkStatesSecond := lDbManager.GetChunkStatesBySkillFile(TPath.GetFullPath(lSkillFile));
    AssertEqualInt(2, Length(lChunkStatesSecond), 'Expected two semantic chunks after update');
    AssertEqualText(lChunkStatesFirst[0].ChunkHash, lChunkStatesSecond[0].ChunkHash,
      'Unchanged section should keep same chunk hash');
    AssertEqualText(lChunkStatesFirst[0].VectorUpdatedUtc, lChunkStatesSecond[0].VectorUpdatedUtc,
      'Unchanged section should keep vector timestamp');
    AssertTrue(not SameText(lChunkStatesFirst[1].ChunkHash, lChunkStatesSecond[1].ChunkHash),
      'Changed section should update chunk hash');
    AssertTrue(not SameText(lChunkStatesFirst[1].VectorUpdatedUtc, lChunkStatesSecond[1].VectorUpdatedUtc),
      'Changed section should refresh vector timestamp');
  finally
    lDbManager.Free;
  end;
end;

procedure RunIndexerTests;
begin
  TestIndexerUpsertAndSkipUnchanged;
  TestIndexerDetectsScriptChangesEvenWhenSkillMarkdownIsUnchanged;
  TestInitializeMigratesLegacyContentlessFtsTable;
  TestInitializeRejectsFutureSchemaVersion;
  TestIndexerRepairsMissingClosingFrontMatterFence;
  TestIndexerRepairsLooseFrontMatterFences;
  TestIndexerRepairsLiteralBackslashNewlineFrontMatter;
  TestIndexerRepairsSingleLineFrontMatter;
  TestIndexerRejectsUnrecoverableFrontMatter;
  TestChunkVectorsAreUpdatedIncrementallyByChunkHash;
end;

end.
