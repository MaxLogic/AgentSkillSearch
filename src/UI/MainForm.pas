unit MainForm;

interface

uses
  System.Classes, Vcl.ComCtrls, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.Menus, Vcl.StdCtrls,
  VCL.TMSFNCWebBrowser,
  DatabaseManager, PipelineCoordinator, SearchController, SettingsModel, SkillSearchService;

type
  TMainForm = class(TForm)
  private
    fAppSettings: TAppSettings;
    fCopyPathMenuItem: TMenuItem;
    fDatabaseManager: TDatabaseManager;
    fDbPath: string;
    fDiagnosticsButton: TButton;
    fDuplicateInfoMemo: TMemo;
    fDuplicateInfoPanel: TPanel;
    fHasScriptsCheckBox: TCheckBox;
    fLogPath: string;
    fOpenFileMenuItem: TMenuItem;
    fOpenFolderMenuItem: TMenuItem;
    fPopupMenu: TPopupMenu;
    fPreviewBrowser: TTMSFNCWebBrowser;
    fResults: TArray<TSkillSearchResult>;
    fResultsListView: TListView;
    fScanButton: TButton;
    fSearchAsYouTypeCheckBox: TCheckBox;
    fSearchButton: TButton;
    fSearchController: TSearchController;
    fSearchEdit: TEdit;
    fSearchService: TSkillSearchService;
    fSettingsPath: string;
    fSourcesListPath: string;
    fStatusBar: TStatusBar;
    procedure ApplySearchResults(const aResults: TArray<TSkillSearchResult>);
    function BuildPipelineOptions: TPipelineOptions;
    function BuildEffectiveQuery: string;
    procedure ConfigureColumns;
    procedure CopySelectedPathToClipboard;
    procedure CreateLayout;
    function EscapeHtml(const aText: string): string;
    function GetSelectedSkillFile: string;
    function IsResultSelectionValid: Boolean;
    procedure OpenSelectedSkillFile;
    procedure OpenSelectedSkillFolder;
    procedure QueueSearch(const aImmediate: Boolean);
    procedure RunScanUpdate;
    procedure RenderPreview(const aResult: TSkillSearchResult);
    procedure ShowEmptyPreview;
    function TryLoadSourceRoots(out aSourceRoots: TArray<string>): Boolean;
    procedure UpdateStatus(const aText: string);

    procedure HandleCopyPathClick(Sender: TObject);
    procedure HandleDiagnosticsButtonClick(Sender: TObject);
    procedure HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleHasScriptsClick(Sender: TObject);
    procedure HandleOpenFileClick(Sender: TObject);
    procedure HandleOpenFolderClick(Sender: TObject);
    procedure HandleResultDoubleClick(Sender: TObject);
    procedure HandleResultKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleResultSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure HandleSearchButtonClick(Sender: TObject);
    procedure HandleSearchCompleted(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>;
      const aError: string);
    procedure HandleSearchEditChange(Sender: TObject);
    procedure HandleSearchEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleScanButtonClick(Sender: TObject);
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  AppMainForm: TMainForm;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.ShellAPI, Winapi.Windows,
  Vcl.Clipbrd,
  AppPaths, DiagnosticsForm, Logging, Settings, SourcesList;

constructor TMainForm.Create(aOwner: TComponent);
var
  i: Integer;
  lSettings: TSettingsLoadResult;
