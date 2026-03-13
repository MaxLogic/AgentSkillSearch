unit MainForm;

interface

uses
  System.Classes, System.Types, Winapi.Messages, Winapi.ShellAPI, System.Skia, Vcl.ComCtrls, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.Forms, Vcl.Menus, Vcl.Skia, Vcl.StdCtrls,
  VCL.TMSFNCWebBrowser,
  DatabaseManager, DockerHealthMonitor, DockerOps, ExternalTools, PipelineCoordinator, RelatedSkillActions,
  SearchController, SearchInteraction, SearchResultActions, SettingsModel, SkillSearchService, TagBrowserActions,
  TrayActions, Vcl.ImgList;

type
  TMainForm = class(TForm)
  published
    SearchPanel: TPanel;
    SearchActionsPanel: TPanel;
    SearchFieldPanel: TPanel;
    SearchEdit: TEdit;
    SearchHistoryButton: TButton;
    SearchEditLabel: TStaticText;
    SearchHelpButton: TButton;
    SearchButton: TButton;
    ScanButton: TButton;
    ScanProgressBar: TProgressBar;
    DiagnosticsButton: TButton;
    SearchAsYouTypeCheckBox: TCheckBox;
    DockerGpuButton: TButton;
    FiltersPanel: TPanel;
    DockerHealthLabel: TStaticText;
    HasScriptsCheckBox: TCheckBox;
    SortButton: TButton;
    TagToggleButton: TButton;
    EditSourcesButton: TButton;
    ScanAnimation: TSkAnimatedImage;
    MainPanel: TPanel;
    TagBrowserPanel: TPanel;
    TagBrowserSplitter: TSplitter;
    TagBrowserLabel: TStaticText;
    TagFilterEdit: TEdit;
    TagListBox: TListBox;
    ResultsPanePanel: TPanel;
    ResultsListView: TListView;
    ResultsPreviewSplitter: TSplitter;
    PreviewHostPanel: TPanel;
    PreviewInfoSplitter: TSplitter;
    PreviewPanel: TPanel;
    RelatedPanel: TPanel;
    RelatedListBox: TListBox;
    RelatedLabel: TStaticText;
    PreviewLabel: TStaticText;
    DuplicateInfoPanel: TPanel;
    DuplicateInfoMemo: TMemo;
    DuplicateInfoLabel: TStaticText;
    ResultsListLabel: TStaticText;
    PreviewBrowser: TTMSFNCWebBrowser;
    StatusBar: TStatusBar;
    IconImages: TImageList;
    ResultsPopupMenu: TPopupMenu;
    SortPopupMenu: TPopupMenu;
    SearchHistoryPopupMenu: TPopupMenu;
    ExportResultsMenuItem: TMenuItem;
    OpenFileMenuItem: TMenuItem;
    OpenFolderMenuItem: TMenuItem;
    CopyPathMenuItem: TMenuItem;
  private
    fTrayHotkeyRegistered: Boolean;
    fTrayIconData: TNotifyIconData;
    fTrayState: TTrayWindowState;
    fTrayPopupMenu: TPopupMenu;
    fAppSettings: TAppSettings;
    fDatabaseManager: TDatabaseManager;
    fDbPath: string;
    fDockerStartThread: TThread;
    fExcludesListPath: string;
    fLogPath: string;
    fResults: TArray<TSkillSearchResult>;
    fScanCancelToken: TPipelineCancellationToken;
    fScanInProgress: Boolean;
    fScanHourGlass: IInterface;
    fScanThread: TThread;
    fDockerHealthMonitor: TDockerHealthMonitor;
    fDockerHealthState: TDockerHealthState;
    fDockerStartInProgress: Boolean;
    fDockerStartHourGlass: IInterface;
    fCurrentSortMode: TSearchSortMode;
    fSearchHistory: TSearchHistorySettings;
    fSearchController: TSearchController;
    fSearchService: TSkillSearchService;
    fSettingsPath: string;
    fSkillsFoundCount: Integer;
    fRelatedItems: TArray<TRelatedSkillResult>;
    fTagBrowserItems: TArray<TSkillTagInfo>;
    fTagFilterGeneration: Integer;
    fTagFilterTimer: TTimer;
    fSkillsUniqueCount: Integer;
    fSkillsValidCount: Integer;
    fSourcesListPath: string;
    procedure ApplySearchResults(const aResults: TArray<TSkillSearchResult>);
    function BuildPipelineOptions: TPipelineOptions;
    procedure BeginScanProgress;
    procedure BeginDockerStart;
    procedure EndDockerStart;
    procedure HandleTagFilterTimer(Sender: TObject);
    procedure HandleDockerHealthPolled(const aState: TDockerHealthState; const aDetail: string);
    procedure HandleDockerStartCompleted(const aResult: TDockerCommandResult);
    procedure EndScanProgress;
    procedure LoadButtonIcons;
    procedure StartDockerStackAsync;
    function BuildEffectiveQuery: string;
    procedure CaptureWindowBounds(out aLeft, aTop, aWidth, aHeight: Integer);
    function CaptureUiState: TUiStateSettings;
    function ClampWindowRectToWorkArea(const aBounds: TRect): TRect;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure BuildSortMenu;
    procedure ConfigureColumns;
    procedure CopySelectedPathToClipboard;
    procedure DispatchSearchQuery(const aQuery: string; const aImmediate: Boolean);
    function EscapeHtml(const aText: string): string;
    procedure ExportResultsAsMarkdown;
    function GetSelectedSkillFile: string;
    function GetSelectedSkillRoot: string;
    procedure HideToTray;
    function IsResultSelectionValid: Boolean;
    procedure LoadUiState;
    procedure OpenSelectedSkillFile;
    procedure OpenSelectedSkillFolder;
    procedure PopupTrayMenu;
    procedure PopulateExternalToolsMenu;
    procedure QueueSearch(const aImmediate: Boolean);
    procedure RefreshCountPanels;
    procedure RefreshInventoryCounters;
    procedure RefreshRelatedSkills(const aSkillFile: string);
    procedure RefreshTagBrowser;
    procedure RegisterTrayHotkey;
    procedure RemoveTrayIcon;
    procedure RenderResultsList(const aPreferredSkillFile: string);
    procedure RenderPreview(const aResult: TSkillSearchResult);
    procedure RestoreFromTray;
    procedure SaveRuntimeState;
    function ScaleStoredUiValue(const aValue, aStoredPPI: Integer): Integer;
    procedure SelectHistoryQuery(const aQuery: string);
    function SerializeColumnWidths: string;
    procedure SetSortMode(const aSortMode: TSearchSortMode; const aResortResults: Boolean = True);
    procedure ShowEmptyPreview;
    procedure ShowTrayIcon;
    function TryLoadSourceRoots(out aSourceRoots: TArray<string>): Boolean;
    procedure UnregisterTrayHotkey;
    procedure UpdateStatus(const aText: string);
    procedure UpdateTagBrowserUi;
    procedure UpdateSortUi;
    procedure UpdateSearchHistoryMenu;
    procedure WaitForWorkerThread(var aThread: TThread);
    procedure HandleTrayHotkeyMessage(var Msg: TMessage); message WM_HOTKEY;
    procedure HandleTrayIconMessage(var Msg: TMessage); message WM_APP + 42;
  published
    procedure HandleCopyPathClick(Sender: TObject);
    procedure HandleDiagnosticsButtonClick(Sender: TObject);
    procedure HandleDockerGpuButtonClick(Sender: TObject);
    procedure HandleEditSourcesButtonClick(Sender: TObject);
    procedure HandleExportResultsClick(Sender: TObject);
    procedure HandleExternalToolClick(Sender: TObject);
    procedure HandleFormClose(Sender: TObject; var Action: TCloseAction);
    procedure HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleHasScriptsClick(Sender: TObject);
    procedure HandleScanCompleted(const aExecuted: Boolean; const aResult: TPipelineRunResult; const aStatusText,
      aFailure: string);
    procedure HandleOpenFileClick(Sender: TObject);
    procedure HandleOpenFolderClick(Sender: TObject);
    procedure HandleRelatedListBoxClick(Sender: TObject);
    procedure HandleResultDoubleClick(Sender: TObject);
    procedure HandleResultKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleResultSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure HandleResultsColumnClick(Sender: TObject; Column: TListColumn);
    procedure HandleSearchButtonClick(Sender: TObject);
    procedure HandleSearchCompleted(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>;
      const aError: string);
    procedure HandleSearchEditChange(Sender: TObject);
    procedure HandleSearchEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleSearchHistoryButtonClick(Sender: TObject);
    procedure HandleSearchHistoryItemClick(Sender: TObject);
    procedure HandleSearchHelpButtonClick(Sender: TObject);
    procedure HandleScanButtonClick(Sender: TObject);
    procedure HandleSortButtonClick(Sender: TObject);
    procedure HandleSortMenuItemClick(Sender: TObject);
    procedure HandleTagFilterEditChange(Sender: TObject);
    procedure HandleTagListBoxClick(Sender: TObject);
    procedure HandleTagToggleButtonClick(Sender: TObject);
    procedure HandleTrayExitClick(Sender: TObject);
    procedure HandleTraySettingsClick(Sender: TObject);
    procedure HandleTrayShowClick(Sender: TObject);
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  AppMainForm: TMainForm;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  Vcl.Clipbrd, Vcl.Dialogs, Vcl.Graphics,
  MaxLogic.StrUtils,
  AppPaths, AutoHourGlass, ConfigDlg, DiagnosticsForm, Logging, PathExclusions, PreviewRenderer, Settings,
  SourcesEditorForm, SourcesList;

