unit DatabaseManager;

interface

uses
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, SkillTypes;

type
  TDbInitResult = record
    DatabasePath: string;
    JournalMode: string;
    SynchronousMode: string;
    TempStore: string;
    ForeignKeysEnabled: Integer;
    Fts5Enabled: Boolean;
  end;

  TRepoPullUpdate = record
    HeadCommit: string;
    LastPullDurationMs: Integer;
    LastPullOutput: string;
    LastPullStatus: string;
    LastPullUtc: string;
    RootPath: string;
  end;

  TRepoState = record
    HeadCommit: string;
    LastPullDurationMs: Integer;
    LastPullOutput: string;
    LastPullStatus: string;
    LastPullUtc: string;
    LastSeenUtc: string;
    RootPath: string;
  end;

  TSkillState = record
    BodyHash: string;
    BodyMarkdown: string;
    Description: string;
    Id: Integer;
    IndexedUtc: string;
    Name: string;
    SkillFile: string;
    SkillRoot: string;
    Tags: string;
  end;

  TDatabaseManager = class
  private
    fConnection: TFDConnection;
    fDatabasePath: string;
    fDriverLink: TFDPhysSQLiteDriverLink;
    fSqliteDllPath: string;
    procedure ApplyPragmas(var aResult: TDbInitResult);
    procedure ConfigureConnection;
    procedure EnsureDatabaseFolder;
    function IsSkillUnchanged(const aSkill: TIndexedSkill): Boolean;
    function QueryScalarInt(const aSql: string): Integer;
    function QuerySkillIdBySkillFile(const aSkillFile: string): Integer;
    function QueryScalarText(const aSql: string): string;
    procedure RunMigrations;
    procedure VerifyFts5Support;
  public
    constructor Create(const aDatabasePath, aSqliteDllPath: string);
    destructor Destroy; override;
    property DatabasePath: string read fDatabasePath;
    property SqliteDllPath: string read fSqliteDllPath;
    function GetRepoCount: Integer;
    function GetSkillCount: Integer;
    function Initialize: TDbInitResult;
    function GetSkillFtsBodyBySkillFile(const aSkillFile: string): string;
    function TableExists(const aTableName: string): Boolean;
    function TryGetRepoState(const aRootPath: string; out aState: TRepoState): Boolean;
    function TryGetSkillState(const aSkillFile: string; out aState: TSkillState): Boolean;
    procedure UpsertRepoRoot(const aRootPath: string);
    procedure UpsertRepoPullResult(const aPull: TRepoPullUpdate);
    procedure UpsertSkill(const aSkill: TIndexedSkill);
    procedure WriteBatch(const aRepoRoots: TArray<string>; const aSkills: TArray<TIndexedSkill>);
    procedure WriteBatchWithRepoPulls(const aRepoRoots: TArray<string>; const aRepoPulls: TArray<TRepoPullUpdate>;
      const aSkills: TArray<TIndexedSkill>);
  end;

implementation

uses
  System.DateUtils, System.IOUtils, System.SysUtils, Data.DB,
  FireDAC.DApt, FireDAC.Stan.Async, FireDAC.Stan.Def, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param;

constructor TDatabaseManager.Create(const aDatabasePath, aSqliteDllPath: string);
begin
  inherited Create;
  fDatabasePath := aDatabasePath;
  fSqliteDllPath := aSqliteDllPath;
end;

destructor TDatabaseManager.Destroy;
begin
  FreeAndNil(fConnection);
  FreeAndNil(fDriverLink);
  inherited Destroy;
end;

procedure TDatabaseManager.EnsureDatabaseFolder;
begin
  if not ForceDirectories(ExtractFilePath(fDatabasePath)) then
  begin
    if not TDirectory.Exists(ExtractFilePath(fDatabasePath)) then
    begin
      raise Exception.CreateFmt('Failed to create database directory: %s', [ExtractFilePath(fDatabasePath)]);
    end;
  end;
end;

procedure TDatabaseManager.ConfigureConnection;
begin
  fDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  fDriverLink.VendorLib := fSqliteDllPath;

  fConnection := TFDConnection.Create(nil);
  fConnection.LoginPrompt := False;
  fConnection.Params.Clear;
  fConnection.Params.Add('DriverID=SQLite');
  fConnection.Params.Add('Database=' + fDatabasePath);
  fConnection.Params.Add('OpenMode=CreateUTF8');
  fConnection.Params.Add('LockingMode=Normal');
  fConnection.Params.Add('BusyTimeout=5000');
  fConnection.Connected := True;
