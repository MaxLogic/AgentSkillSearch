program AgentSkillSearch;

{$IFNDEF WIN64}
  {$MESSAGE FATAL 'AgentSkillSearch requires Win64. Build target Win64 is mandatory because our SQLite runtime is x64-only.'}
{$ENDIF}

uses
  Vcl.Forms,
  SkillSearchMainForm in '..\src\SkillSearchMainForm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TSkillSearchMainForm, MainForm);
  Application.Run;
end.