{$R *.dfm}

procedure QueueToMain(const aProc: TThreadProcedure);
begin
  TThread.Queue(nil, aProc);
end;

const
  cStatusPanelStatus = 0;
  cStatusPanelCounters = 1;
  cStatusPanelLastScan = 2;
  cStatusPanelCache = 3;
  cTrayHotkeyId = 1;
  cTrayIconId = 1;

resourcestring
  rsScanBlockedEditSourcesList = 'Scan blocked: edit Sources.lst and retry.';
  rsScanNeedsSourcesListEdit =
    'Scan cannot start because %s does not contain any usable source directories.' + sLineBreak + sLineBreak +
    'Edit the file first, save it, and then retry Scan.';
  rsSourcesListSaved = 'Sources list saved.';

function ExecuteScanUpdate(const aDatabasePath, aSqliteDllPath: string; const aOptions: TPipelineOptions;
  const aSourceRoots: TArray<string>; const aCancelToken: TPipelineCancellationToken; out aResult: TPipelineRunResult;
  out aStatusText: string): Boolean;
var
  lCoordinator: TPipelineCoordinator;
  lDatabaseManager: TDatabaseManager;
begin
  aResult := Default(TPipelineRunResult);
  aStatusText := '';

  LogInfo('Scan started from UI. Sources=' + IntToStr(Length(aSourceRoots)));
  lDatabaseManager := TDatabaseManager.Create(aDatabasePath, aSqliteDllPath);
  try
    lDatabaseManager.Initialize;
    lCoordinator := TPipelineCoordinator.Create(lDatabaseManager, aOptions);
    try
      aResult := lCoordinator.Run(aSourceRoots, aCancelToken);
    finally
      lCoordinator.Free;
    end;
  finally
    lDatabaseManager.Free;
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

{ TMainForm }

constructor TMainForm.Create(aOwner: TComponent);
var
  i: Integer;
  lMenuItem: TMenuItem;
  lSemanticOptions: TSemanticSearchOptions;
  lSettings: TSettingsLoadResult;
begin
  inherited Create(aOwner);
  AppMainForm := Self;
  fTrayState := DefaultTrayWindowState;

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
  fCurrentSortMode := DefaultSearchSortMode;
  BuildSortMenu;
  fSearchHistory := fAppSettings.SearchHistory;
  if fSearchHistory.MaxItems <= 0 then
  begin
    fSearchHistory.MaxItems := fAppSettings.Search.RecentQueryLimit;
  end;
  UpdateSearchHistoryMenu;
  LoadUiState;
  LoadButtonIcons;
  PopulateExternalToolsMenu;
  RefreshTagBrowser;
  UpdateTagBrowserUi;

  SearchAsYouTypeCheckBox.Checked := fAppSettings.UiState.SearchAsYouType;
  StatusBar.Panels[cStatusPanelCache].Text := 'Cache: ' + fDbPath;
  StatusBar.Panels[cStatusPanelLastScan].Text := 'Last scan: n/a';
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
  fDockerStartThread := nil;
  fDockerHealthState := TDockerHealthState.dhsUnknown;
  DockerHealthLabel.Caption := 'Ollama: checking...';
  DockerHealthLabel.Hint := '';
  fScanThread := nil;
  fDockerHealthMonitor := TDockerHealthMonitor.Create(
    fAppSettings.Docker.HealthCheckCommand,
    10000,
    procedure(const aState: TDockerHealthState; const aDetail: string)
    var
      lForm: TMainForm;
    begin
      lForm := AppMainForm;
      if not Assigned(lForm) then
      begin
        Exit;
      end;

      lForm.HandleDockerHealthPolled(aState, aDetail);
    end
  );
  fDockerHealthMonitor.Start;
  StartDockerStackAsync;

  fTrayPopupMenu := TPopupMenu.Create(Self);

  lMenuItem := TMenuItem.Create(fTrayPopupMenu);
  lMenuItem.Caption := 'Show';
  lMenuItem.OnClick := HandleTrayShowClick;
  fTrayPopupMenu.Items.Add(lMenuItem);

  lMenuItem := TMenuItem.Create(fTrayPopupMenu);
  lMenuItem.Caption := 'Settings...';
  lMenuItem.OnClick := HandleTraySettingsClick;
  fTrayPopupMenu.Items.Add(lMenuItem);

  lMenuItem := TMenuItem.Create(fTrayPopupMenu);
  lMenuItem.Caption := 'Exit';
  lMenuItem.OnClick := HandleTrayExitClick;
  fTrayPopupMenu.Items.Add(lMenuItem);

  fTagFilterTimer := TTimer.Create(Self);
  fTagFilterTimer.Interval := 300;
  fTagFilterTimer.Enabled := False;
  fTagFilterTimer.OnTimer := HandleTagFilterTimer;

  QueueSearch(True);
end;

destructor TMainForm.Destroy;
begin
  RemoveTrayIcon;
  UnregisterTrayHotkey;
  AppMainForm := nil;

  if Assigned(fScanCancelToken) then
  begin
    fScanCancelToken.Cancel;
  end;

  LogInfo('Application shutdown.');
  WaitForWorkerThread(fScanThread);
  if Assigned(fScanCancelToken) then
  begin
    fScanCancelToken.Free;
    fScanCancelToken := nil;
  end;
  WaitForWorkerThread(fDockerStartThread);
  fDockerHealthMonitor.Free;
  fSearchController.Free;
  fSearchService.Free;
  fDatabaseManager.Free;
  inherited Destroy;
end;

procedure TMainForm.CreateWnd;
begin
  inherited CreateWnd;
  RegisterTrayHotkey;
end;

procedure TMainForm.DestroyWnd;
begin
  UnregisterTrayHotkey;
  inherited DestroyWnd;
end;