begin
  inherited Create(aOwner);
  Caption := 'Agent Skill Search';
  Width := 1400;
  Height := 860;
  Position := poScreenCenter;
  KeyPreview := True;
  OnKeyDown := HandleFormKeyDown;

  lSettings := LoadOrCreateSettings(GetSettingsFilePath);
  fAppSettings := lSettings.Settings;
  fSettingsPath := lSettings.SettingsPath;
  fDbPath := ResolveSettingsPath(fAppSettings.General.CacheDbPath, GetExeDirectory);
  fLogPath := ResolveSettingsPath(fAppSettings.General.LogPath, GetExeDirectory);
  fSourcesListPath := ResolveSettingsPath(fAppSettings.General.SourcesListPath, GetExeDirectory);
  InitLogging(fLogPath);
  LogInfo('Application startup. Settings=' + fSettingsPath);
  for i := 0 to Pred(Length(lSettings.RestoredKeys)) do
  begin
    LogInfo('Settings key restored: ' + lSettings.RestoredKeys[i]);
  end;

  fDatabaseManager := TDatabaseManager.Create(fDbPath, GetSqliteDllPath);
  fDatabaseManager.Initialize;

  fSearchService := TSkillSearchService.Create(fDbPath, GetSqliteDllPath);

  CreateLayout;

  fSearchAsYouTypeCheckBox.Checked := fAppSettings.Search.SearchAsYouType;

  fSearchController := TSearchController.Create(
    function(const aQuery: string): TArray<TSkillSearchResult>
    begin
      Result := fSearchService.Search(aQuery);
    end,
    fAppSettings.Search.SearchDebounceMs
  );
  fSearchController.OnCompleted := HandleSearchCompleted;

  QueueSearch(True);
end;

destructor TMainForm.Destroy;
begin
  LogInfo('Application shutdown.');
  fSearchController.Free;
  fSearchService.Free;
  fDatabaseManager.Free;
  inherited Destroy;
end;

procedure TMainForm.CreateLayout;
var
  lFiltersPanel: TPanel;
  lMainPanel: TPanel;
  lPreviewHostPanel: TPanel;
  lSearchPanel: TPanel;
  lSplitter: TSplitter;
