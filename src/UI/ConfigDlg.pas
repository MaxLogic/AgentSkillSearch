unit ConfigDlg;

interface

uses
  System.Classes,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls;

type
  TConfigDlg = class(TForm)
  published
    BtnCancel: TButton;
    BtnOK: TButton;
    ChkCloseToTray: TCheckBox;
    GrpBehaviour: TGroupBox;
    PnlButtons: TPanel;
  private
    function GetCloseToTray: Boolean;
    procedure SetCloseToTray(const aValue: Boolean);
  public
    constructor Create(aOwner: TComponent); override;
    property CloseToTray: Boolean read GetCloseToTray write SetCloseToTray;
  end;

implementation

{$R *.dfm}

constructor TConfigDlg.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
end;

function TConfigDlg.GetCloseToTray: Boolean;
begin
  Result := ChkCloseToTray.Checked;
end;

procedure TConfigDlg.SetCloseToTray(const aValue: Boolean);
begin
  ChkCloseToTray.Checked := aValue;
end;

end.