procedure TMainForm.ConfigureColumns;
begin
  ResultsListView.Columns.BeginUpdate;
  try
    ResultsListView.Columns.Clear;
    with ResultsListView.Columns.Add do
    begin
      Caption := 'Name';
      Width := 230;
    end;

    with ResultsListView.Columns.Add do
    begin
      Caption := 'Rating';
      Width := 90;
    end;

    with ResultsListView.Columns.Add do
    begin
      Caption := 'Description';
      Width := 250;
    end;

    with ResultsListView.Columns.Add do
    begin
      Caption := 'Path';
      Width := 560;
    end;
  finally
    ResultsListView.Columns.EndUpdate;
  end;
end;

function TMainForm.ScaleStoredUiValue(const aValue, aStoredPPI: Integer): Integer;
begin
  Result := SearchInteraction.ScaleStoredUiValue(aValue, aStoredPPI, CurrentPPI);
end;

procedure TMainForm.CaptureWindowBounds(out aLeft, aTop, aWidth, aHeight: Integer);
var
  lBounds: TRect;
  lPlacement: TWindowPlacement;
begin
  if WindowState = wsNormal then
  begin
    lBounds := BoundsRect;
  end else begin
    lPlacement := Default(TWindowPlacement);
    lPlacement.length := SizeOf(TWindowPlacement);
    if GetWindowPlacement(Handle, @lPlacement) then
    begin
      lBounds := lPlacement.rcNormalPosition;
    end else begin
      lBounds := BoundsRect;
    end;
  end;

  aLeft := lBounds.Left;
  aTop := lBounds.Top;
  aWidth := lBounds.Right - lBounds.Left;
  aHeight := lBounds.Bottom - lBounds.Top;
end;

function TMainForm.ClampWindowRectToWorkArea(const aBounds: TRect): TRect;
var
  lHeight: Integer;
  lMonitor: TMonitor;
  lWidth: Integer;
  lWorkArea: TRect;
begin
  Result := aBounds;
  lMonitor := Screen.MonitorFromRect(aBounds, mdNearest);
  if not Assigned(lMonitor) then
  begin
    Exit;
  end;

  lWorkArea := lMonitor.WorkareaRect;
  lWidth := Result.Right - Result.Left;
  lHeight := Result.Bottom - Result.Top;

  if lWidth > (lWorkArea.Right - lWorkArea.Left) then
  begin
    Result.Left := lWorkArea.Left;
    Result.Right := lWorkArea.Right;
  end else begin
    if Result.Left < lWorkArea.Left then
    begin
      OffsetRect(Result, lWorkArea.Left - Result.Left, 0);
    end;
    if Result.Right > lWorkArea.Right then
    begin
      OffsetRect(Result, lWorkArea.Right - Result.Right, 0);
    end;
  end;

  if lHeight > (lWorkArea.Bottom - lWorkArea.Top) then
  begin
    Result.Top := lWorkArea.Top;
    Result.Bottom := lWorkArea.Bottom;
  end else begin
    if Result.Top < lWorkArea.Top then
    begin
      OffsetRect(Result, 0, lWorkArea.Top - Result.Top);
    end;
    if Result.Bottom > lWorkArea.Bottom then
    begin
      OffsetRect(Result, 0, lWorkArea.Bottom - Result.Bottom);
    end;
  end;
end;

function TMainForm.SerializeColumnWidths: string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Pred(ResultsListView.Columns.Count) do
  begin
    if Result <> '' then
    begin
      Result := Result + ';';
    end;
    Result := Result + IntToStr(ResultsListView.Columns[i].Width);
  end;
end;

function TMainForm.CaptureUiState: TUiStateSettings;
begin
  Result := fAppSettings.UiState;
  Result.CurrentPPI := CurrentPPI;
  Result.DuplicateInfoWidth := DuplicateInfoPanel.Height;
  Result.LastQuery := Trim(SearchEdit.Text);
  Result.ResultSortMode := SearchSortModeToString(fCurrentSortMode);
  Result.ResultsColumnWidths := SerializeColumnWidths;
  Result.ResultsPaneWidth := PreviewHostPanel.Width;
  Result.SearchAsYouType := SearchAsYouTypeCheckBox.Checked;
  CaptureWindowBounds(Result.WindowLeft, Result.WindowTop, Result.WindowWidth, Result.WindowHeight);
end;

procedure TMainForm.LoadUiState;
var
  i: Integer;
  lBounds: TRect;
  lHeight: Integer;
  lLeft: Integer;
  lParts: TStringDynArray;
  lStoredPPI: Integer;
  lTop: Integer;
  lWidth: Integer;
begin
  lStoredPPI := fAppSettings.UiState.CurrentPPI;
  if not TryParseSearchSortMode(fAppSettings.UiState.ResultSortMode, fCurrentSortMode) then
  begin
    fCurrentSortMode := DefaultSearchSortMode;
  end;
  UpdateSortUi;

  SearchEdit.Text := fAppSettings.UiState.LastQuery;
  SearchAsYouTypeCheckBox.Checked := fAppSettings.UiState.SearchAsYouType;

  if (fAppSettings.UiState.WindowWidth > 0) and (fAppSettings.UiState.WindowHeight > 0) and
    ((fAppSettings.UiState.WindowLeft <> -1) or (fAppSettings.UiState.WindowTop <> -1)) then
  begin
    lLeft := fAppSettings.UiState.WindowLeft;
    lTop := fAppSettings.UiState.WindowTop;
    lWidth := ScaleStoredUiValue(fAppSettings.UiState.WindowWidth, lStoredPPI);
    lHeight := ScaleStoredUiValue(fAppSettings.UiState.WindowHeight, lStoredPPI);
    lLeft := ScaleStoredUiValue(lLeft, lStoredPPI);
    lTop := ScaleStoredUiValue(lTop, lStoredPPI);
    lBounds := ClampWindowRectToWorkArea(Rect(lLeft, lTop, lLeft + lWidth, lTop + lHeight));
    Position := poDesigned;
    SetBounds(lBounds.Left, lBounds.Top, lBounds.Right - lBounds.Left, lBounds.Bottom - lBounds.Top);
  end;

  if fAppSettings.UiState.ResultsPaneWidth > 0 then
  begin
    PreviewHostPanel.Width := ScaleStoredUiValue(fAppSettings.UiState.ResultsPaneWidth, lStoredPPI);
  end;
  if fAppSettings.UiState.DuplicateInfoWidth > 0 then
  begin
    DuplicateInfoPanel.Height := ScaleStoredUiValue(fAppSettings.UiState.DuplicateInfoWidth, lStoredPPI);
  end;

  if Trim(fAppSettings.UiState.ResultsColumnWidths) <> '' then
  begin
    lParts := SplitString(fAppSettings.UiState.ResultsColumnWidths, ';');
    for i := 0 to Pred(Length(lParts)) do
    begin
      if i >= ResultsListView.Columns.Count then
      begin
        Break;
      end;
      ResultsListView.Columns[i].Width := ScaleStoredUiValue(StrToIntDef(Trim(lParts[i]), 0), lStoredPPI);
    end;
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
  PreviewBrowser.LoadHTML('<html><body><p>No skill selected.</p></body></html>');
  DuplicateInfoMemo.Lines.Text := 'No duplicate details available.';
  fRelatedItems := nil;
  PopulateRelatedSkillsListBox(RelatedListBox, fRelatedItems);
  RelatedPanel.Visible := False;
end;

procedure TMainForm.RenderPreview(const aResult: TSkillSearchResult);
var
  lBodyHtml: string;
  lBodyMarkdown: string;
  lDuplicateText: string;
  lHtml: string;