end;

function TDatabaseManager.QueryScalarText(const aSql: string): string;
var
  lQuery: TFDQuery;
begin
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text := aSql;
    lQuery.Open;
    if lQuery.IsEmpty then
    begin
      Result := '';
    end else begin
      Result := lQuery.Fields[0].AsString;
    end;
  finally
    lQuery.Free;
  end;
end;

function TDatabaseManager.QueryScalarInt(const aSql: string): Integer;
var
  lValue: string;
begin
  lValue := QueryScalarText(aSql);
  if lValue = '' then
  begin
    Exit(0);
  end;
  Result := StrToIntDef(lValue, 0);
end;

function TDatabaseManager.QuerySkillIdBySkillFile(const aSkillFile: string): Integer;
var
  lQuery: TFDQuery;
begin
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text := 'SELECT id FROM skills WHERE skill_file = :skill_file;';
    lQuery.ParamByName('skill_file').AsString := aSkillFile;
    lQuery.Open;
    if lQuery.IsEmpty then
    begin
      Result := 0;
    end else begin
      Result := lQuery.Fields[0].AsInteger;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDatabaseManager.ApplyPragmas(var aResult: TDbInitResult);
begin
  QueryScalarText('PRAGMA journal_mode=WAL;');
  fConnection.ExecSQL('PRAGMA synchronous=NORMAL;');
  fConnection.ExecSQL('PRAGMA temp_store=MEMORY;');
  fConnection.ExecSQL('PRAGMA foreign_keys=ON;');

  aResult.JournalMode := LowerCase(QueryScalarText('PRAGMA journal_mode;'));
  aResult.SynchronousMode := QueryScalarText('PRAGMA synchronous;');
  aResult.TempStore := QueryScalarText('PRAGMA temp_store;');
  aResult.ForeignKeysEnabled := QueryScalarInt('PRAGMA foreign_keys;');
end;

procedure TDatabaseManager.VerifyFts5Support;
begin
  fConnection.ExecSQL('CREATE VIRTUAL TABLE IF NOT EXISTS temp.fts5_probe USING fts5(content);');
  fConnection.ExecSQL('DROP TABLE IF EXISTS temp.fts5_probe;');
end;

procedure TDatabaseManager.RunMigrations;
const
  cSchemaSql =
    'CREATE TABLE IF NOT EXISTS meta (' +
    '  key TEXT PRIMARY KEY,' +
    '  value TEXT NOT NULL' +
    ');' +
    'CREATE TABLE IF NOT EXISTS sources (' +
    '  id INTEGER PRIMARY KEY,' +
    '  path TEXT NOT NULL UNIQUE,' +
    '  enabled INTEGER NOT NULL DEFAULT 1,' +
    '  last_scan_utc TEXT' +
    ');' +
    'CREATE TABLE IF NOT EXISTS repos (' +
    '  id INTEGER PRIMARY KEY,' +
    '  root_path TEXT NOT NULL UNIQUE,' +
    '  last_pull_utc TEXT,' +
    '  last_pull_status TEXT,' +
    '  last_pull_output TEXT,' +
    '  last_pull_duration_ms INTEGER,' +
    '  head_commit TEXT,' +
    '  last_seen_utc TEXT' +
    ');' +
    'CREATE TABLE IF NOT EXISTS skills (' +
    '  id INTEGER PRIMARY KEY,' +
    '  source_id INTEGER NOT NULL,' +
    '  repo_id INTEGER,' +
    '  skill_root TEXT NOT NULL UNIQUE,' +
    '  skill_file TEXT NOT NULL UNIQUE,' +
    '  name TEXT NOT NULL,' +
    '  description TEXT,' +
    '  tags TEXT,' +
    '  body_md TEXT NOT NULL,' +
    '  body_hash TEXT NOT NULL,' +
    '  file_mtime_utc TEXT NOT NULL,' +
    '  indexed_utc TEXT NOT NULL,' +
    '  has_scripts INTEGER NOT NULL DEFAULT 0,' +
    '  scripts_count INTEGER NOT NULL DEFAULT 0,' +
    '  scripts_exts TEXT,' +
    '  FOREIGN KEY(source_id) REFERENCES sources(id),' +
    '  FOREIGN KEY(repo_id) REFERENCES repos(id)' +
    ');' +
    'CREATE VIRTUAL TABLE IF NOT EXISTS skills_fts USING fts5(' +
    '  name,' +
    '  description,' +
    '  tags,' +
    '  body_md,' +
    '  tokenize=''unicode61''' +
    ');';
