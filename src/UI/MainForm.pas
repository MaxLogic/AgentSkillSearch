unit MainForm;

interface

uses
  System.Classes, Vcl.ComCtrls, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.Menus, Vcl.StdCtrls,
  VCL.TMSFNCWebBrowser,
  DatabaseManager, DockerHealthMonitor, DockerOps, PipelineCoordinator, SearchController, SettingsModel,
  SkillSearchService;

type
  TMainForm = class(TForm)
  published
    fSearchPanel: TPanel;
    fSearchActionsPanel: TPanel;
    fSearchFieldPanel: TPanel;
    fSearchEdit: TEdit;
    fSearchEditLabel: TStaticText;
    fSearchHelpImage: TImage;
    fSearchButton: TButton;
    fScanButton: TButton;
    fScanProgressBar: TProgressBar;
    fDiagnosticsButton: TButton;
    fSearchAsYouTypeCheckBox: TCheckBox;
    fDockerGpuButton: TButton;
    fFiltersPanel: TPanel;
    fDockerHealthLabel: TStaticText;
    fHasScriptsCheckBox: TCheckBox;
    fMainPanel: TPanel;
    fResultsPanePanel: TPanel;
    fResultsListView: TListView;
    fResultsPreviewSplitter: TSplitter;
    fPreviewHostPanel: TPanel;
    fPreviewInfoSplitter: TSplitter;
    fPreviewPanel: TPanel;
    fPreviewLabel: TStaticText;
    fDuplicateInfoPanel: TPanel;
    fDuplicateInfoMemo: TMemo;
    fDuplicateInfoLabel: TStaticText;
    fResultsListLabel: TStaticText;
    fPreviewBrowser: TTMSFNCWebBrowser;
    fStatusBar: TStatusBar;
    fPopupMenu: TPopupMenu;
    fOpenFileMenuItem: TMenuItem;
    fOpenFolderMenuItem: TMenuItem;
    fCopyPathMenuItem: TMenuItem;
  private
    fAppSettings: TAppSettings;
    fDatabaseManager: TDatabaseManager;
    fDbPath: string;
    fExcludesListPath: string;
    fLogPath: string;
    fResults: TArray<TSkillSearchResult>;
    fScanCancelToken: TPipelineCancellationToken;
    fScanInProgress: Boolean;
    fScanHourGlass: IInterface;
    fDockerHealthMonitor: TDockerHealthMonitor;
    fDockerHealthState: TDockerHealthState;
    fDockerStartInProgress: Boolean;
    fDockerStartHourGlass: IInterface;
    fSearchController: TSearchController;
    fSearchService: TSkillSearchService;
    fSettingsPath: string;
    fSkillsFoundCount: Integer;
    fSkillsUniqueCount: Integer;
    fSkillsValidCount: Integer;
    fSourcesListPath: string;
    procedure ApplySearchResults(const aResults: TArray<TSkillSearchResult>);
    function BuildPipelineOptions: TPipelineOptions;
    procedure BeginScanProgress;
    procedure BeginDockerStart;
    procedure EndDockerStart;
    procedure HandleDockerHealthPolled(const aState: TDockerHealthState; const aDetail: string);
    procedure HandleDockerStartCompleted(const aResult: TDockerCommandResult);
    procedure EndScanProgress;
    procedure LoadSearchHelpImage;
    function ResolveSearchHelpImagePath: string;
    function ExecuteScanUpdate(const aCancelToken: TPipelineCancellationToken; out aResult: TPipelineRunResult;
      out aStatusText: string): Boolean;
    function BuildEffectiveQuery: string;
    procedure ConfigureColumns;
    procedure CopySelectedPathToClipboard;
    function EscapeHtml(const aText: string): string;
    function GetSelectedSkillFile: string;
    function IsResultSelectionValid: Boolean;
    procedure OpenSelectedSkillFile;
    procedure OpenSelectedSkillFolder;
    procedure QueueSearch(const aImmediate: Boolean);
    procedure RefreshCountPanels;
    procedure RefreshInventoryCounters;
    procedure RenderPreview(const aResult: TSkillSearchResult);
    procedure ShowEmptyPreview;
    function TryLoadSourceRoots(out aSourceRoots: TArray<string>): Boolean;
    procedure UpdateStatus(const aText: string);
  published
    procedure HandleCopyPathClick(Sender: TObject);
    procedure HandleDiagnosticsButtonClick(Sender: TObject);
    procedure HandleDockerGpuButtonClick(Sender: TObject);
    procedure HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleHasScriptsClick(Sender: TObject);
    procedure HandleScanCompleted(const aExecuted: Boolean; const aResult: TPipelineRunResult; const aStatusText,
      aFailure: string);
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
    procedure HandleSearchHelpButtonClick(Sender: TObject);
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
  Vcl.Dialogs,
  Vcl.Imaging.pngimage,
  AppPaths, AutoHourGlass, DiagnosticsForm, Logging, PathExclusions, PreviewRenderer, Settings, SourcesList;