begin
  lBodyMarkdown := Trim(aResult.BodyMarkdown);
  if lBodyMarkdown = '' then
  begin
    lBodyMarkdown := aResult.Snippet;
  end;
  lBodyHtml := BuildPreviewSnippetHtml(HighlightPreviewTerms(lBodyMarkdown, BuildEffectiveQuery));
  lHtml :=
    '<html><body style="font-family:Segoe UI;padding:12px;">' +
    '<h3>' + EscapeHtml(aResult.Name) + '</h3>' +
    '<p><b>Description:</b> ' + EscapeHtml(aResult.Description) + '</p>' +
    '<p><b>Tags:</b> ' + EscapeHtml(aResult.Tags) + '</p>' +
    '<p><b>Scripts:</b> ' + IntToStr(aResult.ScriptsCount) + ' [' + EscapeHtml(aResult.ScriptsExts) + ']</p>' +
    lBodyHtml +
    '<p><b>Path:</b> ' + EscapeHtml(aResult.SkillFile) + '</p>' +
    '</body></html>';

  PreviewBrowser.LoadHTML(lHtml);
  if aResult.DuplicateCount <= 1 then
  begin
    lDuplicateText := 'No duplicate skills detected for this result.';
  end else begin
    lDuplicateText := Format('Duplicate skills detected: %d', [aResult.DuplicateCount]) + sLineBreak +
      'Canonical:' + sLineBreak + aResult.SkillFile + sLineBreak + sLineBreak +
      'Other locations:' + sLineBreak + aResult.DuplicatePaths;
  end;
  DuplicateInfoMemo.Lines.Text := lDuplicateText;
  RefreshRelatedSkills(aResult.SkillFile);
end;

function TMainForm.GetSelectedSkillFile: string;
var
  lIndex: Integer;
begin
  if not IsResultSelectionValid then
  begin
    Exit('');
  end;

  lIndex := ResultsListView.Selected.Index;
  Result := fResults[lIndex].SkillFile;
end;

function TMainForm.GetSelectedSkillRoot: string;
var
  lIndex: Integer;
begin
  if not IsResultSelectionValid then
  begin
    Exit('');
  end;

  lIndex := ResultsListView.Selected.Index;
  Result := fResults[lIndex].SkillRoot;
end;

procedure TMainForm.ShowTrayIcon;
begin
  if fTrayState.TrayIconVisible then
  begin
    Exit;
  end;

  fTrayIconData := Default(TNotifyIconData);
  fTrayIconData.cbSize := TNotifyIconData.SizeOf;
  fTrayIconData.Wnd := Handle;
  fTrayIconData.uID := cTrayIconId;
  fTrayIconData.uFlags := NIF_MESSAGE or NIF_ICON or NIF_TIP;
  fTrayIconData.uCallbackMessage := WM_APP + 42;
  fTrayIconData.hIcon := Application.Icon.Handle;
  StringToWideChar(Caption, @fTrayIconData.szTip[0], High(fTrayIconData.szTip) + 1);

  if not Shell_NotifyIcon(NIM_ADD, @fTrayIconData) then
  begin
    RecordPipelineError('Failed to add tray icon.');
    Exit;
  end;

  fTrayState.TrayIconVisible := True;
end;

procedure TMainForm.RemoveTrayIcon;
begin
  if not fTrayState.TrayIconVisible then
  begin
    Exit;
  end;

  Shell_NotifyIcon(NIM_DELETE, @fTrayIconData);
  fTrayState.TrayIconVisible := False;
end;

procedure TMainForm.HideToTray;
begin
  ShowTrayIcon;
  if not fTrayState.TrayIconVisible then
  begin
    Exit;
  end;

  ShowWindow(Handle, SW_HIDE);
  fTrayState := ApplyHideToTray(fTrayState);
end;

procedure TMainForm.RestoreFromTray;
begin
  RemoveTrayIcon;
  Show;
  if WindowState = TWindowState.wsMinimized then
  begin
    WindowState := TWindowState.wsNormal;
  end;
  ShowWindow(Handle, SW_RESTORE);
  Application.Restore;
  BringToFront;
  SetForegroundWindow(Handle);
  fTrayState := ApplyRestoreFromTray(fTrayState);
end;

procedure TMainForm.PopupTrayMenu;
var
  lPoint: TPoint;
begin
  if not Assigned(fTrayPopupMenu) then
  begin
    Exit;
  end;

  SetForegroundWindow(Handle);
  lPoint := Mouse.CursorPos;
  fTrayPopupMenu.Popup(lPoint.X, lPoint.Y);
  PostMessage(Handle, WM_NULL, 0, 0);
end;

procedure TMainForm.UnregisterTrayHotkey;
begin
  if not fTrayHotkeyRegistered then
  begin
    Exit;
  end;

  UnregisterHotKey(Handle, cTrayHotkeyId);
  fTrayHotkeyRegistered := False;
end;

procedure TMainForm.RegisterTrayHotkey;
var
  lError: string;
  lHotkey: TTrayHotkey;
  lHotkeySetting: string;
begin
  UnregisterTrayHotkey;

  lHotkeySetting := Trim(fAppSettings.Ui.TrayHotkey);
  if lHotkeySetting = '' then
  begin
    Exit;
  end;

  if not TryParseTrayHotkey(lHotkeySetting, lHotkey, lError) then
  begin
    RecordPipelineNotice('Tray hotkey ignored: ' + lHotkeySetting + ' (' + lError + ')');
    Exit;
  end;

  if not RegisterHotKey(Handle, cTrayHotkeyId, lHotkey.Modifiers, lHotkey.VirtualKey) then
  begin
    RecordPipelineNotice('Tray hotkey registration failed: ' + lHotkeySetting);
    Exit;
  end;

  fTrayHotkeyRegistered := True;
end;

function TMainForm.IsResultSelectionValid: Boolean;
begin
  Result := Assigned(ResultsListView.Selected) and
    (ResultsListView.Selected.Index >= 0) and
    (ResultsListView.Selected.Index < Length(fResults));
end;

procedure TMainForm.UpdateStatus(const aText: string);
begin
  StatusBar.Panels[cStatusPanelStatus].Text := aText;
end;

procedure TMainForm.BuildSortMenu;
const
  cSortCaptions: array[TSearchSortMode] of string = (
    'Score',
    'Name A to Z',
    'Name Z to A',
    'Path A to Z',
    'Path Z to A',
    'Date Indexed (Newest)',
    'Date Indexed (Oldest)'
  );
var
  lItem: TMenuItem;
  lSortMode: TSearchSortMode;
begin
  SortPopupMenu.Items.Clear;
  for lSortMode := Low(TSearchSortMode) to High(TSearchSortMode) do
  begin
    lItem := TMenuItem.Create(SortPopupMenu);
    lItem.AutoCheck := False;
    lItem.Caption := cSortCaptions[lSortMode];
    lItem.RadioItem := True;
    lItem.Tag := Ord(lSortMode);
    lItem.OnClick := HandleSortMenuItemClick;
    SortPopupMenu.Items.Add(lItem);
  end;
  UpdateSortUi;
end;

procedure TMainForm.UpdateSortUi;
const
  cSortLabels: array[TSearchSortMode] of string = (
    'Score',
    'Name A to Z',
    'Name Z to A',
    'Path A to Z',
    'Path Z to A',
    'Date Indexed',
    'Date Indexed Oldest'
  );
var
  i: Integer;
begin
  SortButton.Caption := 'Sort: ' + cSortLabels[fCurrentSortMode];
  for i := 0 to Pred(SortPopupMenu.Items.Count) do
  begin
    SortPopupMenu.Items[i].Checked := SortPopupMenu.Items[i].Tag = Ord(fCurrentSortMode);
  end;
end;

procedure TMainForm.SetSortMode(const aSortMode: TSearchSortMode; const aResortResults: Boolean);
var
  lSelectedSkillFile: string;
