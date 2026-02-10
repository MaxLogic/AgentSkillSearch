unit DatabaseManager;

interface

uses
  FireDAC.Comp.Client, FireDAC.Phys.SQLite;

type
  TDbInitResult = record
    DatabasePath: string;
    JournalMode: string;
    SynchronousMode: string;
    TempStore: string;
    ForeignKeysEnabled: Integer;
    Fts5Enabled: Boolean;
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
    function QueryScalarInt(const aSql: string): Integer;
    function QueryScalarText(const aSql: string): string;
    procedure RunMigrations;
    procedure VerifyFts5Support;
  public
    constructor Create(const aDatabasePath, aSqliteDllPath: string);
    destructor Destroy; override;
    function Initialize: TDbInitResult;
    function TableExists(const aTableName: string): Boolean;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
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
    '  content='''' ,' +
    '  tokenize=''unicode61''' +
    ');';
begin
  fConnection.StartTransaction;
  try
    fConnection.ExecSQL(cSchemaSql);
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

function TDatabaseManager.TableExists(const aTableName: string): Boolean;
begin
  Result := QueryScalarInt(
    'SELECT COUNT(1) FROM sqlite_master WHERE type IN (''table'', ''view'') AND name = ' +
    QuotedStr(aTableName) + ';'
  ) > 0;
end;

end.