begin
  fConnection.StartTransaction;
  try
    fConnection.ExecSQL(cSchemaSql);
    fConnection.ExecSQL(
      'INSERT INTO sources(id, path, enabled, last_scan_utc) VALUES (1, ''(auto)'', 1, NULL) ' +
      'ON CONFLICT(id) DO NOTHING;'
    );
    fConnection.ExecSQL('INSERT INTO meta(key, value) VALUES (''schema_version'', ''1'') ON CONFLICT(key) DO UPDATE SET value=excluded.value;');
    fConnection.Commit;
  except
    on E: Exception do
    begin
      if fConnection.InTransaction then
      begin
        fConnection.Rollback;
      end;
      raise Exception.CreateFmt('DB migration failed: %s', [E.Message]);
    end;
  end;
end;

function TDatabaseManager.Initialize: TDbInitResult;
begin
  EnsureDatabaseFolder;
  ConfigureConnection;

  Result.DatabasePath := fDatabasePath;
  ApplyPragmas(Result);
  VerifyFts5Support;
  Result.Fts5Enabled := True;
  RunMigrations;
end;

function TDatabaseManager.GetRepoCount: Integer;
begin
  Result := QueryScalarInt('SELECT COUNT(1) FROM repos;');
end;

function TDatabaseManager.GetSkillCount: Integer;
begin
  Result := QueryScalarInt('SELECT COUNT(1) FROM skills;');
end;

function TDatabaseManager.GetSkillFtsBodyBySkillFile(const aSkillFile: string): string;
var
  lQuery: TFDQuery;
begin
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text :=
      'SELECT f.body_md ' +
      'FROM skills_fts f ' +
      'JOIN skills s ON s.id = f.rowid ' +
      'WHERE s.skill_file = :skill_file;';
    lQuery.ParamByName('skill_file').AsString := aSkillFile;
    lQuery.Open;
    if lQuery.IsEmpty then
    begin
      Exit('');
    end;

    Result := lQuery.Fields[0].AsString;
  finally
    lQuery.Free;
  end;
end;

function TDatabaseManager.TableExists(const aTableName: string): Boolean;
begin
  Result := QueryScalarInt(
    'SELECT COUNT(1) FROM sqlite_master WHERE type IN (''table'', ''view'') AND name = ' +
    QuotedStr(aTableName) + ';'
  ) > 0;
end;

function TDatabaseManager.TryGetSkillState(const aSkillFile: string; out aState: TSkillState): Boolean;
var
  lQuery: TFDQuery;
begin
  aState := Default(TSkillState);

  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text :=
      'SELECT id, skill_root, skill_file, name, description, tags, body_md, body_hash, indexed_utc ' +
      'FROM skills WHERE skill_file = :skill_file;';
    lQuery.ParamByName('skill_file').AsString := aSkillFile;
    lQuery.Open;

    Result := not lQuery.IsEmpty;
    if not Result then
    begin
      Exit(False);
    end;

    aState.Id := lQuery.FieldByName('id').AsInteger;
    aState.SkillRoot := lQuery.FieldByName('skill_root').AsString;
    aState.SkillFile := lQuery.FieldByName('skill_file').AsString;
    aState.Name := lQuery.FieldByName('name').AsString;
    aState.Description := lQuery.FieldByName('description').AsString;
    aState.Tags := lQuery.FieldByName('tags').AsString;
    aState.BodyMarkdown := lQuery.FieldByName('body_md').AsString;
    aState.BodyHash := lQuery.FieldByName('body_hash').AsString;
    aState.IndexedUtc := lQuery.FieldByName('indexed_utc').AsString;
  finally
    lQuery.Free;
  end;
end;

function TDatabaseManager.TryGetRepoState(const aRootPath: string; out aState: TRepoState): Boolean;
var
  lQuery: TFDQuery;