begin
  lSelectedSkillFile := GetSelectedSkillFile;
  fCurrentSortMode := aSortMode;
  UpdateSortUi;

  if aResortResults and (Length(fResults) > 0) then
  begin
    SortSearchResults(fResults, fCurrentSortMode);
    RenderResultsList(lSelectedSkillFile);
  end;
end;

procedure TMainForm.ExportResultsAsMarkdown;
var
  lMarkdown: string;
begin
  if not TryBuildResultsMarkdownList(fResults, lMarkdown) then
  begin
    UpdateStatus('No results to export.');
    Exit;
  end;

  Clipboard.AsText := lMarkdown;
  UpdateStatus(Format('Copied %d results as markdown list.', [Length(fResults)]));
end;

procedure TMainForm.PopulateExternalToolsMenu;
begin
  PopulateExternalToolsPopupMenu(ResultsPopupMenu, fAppSettings.ExternalTools, HandleExternalToolClick, 1);
end;

procedure TMainForm.DispatchSearchQuery(const aQuery: string; const aImmediate: Boolean);
begin
  if not fScanInProgress then
  begin
    ScanAnimation.Visible := True;
    ScanAnimation.Animation.Loop := True;
    ScanAnimation.Animation.Enabled := True;
    ScanAnimation.Animation.Start;
  end;
  if aImmediate then
  begin
    fSearchController.QueueSearch(aQuery, 0);
  end else begin
    fSearchController.QueueSearch(aQuery);
  end;
  UpdateStatus('Searching...');
end;

procedure TMainForm.SaveRuntimeState;
begin
  fAppSettings.UiState := CaptureUiState;
  SaveUiState(fSettingsPath, fAppSettings.UiState);
  SaveSearchHistory(fSettingsPath, fSearchHistory);
end;

procedure TMainForm.UpdateSearchHistoryMenu;
var
  i: Integer;
  lItem: TMenuItem;
begin
  SearchHistoryPopupMenu.Items.Clear;
  for i := 0 to Pred(Length(fSearchHistory.Items)) do
  begin
    lItem := TMenuItem.Create(SearchHistoryPopupMenu);
    lItem.Caption := fSearchHistory.Items[i];
    lItem.OnClick := HandleSearchHistoryItemClick;
    SearchHistoryPopupMenu.Items.Add(lItem);
  end;

  SearchHistoryButton.Enabled := Length(fSearchHistory.Items) > 0;
end;

procedure TMainForm.SelectHistoryQuery(const aQuery: string);
begin
  ExecuteHistorySelection(
    aQuery,
    fSearchHistory,
    procedure(const aSelectedQuery: string)
    begin
      SearchEdit.Text := aSelectedQuery;
    end,
    procedure(const aPreparedQuery: string)
    begin
      UpdateSearchHistoryMenu;
      DispatchSearchQuery(aPreparedQuery, True);
    end
  );
end;

procedure TMainForm.RenderResultsList(const aPreferredSkillFile: string);
var
  i: Integer;
  lItem: TListItem;
  lSelectedIndex: Integer;
begin
  lSelectedIndex := -1;
  ResultsListView.Items.BeginUpdate;
  try
    ResultsListView.Items.Clear;
    for i := 0 to Pred(Length(fResults)) do
    begin
      lItem := ResultsListView.Items.Add;
      lItem.Caption := fResults[i].Name;
      lItem.SubItems.Add(FormatFloat('0.000', fResults[i].FinalScore));
      lItem.SubItems.Add(fResults[i].Description);
      lItem.SubItems.Add(fResults[i].SkillRoot);
      if (aPreferredSkillFile <> '') and SameText(fResults[i].SkillFile, aPreferredSkillFile) then
      begin
        lSelectedIndex := i;
      end;
    end;
  finally
    ResultsListView.Items.EndUpdate;
  end;

  if ResultsListView.Items.Count = 0 then
  begin
    ShowEmptyPreview;
    Exit;
  end;

  if lSelectedIndex < 0 then
  begin
    lSelectedIndex := 0;
  end;
  ResultsListView.Items[lSelectedIndex].Selected := True;
  ResultsListView.Items[lSelectedIndex].Focused := True;
  RenderPreview(fResults[lSelectedIndex]);
end;

procedure TMainForm.RefreshCountPanels;
begin
  StatusBar.Panels[cStatusPanelCounters].Text := Format(
    'Found: %d | Valid: %d | Unique: %d | Results: %d',
    [fSkillsFoundCount, fSkillsValidCount, fSkillsUniqueCount, Length(fResults)]);
end;

procedure TMainForm.RefreshInventoryCounters;
begin
  fSkillsValidCount := fDatabaseManager.GetValidSkillCount;
  fSkillsUniqueCount := fDatabaseManager.GetUniqueSkillCount;
end;

procedure TMainForm.RefreshRelatedSkills(const aSkillFile: string);
begin
  if (not fAppSettings.Semantic.Enabled) or (Trim(aSkillFile) = '') then
  begin
    fRelatedItems := nil;
    PopulateRelatedSkillsListBox(RelatedListBox, fRelatedItems);
    RelatedPanel.Visible := False;
    Exit;
  end;

  fRelatedItems := fSearchService.FindRelatedSkills(aSkillFile, 3);
  PopulateRelatedSkillsListBox(RelatedListBox, fRelatedItems);
  RelatedPanel.Visible := Length(fRelatedItems) > 0;
end;

procedure TMainForm.RefreshTagBrowser;
begin
  fTagBrowserItems := fDatabaseManager.GetSkillTagCounts;
  PopulateTagListBox(TagListBox, fTagBrowserItems);
end;

procedure TMainForm.LoadButtonIcons;
const
  cS = '#374151'; // Tailwind gray-700 – readable on light backgrounds
  cA = ' stroke-width="2" stroke-linecap="round" stroke-linejoin="round">';
  cH = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + cS + '"' + cA;

  cSvgSearch   = cH + '<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/></svg>';
  cSvgRefresh  = cH +
    '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/>' +
    '<path d="M21 3v5h-5"/>' +
    '<path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/>' +
    '<path d="M8 16H3v5"/></svg>';
  cSvgHistory  = cH +
    '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>' +
    '<path d="M3 3v5h5"/><path d="M12 7v5l4 2"/></svg>';
  cSvgInfo     = cH +
    '<circle cx="12" cy="12" r="10"/>' +
    '<path d="M12 16v-4"/><path d="M12 8h.01"/></svg>';
  cSvgSort     = cH +
    '<path d="m21 16-4 4-4-4"/><path d="M17 20V4"/>' +
    '<path d="m3 8 4-4 4 4"/><path d="M7 4v16"/></svg>';
  cSvgTag      = cH +
    '<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 ' +
    '.586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/>' +
    '<circle cx="7.5" cy="7.5" r=".5" fill="' + cS + '"/></svg>';
  cSvgFolder   = cH +
    '<path d="m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6' +
    'a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9' +
    'l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2"/></svg>';
  cSvgSettings = cH +
    '<path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915' +
    ' 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033' +
    ' 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915' +
    ' 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051' +
    ' a2.34 2.34 0 0 0 3.319-1.915"/>' +
    '<circle cx="12" cy="12" r="3"/></svg>';
  cSvgCpu      = cH +
    '<path d="M12 20v2"/><path d="M12 2v2"/><path d="M17 20v2"/><path d="M17 2v2"/>' +
    '<path d="M2 12h2"/><path d="M2 17h2"/><path d="M2 7h2"/><path d="M20 12h2"/>' +
    '<path d="M20 17h2"/><path d="M20 7h2"/><path d="M7 20v2"/><path d="M7 2v2"/>' +
    '<rect x="4" y="4" width="16" height="16" rx="2"/>' +
    '<rect x="8" y="8" width="8" height="8" rx="1"/></svg>';

  cIconSize = 20;
  cSvgs: array[0..8] of string = (
    cSvgSearch, cSvgRefresh, cSvgHistory, cSvgInfo,
    cSvgSort, cSvgTag, cSvgFolder, cSvgSettings, cSvgCpu
  );