{$R *.dfm}

const
  cStatusPanelStatus = 0;
  cStatusPanelFound = 1;
  cStatusPanelValid = 2;
  cStatusPanelUnique = 3;
  cStatusPanelResults = 4;
  cStatusPanelLastScan = 5;
  cStatusPanelCache = 6;

{ TMainForm }

constructor TMainForm.Create(aOwner: TComponent);
var
  i: Integer;
  lSemanticOptions: TSemanticSearchOptions;
  lSettings: TSettingsLoadResult;
begin
  inherited Create(aOwner);

  lSettings := LoadOrCreateSettings(GetSettingsFilePath);
  fAppSettings := lSettings.Settings;
  fSettingsPath := lSettings.SettingsPath;
  fDbPath := ResolveSettingsPath(fAppSettings.General.CacheDbPath, GetExeDirectory);
  fExcludesListPath := ResolveSettingsPath(fAppSettings.General.ExcludesListPath, GetExeDirectory);
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

  lSemanticOptions := DefaultSemanticSearchOptions;
  lSemanticOptions.Enabled := fAppSettings.Semantic.Enabled;
  lSemanticOptions.CandidateRerankCount := fAppSettings.Semantic.CandidateRerankCount;
  lSemanticOptions.Model := fAppSettings.Semantic.Model;
  lSemanticOptions.OllamaBaseUrl := fAppSettings.Semantic.OllamaBaseUrl;

  fSearchService := TSkillSearchService.Create(
    fDbPath,
    GetSqliteDllPath,
    fAppSettings.Search.SnippetMaxChars,
    fAppSettings.Search.MaxResults,
    lSemanticOptions
  );

  ConfigureColumns;
  LoadSearchHelpImage;

  fSearchAsYouTypeCheckBox.Checked := fAppSettings.Search.SearchAsYouType;
  fStatusBar.Panels[cStatusPanelCache].Text := 'Cache: ' + fDbPath;
  fStatusBar.Panels[cStatusPanelLastScan].Text := 'Last scan: n/a';
  fSkillsFoundCount := 0;
  RefreshInventoryCounters;
  RefreshCountPanels;

  fSearchController := TSearchController.Create(
    function(const aQuery: string): TArray<TSkillSearchResult>
    begin
      Result := fSearchService.Search(aQuery);
    end,
    fAppSettings.Search.SearchDebounceMs
  );
  fSearchController.OnCompleted := HandleSearchCompleted;
  fDockerStartInProgress := False;
  fDockerHealthState := TDockerHealthState.dhsUnknown;
  fDockerHealthLabel.Caption := 'Docker: checking...';
  fDockerHealthLabel.Hint := '';
  fDockerHealthMonitor := TDockerHealthMonitor.Create(
    fAppSettings.Docker.HealthCheckCommand,
    10000,
    HandleDockerHealthPolled
  );
  fDockerHealthMonitor.Start;

  QueueSearch(True);
end;

destructor TMainForm.Destroy;
begin
  AppMainForm := nil;

  if Assigned(fScanCancelToken) then
  begin
    fScanCancelToken.Cancel;
    if not fScanInProgress then
    begin
      fScanCancelToken.Free;
      fScanCancelToken := nil;
    end;
  end;

  LogInfo('Application shutdown.');
  fDockerHealthMonitor.Free;
  fSearchController.Free;
  fSearchService.Free;
  fDatabaseManager.Free;
  inherited Destroy;
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
  lDuplicateText: string;
  lHtml: string;
  lSnippetHtml: string;
