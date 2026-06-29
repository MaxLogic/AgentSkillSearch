unit FailedRepoPullsDialog;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.Types,
  Vcl.Buttons, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics, Vcl.StdCtrls,
  DatabaseManager, GitPullFailures;

type
  TFailedRepoPullGroup = record
    Actions: TArray<TGitPullRepairAction>;
    Caption: string;
    Pulls: TArray<TRepoPullUpdate>;
    Reason: TGitPullFailureReason;
  end;

  TRepairButtonContext = record
    ActionKind: TGitPullRepairActionKind;
    GroupIndex: Integer;
    IsGroup: Boolean;
    RepoPath: string;
  end;

  TFailedRepoPullsDialog = class(TForm)
  published
    BtnClose: TBitBtn;
    ContentPanel: TPanel;
    FooterPanel: TPanel;
    HeaderPanel: TPanel;
    RepoHostPanel: TPanel;
    RepoScrollBox: TScrollBox;
    StatusText: TStaticText;
    SummaryText: TStaticText;
    TitleText: TStaticText;
    procedure HandleCloseClick(Sender: TObject);
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  private
    fButtonContexts: TDictionary<TObject, TRepairButtonContext>;
    fGitExePath: string;
    fGroups: TArray<TFailedRepoPullGroup>;
    fRepairsApplied: Boolean;
    function ConfirmRepair(const aAction: TGitPullRepairAction; const aRepoCount: Integer): Boolean;
    procedure ClearDynamicContent;
    procedure CreateActionButton(aParent: TWinControl; const aCaption: string; const aContext: TRepairButtonContext);
    procedure CreateGroupSection(const aGroupIndex: Integer);
    procedure CreateRepoCard(aParent: TWinControl; const aGroupIndex, aPullIndex: Integer);
    procedure HandleOpenRepoClick(Sender: TObject);
    procedure HandleRepairClick(Sender: TObject);
    procedure ResizeRepoHostPanel;
    function ScaleVal(const aValue: Integer): Integer;
    procedure SetStatus(const aText: string);
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    class function Execute(aOwner: TComponent; const aFailedPulls: TArray<TRepoPullUpdate>; const aGitExePath: string;
      out aRepairsApplied: Boolean): Boolean; static;
    procedure LoadFailures(const aFailedPulls: TArray<TRepoPullUpdate>);
    property RepairsApplied: Boolean read fRepairsApplied;
  end;

function BuildFailedRepoPullGroups(const aFailedPulls: TArray<TRepoPullUpdate>): TArray<TFailedRepoPullGroup>;
function GitPullFailureReasonCaption(const aReason: TGitPullFailureReason): string;
function ShouldResolveFailedRepoPullsAfterScan(const aExecuted, aCancelled: Boolean; const aFailure: string;
  const aFailedPullCount: Integer): Boolean;

implementation

uses
  System.IOUtils, System.UITypes,
  Winapi.ShellAPI, Winapi.Windows,
  Vcl.Dialogs;

{$R *.dfm}

function GitPullFailureReasonCaption(const aReason: TGitPullFailureReason): string;
begin
  case aReason of
    TGitPullFailureReason.gfrLocalChanges:
      Result := 'Local changes would be overwritten';
    TGitPullFailureReason.gfrDiverged:
      Result := 'Branch cannot fast-forward';
    TGitPullFailureReason.gfrStaleRemoteRefs:
      Result := 'Stale remote-tracking refs';
    TGitPullFailureReason.gfrRemoteMissing:
      Result := 'Remote repository not found';
    TGitPullFailureReason.gfrAuthentication:
      Result := 'Authentication required';
  else
    Result := 'Unknown pull failure';
  end;
end;

function ShouldResolveFailedRepoPullsAfterScan(const aExecuted, aCancelled: Boolean; const aFailure: string;
  const aFailedPullCount: Integer): Boolean;
begin
  Result := aExecuted and (not aCancelled) and (Trim(aFailure) = '') and (aFailedPullCount > 0);
end;

procedure AddPullToGroup(var aGroup: TFailedRepoPullGroup; const aPull: TRepoPullUpdate);
var
  lIndex: Integer;
begin
  lIndex := Length(aGroup.Pulls);
  SetLength(aGroup.Pulls, lIndex + 1);
  aGroup.Pulls[lIndex] := aPull;