var
  lBmp: TBitmap;
  lSvg: string;
begin
  if not Assigned(IconImages) then
  begin
    IconImages := TImageList.Create(Self);
    IconImages.Width := cIconSize;
    IconImages.Height := cIconSize;
    IconImages.ColorDepth := cd32Bit;
  end;
  IconImages.Clear;

  for lSvg in cSvgs do
  begin
    lBmp := TBitmap.Create;
    try
      lBmp.SetSize(cIconSize, cIconSize);
      lBmp.PixelFormat := pf32bit;
      lBmp.AlphaFormat := afDefined;
      lBmp.SkiaDraw(
        procedure(const ACanvas: ISkCanvas)
        var
          lDom: ISkSVGDOM;
        begin
          lDom := TSkSVGDOM.Make(lSvg);
          if Assigned(lDom) then
          begin
            lDom.SetContainerSize(TSizeF.Create(cIconSize, cIconSize));
            lDom.Render(ACanvas);
          end;
        end);
      IconImages.Add(lBmp, nil);
    finally
      lBmp.Free;
    end;
  end;

  SearchButton.Images        := IconImages; SearchButton.ImageIndex        := 0;
  ScanButton.Images          := IconImages; ScanButton.ImageIndex          := 1;
  SearchHistoryButton.Images := IconImages; SearchHistoryButton.ImageIndex := 2;
  SearchHelpButton.Images    := IconImages; SearchHelpButton.ImageIndex    := 3;
  SortButton.Images          := IconImages; SortButton.ImageIndex          := 4;
  TagToggleButton.Images     := IconImages; TagToggleButton.ImageIndex     := 5;
  EditSourcesButton.Images   := IconImages; EditSourcesButton.ImageIndex   := 6;
  DiagnosticsButton.Images   := IconImages; DiagnosticsButton.ImageIndex   := 7;
  DockerGpuButton.Images     := IconImages; DockerGpuButton.ImageIndex     := 8;
end;

function TMainForm.BuildEffectiveQuery: string;
begin
  Result := Trim(SearchEdit.Text);
  if HasScriptsCheckBox.Checked and (not ContainsText(Result, 'has:scripts')) and
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
  Result.SemanticOptions.Enabled := fAppSettings.Semantic.Enabled;
  Result.SemanticOptions.CandidateRerankCount := fAppSettings.Semantic.CandidateRerankCount;
  Result.SemanticOptions.EmbeddingRequester := nil;
  Result.SemanticOptions.Model := fAppSettings.Semantic.Model;
  Result.SemanticOptions.OllamaBaseUrl := fAppSettings.Semantic.OllamaBaseUrl;
  Result.SkipFolders := fAppSettings.Git.SkipFolders;
  Result.SkillFileName := fAppSettings.Index.SkillFileName;
  Result.TreatWorktreesAsRepos := fAppSettings.Git.TreatWorktreesAsRepos;
  Result.OnEmbeddingProgress :=
    procedure(const aCurrent, aTotal: Integer; const aStatusText: string)
    begin
      QueueToMain(procedure
        var
          lForm: TMainForm;
        begin
          lForm := AppMainForm;
          if not Assigned(lForm) or (Trim(aStatusText) = '') then
          begin
            Exit;
          end;

          lForm.UpdateStatus(aStatusText);
        end);
    end;
  Result.IndexOptions.ComputeHasScripts := fAppSettings.Index.ComputeHasScripts;
  Result.IndexOptions.HasScriptsMaxFilesToScan := fAppSettings.Index.HasScriptsMaxFilesToScan;
  Result.IndexOptions.HasScriptsSkipFolders := fAppSettings.Index.HasScriptsSkipFolders;
  Result.IndexOptions.ScriptExtensions := fAppSettings.Index.ScriptExtensions;
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

  lParseResult := LoadUsableSourcesListFile(fSourcesListPath, GetExeDirectory);
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

procedure TMainForm.WaitForWorkerThread(var aThread: TThread);
begin
  if not Assigned(aThread) then
  begin
    Exit;
  end;

  aThread.WaitFor;
  TThread.RemoveQueuedEvents(aThread);
  aThread.Free;
  aThread := nil;
end;

procedure TMainForm.BeginScanProgress;
begin
  fScanInProgress := True;
  fScanHourGlass := AutoHourGlass.MakeCHG;
  ScanButton.Enabled := False;
  ScanProgressBar.Visible := True;
  ScanProgressBar.Style := pbstMarquee;
  ScanProgressBar.MarqueeInterval := 30;
  ScanAnimation.Visible := True;
  ScanAnimation.Animation.Loop := True;
  ScanAnimation.Animation.Enabled := True;
  ScanAnimation.Animation.Start;
  UpdateStatus('Scan running... (indeterminate)');
end;

procedure TMainForm.BeginDockerStart;
begin
  fDockerStartInProgress := True;
  fDockerStartHourGlass := AutoHourGlass.MakeCHG;
  DockerGpuButton.Enabled := False;
  UpdateStatus('Starting Ollama container...');
end;

procedure TMainForm.EndDockerStart;
begin
  fDockerStartHourGlass := nil;
  DockerGpuButton.Enabled := True;
  fDockerStartInProgress := False;
end;

procedure TMainForm.StartDockerStackAsync;
var
  lStartCommand: string;
begin
  if fDockerStartInProgress then
  begin
    Exit;
  end;

  if Assigned(fDockerStartThread) then
  begin
    WaitForWorkerThread(fDockerStartThread);
  end;

  lStartCommand := fAppSettings.Docker.StartGpuCommand;
  BeginDockerStart;
  fDockerStartThread := TThread.CreateAnonymousThread(
    procedure
    var
      lResult: TDockerCommandResult;
    begin
      lResult := StartDockerGpuStack(lStartCommand, 45);
      QueueToMain(procedure
        var
          lForm: TMainForm;
        begin
          lForm := AppMainForm;
          if not Assigned(lForm) then
          begin
            Exit;
          end;

          lForm.HandleDockerStartCompleted(lResult);
        end);
    end
  );
  fDockerStartThread.FreeOnTerminate := False;
  fDockerStartThread.Start;
end;

procedure TMainForm.EndScanProgress;
begin
  fScanHourGlass := nil;
  ScanProgressBar.Visible := False;
  ScanButton.Enabled := True;
  fScanInProgress := False;
  ScanAnimation.Animation.Loop := False;
  ScanAnimation.Animation.Enabled := False;
  ScanAnimation.Visible := False;

  if Assigned(fScanCancelToken) then
  begin
    fScanCancelToken.Free;
    fScanCancelToken := nil;
  end;
end;

procedure TMainForm.HandleDockerHealthPolled(const aState: TDockerHealthState; const aDetail: string);
const
  cHealthyCaption = 'Ollama: running';
  cUnhealthyCaption = 'Ollama: unavailable';
  cUnknownCaption = 'Ollama: unknown';
begin
  if aState <> fDockerHealthState then
  begin
    fDockerHealthState := aState;
    case aState of
      TDockerHealthState.dhsHealthy:
        begin
          RecordPipelineNotice('Ollama health: healthy');
        end;
      TDockerHealthState.dhsUnhealthy:
        begin
          RecordPipelineNotice('Ollama health: unhealthy');
        end;
    else
      begin
        RecordPipelineNotice('Ollama health: unknown');
      end;
    end;
  end;

  case aState of
    TDockerHealthState.dhsHealthy:
      begin
        DockerHealthLabel.Caption := cHealthyCaption;
      end;
    TDockerHealthState.dhsUnhealthy:
      begin
        DockerHealthLabel.Caption := cUnhealthyCaption;
      end;
  else
    begin
      DockerHealthLabel.Caption := cUnknownCaption;
    end;
  end;

  DockerHealthLabel.Hint := aDetail;