begin
  lSnippetHtml := BuildPreviewSnippetHtml(aResult.Snippet);
  lHtml :=
    '<html><body style="font-family:Segoe UI;padding:12px;">' +
    '<h3>' + EscapeHtml(aResult.Name) + '</h3>' +
    '<p><b>Description:</b> ' + EscapeHtml(aResult.Description) + '</p>' +
    '<p><b>Tags:</b> ' + EscapeHtml(aResult.Tags) + '</p>' +
    '<p><b>Scripts:</b> ' + IntToStr(aResult.ScriptsCount) + ' [' + EscapeHtml(aResult.ScriptsExts) + ']</p>' +
    '<p><b>Snippet:</b><br/>' + lSnippetHtml + '</p>' +
    '<p><b>Path:</b> ' + EscapeHtml(aResult.SkillFile) + '</p>' +
    '</body></html>';

  fPreviewBrowser.LoadHTML(lHtml);
  if aResult.DuplicateCount <= 1 then
  begin
    lDuplicateText := 'No duplicate skills detected for this result.';
  end else begin
    lDuplicateText := Format('Duplicate skills detected: %d', [aResult.DuplicateCount]) + sLineBreak +
      'Canonical:' + sLineBreak + aResult.SkillFile + sLineBreak + sLineBreak +
      'Other locations:' + sLineBreak + aResult.DuplicatePaths;
  end;
  fDuplicateInfoMemo.Lines.Text := lDuplicateText;
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
  fStatusBar.Panels[cStatusPanelStatus].Text := aText;
end;

procedure TMainForm.RefreshCountPanels;
begin
  fStatusBar.Panels[cStatusPanelFound].Text := Format('Found: %d', [fSkillsFoundCount]);
  fStatusBar.Panels[cStatusPanelValid].Text := Format('Valid: %d', [fSkillsValidCount]);
  fStatusBar.Panels[cStatusPanelUnique].Text := Format('Unique: %d', [fSkillsUniqueCount]);
  fStatusBar.Panels[cStatusPanelResults].Text := Format('Results: %d', [Length(fResults)]);
end;

procedure TMainForm.RefreshInventoryCounters;
begin
  fSkillsValidCount := fDatabaseManager.GetValidSkillCount;
  fSkillsUniqueCount := fDatabaseManager.GetUniqueSkillCount;
end;

function TMainForm.ResolveSearchHelpImagePath: string;
const
  cImageFileName = 'search-syntax-help-64.png';
var
  i: Integer;
  lCandidate: string;
  lDir: string;
  lParent: string;
begin
  Result := '';
  lDir := ExcludeTrailingPathDelimiter(GetExeDirectory);
  for i := 0 to 6 do
  begin
    lCandidate := TPath.Combine(lDir, cImageFileName);
    if TFile.Exists(lCandidate) then
    begin
      Exit(lCandidate);
    end;

    lCandidate := TPath.Combine(TPath.Combine(TPath.Combine(lDir, 'assets'), 'runtime'), cImageFileName);
    if TFile.Exists(lCandidate) then
    begin
      Exit(lCandidate);
    end;

    lParent := ExtractFileDir(lDir);
    if SameText(lParent, lDir) then
    begin
      Break;
    end;
    lDir := lParent;
  end;
end;

procedure TMainForm.LoadSearchHelpImage;
var
  lImagePath: string;
begin
  lImagePath := ResolveSearchHelpImagePath;
  if lImagePath = '' then
  begin
    RecordPipelineNotice('Search syntax help image not found.');
    Exit;
  end;

  try
    fSearchHelpImage.Picture.LoadFromFile(lImagePath);
  except
    on E: Exception do
    begin
      RecordPipelineError('Failed to load search syntax help image "' + lImagePath + '": ' + E.Message);
    end;
  end;
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
var
  i: Integer;
  lExclusions: TPathExclusionsParseResult;
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
  lExclusions := ParsePathExclusionsFile(fExcludesListPath);
  Result.ExcludePathPatterns := lExclusions.Patterns;

  for i := 0 to Pred(Length(lExclusions.Issues)) do
  begin
    RecordPipelineError(
      Format(
        'Excludes list issue line %d "%s": %s',
        [lExclusions.Issues[i].LineNumber, Trim(lExclusions.Issues[i].RawLine), lExclusions.Issues[i].Reason]
      )
    );
  end;
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

