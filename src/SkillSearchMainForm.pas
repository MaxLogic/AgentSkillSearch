unit SkillSearchMainForm;

interface

uses
  System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls;

type
  TSkillSearchMainForm = class(TForm)
  private
    fInfoLabel: TLabel;
    procedure InitializeDatabase;
  public
    constructor Create(aOwner: TComponent); override;
  end;

var
  MainForm: TSkillSearchMainForm;

implementation

uses
  AppPaths, DatabaseManager;

constructor TSkillSearchMainForm.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  Caption := 'Agent Skill Search';
  Width := 960;
  Height := 640;

  InitializeDatabase;

  fInfoLabel := TLabel.Create(self);
  fInfoLabel.Parent := self;
  fInfoLabel.Left := 24;
  fInfoLabel.Top := 24;
  fInfoLabel.Caption := 'Project bootstrap complete. Core features are implemented in subsequent tasks.';
end;

procedure TSkillSearchMainForm.InitializeDatabase;
var
  lDbManager: TDatabaseManager;
begin
  lDbManager := TDatabaseManager.Create(GetCacheDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;
  finally
    lDbManager.Free;
  end;
end;

end.