end;

procedure TMainForm.HandleDockerStartCompleted(const aResult: TDockerCommandResult);
var
  lMessage: string;
begin
  try
    if aResult.Success then
    begin
      lMessage := 'Ollama start request succeeded.';
      RecordPipelineNotice(lMessage);
      UpdateStatus(lMessage);
      Exit;
    end;

    if aResult.TimedOut then
    begin
      lMessage := 'Ollama start request timed out.';
    end else begin
      lMessage := Format('Ollama start failed (exit=%d).', [aResult.ExitCode]);
    end;

    if Trim(aResult.OutputText) <> '' then
    begin
      lMessage := lMessage + ' ' + aResult.OutputText;
    end;
    RecordPipelineError(lMessage);
    UpdateStatus(lMessage);
  finally
    EndDockerStart;
    WaitForWorkerThread(fDockerStartThread);
  end;
end;

procedure TMainForm.QueueSearch(const aImmediate: Boolean);
var
  lQuery: string;
begin
  lQuery := BuildEffectiveQuery;
  if aImmediate then
  begin
    ExecuteImmediateSearch(
      lQuery,
      fSearchHistory,
      procedure(const aPreparedQuery: string)
      begin
        UpdateSearchHistoryMenu;
        DispatchSearchQuery(aPreparedQuery, True);
      end
    );
  end else begin
    DispatchSearchQuery(lQuery, False);
  end;
end;

procedure TMainForm.ApplySearchResults(const aResults: TArray<TSkillSearchResult>);
begin
  if not fScanInProgress then
  begin
    ScanAnimation.Animation.Loop := False;
    ScanAnimation.Animation.Enabled := False;
    ScanAnimation.Visible := False;
  end;
  fResults := aResults;
  SortSearchResults(fResults, fCurrentSortMode);
  RenderResultsList('');

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
    '- OR / grouping: (retry OR backoff) timeout' + sLineBreak +
    '- phrase: "rate limit"' + sLineBreak +
    '- exclude: -jwt' + sLineBreak +
    '- name filter: name:ollama' + sLineBreak +
    '- tag filter: tag:docker' + sLineBreak +
    '- path filter: path:openclaw' + sLineBreak +
    '- extension filter: ext:py' + sLineBreak +
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
    RefreshTagBrowser;
    RefreshCountPanels;
    StatusBar.Panels[cStatusPanelLastScan].Text := 'Last scan: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    QueueSearch(True);
  finally
    EndScanProgress;
    WaitForWorkerThread(fScanThread);
  end;
end;

procedure TMainForm.HandleScanButtonClick(Sender: TObject);
var
  lDatabasePath: string;
  lOptions: TPipelineOptions;
  lSqliteDllPath: string;
  lSourceRoots: TArray<string>;
begin
  if fScanInProgress then
  begin
    Exit;
  end;

  if not TryLoadSourceRoots(lSourceRoots) then
  begin
    UpdateStatus(rsScanBlockedEditSourcesList);
    MessageDlg(Format(rsScanNeedsSourcesListEdit, [ExtractFileName(fSourcesListPath)]), TMsgDlgType.mtWarning,
      [TMsgDlgBtn.mbOK], 0);
    Exit;
  end;

  lOptions := BuildPipelineOptions;
  lDatabasePath := fDatabaseManager.DatabasePath;
  lSqliteDllPath := fDatabaseManager.SqliteDllPath;
  BeginScanProgress;
  fScanCancelToken := TPipelineCancellationToken.Create;

  if Assigned(fScanThread) then
  begin
    WaitForWorkerThread(fScanThread);
  end;

  fScanThread := TThread.CreateAnonymousThread(
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
        lExecuted := ExecuteScanUpdate(lDatabasePath, lSqliteDllPath, lOptions, lSourceRoots, fScanCancelToken,
          lResult, lStatusText);
      except
        on E: Exception do
        begin
          lFailure := E.Message;
        end;
      end;

      QueueToMain(procedure
        var
          lForm: TMainForm;
        begin
          lForm := AppMainForm;
          if not Assigned(lForm) then
          begin
            Exit;
          end;

          lForm.HandleScanCompleted(lExecuted, lResult, lStatusText, lFailure);
        end);
    end
  );
  fScanThread.FreeOnTerminate := False;
  fScanThread.Start;
end;

procedure TMainForm.HandleDiagnosticsButtonClick(Sender: TObject);
begin
  ShowDiagnosticsDialog(self);
end;

procedure TMainForm.HandleExportResultsClick(Sender: TObject);
begin
  ExportResultsAsMarkdown;
end;

procedure TMainForm.HandleExternalToolClick(Sender: TObject);
var
  lLaunch: TExternalToolLaunch;
  lSelectedSkillRoot: string;
begin
  lSelectedSkillRoot := GetSelectedSkillRoot;
  if lSelectedSkillRoot = '' then
  begin
    Exit;
  end;

  if not (Sender is TMenuItem) then
  begin
    Exit;
  end;

  if not TryPrepareExternalToolLaunch(fAppSettings.ExternalTools, TMenuItem(Sender).Tag, lSelectedSkillRoot, lLaunch)
  then
  begin
    Exit;
  end;

  if ShellExecute(Handle, 'open', PChar(lLaunch.ExecutablePath), PChar(lLaunch.Parameters), nil, SW_SHOWNORMAL) <= 32
  then
  begin
    RecordPipelineError('Failed to launch external tool: ' + lLaunch.Name);
    UpdateStatus('Failed to launch external tool: ' + lLaunch.Name);
    Exit;
  end;

  UpdateStatus('Launched: ' + lLaunch.Name);
end;

procedure TMainForm.HandleFormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveRuntimeState;
  if fAppSettings.Ui.CloseToTray and ShouldHideToTrayOnClose(fTrayState.ExitRequested) then
  begin
    HideToTray;
    if fTrayState.TrayIconVisible then
    begin
      Action := TCloseAction.caNone;
      Exit;
    end;
  end;

  RemoveTrayIcon;
end;

procedure TMainForm.HandleDockerGpuButtonClick(Sender: TObject);
begin
  StartDockerStackAsync;
end;

procedure TMainForm.HandleEditSourcesButtonClick(Sender: TObject);
begin
  if not TSourcesEditorForm.Execute(Self, fSourcesListPath, GetExeDirectory) then
  begin
    Exit;
  end;

  UpdateStatus(rsSourcesListSaved);
end;

procedure TMainForm.HandleSearchCompleted(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>;
  const aError: string);
begin
  if GetCurrentThreadId <> MainThreadID then
  begin
    QueueToMain(procedure
      var
        lForm: TMainForm;
      begin
        lForm := AppMainForm;
        if not Assigned(lForm) then
        begin
          Exit;
        end;

        lForm.HandleSearchCompleted(aGenerationId, aResults, aError);
      end);
    Exit;
  end;

  if not Assigned(fSearchController) then
  begin
    Exit;
  end;
  if aGenerationId <> fSearchController.CurrentGeneration then
  begin
    Exit;
  end;

  if aError <> '' then
  begin
    if not fScanInProgress then
    begin
      ScanAnimation.Animation.Loop := False;
      ScanAnimation.Animation.Enabled := False;
      ScanAnimation.Visible := False;
    end;
    UpdateStatus('Search failed: ' + aError);
    Exit;
  end;

  ApplySearchResults(aResults);
end;

procedure TMainForm.HandleSearchEditChange(Sender: TObject);
begin
  if SearchAsYouTypeCheckBox.Checked then
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