begin
  lSearchPanel := TPanel.Create(self);
  lSearchPanel.Parent := self;
  lSearchPanel.Align := alTop;
  lSearchPanel.Height := 52;
  lSearchPanel.BevelOuter := bvNone;

  fSearchEdit := TEdit.Create(self);
  fSearchEdit.Parent := lSearchPanel;
  fSearchEdit.Align := alClient;
  fSearchEdit.Margins.Left := 8;
  fSearchEdit.Margins.Top := 8;
  fSearchEdit.Margins.Right := 8;
  fSearchEdit.Margins.Bottom := 8;
  fSearchEdit.TextHint := 'Search skills (supports name:, tag:, path:, has:scripts, limit:)';
  fSearchEdit.OnChange := HandleSearchEditChange;
  fSearchEdit.OnKeyDown := HandleSearchEditKeyDown;

  fSearchButton := TButton.Create(self);
  fSearchButton.Parent := lSearchPanel;
  fSearchButton.Align := alRight;
  fSearchButton.Width := 100;
  fSearchButton.Caption := 'Search';
  fSearchButton.OnClick := HandleSearchButtonClick;

  fScanButton := TButton.Create(self);
  fScanButton.Parent := lSearchPanel;
  fScanButton.Align := alRight;
  fScanButton.Width := 110;
  fScanButton.Caption := 'Scan/Update';
  fScanButton.OnClick := HandleScanButtonClick;

  fDiagnosticsButton := TButton.Create(self);
  fDiagnosticsButton.Parent := lSearchPanel;
  fDiagnosticsButton.Align := alRight;
  fDiagnosticsButton.Width := 110;
  fDiagnosticsButton.Caption := 'Diagnostics';
  fDiagnosticsButton.OnClick := HandleDiagnosticsButtonClick;

  fSearchAsYouTypeCheckBox := TCheckBox.Create(self);
  fSearchAsYouTypeCheckBox.Parent := lSearchPanel;
  fSearchAsYouTypeCheckBox.Align := alRight;
  fSearchAsYouTypeCheckBox.Width := 150;
  fSearchAsYouTypeCheckBox.Caption := 'Search as you type';
  fSearchAsYouTypeCheckBox.Checked := False;

  lFiltersPanel := TPanel.Create(self);
  lFiltersPanel.Parent := self;
  lFiltersPanel.Align := alTop;
  lFiltersPanel.Height := 34;
  lFiltersPanel.BevelOuter := bvNone;

  fHasScriptsCheckBox := TCheckBox.Create(self);
  fHasScriptsCheckBox.Parent := lFiltersPanel;
  fHasScriptsCheckBox.Align := alLeft;
  fHasScriptsCheckBox.Width := 160;
  fHasScriptsCheckBox.Caption := 'Has scripts';
  fHasScriptsCheckBox.OnClick := HandleHasScriptsClick;

  lMainPanel := TPanel.Create(self);
  lMainPanel.Parent := self;
  lMainPanel.Align := alClient;
  lMainPanel.BevelOuter := bvNone;

  fResultsListView := TListView.Create(self);
  fResultsListView.Parent := lMainPanel;
  fResultsListView.Align := alLeft;
  fResultsListView.Width := 730;
  fResultsListView.ViewStyle := vsReport;
  fResultsListView.ReadOnly := True;
  fResultsListView.RowSelect := True;
  fResultsListView.HideSelection := False;
  fResultsListView.OnDblClick := HandleResultDoubleClick;
  fResultsListView.OnKeyDown := HandleResultKeyDown;
  fResultsListView.OnSelectItem := HandleResultSelectItem;
  ConfigureColumns;

  fPopupMenu := TPopupMenu.Create(self);
  fOpenFileMenuItem := TMenuItem.Create(fPopupMenu);
  fOpenFileMenuItem.Caption := 'Open Skill File';
  fOpenFileMenuItem.OnClick := HandleOpenFileClick;
  fPopupMenu.Items.Add(fOpenFileMenuItem);

  fOpenFolderMenuItem := TMenuItem.Create(fPopupMenu);
  fOpenFolderMenuItem.Caption := 'Open Containing Folder';
  fOpenFolderMenuItem.OnClick := HandleOpenFolderClick;
  fPopupMenu.Items.Add(fOpenFolderMenuItem);

  fCopyPathMenuItem := TMenuItem.Create(fPopupMenu);
  fCopyPathMenuItem.Caption := 'Copy Skill Path';
  fCopyPathMenuItem.OnClick := HandleCopyPathClick;
  fPopupMenu.Items.Add(fCopyPathMenuItem);

  fResultsListView.PopupMenu := fPopupMenu;

  lSplitter := TSplitter.Create(self);
  lSplitter.Parent := lMainPanel;
  lSplitter.Align := alLeft;

  lPreviewHostPanel := TPanel.Create(self);
  lPreviewHostPanel.Parent := lMainPanel;
  lPreviewHostPanel.Align := alClient;
  lPreviewHostPanel.BevelOuter := bvNone;

  fDuplicateInfoPanel := TPanel.Create(self);
  fDuplicateInfoPanel.Parent := lPreviewHostPanel;
  fDuplicateInfoPanel.Align := alRight;
  fDuplicateInfoPanel.Width := 220;
  fDuplicateInfoPanel.Caption := 'Duplicate Info';

  fDuplicateInfoMemo := TMemo.Create(self);
  fDuplicateInfoMemo.Parent := fDuplicateInfoPanel;
  fDuplicateInfoMemo.Align := alClient;
  fDuplicateInfoMemo.ReadOnly := True;
  fDuplicateInfoMemo.Lines.Text := 'No duplicate details available.';

  fPreviewBrowser := TTMSFNCWebBrowser.Create(self);
  fPreviewBrowser.Parent := lPreviewHostPanel;
  fPreviewBrowser.Align := alClient;

  fStatusBar := TStatusBar.Create(self);
  fStatusBar.Parent := self;
  fStatusBar.Align := alBottom;
  fStatusBar.SimplePanel := False;
  fStatusBar.Panels.Add.Text := 'Ready';
  fStatusBar.Panels.Add.Text := 'Last scan: n/a';
  fStatusBar.Panels.Add.Text := 'Cache: ' + fDbPath;
  fStatusBar.Panels[0].Width := 420;
  fStatusBar.Panels[1].Width := 220;
  fStatusBar.Panels[2].Width := 640;
end;

procedure TMainForm.ConfigureColumns;
begin
  fResultsListView.Columns.BeginUpdate;
  try
    fResultsListView.Columns.Clear;
    with fResultsListView.Columns.Add do
    begin
      Caption := 'Name';
      Width := 230;
    end;

    with fResultsListView.Columns.Add do
    begin
      Caption := 'Rating';
      Width := 90;
    end;

    with fResultsListView.Columns.Add do
    begin
      Caption := 'Description';
      Width := 250;
    end;

    with fResultsListView.Columns.Add do
    begin
      Caption := 'Path';
      Width := 560;
    end;
  finally
    fResultsListView.Columns.EndUpdate;
  end;