procedure TMainForm.BeginScanProgress;
begin
  fScanInProgress := True;
  fScanHourGlass := AutoHourGlass.MakeCHG;
  fScanButton.Enabled := False;
  fScanProgressBar.Visible := True;
  fScanProgressBar.Style := pbstMarquee;
  fScanProgressBar.MarqueeInterval := 30;
  UpdateStatus('Scan running... (indeterminate)');
end;

procedure TMainForm.BeginDockerStart;
begin
  fDockerStartInProgress := True;
  fDockerStartHourGlass := AutoHourGlass.MakeCHG;
  fDockerGpuButton.Enabled := False;
  UpdateStatus('Starting Docker stack...');
end;

procedure TMainForm.EndDockerStart;
begin
  fDockerStartHourGlass := nil;
  fDockerGpuButton.Enabled := True;
  fDockerStartInProgress := False;
end;

procedure TMainForm.EndScanProgress;
begin
  fScanHourGlass := nil;
  fScanProgressBar.Visible := False;
  fScanButton.Enabled := True;
  fScanInProgress := False;

  if Assigned(fScanCancelToken) then
  begin
    fScanCancelToken.Free;
    fScanCancelToken := nil;
  end;
end;

procedure TMainForm.HandleDockerHealthPolled(const aState: TDockerHealthState; const aDetail: string);
const
  cHealthyCaption = 'Docker: healthy';
  cUnhealthyCaption = 'Docker: unhealthy';
  cUnknownCaption = 'Docker: unknown';
begin
  if aState <> fDockerHealthState then
  begin
    fDockerHealthState := aState;
    case aState of
      TDockerHealthState.dhsHealthy:
        begin
          RecordPipelineNotice('Docker health: healthy');
        end;
      TDockerHealthState.dhsUnhealthy:
        begin
          RecordPipelineNotice('Docker health: unhealthy');
        end;
    else
      begin
        RecordPipelineNotice('Docker health: unknown');
      end;
    end;
  end;

  case aState of
    TDockerHealthState.dhsHealthy:
      begin
        fDockerHealthLabel.Caption := cHealthyCaption;
      end;
    TDockerHealthState.dhsUnhealthy:
      begin
        fDockerHealthLabel.Caption := cUnhealthyCaption;
      end;
  else
    begin
      fDockerHealthLabel.Caption := cUnknownCaption;
    end;
  end;

  fDockerHealthLabel.Hint := aDetail;
end;

procedure TMainForm.HandleDockerStartCompleted(const aResult: TDockerCommandResult);
var
  lMessage: string;
begin
  try
    if aResult.Success then
    begin
      lMessage := 'Docker stack start request succeeded.';
      RecordPipelineNotice(lMessage);
      UpdateStatus(lMessage);
      Exit;
    end;

    if aResult.TimedOut then
    begin
      lMessage := 'Docker stack start request timed out.';
    end else begin
      lMessage := Format('Docker stack start failed (exit=%d).', [aResult.ExitCode]);
    end;

    if Trim(aResult.OutputText) <> '' then
    begin
      lMessage := lMessage + ' ' + aResult.OutputText;
    end;
    RecordPipelineError(lMessage);
    UpdateStatus(lMessage);
  finally
    EndDockerStart;
  end;
end;

function TMainForm.ExecuteScanUpdate(const aCancelToken: TPipelineCancellationToken; out aResult: TPipelineRunResult;
  out aStatusText: string): Boolean;
var
  lCoordinator: TPipelineCoordinator;
  lOptions: TPipelineOptions;
  lSourceRoots: TArray<string>;
begin
  aResult := Default(TPipelineRunResult);
  aStatusText := '';

  if not TryLoadSourceRoots(lSourceRoots) then
  begin
    aStatusText := 'Scan skipped: no valid source paths.';
    Exit(False);
  end;

  lOptions := BuildPipelineOptions;
  LogInfo('Scan started from UI. Sources=' + IntToStr(Length(lSourceRoots)));

  lCoordinator := TPipelineCoordinator.Create(fDatabaseManager, lOptions);
  try
    aResult := lCoordinator.Run(lSourceRoots, aCancelToken);
  finally
    lCoordinator.Free;
  end;

  aStatusText := Format(
    'Scan complete. Repos queued/pulled/throttled/failed: %d/%d/%d/%d | Skills queued/written: %d/%d | Errors: %d',
    [aResult.ReposQueued, aResult.ReposPulled, aResult.ReposThrottled, aResult.ReposFailed, aResult.SkillsQueued,
     aResult.SkillsWritten, aResult.ErrorCount]
  );
  if aResult.Cancelled then
  begin
    aStatusText := aStatusText + ' | Cancelled';
  end;
  if Trim(aResult.LastError) <> '' then
  begin
    aStatusText := aStatusText + ' | Last error: ' + aResult.LastError;
  end;

  Result := True;
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

  RefreshCountPanels;
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

