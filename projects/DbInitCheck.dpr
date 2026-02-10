program DbInitCheck;

{$APPTYPE CONSOLE}

{$IFNDEF WIN64}
  {$MESSAGE FATAL 'AgentSkillSearch requires Win64. Build target Win64 is mandatory because our SQLite runtime is x64-only.'}
{$ENDIF}

uses
  System.SysUtils,
  AppPaths in '..\src\AppPaths.pas',
  DatabaseManager in '..\src\Db\DatabaseManager.pas';

var
  lResult: TDbInitResult;
  lDbManager: TDatabaseManager;

begin
  try
    lDbManager := TDatabaseManager.Create(GetCacheDbPath, GetSqliteDllPath);
    try
      lResult := lDbManager.Initialize;

      Writeln('DB_PATH=', lResult.DatabasePath);
      Writeln('JOURNAL_MODE=', lResult.JournalMode);
      Writeln('SYNCHRONOUS=', lResult.SynchronousMode);
      Writeln('TEMP_STORE=', lResult.TempStore);
      Writeln('FOREIGN_KEYS=', lResult.ForeignKeysEnabled);
      Writeln('FTS5_ENABLED=', BoolToStr(lResult.Fts5Enabled, True));
      Writeln('HAS_META=', BoolToStr(lDbManager.TableExists('meta'), True));
      Writeln('HAS_SOURCES=', BoolToStr(lDbManager.TableExists('sources'), True));
      Writeln('HAS_REPOS=', BoolToStr(lDbManager.TableExists('repos'), True));
      Writeln('HAS_SKILLS=', BoolToStr(lDbManager.TableExists('skills'), True));
      Writeln('HAS_SKILLS_FTS=', BoolToStr(lDbManager.TableExists('skills_fts'), True));
    finally
      lDbManager.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('ERROR=', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
