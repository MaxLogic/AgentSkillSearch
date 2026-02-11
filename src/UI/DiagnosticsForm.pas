unit DiagnosticsForm;

interface

uses
  System.Classes, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls;

procedure ShowDiagnosticsDialog(aOwner: TComponent);

implementation

uses
  Logging;

type
  TDiagnosticsForm = class(TForm)
  private
    fCloseButton: TButton;
    fMemo: TMemo;
    fRefreshButton: TButton;
    procedure HandleCloseClick(Sender: TObject);
    procedure HandleRefreshClick(Sender: TObject);
    procedure RefreshText;
  public
    constructor Create(aOwner: TComponent); override;
  end;

constructor TDiagnosticsForm.Create(aOwner: TComponent);
var
  lButtonsPanel: TPanel;
begin
  inherited CreateNew(aOwner);
  Caption := 'Diagnostics';
  Width := 900;
  Height := 620;
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;

  lButtonsPanel := TPanel.Create(self);
  lButtonsPanel.Parent := self;
  lButtonsPanel.Align := alBottom;
  lButtonsPanel.Height := 44;
  lButtonsPanel.BevelOuter := bvNone;

  fCloseButton := TButton.Create(self);
  fCloseButton.Parent := lButtonsPanel;
  fCloseButton.Align := alRight;
  fCloseButton.Width := 100;
  fCloseButton.Caption := 'Close';
  fCloseButton.Cancel := True;
  fCloseButton.OnClick := HandleCloseClick;

  fRefreshButton := TButton.Create(self);
  fRefreshButton.Parent := lButtonsPanel;
  fRefreshButton.Align := alRight;
  fRefreshButton.Width := 100;
  fRefreshButton.Caption := 'Refresh';
  fRefreshButton.OnClick := HandleRefreshClick;

  fMemo := TMemo.Create(self);
  fMemo.Parent := self;
  fMemo.Align := alClient;
  fMemo.ReadOnly := True;
  fMemo.ScrollBars := ssBoth;
  fMemo.WordWrap := False;

  RefreshText;
end;

procedure TDiagnosticsForm.HandleCloseClick(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TDiagnosticsForm.HandleRefreshClick(Sender: TObject);
begin
  RefreshText;
end;

procedure TDiagnosticsForm.RefreshText;
begin
  fMemo.Lines.Text := BuildDiagnosticsText;
  fMemo.SelStart := 0;
end;

procedure ShowDiagnosticsDialog(aOwner: TComponent);
var
  lForm: TDiagnosticsForm;
begin
  lForm := TDiagnosticsForm.Create(aOwner);
  try
    lForm.ShowModal;
  finally
    lForm.Free;
  end;
end;

end.
