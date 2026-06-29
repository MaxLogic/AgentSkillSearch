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
    fRepoStatusTexts: TDictionary<string, TStaticText>;
    fRepairsApplied: Boolean;
    function ConfirmRepair(const aAction: TGitPullRepairAction; const aRepoCount: Integer): Boolean;
    function CountTextRows(const aText: string): Integer;
    procedure ClearDynamicContent;
    procedure CreateActionButton(aParent: TWinControl; const aCaption: string; const aContext: TRepairButtonContext);
    procedure CreateGroupSection(const aGroupIndex: Integer);
    procedure CreateRepoCard(aParent: TWinControl; const aGroupIndex, aPullIndex: Integer);
    procedure HandleOpenRepoClick(Sender: TObject);
    procedure HandleRepairClick(Sender: TObject);
    function NormalizePullOutputText(const aText: string): string;
    procedure ResizeGroupSections;
    procedure ResizeRepoHostPanel;
    procedure ResetRepoScrollToTop;
    function ScaleVal(const aValue: Integer): Integer;
    procedure SetStatus(const aText: string);
    function StackedChildrenHeight(const aParent: TWinControl; const aIncludePadding: Boolean): Integer;
    function StaticTextHeightForRows(const aText: TStaticText; const aCaption: string): Integer;
    function StaticTextRowHeight(const aText: TStaticText): Integer;
    procedure UpdateRepoRepairResult(const aAction: TGitPullRepairAction; const aResult: TGitPullRepairResult);
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
  Winapi.Messages, Winapi.ShellAPI, Winapi.Windows,
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

function CountText(const aCount: Integer; const aSingular, aPlural: string): string;
begin
  if aCount = 1 then
  begin
    Exit(Format('%d %s', [aCount, aSingular]));
  end;

  Result := Format('%d %s', [aCount, aPlural]);
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

  if lFailedCount > 0 then
  begin
    Result := Format('%s: fixed %s, %s failed.',
      [aAction.Caption, CountText(aSuccessCount, 'repo', 'repos'), CountText(lFailedCount, 'repo', 'repos')]);
  end else begin
    Result := Format('%s: fixed %s.', [aAction.Caption, CountText(aSuccessCount, 'repo', 'repos')]);
  end;

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
  fRepoStatusTexts := TDictionary<string, TStaticText>.Create;
  fGitExePath := 'git.exe';
end;

destructor TFailedRepoPullsDialog.Destroy;
begin
  fRepoStatusTexts.Free;
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

function TFailedRepoPullsDialog.CountTextRows(const aText: string): Integer;
var
  i: Integer;
  lText: string;