end;

function TMainForm.EscapeHtml(const aText: string): string;
begin
  Result := StringReplace(aText, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

procedure TMainForm.ShowEmptyPreview;
begin
  fPreviewBrowser.LoadHTML('<html><body><p>No skill selected.</p></body></html>');
  fDuplicateInfoMemo.Lines.Text := 'No duplicate details available.';
end;

procedure TMainForm.RenderPreview(const aResult: TSkillSearchResult);
var
  lHtml: string;
begin
  lHtml :=
    '<html><body style="font-family:Segoe UI;padding:12px;">' +
    '<h3>' + EscapeHtml(aResult.Name) + '</h3>' +
    '<p><b>Description:</b> ' + EscapeHtml(aResult.Description) + '</p>' +
    '<p><b>Tags:</b> ' + EscapeHtml(aResult.Tags) + '</p>' +
    '<p><b>Scripts:</b> ' + IntToStr(aResult.ScriptsCount) + ' [' + EscapeHtml(aResult.ScriptsExts) + ']</p>' +
    '<p><b>Path:</b> ' + EscapeHtml(aResult.SkillFile) + '</p>' +
    '</body></html>';

  fPreviewBrowser.LoadHTML(lHtml);
  fDuplicateInfoMemo.Lines.Text := 'Duplicate rows are not collapsed in this view yet.' + sLineBreak +
    'This side area is reserved for duplicate summaries.';
end;

function TMainForm.GetSelectedSkillFile: string;
var
  lIndex: Integer;
begin
  if not IsResultSelectionValid then
  begin
    Exit('');
  end;

  lIndex := fResultsListView.Selected.Index;
  Result := fResults[lIndex].SkillFile;
end;

function TMainForm.IsResultSelectionValid: Boolean;
begin
  Result := Assigned(fResultsListView.Selected) and
    (fResultsListView.Selected.Index >= 0) and
    (fResultsListView.Selected.Index < Length(fResults));
end;

procedure TMainForm.UpdateStatus(const aText: string);
begin
  fStatusBar.Panels[0].Text := aText;
end;

function TMainForm.BuildEffectiveQuery: string;
begin
  Result := Trim(fSearchEdit.Text);
  if fHasScriptsCheckBox.Checked and (not ContainsText(Result, 'has:scripts')) and
    (not ContainsText(Result, '-has:scripts')) then
  begin
    if Result <> '' then
    begin
      Result := Result + ' ';
    end;
    Result := Result + 'has:scripts';
  end;
end;

function TMainForm.BuildPipelineOptions: TPipelineOptions;
begin
  Result := DefaultPipelineOptions;
  Result.GitExePath := fAppSettings.Git.GitExePath;
  Result.GitPullArgs := fAppSettings.Git.GitPullArgs;
  Result.GitPullTimeoutSeconds := fAppSettings.Git.GitPullTimeoutSeconds;
  Result.MaxGitPullThreads := fAppSettings.General.MaxGitPullThreads;
  Result.MaxIndexThreads := fAppSettings.General.MaxIndexThreads;
  Result.MaxScanThreads := fAppSettings.General.MaxScanThreads;
  Result.MinPullIntervalMinutes := fAppSettings.Git.MinPullIntervalMinutes;
  Result.PullEnabled := fAppSettings.Git.PullEnabled;
  Result.SkipFolders := fAppSettings.Git.SkipFolders;
  Result.SkillFileName := fAppSettings.Index.SkillFileName;
  Result.TreatWorktreesAsRepos := fAppSettings.Git.TreatWorktreesAsRepos;
end;

function TMainForm.TryLoadSourceRoots(out aSourceRoots: TArray<string>): Boolean;
var
  i: Integer;
  lParseResult: TSourcesListParseResult;
begin
  aSourceRoots := nil;
  if not TFile.Exists(fSourcesListPath) then
  begin
    RecordPipelineError('Sources list not found: ' + fSourcesListPath);
    Exit(False);
  end;

  lParseResult := ParseSourcesListFile(fSourcesListPath, GetExeDirectory);
  for i := 0 to Pred(Length(lParseResult.Issues)) do
  begin
    RecordPipelineError(
      Format(
        'Sources list issue line %d "%s": %s',
        [lParseResult.Issues[i].LineNumber, Trim(lParseResult.Issues[i].RawLine), lParseResult.Issues[i].Reason]
      )
    );
  end;

  aSourceRoots := lParseResult.ValidPaths;
  Result := Length(aSourceRoots) > 0;
end;

procedure TMainForm.RunScanUpdate;
var
  lCoordinator: TPipelineCoordinator;
  lOptions: TPipelineOptions;
  lResult: TPipelineRunResult;
  lSourceRoots: TArray<string>;
  lStatusText: string;
begin
  if not TryLoadSourceRoots(lSourceRoots) then
  begin
    UpdateStatus('Scan skipped: no valid source paths.');
    Exit;
  end;

  lOptions := BuildPipelineOptions;
  UpdateStatus('Scanning and indexing...');
  LogInfo('Scan started from UI. Sources=' + IntToStr(Length(lSourceRoots)));

  lCoordinator := TPipelineCoordinator.Create(fDatabaseManager, lOptions);
  try
    lResult := lCoordinator.Run(lSourceRoots, nil);
  finally
    lCoordinator.Free;
  end;

  lStatusText := Format(
    'Scan complete. Repos queued/pulled/throttled/failed: %d/%d/%d/%d | Skills queued/written: %d/%d | Errors: %d',
    [lResult.ReposQueued, lResult.ReposPulled, lResult.ReposThrottled, lResult.ReposFailed, lResult.SkillsQueued,
     lResult.SkillsWritten, lResult.ErrorCount]
  );
  if lResult.Cancelled then
  begin
    lStatusText := lStatusText + ' | Cancelled';
  end;
  if Trim(lResult.LastError) <> '' then
  begin
    lStatusText := lStatusText + ' | Last error: ' + lResult.LastError;
  end;

  UpdateStatus(lStatusText);
  fStatusBar.Panels[1].Text := 'Last scan: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
  QueueSearch(True);
end;

procedure TMainForm.QueueSearch(const aImmediate: Boolean);
var
  lQuery: string;
begin
  lQuery := BuildEffectiveQuery;
  if aImmediate then
  begin
    fSearchController.QueueSearch(lQuery, 0);
  end else begin
    fSearchController.QueueSearch(lQuery);
  end;
  UpdateStatus('Searching...');
end;

procedure TMainForm.ApplySearchResults(const aResults: TArray<TSkillSearchResult>);
var
  i: Integer;
  lItem: TListItem;
begin
  fResults := aResults;

  fResultsListView.Items.BeginUpdate;
  try
    fResultsListView.Items.Clear;
    for i := 0 to Pred(Length(fResults)) do
    begin
      lItem := fResultsListView.Items.Add;
      lItem.Caption := fResults[i].Name;
      lItem.SubItems.Add(FormatFloat('0.000', fResults[i].LexScore));
      lItem.SubItems.Add(fResults[i].Description);
      lItem.SubItems.Add(fResults[i].SkillRoot);
    end;
  finally
    fResultsListView.Items.EndUpdate;
  end;

  if fResultsListView.Items.Count > 0 then
  begin
    fResultsListView.Items[0].Selected := True;
    fResultsListView.Items[0].Focused := True;
    RenderPreview(fResults[0]);
  end else begin
    ShowEmptyPreview;
  end;

  UpdateStatus(Format('Results: %d | Query: %s', [Length(fResults), BuildEffectiveQuery]));
end;

procedure TMainForm.OpenSelectedSkillFile;
var
  lSkillFile: string;
begin
  lSkillFile := GetSelectedSkillFile;
  if lSkillFile = '' then
  begin
    Exit;
  end;

  ShellExecute(Handle, 'open', PChar(lSkillFile), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.OpenSelectedSkillFolder;
var
  lArgs: string;
  lSkillFile: string;
begin
  lSkillFile := GetSelectedSkillFile;
  if lSkillFile = '' then
  begin
    Exit;
  end;

  lArgs := '/select,"' + lSkillFile + '"';
  ShellExecute(Handle, 'open', 'explorer.exe', PChar(lArgs), nil, SW_SHOWNORMAL);
end;

procedure TMainForm.CopySelectedPathToClipboard;
var
  lSkillFile: string;
begin
  lSkillFile := GetSelectedSkillFile;
  if lSkillFile = '' then
  begin
    Exit;
  end;

  Clipboard.AsText := lSkillFile;
  UpdateStatus('Copied: ' + lSkillFile);
end;

procedure TMainForm.HandleSearchButtonClick(Sender: TObject);
begin
  QueueSearch(True);
end;

procedure TMainForm.HandleScanButtonClick(Sender: TObject);
begin
  try
    RunScanUpdate;
  except
    on E: Exception do
    begin
      RecordPipelineError('Scan failed: ' + E.Message);
      UpdateStatus('Scan failed: ' + E.Message);
    end;
  end;
end;

procedure TMainForm.HandleDiagnosticsButtonClick(Sender: TObject);
begin
  ShowDiagnosticsDialog(self);
end;

procedure TMainForm.HandleSearchCompleted(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>;
  const aError: string);
begin
  if GetCurrentThreadId <> MainThreadID then
  begin
    TThread.Queue(nil,
      procedure
      begin
        HandleSearchCompleted(aGenerationId, aResults, aError);
      end
    );
    Exit;
  end;

  if aError <> '' then
  begin
    UpdateStatus('Search failed: ' + aError);
    Exit;
  end;

  ApplySearchResults(aResults);
end;

procedure TMainForm.HandleSearchEditChange(Sender: TObject);
begin
  if fSearchAsYouTypeCheckBox.Checked then
  begin
    QueueSearch(False);
  end;
end;

procedure TMainForm.HandleSearchEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    QueueSearch(True);
    Key := 0;
  end;
end;

procedure TMainForm.HandleResultSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if not Selected then
  begin
    Exit;
  end;

  if (Item.Index >= 0) and (Item.Index < Length(fResults)) then
  begin
    RenderPreview(fResults[Item.Index]);
  end else begin
    ShowEmptyPreview;
  end;
end;

procedure TMainForm.HandleResultDoubleClick(Sender: TObject);
begin
  OpenSelectedSkillFile;
end;

procedure TMainForm.HandleResultKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if ssCtrl in Shift then
    begin
      OpenSelectedSkillFolder;
    end else begin
      OpenSelectedSkillFile;
    end;
    Key := 0;
    Exit;
  end;

  if (Key = VK_APPS) or ((Key = VK_F10) and (ssShift in Shift)) then
  begin
    if Assigned(fResultsListView.Selected) then
    begin
      fPopupMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
      Key := 0;
    end;
  end;
end;

procedure TMainForm.HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('L')) and (ssCtrl in Shift) then
  begin
    fSearchEdit.SetFocus;
    fSearchEdit.SelectAll;
    Key := 0;
    Exit;
  end;

  if (Key = VK_RETURN) and (ssCtrl in Shift) then
  begin
    OpenSelectedSkillFolder;
    Key := 0;
    Exit;
  end;

  if Key = VK_F5 then
  begin
    HandleScanButtonClick(Sender);
    Key := 0;
    Exit;
  end;

  if Key = VK_ESCAPE then
  begin
    fSearchController.CancelCurrent;
    UpdateStatus('Search cancelled by user.');
    Key := 0;
  end;
end;

procedure TMainForm.HandleOpenFileClick(Sender: TObject);
begin
  OpenSelectedSkillFile;
end;

procedure TMainForm.HandleOpenFolderClick(Sender: TObject);
begin
  OpenSelectedSkillFolder;
end;

procedure TMainForm.HandleCopyPathClick(Sender: TObject);
begin
  CopySelectedPathToClipboard;
end;

procedure TMainForm.HandleHasScriptsClick(Sender: TObject);
begin
  QueueSearch(False);
end;

end.