procedure TMainForm.HandleSearchHistoryButtonClick(Sender: TObject);
var
  lPoint: TPoint;
begin
  if SearchHistoryPopupMenu.Items.Count = 0 then
  begin
    UpdateStatus('No recent queries yet.');
    Exit;
  end;

  lPoint := SearchHistoryButton.ClientToScreen(Point(0, SearchHistoryButton.Height));
  SearchHistoryPopupMenu.Popup(lPoint.X, lPoint.Y);
end;

procedure TMainForm.HandleSearchHistoryItemClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then
  begin
    Exit;
  end;

  SelectHistoryQuery(TMenuItem(Sender).Caption);
end;

procedure TMainForm.HandleResultsColumnClick(Sender: TObject; Column: TListColumn);
begin
  case Column.Index of
    0:
      begin
        if fCurrentSortMode = TSearchSortMode.ssmNameAsc then
        begin
          SetSortMode(TSearchSortMode.ssmNameDesc);
        end else begin
          SetSortMode(TSearchSortMode.ssmNameAsc);
        end;
      end;
    1:
      begin
        SetSortMode(TSearchSortMode.ssmScore);
      end;
    3:
      begin
        if fCurrentSortMode = TSearchSortMode.ssmPathAsc then
        begin
          SetSortMode(TSearchSortMode.ssmPathDesc);
        end else begin
          SetSortMode(TSearchSortMode.ssmPathAsc);
        end;
      end;
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
    if Assigned(ResultsListView.Selected) then
    begin
      ResultsPopupMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
      Key := 0;
    end;
  end;
end;

procedure TMainForm.HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('L')) and (ssCtrl in Shift) then
  begin
    SearchEdit.SetFocus;
    SearchEdit.SelectAll;
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

procedure TMainForm.HandleRelatedListBoxClick(Sender: TObject);
var
  lNavigation: TRelatedSkillNavigation;
  lRelatedItem: TRelatedSkillResult;
begin
  if not TryGetSelectedRelatedSkill(RelatedListBox, fRelatedItems, lRelatedItem) then
  begin
    Exit;
  end;

  lNavigation := ResolveRelatedSkillNavigation(lRelatedItem, fResults);
  case lNavigation.Action of
    TRelatedSkillAction.rsaSelectResult:
      begin
        ResultsListView.Items[lNavigation.ResultIndex].Selected := True;
        ResultsListView.Items[lNavigation.ResultIndex].Focused := True;
        RenderPreview(fResults[lNavigation.ResultIndex]);
      end;
    TRelatedSkillAction.rsaOpenFile:
      begin
        ShellExecute(Handle, 'open', PChar(lNavigation.SkillFile), nil, nil, SW_SHOWNORMAL);
      end;
  end;
end;

procedure TMainForm.HandleCopyPathClick(Sender: TObject);
begin
  CopySelectedPathToClipboard;
end;

procedure TMainForm.HandleSortButtonClick(Sender: TObject);
var
  lPoint: TPoint;
begin
  lPoint := SortButton.ClientToScreen(Point(0, SortButton.Height));
  SortPopupMenu.Popup(lPoint.X, lPoint.Y);
end;

procedure TMainForm.HandleSortMenuItemClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then
  begin
    Exit;
  end;

  SetSortMode(TSearchSortMode(TMenuItem(Sender).Tag));
end;

procedure TMainForm.HandleTagListBoxClick(Sender: TObject);
var
  lTag: string;
  lText: string;
  lParenPos: Integer;
begin
  if TagListBox.ItemIndex < 0 then
  begin
    Exit;
  end;

  lText := TagListBox.Items[TagListBox.ItemIndex];
  lParenPos := LastDelimiter('(', lText);
  if lParenPos > 1 then
  begin
    lTag := Trim(Copy(lText, 1, lParenPos - 1));
  end else begin
    lTag := Trim(lText);
  end;

  if lTag = '' then
  begin
    Exit;
  end;

  SearchEdit.Text := AppendTagFilterQuery(SearchEdit.Text, lTag);
  QueueSearch(True);
end;

procedure TMainForm.HandleTagFilterEditChange(Sender: TObject);
begin
  Inc(fTagFilterGeneration);
  fTagFilterTimer.Enabled := False;
  fTagFilterTimer.Enabled := True;
end;

procedure TMainForm.HandleTagFilterTimer(Sender: TObject);
var
  lFilter: string;
  lGeneration: Integer;
  lItems: TArray<TSkillTagInfo>;
begin
  fTagFilterTimer.Enabled := False;
  lFilter := Trim(TagFilterEdit.Text);
  lGeneration := fTagFilterGeneration;
  lItems := Copy(fTagBrowserItems);

  TThread.CreateAnonymousThread(
    procedure
    var
      lFilterEx: TFilterEx;
      lItem: TSkillTagInfo;
      lResult: TStringList;
    begin
      lResult := TStringList.Create;
      try
        if lFilter <> '' then
          lFilterEx := TFilterEx.Create(lFilter);
        for lItem in lItems do
        begin
          if (lFilter = '') or lFilterEx.Matches(lItem.Name) then
            lResult.Add(Format('%s (%d)', [lItem.Name, lItem.SkillCount]));
        end;
        QueueToMain(procedure
          begin
            try
              if lGeneration = fTagFilterGeneration then
              begin
                TagListBox.Items.BeginUpdate;
                try
                  TagListBox.Items.Assign(lResult);
                finally
                  TagListBox.Items.EndUpdate;
                end;
              end;
            finally
              lResult.Free;
            end;
          end);
        lResult := nil;
      finally
        lResult.Free;
      end;
    end).Start;
end;

procedure TMainForm.HandleTagToggleButtonClick(Sender: TObject);
begin
  TagBrowserPanel.Visible := not TagBrowserPanel.Visible;
  UpdateTagBrowserUi;
end;

procedure TMainForm.HandleTrayShowClick(Sender: TObject);
begin
  RestoreFromTray;
end;

procedure TMainForm.HandleTrayExitClick(Sender: TObject);
begin
  fTrayState := ApplyTrayExitRequest(fTrayState);
  Close;
end;

procedure TMainForm.HandleTrayHotkeyMessage(var Msg: TMessage);
begin
  if Msg.WParam <> cTrayHotkeyId then
  begin
    Exit;
  end;

  RestoreFromTray;
end;

procedure TMainForm.HandleTrayIconMessage(var Msg: TMessage);
var
  lAction: TTrayMessageAction;
begin
  lAction := ResolveTrayMessageAction(Msg.LParam);
  case lAction of
    TTrayMessageAction.tmaRestore:
      begin
        RestoreFromTray;
      end;
    TTrayMessageAction.tmaShowMenu:
      begin
        PopupTrayMenu;
      end;
  end;
end;

procedure TMainForm.HandleHasScriptsClick(Sender: TObject);
begin
  QueueSearch(False);
end;

procedure TMainForm.UpdateTagBrowserUi;
begin
  TagBrowserSplitter.Visible := TagBrowserPanel.Visible;
  if TagBrowserPanel.Visible then
  begin
    TagToggleButton.Caption := 'Hide Tags';
  end else begin
    TagToggleButton.Caption := 'Show Tags';
  end;
end;

procedure TMainForm.HandleTraySettingsClick(Sender: TObject);
var
  lDlg: TConfigDlg;
begin
  lDlg := TConfigDlg.Create(Self);
  try
    lDlg.CloseToTray := fAppSettings.Ui.CloseToTray;
    if lDlg.ShowModal = mrOK then
    begin
      fAppSettings.Ui.CloseToTray := lDlg.CloseToTray;
      SaveUiSettings(fSettingsPath, fAppSettings.Ui);
    end;
  finally
    lDlg.Free;
  end;
end;

end.