procedure TMainForm.HandleSearchHelpButtonClick(Sender: TObject);
const
  cSearchHelpText =
    'Search syntax:' + sLineBreak +
    '- words: retry backoff' + sLineBreak +
    '- phrase: "rate limit"' + sLineBreak +
    '- exclude: -jwt' + sLineBreak +
    '- name filter: name:ollama' + sLineBreak +
    '- tag filter: tag:docker' + sLineBreak +
    '- path filter: path:openclaw' + sLineBreak +
    '- scripts filter: has:scripts / -has:scripts' + sLineBreak +
    '- result limit: limit:200';
begin
  MessageDlg(cSearchHelpText, TMsgDlgType.mtInformation, [TMsgDlgBtn.mbOK], 0);
end;

procedure TMainForm.HandleScanCompleted(const aExecuted: Boolean; const aResult: TPipelineRunResult; const aStatusText,
  aFailure: string);
begin
  try
    if aFailure <> '' then
    begin
      RecordPipelineError('Scan failed: ' + aFailure);
      UpdateStatus('Scan failed: ' + aFailure);
      Exit;
    end;

    if not aExecuted then
    begin
      UpdateStatus(aStatusText);
      Exit;
    end;

    UpdateStatus(aStatusText);
    fSkillsFoundCount := aResult.SkillsQueued;
    RefreshInventoryCounters;
    RefreshCountPanels;
    fStatusBar.Panels[cStatusPanelLastScan].Text := 'Last scan: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    QueueSearch(True);
  finally
    EndScanProgress;
  end;
end;

procedure TMainForm.HandleScanButtonClick(Sender: TObject);
begin
  if fScanInProgress then
  begin
    Exit;
  end;

  BeginScanProgress;
  fScanCancelToken := TPipelineCancellationToken.Create;

  TThread.CreateAnonymousThread(
    procedure
    var
      lResult: TPipelineRunResult;
      lStatusText: string;
      lExecuted: Boolean;
      lFailure: string;
    begin
      lExecuted := False;
      lFailure := '';
      try
        lExecuted := ExecuteScanUpdate(fScanCancelToken, lResult, lStatusText);
      except
        on E: Exception do
        begin
          lFailure := E.Message;
        end;
      end;

      TThread.Queue(nil,
        procedure
        var
          lForm: TMainForm;
        begin
          lForm := AppMainForm;
          if not Assigned(lForm) then
          begin
            Exit;
          end;

          lForm.HandleScanCompleted(lExecuted, lResult, lStatusText, lFailure);
        end
      );
    end
  ).Start;
end;

procedure TMainForm.HandleDiagnosticsButtonClick(Sender: TObject);
begin
  ShowDiagnosticsDialog(self);
end;

procedure TMainForm.HandleDockerGpuButtonClick(Sender: TObject);
begin
  if fDockerStartInProgress then
  begin
    Exit;
  end;

  BeginDockerStart;
  TThread.CreateAnonymousThread(
    procedure
    var
      lResult: TDockerCommandResult;
    begin
      lResult := StartDockerGpuStack(fAppSettings.Docker.StartGpuCommand, 45);
      TThread.Queue(nil,
        procedure
        var
          lForm: TMainForm;
        begin
          lForm := AppMainForm;
          if not Assigned(lForm) then
          begin
            Exit;
          end;

          lForm.HandleDockerStartCompleted(lResult);
        end
      );
    end
  ).Start;
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
    if fScanInProgress and Assigned(fScanCancelToken) then
    begin
      fScanCancelToken.Cancel;
      UpdateStatus('Scan cancellation requested...');
      Key := 0;
      Exit;
    end;

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
