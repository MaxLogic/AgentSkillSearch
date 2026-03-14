unit ConfigDlg;

interface

uses
  System.Classes,
  Vcl.Buttons, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls;

type
  TConfigDlg = class(TForm)
  published
    BalloonHint: TBalloonHint;
    BtnEditSources: TBitBtn;
    BtnCancel: TBitBtn;
    BtnOK: TBitBtn;
    ChkCloseToTray: TCheckBox;
    ChkSearchAsYouType: TCheckBox;
    GrpBehaviour: TPanel;
    PnlButtons: TPanel;
    LblSection: TStaticText;
    LblTitle: TStaticText;
  private
    fSourcesEdited: Boolean;
    fSourcesListPath: string;
    function GetCloseToTray: Boolean;
    function GetSearchAsYouType: Boolean;
    procedure SetCloseToTray(const aValue: Boolean);
    procedure SetSearchAsYouType(const aValue: Boolean);
  published
    procedure HandleEditSourcesClick(Sender: TObject);
  public
    constructor Create(aOwner: TComponent); override;
    property CloseToTray: Boolean read GetCloseToTray write SetCloseToTray;
    property SearchAsYouType: Boolean read GetSearchAsYouType write SetSearchAsYouType;
    property SourcesEdited: Boolean read fSourcesEdited;
    property SourcesListPath: string read fSourcesListPath write fSourcesListPath;
  end;

implementation

uses
  MaxLogic.BalloonDefaultImageList,
  AppPaths, SourcesEditorForm;

{$R *.dfm}

constructor TConfigDlg.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  BalloonHint.Images := TImageListForBalloonForm.Instance.ImageList1;
  BalloonHint.ImageIndex := 0;
  CustomHint := BalloonHint;
  ShowHint := True;
  fSourcesEdited := False;
end;

procedure TConfigDlg.HandleEditSourcesClick(Sender: TObject);
begin
  if not TSourcesEditorForm.Execute(Self, fSourcesListPath, GetExeDirectory) then
  begin
    Exit;
  end;

  fSourcesEdited := True;
end;

function TConfigDlg.GetCloseToTray: Boolean;
begin
  Result := ChkCloseToTray.Checked;
end;

function TConfigDlg.GetSearchAsYouType: Boolean;
begin
  Result := ChkSearchAsYouType.Checked;
end;

procedure TConfigDlg.SetCloseToTray(const aValue: Boolean);
begin
  ChkCloseToTray.Checked := aValue;
end;

procedure TConfigDlg.SetSearchAsYouType(const aValue: Boolean);
begin
  ChkSearchAsYouType.Checked := aValue;
end;

end.