end;

function BuildRepairStatusText(const aAction: TGitPullRepairAction; const aResults: TArray<TGitPullRepairResult>;
  const aSuccessCount: Integer): string;
var
  i: Integer;
  lFailedCount: Integer;
  lUpdatedRepos: string;
begin
  lFailedCount := Length(aResults) - aSuccessCount;
  lUpdatedRepos := '';
  for i := 0 to Pred(Length(aResults)) do
  begin
    if aResults[i].Success then
    begin
      if lUpdatedRepos <> '' then
      begin
        lUpdatedRepos := lUpdatedRepos + '; ';
      end;
      lUpdatedRepos := lUpdatedRepos + aResults[i].RepoPath;
    end;
  end;

  Result := Format('%s finished: %d fixed, %d failed.', [aAction.Caption, aSuccessCount, lFailedCount]);
  if lUpdatedRepos <> '' then
  begin
    Result := Result + ' Updated: ' + lUpdatedRepos;
  end;
end;

function BuildFailedRepoPullGroups(const aFailedPulls: TArray<TRepoPullUpdate>): TArray<TFailedRepoPullGroup>;
var
  i: Integer;
  j: Integer;
  lGroupIndex: Integer;
  lReason: TGitPullFailureReason;
begin
  Result := nil;

  for i := 0 to Pred(Length(aFailedPulls)) do
  begin
    lReason := ClassifyGitPullFailure(aFailedPulls[i].LastPullOutput);
    lGroupIndex := -1;

    for j := 0 to Pred(Length(Result)) do
    begin
      if Result[j].Reason = lReason then
      begin
        lGroupIndex := j;
        Break;
      end;
    end;

    if lGroupIndex < 0 then
    begin
      lGroupIndex := Length(Result);
      SetLength(Result, lGroupIndex + 1);
      Result[lGroupIndex].Reason := lReason;
      Result[lGroupIndex].Caption := GitPullFailureReasonCaption(lReason);
      Result[lGroupIndex].Actions := BuildGitPullRepairActions(lReason);
    end;

    AddPullToGroup(Result[lGroupIndex], aFailedPulls[i]);
  end;
end;

constructor TFailedRepoPullsDialog.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fButtonContexts := TDictionary<TObject, TRepairButtonContext>.Create;
  fGitExePath := 'git.exe';
end;

destructor TFailedRepoPullsDialog.Destroy;
begin
  fButtonContexts.Free;
  inherited Destroy;
end;

function TFailedRepoPullsDialog.ConfirmRepair(const aAction: TGitPullRepairAction; const aRepoCount: Integer): Boolean;
begin
  if not aAction.RequiresConfirmation then
  begin
    Exit(True);
  end;

  Result := MessageDlg(Format('%s can discard local work in %d repo(s). Continue?',
    [aAction.Caption, aRepoCount]), mtWarning, [mbYes, mbNo], 0) = mrYes;
end;

procedure TFailedRepoPullsDialog.ClearDynamicContent;
begin
  fButtonContexts.Clear;
  while RepoHostPanel.ControlCount > 0 do
  begin
    RepoHostPanel.Controls[0].Free;
  end;
  RepoHostPanel.Height := ScaleVal(1);
end;

procedure TFailedRepoPullsDialog.CreateActionButton(aParent: TWinControl; const aCaption: string;
  const aContext: TRepairButtonContext);
var
  lButton: TBitBtn;
begin
  lButton := TBitBtn.Create(aParent);
  lButton.Parent := aParent;
  lButton.Align := alLeft;
  lButton.AlignWithMargins := True;
  lButton.Margins.Left := 0;
  lButton.Margins.Top := 0;
  lButton.Margins.Right := ScaleVal(8);
  lButton.Margins.Bottom := 0;
  lButton.Width := ScaleVal(128);
  lButton.Caption := aCaption;
  lButton.TabOrder := Pred(aParent.ControlCount);
  lButton.OnClick := HandleRepairClick;
  fButtonContexts.Add(lButton, aContext);
end;

procedure TFailedRepoPullsDialog.CreateGroupSection(const aGroupIndex: Integer);
var
  i: Integer;
  lActionPanel: TPanel;
  lContext: TRepairButtonContext;
  lGroupHeaderPanel: TPanel;
  lGroupPanel: TPanel;
  lHeaderText: TStaticText;