begin
  aState := Default(TRepoState);

  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text :=
      'SELECT root_path, last_pull_utc, last_pull_status, last_pull_output, last_pull_duration_ms, head_commit, last_seen_utc ' +
      'FROM repos WHERE root_path = :root_path;';
    lQuery.ParamByName('root_path').AsString := aRootPath;
    lQuery.Open;

    Result := not lQuery.IsEmpty;
    if not Result then
    begin
      Exit(False);
    end;

    aState.RootPath := lQuery.FieldByName('root_path').AsString;
    aState.LastPullUtc := lQuery.FieldByName('last_pull_utc').AsString;
    aState.LastPullStatus := lQuery.FieldByName('last_pull_status').AsString;
    aState.LastPullOutput := lQuery.FieldByName('last_pull_output').AsString;
    aState.LastPullDurationMs := lQuery.FieldByName('last_pull_duration_ms').AsInteger;
    aState.HeadCommit := lQuery.FieldByName('head_commit').AsString;
    aState.LastSeenUtc := lQuery.FieldByName('last_seen_utc').AsString;
  finally
    lQuery.Free;
  end;
end;

procedure TDatabaseManager.UpsertRepoRoot(const aRootPath: string);
var
  lUtcNow: TDateTime;
  lUtcText: string;
begin
  lUtcNow := TTimeZone.Local.ToUniversalTime(Now);
  lUtcText := FormatDateTime('yyyy-mm-dd\"T\"hh:nn:ss\"Z\"', lUtcNow, TFormatSettings.Invariant);

  fConnection.ExecSQL(
    'INSERT INTO repos(root_path, last_seen_utc) VALUES (:root_path, :last_seen_utc) ' +
    'ON CONFLICT(root_path) DO UPDATE SET last_seen_utc=excluded.last_seen_utc',
    [aRootPath, lUtcText]
  );
end;

procedure TDatabaseManager.UpsertRepoPullResult(const aPull: TRepoPullUpdate);
var
  lQuery: TFDQuery;
  lUtcNow: TDateTime;
  lUtcText: string;
begin
  lUtcNow := TTimeZone.Local.ToUniversalTime(Now);
  lUtcText := FormatDateTime('yyyy-mm-dd\"T\"hh:nn:ss\"Z\"', lUtcNow, TFormatSettings.Invariant);

  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text :=
      'INSERT INTO repos(root_path, last_pull_utc, last_pull_status, last_pull_output, last_pull_duration_ms, head_commit, last_seen_utc) ' +
      'VALUES (:root_path, :last_pull_utc, :last_pull_status, :last_pull_output, :last_pull_duration_ms, :head_commit, :last_seen_utc) ' +
      'ON CONFLICT(root_path) DO UPDATE SET ' +
      '  last_pull_utc=COALESCE(excluded.last_pull_utc, repos.last_pull_utc), ' +
      '  last_pull_status=excluded.last_pull_status, ' +
      '  last_pull_output=excluded.last_pull_output, ' +
      '  last_pull_duration_ms=excluded.last_pull_duration_ms, ' +
      '  head_commit=COALESCE(excluded.head_commit, repos.head_commit), ' +
      '  last_seen_utc=excluded.last_seen_utc';

    lQuery.ParamByName('root_path').AsString := aPull.RootPath;

    if Trim(aPull.LastPullUtc) <> '' then
    begin
      lQuery.ParamByName('last_pull_utc').AsString := aPull.LastPullUtc;
    end else begin
      lQuery.ParamByName('last_pull_utc').DataType := ftString;
      lQuery.ParamByName('last_pull_utc').Clear;
    end;

    lQuery.ParamByName('last_pull_status').AsString := aPull.LastPullStatus;
    lQuery.ParamByName('last_pull_output').AsString := aPull.LastPullOutput;
    lQuery.ParamByName('last_pull_duration_ms').AsInteger := aPull.LastPullDurationMs;

    if Trim(aPull.HeadCommit) <> '' then
    begin
      lQuery.ParamByName('head_commit').AsString := aPull.HeadCommit;
    end else begin
      lQuery.ParamByName('head_commit').DataType := ftString;
      lQuery.ParamByName('head_commit').Clear;
    end;

    lQuery.ParamByName('last_seen_utc').AsString := lUtcText;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
end;

function TDatabaseManager.IsSkillUnchanged(const aSkill: TIndexedSkill): Boolean;
var
  lQuery: TFDQuery;
begin
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text := 'SELECT body_hash, file_mtime_utc FROM skills WHERE skill_file = :skill_file;';
    lQuery.ParamByName('skill_file').AsString := aSkill.SkillFile;
    lQuery.Open;
    if lQuery.IsEmpty then
    begin
      Exit(False);
    end;

    Result := SameText(lQuery.FieldByName('body_hash').AsString, aSkill.BodyHash) and
      SameText(lQuery.FieldByName('file_mtime_utc').AsString, aSkill.FileMtimeUtc);
  finally
    lQuery.Free;
  end;