begin
  lText := StringReplace(aText, #13#10, #10, [rfReplaceAll]);
  lText := StringReplace(lText, #13, #10, [rfReplaceAll]);
  lText := TrimRight(lText);
  if lText = '' then
  begin
    Exit(1);
  end;

  Result := 1;
  for i := 1 to Length(lText) do
  begin
    if lText[i] = #10 then
    begin
      Inc(Result);
    end;
  end;
end;

procedure TFailedRepoPullsDialog.ClearDynamicContent;
begin
  fButtonContexts.Clear;
  fRepoStatusTexts.Clear;
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

  for i := Pred(Length(fGroups[aGroupIndex].Pulls)) downto 0 do
  begin
    CreateRepoCard(lGroupPanel, aGroupIndex, i);
  end;

  if Length(fGroups[aGroupIndex].Actions) > 0 then
  begin
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
  end;

  lGroupHeaderPanel := TPanel.Create(lGroupPanel);
  lGroupHeaderPanel.Parent := lGroupPanel;
  lGroupHeaderPanel.Align := alTop;
  lGroupHeaderPanel.Height := ScaleVal(56);
  lGroupHeaderPanel.BevelOuter := bvNone;
  lGroupHeaderPanel.Caption := '';
  lGroupHeaderPanel.Color := clBtnFace;
  lGroupHeaderPanel.ParentBackground := False;
  lGroupHeaderPanel.Padding.Left := ScaleVal(10);
  lGroupHeaderPanel.Padding.Top := ScaleVal(8);
  lGroupHeaderPanel.Padding.Right := ScaleVal(10);
  lGroupHeaderPanel.Padding.Bottom := ScaleVal(8);
  lGroupHeaderPanel.TabOrder := 0;

  lHeaderText := TStaticText.Create(lGroupHeaderPanel);
  lHeaderText.Parent := lGroupHeaderPanel;
  lHeaderText.Align := alClient;
  lHeaderText.AutoSize := False;
  lHeaderText.Caption := Format('Reason: %s%s%s, %s',
    [fGroups[aGroupIndex].Caption, sLineBreak, CountText(Length(fGroups[aGroupIndex].Pulls), 'repo', 'repos'),
    CountText(Length(fGroups[aGroupIndex].Actions), 'available fix', 'available fixes')]);
  lHeaderText.Height := ScaleVal(40);
  lHeaderText.Font.Height := -15;
  lHeaderText.Font.Style := [fsBold];
  lHeaderText.ParentFont := False;
  lHeaderText.TabStop := False;

  lGroupPanel.Height := StackedChildrenHeight(lGroupPanel, True);
end;

procedure TFailedRepoPullsDialog.CreateRepoCard(aParent: TWinControl; const aGroupIndex, aPullIndex: Integer);
var
  i: Integer;
  lButtonPanel: TPanel;
  lContext: TRepairButtonContext;
  lOpenButton: TBitBtn;
  lOutputText: TStaticText;
  lOutputCaption: string;
  lPathText: TStaticText;
  lPull: TRepoPullUpdate;
  lRepoPanel: TPanel;
  lRepoStatusText: TStaticText;
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

  lRepoStatusText := TStaticText.Create(lRepoPanel);
  lRepoStatusText.Parent := lRepoPanel;
  lRepoStatusText.Align := alTop;
  lRepoStatusText.AutoSize := False;
  lRepoStatusText.Caption := '';
  lRepoStatusText.Height := 0;
  lRepoStatusText.Font.Color := clGrayText;
  lRepoStatusText.TabStop := False;
  fRepoStatusTexts.AddOrSetValue(lPull.RootPath, lRepoStatusText);

  lOutputText := TStaticText.Create(lRepoPanel);
  lOutputText.Parent := lRepoPanel;
  lOutputText.Align := alTop;
  lOutputText.AutoSize := False;
  lOutputCaption := NormalizePullOutputText(lPull.LastPullOutput);
  lOutputText.Caption := lOutputCaption;
  lOutputText.Height := StaticTextHeightForRows(lOutputText, lOutputCaption);
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

  lRepoPanel.Height := StackedChildrenHeight(lRepoPanel, True);
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
    UpdateRepoRepairResult(lAction, lResults[i]);
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

function TFailedRepoPullsDialog.NormalizePullOutputText(const aText: string): string;
var
  lText: string;
begin
  lText := StringReplace(aText, #13#10, #10, [rfReplaceAll]);
  lText := StringReplace(lText, #13, #10, [rfReplaceAll]);
  lText := StringReplace(TrimRight(lText), #10, sLineBreak, [rfReplaceAll]);
  Result := lText;
end;

function TFailedRepoPullsDialog.ScaleVal(const aValue: Integer): Integer;
begin
  Result := MulDiv(aValue, CurrentPPI, 96);
end;

function TFailedRepoPullsDialog.StackedChildrenHeight(const aParent: TWinControl;
  const aIncludePadding: Boolean): Integer;
var
  i: Integer;
  lControl: TControl;
begin
  Result := 0;
  if aIncludePadding then
  begin
    Inc(Result, aParent.Padding.Top + aParent.Padding.Bottom);
  end;

  for i := 0 to Pred(aParent.ControlCount) do
  begin
    lControl := aParent.Controls[i];
    if lControl.Visible then
    begin
      Inc(Result, lControl.Height + lControl.Margins.Top + lControl.Margins.Bottom);
    end;
  end;

  if Result < ScaleVal(1) then
  begin
    Result := ScaleVal(1);
  end;
end;

function TFailedRepoPullsDialog.StaticTextHeightForRows(const aText: TStaticText; const aCaption: string): Integer;
begin
  Result := (CountTextRows(aCaption) * StaticTextRowHeight(aText)) + ScaleVal(4);
end;

function TFailedRepoPullsDialog.StaticTextRowHeight(const aText: TStaticText): Integer;
var
  lCanvas: TControlCanvas;
begin
  lCanvas := TControlCanvas.Create;
  try
    lCanvas.Control := aText;
    lCanvas.Font.Assign(aText.Font);
    Result := lCanvas.TextHeight('Hg');
  finally
    lCanvas.Free;
  end;

  if Result < ScaleVal(1) then
  begin
    Result := ScaleVal(17);
  end;
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

procedure TFailedRepoPullsDialog.ResetRepoScrollToTop;
begin
  RepoScrollBox.VertScrollBar.Position := 0;
  RepoScrollBox.Perform(WM_VSCROLL, SB_TOP, 0);
end;

procedure TFailedRepoPullsDialog.ResizeGroupSections;
var
  i: Integer;
  lControl: TControl;
begin
  for i := 0 to Pred(RepoHostPanel.ControlCount) do
  begin
    lControl := RepoHostPanel.Controls[i];
    if lControl is TPanel then
    begin
      lControl.Height := StackedChildrenHeight(lControl as TWinControl, True);
    end;
  end;
  ResizeRepoHostPanel;
end;

procedure TFailedRepoPullsDialog.UpdateRepoRepairResult(const aAction: TGitPullRepairAction;
  const aResult: TGitPullRepairResult);
var
  lCaption: string;
  lStatusText: TStaticText;
begin
  if not fRepoStatusTexts.TryGetValue(aResult.RepoPath, lStatusText) then
  begin
    Exit;
  end;

  if aResult.Success then
  begin
    lCaption := Format('Fixed by %s.', [aAction.Caption]);
    lStatusText.Font.Color := clGreen;
  end else begin
    lCaption := Format('%s failed (exit %d): %s',
      [aAction.Caption, aResult.ExitCode, Copy(NormalizePullOutputText(aResult.OutputText), 1, 180)]);
    lStatusText.Font.Color := clRed;
  end;

  lStatusText.Caption := lCaption;
  lStatusText.Height := StaticTextHeightForRows(lStatusText, lCaption);
  if Assigned(lStatusText.Parent) then
  begin
    lStatusText.Parent.Height := StackedChildrenHeight(lStatusText.Parent, True);
  end;
  ResizeGroupSections;
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
  ResetRepoScrollToTop;
end;

procedure TFailedRepoPullsDialog.SetStatus(const aText: string);
begin
  StatusText.Caption := aText;
end;

end.