begin
  lGroupPanel := TPanel.Create(RepoHostPanel);
  lGroupPanel.Parent := RepoHostPanel;
  lGroupPanel.Align := alTop;
  lGroupPanel.AlignWithMargins := True;
  lGroupPanel.Margins.Left := 0;
  lGroupPanel.Margins.Top := 0;
  lGroupPanel.Margins.Right := ScaleVal(12);
  lGroupPanel.Margins.Bottom := ScaleVal(12);
  lGroupPanel.BevelOuter := bvNone;
  lGroupPanel.Caption := '';
  lGroupPanel.Color := clWindow;
  lGroupPanel.ParentBackground := False;
  lGroupPanel.Padding.Left := ScaleVal(12);
  lGroupPanel.Padding.Top := ScaleVal(12);
  lGroupPanel.Padding.Right := ScaleVal(12);
  lGroupPanel.Padding.Bottom := ScaleVal(12);
  lGroupPanel.Height := ScaleVal(86) + (Length(fGroups[aGroupIndex].Pulls) * ScaleVal(96));
  lGroupPanel.TabOrder := Pred(RepoHostPanel.ControlCount);

  lActionPanel := TPanel.Create(lGroupPanel);
  lActionPanel.Parent := lGroupPanel;
  lActionPanel.Align := alTop;
  lActionPanel.Height := ScaleVal(36);
  lActionPanel.BevelOuter := bvNone;
  lActionPanel.Caption := '';
  lActionPanel.TabOrder := 1;

  for i := 0 to Pred(Length(fGroups[aGroupIndex].Actions)) do
  begin
    lContext.ActionKind := fGroups[aGroupIndex].Actions[i].Kind;
    lContext.GroupIndex := aGroupIndex;
    lContext.IsGroup := True;
    lContext.RepoPath := '';
    CreateActionButton(lActionPanel, fGroups[aGroupIndex].Actions[i].Caption + ' all', lContext);
  end;

  lGroupHeaderPanel := TPanel.Create(lGroupPanel);
  lGroupHeaderPanel.Parent := lGroupPanel;
  lGroupHeaderPanel.Align := alTop;
  lGroupHeaderPanel.Height := ScaleVal(38);
  lGroupHeaderPanel.BevelOuter := bvNone;
  lGroupHeaderPanel.Caption := '';
  lGroupHeaderPanel.Color := clBtnFace;
  lGroupHeaderPanel.ParentBackground := False;
  lGroupHeaderPanel.Padding.Left := ScaleVal(10);
  lGroupHeaderPanel.Padding.Top := ScaleVal(7);
  lGroupHeaderPanel.Padding.Right := ScaleVal(10);
  lGroupHeaderPanel.Padding.Bottom := ScaleVal(7);
  lGroupHeaderPanel.TabOrder := 0;

  lHeaderText := TStaticText.Create(lGroupHeaderPanel);
  lHeaderText.Parent := lGroupHeaderPanel;
  lHeaderText.Align := alClient;
  lHeaderText.AutoSize := False;
  lHeaderText.Caption := Format('Reason: %s  |  %d repo(s), %d repair action(s)',
    [fGroups[aGroupIndex].Caption, Length(fGroups[aGroupIndex].Pulls), Length(fGroups[aGroupIndex].Actions)]);
  lHeaderText.Font.Style := [fsBold];
  lHeaderText.TabStop := False;

  for i := Pred(Length(fGroups[aGroupIndex].Pulls)) downto 0 do
  begin
    CreateRepoCard(lGroupPanel, aGroupIndex, i);
  end;
end;

procedure TFailedRepoPullsDialog.CreateRepoCard(aParent: TWinControl; const aGroupIndex, aPullIndex: Integer);
var
  i: Integer;
  lButtonPanel: TPanel;
  lContext: TRepairButtonContext;
  lOpenButton: TBitBtn;
  lOutputText: TStaticText;
  lPathText: TStaticText;
  lPull: TRepoPullUpdate;
  lRepoPanel: TPanel;
