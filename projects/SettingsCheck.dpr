program SettingsCheck;

{$APPTYPE CONSOLE}

{$IFNDEF WIN64}
  {$MESSAGE FATAL 'AgentSkillSearch requires Win64. Build target Win64 is mandatory because our SQLite runtime is x64-only.'}
{$ENDIF}

uses
  System.SysUtils,
  Settings in '..\src\Settings.pas';

var
  i: Integer;
  lResult: TSettingsLoadResult;

begin
  try
    lResult := LoadOrCreateSettings(GetSettingsFilePath);
    Writeln('SETTINGS_PATH=', lResult.SettingsPath);
    Writeln('RESTORED_KEYS_COUNT=', Length(lResult.RestoredKeys));

    for i := 0 to Pred(Length(lResult.RestoredKeys)) do
    begin
      Writeln('RESTORED_KEY=', lResult.RestoredKeys[i]);
    end;
  except
    on E: Exception do
    begin
      Writeln('ERROR=', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