end;

procedure TDatabaseManager.UpsertSkill(const aSkill: TIndexedSkill);
var
  lQuery: TFDQuery;
  lSkillId: Integer;
begin
  if IsSkillUnchanged(aSkill) then
  begin
    Exit;
  end;

  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := fConnection;
    lQuery.SQL.Text :=
      'INSERT INTO skills (' +
      '  source_id, repo_id, skill_root, skill_file, name, description, tags, body_md, body_hash, file_mtime_utc, indexed_utc' +
      ') VALUES (' +
      '  :source_id, :repo_id, :skill_root, :skill_file, :name, :description, :tags, :body_md, :body_hash, :file_mtime_utc, :indexed_utc' +
      ') ON CONFLICT(skill_file) DO UPDATE SET ' +
      '  source_id=excluded.source_id, ' +
      '  repo_id=excluded.repo_id, ' +
      '  skill_root=excluded.skill_root, ' +
      '  name=excluded.name, ' +
      '  description=excluded.description, ' +
      '  tags=excluded.tags, ' +
      '  body_md=excluded.body_md, ' +
      '  body_hash=excluded.body_hash, ' +
      '  file_mtime_utc=excluded.file_mtime_utc, ' +
      '  indexed_utc=excluded.indexed_utc';

    lQuery.ParamByName('source_id').AsInteger := aSkill.SourceId;
    if aSkill.RepoId > 0 then
    begin
      lQuery.ParamByName('repo_id').AsInteger := aSkill.RepoId;
    end else begin
      lQuery.ParamByName('repo_id').DataType := ftInteger;
      lQuery.ParamByName('repo_id').Clear;
    end;
    lQuery.ParamByName('skill_root').AsString := aSkill.SkillRoot;
    lQuery.ParamByName('skill_file').AsString := aSkill.SkillFile;
    lQuery.ParamByName('name').AsString := aSkill.Name;
    lQuery.ParamByName('description').AsString := aSkill.Description;
    lQuery.ParamByName('tags').AsString := aSkill.Tags;
    lQuery.ParamByName('body_md').AsString := aSkill.BodyMarkdown;
    lQuery.ParamByName('body_hash').AsString := aSkill.BodyHash;
    lQuery.ParamByName('file_mtime_utc').AsString := aSkill.FileMtimeUtc;
    lQuery.ParamByName('indexed_utc').AsString := aSkill.IndexedUtc;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;

  lSkillId := QuerySkillIdBySkillFile(aSkill.SkillFile);
  if lSkillId > 0 then
  begin
    fConnection.ExecSQL('DELETE FROM skills_fts WHERE rowid = :rowid', [lSkillId]);
    fConnection.ExecSQL(
      'INSERT INTO skills_fts(rowid, name, description, tags, body_md) VALUES(:rowid, :name, :description, :tags, :body_md)',
      [lSkillId, aSkill.Name, aSkill.Description, aSkill.Tags, aSkill.BodyMarkdown]
    );
  end;
end;

procedure TDatabaseManager.WriteBatch(const aRepoRoots: TArray<string>; const aSkills: TArray<TIndexedSkill>);
begin
  WriteBatchWithRepoPulls(aRepoRoots, nil, aSkills);
end;

procedure TDatabaseManager.WriteBatchWithRepoPulls(const aRepoRoots: TArray<string>;
  const aRepoPulls: TArray<TRepoPullUpdate>; const aSkills: TArray<TIndexedSkill>);
var
  i: Integer;
begin
  if (Length(aRepoRoots) = 0) and (Length(aRepoPulls) = 0) and (Length(aSkills) = 0) then
  begin
    Exit;
  end;

  fConnection.StartTransaction;
  try
    for i := 0 to Pred(Length(aRepoRoots)) do
    begin
      UpsertRepoRoot(aRepoRoots[i]);
    end;

    for i := 0 to Pred(Length(aRepoPulls)) do
    begin
      UpsertRepoPullResult(aRepoPulls[i]);
    end;

    for i := 0 to Pred(Length(aSkills)) do
    begin
      UpsertSkill(aSkills[i]);
    end;

    fConnection.Commit;
  except
    on E: Exception do
    begin
      if fConnection.InTransaction then
      begin
        fConnection.Rollback;
      end;
      raise Exception.CreateFmt('Write batch failed: %s', [E.Message]);
    end;
  end;
end;

end.