begin
  lPull := fGroups[aGroupIndex].Pulls[aPullIndex];

  lRepoPanel := TPanel.Create(aParent);
  lRepoPanel.Parent := aParent;
  lRepoPanel.Align := alTop;
  lRepoPanel.AlignWithMargins := True;
  lRepoPanel.Margins.Left := 0;
  lRepoPanel.Margins.Top := ScaleVal(8);
  lRepoPanel.Margins.Right := 0;
  lRepoPanel.Margins.Bottom := 0;
  lRepoPanel.Height := ScaleVal(88);
  lRepoPanel.BevelOuter := bvNone;
  lRepoPanel.Caption := '';
  lRepoPanel.Color := clBtnFace;
  lRepoPanel.ParentBackground := False;
  lRepoPanel.Padding.Left := ScaleVal(10);
  lRepoPanel.Padding.Top := ScaleVal(8);
  lRepoPanel.Padding.Right := ScaleVal(10);
  lRepoPanel.Padding.Bottom := ScaleVal(8);
  lRepoPanel.TabOrder := Pred(aParent.ControlCount);

  lButtonPanel := TPanel.Create(lRepoPanel);
  lButtonPanel.Parent := lRepoPanel;
  lButtonPanel.Align := alBottom;
  lButtonPanel.Height := ScaleVal(30);
  lButtonPanel.BevelOuter := bvNone;
  lButtonPanel.Caption := '';
  lButtonPanel.TabOrder := 0;

  lOpenButton := TBitBtn.Create(lButtonPanel);
  lOpenButton.Parent := lButtonPanel;
  lOpenButton.Align := alLeft;
  lOpenButton.AlignWithMargins := True;
  lOpenButton.Margins.Left := 0;
  lOpenButton.Margins.Top := 0;
  lOpenButton.Margins.Right := ScaleVal(8);
  lOpenButton.Margins.Bottom := 0;
  lOpenButton.Width := ScaleVal(96);
  lOpenButton.Caption := 'Open';
  lOpenButton.Hint := lPull.RootPath;
  lOpenButton.TabOrder := 0;
  lOpenButton.OnClick := HandleOpenRepoClick;

  for i := 0 to Pred(Length(fGroups[aGroupIndex].Actions)) do
  begin
    lContext.ActionKind := fGroups[aGroupIndex].Actions[i].Kind;
    lContext.GroupIndex := aGroupIndex;
    lContext.IsGroup := False;
    lContext.RepoPath := lPull.RootPath;
    CreateActionButton(lButtonPanel, fGroups[aGroupIndex].Actions[i].Caption, lContext);
  end;

  lOutputText := TStaticText.Create(lRepoPanel);
  lOutputText.Parent := lRepoPanel;
  lOutputText.Align := alClient;
  lOutputText.AutoSize := False;
  lOutputText.Caption := Copy(StringReplace(lPull.LastPullOutput, sLineBreak, ' ', [rfReplaceAll]), 1, 220);
  lOutputText.Font.Color := clGrayText;
  lOutputText.TabStop := False;

  lPathText := TStaticText.Create(lRepoPanel);
  lPathText.Parent := lRepoPanel;
  lPathText.Align := alTop;
  lPathText.AutoSize := False;
  lPathText.Height := ScaleVal(22);
  lPathText.Caption := lPull.RootPath;
  lPathText.Font.Style := [fsBold];
  lPathText.TabStop := False;
end;

function TFailedRepoPullsDialog.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
var
  lContentPoint: TPoint;
  lStep: Integer;
begin
  Result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  if Result then
  begin
    Exit;
  end;

  lContentPoint := ContentPanel.ScreenToClient(MousePos);
  if not PtInRect(ContentPanel.ClientRect, lContentPoint) then
  begin
    Exit(False);
  end;

  lStep := RepoScrollBox.VertScrollBar.Increment;
  if lStep <= 0 then
  begin
    lStep := ScaleVal(48);
  end;

  RepoScrollBox.VertScrollBar.Position := RepoScrollBox.VertScrollBar.Position -
    ((WheelDelta div WHEEL_DELTA) * lStep * 3);
  Result := True;
end;

class function TFailedRepoPullsDialog.Execute(aOwner: TComponent; const aFailedPulls: TArray<TRepoPullUpdate>;
  const aGitExePath: string; out aRepairsApplied: Boolean): Boolean;
var
  lDialog: TFailedRepoPullsDialog;
