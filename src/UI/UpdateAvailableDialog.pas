unit UpdateAvailableDialog;

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Buttons, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls,
  VCL.TMSFNCWebBrowser,
  AppUpdateActions;

type
  TUpdateAvailableDialog = class(TForm)
  published
    BtnLater: TBitBtn;
    BtnOpenRelease: TBitBtn;
    ButtonsPanel: TPanel;
    CopyPanel: TPanel;
    DetailText: TStaticText;
    PromptText: TStaticText;
    TitleText: TStaticText;
    VisualBrowser: TTMSFNCWebBrowser;
    VisualPanel: TPanel;
    VisualShellPanel: TPanel;
    EyebrowText: TStaticText;
    VersionCardPanel: TPanel;
    VersionText: TStaticText;
    ReleaseNameText: TStaticText;
    procedure FormShow(Sender: TObject);
    procedure VisualBrowserInitialized(Sender: TObject);
  private
    fBrowserReady: Boolean;
    fPendingVisualHtml: string;
    procedure ApplyPrompt(const aPrompt: TUpdatePromptInfo);
    procedure LoadVisualHtml(const aHtml: string);
  public
    class function Execute(aOwner: TComponent; const aPrompt: TUpdatePromptInfo): Boolean;
  end;

implementation

uses
  UpdateAvailableDialogHtml;

{$R *.dfm}

procedure TUpdateAvailableDialog.ApplyPrompt(const aPrompt: TUpdatePromptInfo);
begin
  Caption := 'Update available';
  TitleText.Caption := aPrompt.Headline;
  PromptText.Caption := aPrompt.BodyText;
  DetailText.Caption := 'Want me to open GitHub so we can take a look?';
  ReleaseNameText.Caption := 'Release: ' + aPrompt.ReleaseName;
  VersionText.Caption := Format('Current: %s' + sLineBreak + 'Latest: %s', [aPrompt.CurrentVersion, aPrompt.LatestVersion]);
  LoadVisualHtml(GetUpdateAvailableVisualHtml);
end;

class function TUpdateAvailableDialog.Execute(aOwner: TComponent; const aPrompt: TUpdatePromptInfo): Boolean;
var
  lDialog: TUpdateAvailableDialog;
begin
  lDialog := TUpdateAvailableDialog.Create(aOwner);
  try
    lDialog.ApplyPrompt(aPrompt);
    Result := lDialog.ShowModal = mrOK;
  finally
    lDialog.Free;
  end;
end;

procedure TUpdateAvailableDialog.FormShow(Sender: TObject);
begin
  BtnOpenRelease.SetFocus;
end;

procedure TUpdateAvailableDialog.LoadVisualHtml(const aHtml: string);
begin
  fPendingVisualHtml := aHtml;
  if fBrowserReady then
  begin
    VisualBrowser.LoadHTML(fPendingVisualHtml);
  end;
end;

procedure TUpdateAvailableDialog.VisualBrowserInitialized(Sender: TObject);
begin
  fBrowserReady := True;
  if Trim(fPendingVisualHtml) <> '' then
  begin
    VisualBrowser.LoadHTML(fPendingVisualHtml);
  end;
end;

end.
