program PipelineTestsRunner;

{$APPTYPE CONSOLE}

{$IFNDEF WIN64}
  {$MESSAGE FATAL 'AgentSkillSearch requires Win64. Build target Win64 is mandatory because our SQLite runtime is x64-only.'}
{$ENDIF}

uses
  System.SysUtils,
  PipelineTests in 'PipelineTests.pas';

begin
  try
    RunPipelineTests;
    Writeln('ALL_TESTS_PASSED');
  except
    on E: Exception do
    begin
      Writeln('TEST_FAILED=', E.Message);
      ExitCode := 1;
    end;
  end;
end.