begin
  aRepairsApplied := False;
  lDialog := TFailedRepoPullsDialog.Create(aOwner);
  try
    if Trim(aGitExePath) <> '' then
    begin
      lDialog.fGitExePath := aGitExePath;
    end;
    lDialog.LoadFailures(aFailedPulls);
    Result := lDialog.ShowModal = mrOk;
    aRepairsApplied := lDialog.RepairsApplied;
  finally
    lDialog.Free;
  end;
end;

procedure TFailedRepoPullsDialog.HandleCloseClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TFailedRepoPullsDialog.HandleOpenRepoClick(Sender: TObject);
var
  lPath: string;
begin
  lPath := (Sender as TBitBtn).Hint;
  if TDirectory.Exists(lPath) then
  begin
    ShellExecute(Handle, 'open', PChar(lPath), nil, nil, SW_SHOWNORMAL);
  end;
end;

procedure TFailedRepoPullsDialog.HandleRepairClick(Sender: TObject);
var
  i: Integer;
  lAction: TGitPullRepairAction;
  lContext: TRepairButtonContext;
  lRepoPaths: TArray<string>;
  lResults: TArray<TGitPullRepairResult>;
  lSuccessCount: Integer;
begin
  if not fButtonContexts.TryGetValue(Sender as TObject, lContext) then
  begin
    Exit;
  end;

  lAction := Default(TGitPullRepairAction);
  for i := 0 to Pred(Length(fGroups[lContext.GroupIndex].Actions)) do
  begin
    if fGroups[lContext.GroupIndex].Actions[i].Kind = lContext.ActionKind then
    begin
      lAction := fGroups[lContext.GroupIndex].Actions[i];
      Break;
    end;
  end;

  if lContext.IsGroup then
  begin
    SetLength(lRepoPaths, Length(fGroups[lContext.GroupIndex].Pulls));
    for i := 0 to Pred(Length(lRepoPaths)) do
    begin
      lRepoPaths[i] := fGroups[lContext.GroupIndex].Pulls[i].RootPath;
    end;
  end else begin
    lRepoPaths := [lContext.RepoPath];
  end;

  if not ConfirmRepair(lAction, Length(lRepoPaths)) then
  begin
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  try
    lResults := ExecuteGitPullRepairGroup(lRepoPaths, fGitExePath, lContext.ActionKind, lAction.RequiresConfirmation);
  finally
    Screen.Cursor := crDefault;
  end;

  lSuccessCount := 0;
  for i := 0 to Pred(Length(lResults)) do
  begin
    if lResults[i].Success then
    begin
      Inc(lSuccessCount);
    end;
  end;

  if lSuccessCount > 0 then
  begin
    fRepairsApplied := True;
  end;
  SetStatus(BuildRepairStatusText(lAction, lResults, lSuccessCount));
end;

function TFailedRepoPullsDialog.ScaleVal(const aValue: Integer): Integer;
begin
  Result := MulDiv(aValue, CurrentPPI, 96);
end;

procedure TFailedRepoPullsDialog.ResizeRepoHostPanel;
var
  i: Integer;
  lControl: TControl;
  lHeight: Integer;
begin
  lHeight := 0;
  for i := 0 to Pred(RepoHostPanel.ControlCount) do
  begin
    lControl := RepoHostPanel.Controls[i];
    if lControl.Visible then
    begin
      Inc(lHeight, lControl.Height + lControl.Margins.Top + lControl.Margins.Bottom);
    end;
  end;

  if lHeight < ScaleVal(1) then
  begin
    lHeight := ScaleVal(1);
  end;
  RepoHostPanel.Height := lHeight;
end;

procedure TFailedRepoPullsDialog.LoadFailures(const aFailedPulls: TArray<TRepoPullUpdate>);
var
  i: Integer;
  lRepoCount: Integer;
begin
  fGroups := BuildFailedRepoPullGroups(aFailedPulls);
  lRepoCount := 0;
  for i := 0 to Pred(Length(fGroups)) do
  begin
    Inc(lRepoCount, Length(fGroups[i].Pulls));
  end;

  SummaryText.Caption := Format('%d failed repo pull(s) in %d group(s).', [lRepoCount, Length(fGroups)]);
  ClearDynamicContent;
  for i := Pred(Length(fGroups)) downto 0 do
  begin
    CreateGroupSection(i);
  end;
  ResizeRepoHostPanel;
end;

procedure TFailedRepoPullsDialog.SetStatus(const aText: string);
begin
  StatusText.Caption := aText;
end;

end.
