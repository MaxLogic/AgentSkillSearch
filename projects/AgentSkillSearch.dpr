program AgentSkillSearch;

{$IFNDEF WIN64}
  {$MESSAGE FATAL 'AgentSkillSearch requires Win64. Build target Win64 is mandatory because our SQLite runtime is x64-only.'}
{$ENDIF}

uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  FireDAC.VCLUI.Wait,
  Vcl.Forms,
  MainForm in '..\src\UI\MainForm.pas',
  SourcesEditorForm in '..\src\UI\SourcesEditorForm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, AppMainForm);
  Application.Run;
end.
