unit MainForm;

interface

uses
  System.Classes, System.Types, Winapi.Messages, Winapi.ShellAPI, Vcl.Buttons, Vcl.ComCtrls, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.Forms, Vcl.Menus, Vcl.Skia, Vcl.StdCtrls, Vcl.VirtualImageList,
  VCL.TMSFNCWebBrowser,
  AdvTypes,
  AppUpdateActions, DatabaseManager, DockerHealthMonitor, DockerOps, DockerStatusUi, ExternalTools,
  MaxLogic.GitHubReleaseChecker, PipelineCoordinator, RelatedSkillActions, ScanActivityUi, ScanProgressBuffer,
  SearchController, SearchInteraction, SearchResultActions, SettingsModel, SkillSearchService,
  TrayActions, VCL.TMSFNCCustomControl, VCL.TMSFNCGraphics, VCL.TMSFNCGraphicsTypes, VCL.TMSFNCTypes,
  VCL.TMSFNCUtils, System.Skia, Vcl.BaseImageCollection, System.ImageList,
  Vcl.ImgList;

type
  TScanCompletionSnapshot = record
    CompletedAt: TDateTime;
    ErrorText: string;
    SkillsUniqueCount: Integer;
    SkillsValidCount: Integer;
    TagBrowserItems: TArray<TSkillTagInfo>;
  end;

  TAppMainForm = class(TForm)
    SearchPanel: TPanel;
    SearchActionsPanel: TPanel;
    SearchFieldPanel: TPanel;
    SearchEdit: TEdit;
    SearchHistoryButton: TSpeedButton;
    SearchHelpButton: TSpeedButton;
    SearchButton: TBitBtn;
    ScanButton: TBitBtn;
    ScanProgressBar: TProgressBar;
    DiagnosticsButton: TSpeedButton;
    DockerGpuButton: TBitBtn;
    DockerAlertPanel: TPanel;
    DockerAlertIconText: TStaticText;
    DockerAlertText: TStaticText;
    HasScriptsCheckBox: TCheckBox;
    SortButton: TSpeedButton;
    TagToggleButton: TSpeedButton;
    SettingsButton: TSpeedButton;
    ScanAnimation: TSkAnimatedImage;
    ActivityPanel: TPanel;
    ActivityText: TStaticText;
    ScanActivityTimer: TTimer;
    MainPanel: TPanel;
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
    ButtonImages: TVirtualImageList;
    ButtonSvgCollection: TAdvSVGImageCollection;
    ResultsPopupMenu: TPopupMenu;
    SortPopupMenu: TPopupMenu;
    SearchHistoryPopupMenu: TPopupMenu;
    HintBalloon: TBalloonHint;
    ExportResultsMenuItem: TMenuItem;
    OpenFileMenuItem: TMenuItem;
    OpenFolderMenuItem: TMenuItem;
    CopyPathMenuItem: TMenuItem;
    pnlScanningRight: TPanel;
    SearchEditLabel: TStaticText;
    procedure FormCreate(Sender: TObject);
    procedure HandleFormShow(Sender: TObject);
    procedure PreviewBrowserInitialized(Sender: TObject);
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
    fScanProgress: TPipelineProgress;
    fScanStartedAt: TDateTime;
    fScanThread: TThread;
    fDockerHealthMonitor: TDockerHealthMonitor;
    fDockerHealthDetail: string;
    fDockerHealthState: TDockerHealthState;
    fDockerStartFailureMessage: string;
    fDockerStartInProgress: Boolean;
    fDockerStartHourGlass: IInterface;
    fCurrentSortMode: TSearchSortMode;
    fPendingPreviewHtml: string;
    fPreviewBrowserReady: Boolean;
    fScanProgressBuffer: TScanProgressBuffer;
    fSearchHistory: TSearchHistorySettings;
    fSearchController: TSearchController;
    fSearchService: TSkillSearchService;
    fSelectedTags: TStringList;
    fSettingsPath: string;
    fSkillsFoundCount: Integer;
    fRelatedItems: TArray<TRelatedSkillResult>;
    fTagBrowserItems: TArray<TSkillTagInfo>;
    fSkillsUniqueCount: Integer;
    fSkillsValidCount: Integer;
    fSourcesListPath: string;
    fStartupChecksStarted: Boolean;
    fUpdateCheckThread: TThread;
    procedure ApplySearchResults(const aResults: TArray<TSkillSearchResult>);
    procedure ApplyPendingScanProgress;
    function BuildPipelineOptions: TPipelineOptions;
    procedure BeginScanProgress;
    procedure BeginDockerStart;
    procedure ConfigureBalloonHints;
    procedure EndDockerStart;
    procedure HandleDockerHealthPolled(const aState: TDockerHealthState; const aDetail: string);
    procedure HandleDockerStartCompleted(const aResult: TDockerCommandResult);
    procedure EndScanProgress;
    procedure HideActivityUi;
    procedure HandlePendingScanProgress(const aProgress: TPipelineProgress);
    procedure RefreshScanActivityUi;
    procedure StartDockerStackAsync;
    procedure StartUpdateCheckAsync;
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
    procedure LoadPreviewHtml(const aHtml: string);
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
    procedure ShowUpdateAvailableDialog(const aCheckResult: TGitHubReleaseCheckResult);
    procedure ShowTrayIcon;
    function TryLoadSourceRoots(out aSourceRoots: TArray<string>): Boolean;
    procedure UnregisterTrayHotkey;
    procedure UpdateActivityUi(const aText: string; const aShowProgressBar: Boolean);
    procedure UpdateDockerStatusUi;
    procedure UpdateStatus(const aText: string);
    procedure UpdateTagFilterUi;
    procedure UpdateSortUi;
    procedure UpdateSearchHistoryMenu;
    procedure WaitForWorkerThread(var aThread: TThread);
    procedure HandleUpdateCheckCompleted(const aResult: TGitHubReleaseCheckResult);
    procedure HandleTrayHotkeyMessage(var Msg: TMessage); message WM_HOTKEY;
    procedure HandleTrayIconMessage(var Msg: TMessage); message WM_APP + 42;
  published
    procedure HandleCopyPathClick(Sender: TObject);
    procedure HandleDiagnosticsButtonClick(Sender: TObject);
    procedure HandleDockerGpuButtonClick(Sender: TObject);
    procedure HandleExportResultsClick(Sender: TObject);
    procedure HandleExternalToolClick(Sender: TObject);
    procedure HandleFormClose(Sender: TObject; var Action: TCloseAction);
    procedure HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleHasScriptsClick(Sender: TObject);
    procedure HandleScanCompleted(const aExecuted: Boolean; const aResult: TPipelineRunResult; const aStatusText,
      aFailure: string; const aCompletion: TScanCompletionSnapshot);
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
    procedure HandleScanActivityTimer(Sender: TObject);
    procedure HandleSearchEditChange(Sender: TObject);
    procedure HandleSearchEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleSearchHistoryButtonClick(Sender: TObject);
    procedure HandleSearchHistoryItemClick(Sender: TObject);
    procedure HandleSearchHelpButtonClick(Sender: TObject);
    procedure HandleScanButtonClick(Sender: TObject);
    procedure HandleSortButtonClick(Sender: TObject);
    procedure HandleSortMenuItemClick(Sender: TObject);
    procedure HandleTagToggleButtonClick(Sender: TObject);
    procedure HandleTrayExitClick(Sender: TObject);
    procedure HandleTraySettingsClick(Sender: TObject);
    procedure HandleTrayShowClick(Sender: TObject);
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  AppMainForm: TAppMainForm;

implementation

uses
  System.DateUtils, System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  Vcl.Clipbrd, Vcl.Dialogs,
  MaxLogic.BalloonDefaultImageList,
  AppPaths, AutoHourGlass, ConfigDlg, DiagnosticsForm, Logging, PathExclusions, PreviewEmptyStateHtml,
  PreviewRenderer, Settings, SourcesList, TagFilterDialog, UpdateAvailableDialog,
  MaxMadExcept, MaxLogic.ioUtils;

{$R *.dfm}

procedure QueueToMain(const aProc: TThreadProcedure);
begin
  TThread.Queue(nil, aProc);
end;

const
  cStatusPanelStatus = 0;
  cStatusPanelCounters = 1;
  cStatusPanelLastScan = 2;
  cStatusPanelDocker = 3;
  cStatusPanelCache = 4;
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

function BuildScanCompletionSnapshot(const aDatabasePath, aSqliteDllPath: string): TScanCompletionSnapshot;
var
  lDatabaseManager: TDatabaseManager;
begin
  Result := Default(TScanCompletionSnapshot);
  Result.CompletedAt := Now;

  lDatabaseManager := TDatabaseManager.Create(aDatabasePath, aSqliteDllPath);
  try
    lDatabaseManager.Initialize;
    Result.SkillsValidCount := lDatabaseManager.GetValidSkillCount;
    Result.SkillsUniqueCount := lDatabaseManager.GetUniqueSkillCount;
    Result.TagBrowserItems := lDatabaseManager.GetSkillTagCounts;
  except
    on E: Exception do
    begin
      Result.ErrorText := E.Message;
    end;
  end;
  lDatabaseManager.Free;
end;

{ TAppMainForm }

constructor TAppMainForm.Create(aOwner: TComponent);
var
  i: Integer;
  lMenuItem: TMenuItem;
  lSemanticOptions: TSemanticSearchOptions;
  lSettings: TSettingsLoadResult;
begin
  inherited Create(aOwner);
  AppMainForm := Self;
  fTrayState := DefaultTrayWindowState;
  fSelectedTags := TStringList.Create;
  fSelectedTags.CaseSensitive := False;
  fSelectedTags.Duplicates := dupIgnore;
  fSelectedTags.Sorted := True;

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
  ConfigureBalloonHints;
  fScanProgressBuffer := TScanProgressBuffer.Create;
  fSearchHistory := fAppSettings.SearchHistory;
  if fSearchHistory.MaxItems <= 0 then
  begin
    fSearchHistory.MaxItems := fAppSettings.Search.RecentQueryLimit;
  end;
  UpdateSearchHistoryMenu;
  LoadUiState;
  PopulateExternalToolsMenu;
  RefreshTagBrowser;
  UpdateTagFilterUi;

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
  fPendingPreviewHtml := '';
  fPreviewBrowserReady := False;
  fScanProgress := Default(TPipelineProgress);
  fScanStartedAt := 0;
  fDockerHealthDetail := '';
  fDockerHealthState := TDockerHealthState.dhsUnknown;
  fDockerStartFailureMessage := '';
  fScanThread := nil;
  fStartupChecksStarted := False;
  fUpdateCheckThread := nil;
  HideActivityUi;
  UpdateDockerStatusUi;
  fDockerHealthMonitor := TDockerHealthMonitor.Create(
    fAppSettings.Docker.HealthCheckCommand,
    10000,
    procedure(const aState: TDockerHealthState; const aDetail: string)
    var
      lForm: TAppMainForm;
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

  ShowEmptyPreview;
  QueueSearch(True);
end;

procedure TAppMainForm.FormCreate(Sender: TObject);
begin
  // maxLogic.madExcept.SetUpWebUpload('https://maxlogic.eu/bugreport_mailer/bugreport_mailer.php', 'maxlogic');
  MaxMadExcept.AdjustMadExcept(GetInstallDir);
end;

procedure TAppMainForm.HandleFormShow(Sender: TObject);
begin
  if fStartupChecksStarted then
  begin
    Exit;
  end;

  fStartupChecksStarted := True;
  if ShouldCheckForUpdatesOnStartup(fAppSettings.Ui) then
  begin
    StartUpdateCheckAsync;
  end;
end;

destructor TAppMainForm.Destroy;
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
  WaitForWorkerThread(fUpdateCheckThread);
  fDockerHealthMonitor.Free;
  fSearchController.Free;
  fSearchService.Free;
  fScanProgressBuffer.Free;
  fSelectedTags.Free;
  fDatabaseManager.Free;
  inherited Destroy;
end;

procedure TAppMainForm.CreateWnd;
begin
  inherited CreateWnd;
  RegisterTrayHotkey;
end;

procedure TAppMainForm.DestroyWnd;
begin
  UnregisterTrayHotkey;
  inherited DestroyWnd;
end;

procedure TAppMainForm.ConfigureColumns;
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

function TAppMainForm.ScaleStoredUiValue(const aValue, aStoredPPI: Integer): Integer;
begin
  Result := SearchInteraction.ScaleStoredUiValue(aValue, aStoredPPI, CurrentPPI);
end;

procedure TAppMainForm.ConfigureBalloonHints;
begin
  HintBalloon.Images := TImageListForBalloonForm.Instance.ImageList1;
  HintBalloon.ImageIndex := 0;
  CustomHint := HintBalloon;
  ShowHint := True;
end;

procedure TAppMainForm.ApplyPendingScanProgress;
var
  lProgress: TPipelineProgress;
begin
  if not Assigned(fScanProgressBuffer) then
  begin
    Exit;
  end;

  if fScanProgressBuffer.TryConsume(lProgress) then
  begin
    HandlePendingScanProgress(lProgress);
  end;
end;

procedure TAppMainForm.UpdateActivityUi(const aText: string; const aShowProgressBar: Boolean);
begin
  ActivityText.Caption := aText;
  ActivityPanel.Visible := True;
  ScanProgressBar.Visible := aShowProgressBar;
  if aShowProgressBar then
  begin
    ScanProgressBar.Style := pbstMarquee;
    ScanProgressBar.MarqueeInterval := 30;
  end;
  ScanAnimation.Visible := True;
  ScanAnimation.Animation.Loop := True;
  ScanAnimation.Animation.Enabled := True;
  ScanAnimation.Animation.Start;
end;

procedure TAppMainForm.RefreshScanActivityUi;
var
  lSnapshot: TScanActivitySnapshot;
begin
  lSnapshot := Default(TScanActivitySnapshot);
  if fScanStartedAt > 0 then
  begin
    lSnapshot.ElapsedMs := MilliSecondsBetween(Now, fScanStartedAt);
  end else begin
    lSnapshot.ElapsedMs := fScanProgress.ElapsedMs;
  end;
  lSnapshot.ReposFailed := fScanProgress.ReposFailed;
  lSnapshot.ReposFound := fScanProgress.ReposFound;
  lSnapshot.ReposPulled := fScanProgress.ReposPulled;
  lSnapshot.ReposThrottled := fScanProgress.ReposThrottled;
  lSnapshot.SkillsFound := fScanProgress.SkillsFound;
  lSnapshot.SkillsWritten := fScanProgress.SkillsWritten;
  lSnapshot.StatusText := fScanProgress.StatusText;
  UpdateActivityUi(BuildScanActivitySummary(lSnapshot), True);
end;

procedure TAppMainForm.HandlePendingScanProgress(const aProgress: TPipelineProgress);
begin
  fScanProgress := aProgress;
  if Trim(aProgress.StatusText) <> '' then
  begin
    UpdateStatus(aProgress.StatusText);
  end;
  if fScanInProgress then
  begin
    RefreshScanActivityUi;
  end;
end;

procedure TAppMainForm.HandleScanActivityTimer(Sender: TObject);
begin
  ApplyPendingScanProgress;
  if fScanInProgress then
  begin
    RefreshScanActivityUi;
  end;
end;

procedure TAppMainForm.HideActivityUi;
begin
  ScanActivityTimer.Enabled := False;
  ScanProgressBar.Visible := False;
  ScanAnimation.Animation.Loop := False;
  ScanAnimation.Animation.Enabled := False;
  ScanAnimation.Visible := False;
  ActivityPanel.Visible := False;
end;

procedure TAppMainForm.UpdateDockerStatusUi;
var
  lDetail: string;
  lUiState: TDockerStatusUiState;
begin
  lUiState := BuildDockerStatusUiState(
    fDockerHealthState,
    fDockerHealthDetail,
    fDockerStartFailureMessage,
    fDockerStartInProgress
  );

  StatusBar.Panels[cStatusPanelDocker].Text := lUiState.StatusText;
  DockerAlertPanel.Visible := lUiState.ShowAlert;
  DockerAlertText.Caption := lUiState.AlertText;
  DockerGpuButton.Enabled := not fDockerStartInProgress;

  lDetail := Trim(fDockerStartFailureMessage);
  if lDetail = '' then
  begin
    lDetail := Trim(fDockerHealthDetail);
  end;

  DockerAlertText.Hint := lDetail;
  DockerGpuButton.Hint := 'Docker|Start the local Docker stack used by Ollama.|0';
end;

procedure TAppMainForm.CaptureWindowBounds(out aLeft, aTop, aWidth, aHeight: Integer);
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

function TAppMainForm.ClampWindowRectToWorkArea(const aBounds: TRect): TRect;
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

function TAppMainForm.SerializeColumnWidths: string;
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

function TAppMainForm.CaptureUiState: TUiStateSettings;
begin
  Result := fAppSettings.UiState;
  Result.CurrentPPI := CurrentPPI;
  Result.DuplicateInfoWidth := DuplicateInfoPanel.Height;
  Result.LastQuery := Trim(SearchEdit.Text);
  Result.ResultSortMode := SearchSortModeToString(fCurrentSortMode);
  Result.ResultsColumnWidths := SerializeColumnWidths;
  Result.ResultsPaneWidth := PreviewHostPanel.Width;
  Result.SearchAsYouType := fAppSettings.Ui.SearchAsYouType;
  CaptureWindowBounds(Result.WindowLeft, Result.WindowTop, Result.WindowWidth, Result.WindowHeight);
end;

procedure TAppMainForm.LoadUiState;
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

function TAppMainForm.EscapeHtml(const aText: string): string;
begin
  Result := StringReplace(aText, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

procedure TAppMainForm.ShowEmptyPreview;
begin
  LoadPreviewHtml(GetPreviewEmptyStateHtml);
  DuplicateInfoMemo.Clear;
  DuplicateInfoPanel.Visible := False;
  fRelatedItems := nil;
  PopulateRelatedSkillsListBox(RelatedListBox, fRelatedItems);
  RelatedPanel.Visible := False;
end;

procedure TAppMainForm.LoadPreviewHtml(const aHtml: string);
begin
  fPendingPreviewHtml := aHtml;
  if fPreviewBrowserReady and Assigned(PreviewBrowser) then
  begin
    PreviewBrowser.LoadHTML(fPendingPreviewHtml);
  end;
end;

procedure TAppMainForm.RenderPreview(const aResult: TSkillSearchResult);
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

  LoadPreviewHtml(lHtml);
  DuplicateInfoPanel.Visible := ShouldShowDuplicateDetails(aResult.DuplicateCount);
  if DuplicateInfoPanel.Visible then
  begin
    lDuplicateText := Format('Duplicate skills detected: %d', [aResult.DuplicateCount]) + sLineBreak +
      'Canonical:' + sLineBreak + aResult.SkillFile + sLineBreak + sLineBreak +
      'Other locations:' + sLineBreak + aResult.DuplicatePaths;
    DuplicateInfoMemo.Lines.Text := lDuplicateText;
  end else begin
    DuplicateInfoMemo.Clear;
  end;
  RefreshRelatedSkills(aResult.SkillFile);
end;

function TAppMainForm.GetSelectedSkillFile: string;
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

function TAppMainForm.GetSelectedSkillRoot: string;
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

procedure TAppMainForm.ShowTrayIcon;
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

procedure TAppMainForm.RemoveTrayIcon;
begin
  if not fTrayState.TrayIconVisible then
  begin
    Exit;
  end;

  Shell_NotifyIcon(NIM_DELETE, @fTrayIconData);
  fTrayState.TrayIconVisible := False;
end;

procedure TAppMainForm.HideToTray;
begin
  ShowTrayIcon;
  if not fTrayState.TrayIconVisible then
  begin
    Exit;
  end;

  ShowWindow(Handle, SW_HIDE);
  fTrayState := ApplyHideToTray(fTrayState);
end;

procedure TAppMainForm.RestoreFromTray;
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

procedure TAppMainForm.PopupTrayMenu;
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

procedure TAppMainForm.UnregisterTrayHotkey;
begin
  if not fTrayHotkeyRegistered then
  begin
    Exit;
  end;

  UnregisterHotKey(Handle, cTrayHotkeyId);
  fTrayHotkeyRegistered := False;
end;

procedure TAppMainForm.RegisterTrayHotkey;
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

function TAppMainForm.IsResultSelectionValid: Boolean;
begin
  Result := Assigned(ResultsListView.Selected) and
    (ResultsListView.Selected.Index >= 0) and
    (ResultsListView.Selected.Index < Length(fResults));
end;

procedure TAppMainForm.UpdateStatus(const aText: string);
begin
  StatusBar.Panels[cStatusPanelStatus].Text := aText;
end;

procedure TAppMainForm.BuildSortMenu;
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

procedure TAppMainForm.UpdateSortUi;
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
  SortButton.Hint := Format('Sort results|Current sort: %s. Click to choose another sort order.|0',
    [cSortLabels[fCurrentSortMode]]);
  for i := 0 to Pred(SortPopupMenu.Items.Count) do
  begin
    SortPopupMenu.Items[i].Checked := SortPopupMenu.Items[i].Tag = Ord(fCurrentSortMode);
  end;
end;

procedure TAppMainForm.SetSortMode(const aSortMode: TSearchSortMode; const aResortResults: Boolean);
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

procedure TAppMainForm.ExportResultsAsMarkdown;
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

procedure TAppMainForm.PopulateExternalToolsMenu;
begin
  PopulateExternalToolsPopupMenu(ResultsPopupMenu, fAppSettings.ExternalTools, HandleExternalToolClick, 1);
end;

procedure TAppMainForm.DispatchSearchQuery(const aQuery: string; const aImmediate: Boolean);
begin
  if aImmediate then
  begin
    fSearchController.QueueSearch(aQuery, 0);
  end else begin
    fSearchController.QueueSearch(aQuery);
  end;
  UpdateStatus('Searching...');
end;

procedure TAppMainForm.SaveRuntimeState;
begin
  fAppSettings.UiState := CaptureUiState;
  SaveUiState(fSettingsPath, fAppSettings.UiState);
  SaveSearchHistory(fSettingsPath, fSearchHistory);
end;

procedure TAppMainForm.UpdateSearchHistoryMenu;
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

procedure TAppMainForm.SelectHistoryQuery(const aQuery: string);
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

procedure TAppMainForm.RenderResultsList(const aPreferredSkillFile: string);
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

procedure TAppMainForm.RefreshCountPanels;
begin
  StatusBar.Panels[cStatusPanelCounters].Text := Format(
    'Found: %d | Valid: %d | Unique: %d | Results: %d',
    [fSkillsFoundCount, fSkillsValidCount, fSkillsUniqueCount, Length(fResults)]);
end;

procedure TAppMainForm.RefreshInventoryCounters;
begin
  fSkillsValidCount := fDatabaseManager.GetValidSkillCount;
  fSkillsUniqueCount := fDatabaseManager.GetUniqueSkillCount;
end;

procedure TAppMainForm.RefreshRelatedSkills(const aSkillFile: string);
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

procedure TAppMainForm.RefreshTagBrowser;
begin
  fTagBrowserItems := fDatabaseManager.GetSkillTagCounts;
end;

function TAppMainForm.BuildEffectiveQuery: string;
var
  lSelectedTagsQuery: string;
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

  lSelectedTagsQuery := BuildSelectedTagsQuery(fSelectedTags.ToStringArray);
  if lSelectedTagsQuery <> '' then
  begin
    if Result <> '' then
    begin
      Result := Result + ' ';
    end;
    Result := Result + lSelectedTagsQuery;
  end;
end;

function TAppMainForm.BuildPipelineOptions: TPipelineOptions;
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
    var
      lForm: TAppMainForm;
    begin
      lForm := AppMainForm;
      if not Assigned(lForm) or (Trim(aStatusText) = '') then
      begin
        Exit;
      end;

      lForm.fScanProgressBuffer.PublishStatus(aStatusText);
    end;
  Result.OnProgress :=
    procedure(const aProgress: TPipelineProgress)
    var
      lForm: TAppMainForm;
    begin
      lForm := AppMainForm;
      if not Assigned(lForm) then
      begin
        Exit;
      end;

      lForm.fScanProgressBuffer.Publish(aProgress);
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

function TAppMainForm.TryLoadSourceRoots(out aSourceRoots: TArray<string>): Boolean;
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

procedure TAppMainForm.WaitForWorkerThread(var aThread: TThread);
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

procedure TAppMainForm.BeginScanProgress;
begin
  fScanInProgress := True;
  fScanProgress := Default(TPipelineProgress);
  fScanProgress.StatusText := 'Scanning source folders...';
  fScanStartedAt := Now;
  fScanHourGlass := AutoHourGlass.MakeCHG;
  ScanButton.Enabled := False;
  ScanActivityTimer.Enabled := True;
  RefreshScanActivityUi;
  UpdateStatus('Scan running... (indeterminate)');
end;

procedure TAppMainForm.BeginDockerStart;
begin
  fDockerStartInProgress := True;
  fDockerStartFailureMessage := '';
  fDockerStartHourGlass := AutoHourGlass.MakeCHG;
  UpdateDockerStatusUi;
  UpdateStatus('Starting Ollama container...');
end;

procedure TAppMainForm.EndDockerStart;
begin
  fDockerStartHourGlass := nil;
  fDockerStartInProgress := False;
end;

procedure TAppMainForm.StartDockerStackAsync;
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
          lForm: TAppMainForm;
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

procedure TAppMainForm.StartUpdateCheckAsync;
var
  lCurrentVersion: string;
begin
  if Assigned(fUpdateCheckThread) then
  begin
    Exit;
  end;

  lCurrentVersion := GetBuildInfo;
  if Trim(lCurrentVersion) = '' then
  begin
    LogInfo('Startup update check skipped because the current version is unavailable.');
    Exit;
  end;

  LogInfo('Startup update check started. CurrentVersion=' + lCurrentVersion);
  fUpdateCheckThread := TThread.CreateAnonymousThread(
    procedure
    var
      lChecker: TMaxGitHubReleaseChecker;
      lResult: TGitHubReleaseCheckResult;
    begin
      lChecker := TMaxGitHubReleaseChecker.Create(cUpdateRepoOwner, cUpdateRepoName);
      try
        lResult := lChecker.CheckLatestRelease(lCurrentVersion);
      finally
        lChecker.Free;
      end;

      QueueToMain(
        procedure
        var
          lForm: TAppMainForm;
        begin
          lForm := AppMainForm;
          if not Assigned(lForm) then
          begin
            Exit;
          end;

          lForm.HandleUpdateCheckCompleted(lResult);
        end
      );
    end
  );
  fUpdateCheckThread.FreeOnTerminate := False;
  fUpdateCheckThread.Start;
end;

procedure TAppMainForm.EndScanProgress;
begin
  fScanHourGlass := nil;
  ScanButton.Enabled := True;
  fScanInProgress := False;
  fScanStartedAt := 0;
  HideActivityUi;

  if Assigned(fScanCancelToken) then
  begin
    fScanCancelToken.Free;
    fScanCancelToken := nil;
  end;
end;

procedure TAppMainForm.HandleDockerHealthPolled(const aState: TDockerHealthState; const aDetail: string);
begin
  fDockerHealthDetail := aDetail;
  if aState <> fDockerHealthState then
  begin
    fDockerHealthState := aState;
    case aState of
      TDockerHealthState.dhsHealthy:
        begin
          RecordPipelineNotice('Ollama health: healthy');
          fDockerStartFailureMessage := '';
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
  UpdateDockerStatusUi;
end;

procedure TAppMainForm.HandleUpdateCheckCompleted(const aResult: TGitHubReleaseCheckResult);
begin
  WaitForWorkerThread(fUpdateCheckThread);

  case aResult.Status of
    TGitHubReleaseCheckStatus.gcsSuccess:
      begin
        LogInfo('Startup update check finished. Latest=' + aResult.LatestRelease.TagName);
      end;
    TGitHubReleaseCheckStatus.gcsNoRelease:
      begin
        LogInfo('Startup update check finished. No published release found.');
        Exit;
      end;
    TGitHubReleaseCheckStatus.gcsHttpError,
    TGitHubReleaseCheckStatus.gcsInvalidResponse,
    TGitHubReleaseCheckStatus.gcsRequestFailed:
      begin
        LogInfo('Startup update check failed: ' + aResult.ErrorMessage);
        Exit;
      end;
  end;

  if ShouldPromptForAppUpdate(aResult) then
  begin
    ShowUpdateAvailableDialog(aResult);
  end;
end;

procedure TAppMainForm.HandleDockerStartCompleted(const aResult: TDockerCommandResult);
var
  lMessage: string;
begin
  try
    if aResult.Success then
    begin
      fDockerStartFailureMessage := '';
      fDockerHealthState := TDockerHealthState.dhsUnknown;
      fDockerHealthDetail := '';
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
    fDockerStartFailureMessage := 'Docker or Ollama is not running. Start the local stack now.';
    RecordPipelineError(lMessage);
    UpdateStatus(lMessage);
  finally
    EndDockerStart;
    UpdateDockerStatusUi;
    WaitForWorkerThread(fDockerStartThread);
  end;
end;

procedure TAppMainForm.QueueSearch(const aImmediate: Boolean);
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

procedure TAppMainForm.ApplySearchResults(const aResults: TArray<TSkillSearchResult>);
begin
  fResults := aResults;
  SortSearchResults(fResults, fCurrentSortMode);
  RenderResultsList('');

  RefreshCountPanels;
  UpdateStatus(Format('Results: %d | Query: %s', [Length(fResults), BuildEffectiveQuery]));
end;

procedure TAppMainForm.OpenSelectedSkillFile;
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

procedure TAppMainForm.OpenSelectedSkillFolder;
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

procedure TAppMainForm.CopySelectedPathToClipboard;
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

procedure TAppMainForm.HandleSearchButtonClick(Sender: TObject);
begin
  QueueSearch(True);
end;

procedure TAppMainForm.HandleSearchHelpButtonClick(Sender: TObject);
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

procedure TAppMainForm.HandleScanCompleted(const aExecuted: Boolean; const aResult: TPipelineRunResult;
  const aStatusText, aFailure: string; const aCompletion: TScanCompletionSnapshot);
var
  lCompletedAt: TDateTime;
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
    if aCompletion.ErrorText = '' then
    begin
      fSkillsValidCount := aCompletion.SkillsValidCount;
      fSkillsUniqueCount := aCompletion.SkillsUniqueCount;
      fTagBrowserItems := aCompletion.TagBrowserItems;
    end else begin
      RecordPipelineError('Post-scan refresh failed: ' + aCompletion.ErrorText);
    end;
    RefreshCountPanels;
    lCompletedAt := aCompletion.CompletedAt;
    if lCompletedAt <= 0 then
    begin
      lCompletedAt := Now;
    end;
    StatusBar.Panels[cStatusPanelLastScan].Text := 'Last scan: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', lCompletedAt);
    QueueSearch(True);
  finally
    EndScanProgress;
    WaitForWorkerThread(fScanThread);
  end;
end;

procedure TAppMainForm.HandleScanButtonClick(Sender: TObject);
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
      lCompletion: TScanCompletionSnapshot;
      lResult: TPipelineRunResult;
      lStatusText: string;
      lExecuted: Boolean;
      lFailure: string;
    begin
      lExecuted := False;
      lFailure := '';
      lCompletion := Default(TScanCompletionSnapshot);
      try
        lExecuted := ExecuteScanUpdate(lDatabasePath, lSqliteDllPath, lOptions, lSourceRoots, fScanCancelToken,
          lResult, lStatusText);
        if lExecuted then
        begin
          lCompletion := BuildScanCompletionSnapshot(lDatabasePath, lSqliteDllPath);
        end;
      except
        on E: Exception do
        begin
          lFailure := E.Message;
        end;
      end;

      QueueToMain(procedure
        var
          lForm: TAppMainForm;
        begin
          lForm := AppMainForm;
          if not Assigned(lForm) then
          begin
            Exit;
          end;

          lForm.HandleScanCompleted(lExecuted, lResult, lStatusText, lFailure, lCompletion);
        end);
    end
  );
  fScanThread.FreeOnTerminate := False;
  fScanThread.Start;
end;

procedure TAppMainForm.HandleDiagnosticsButtonClick(Sender: TObject);
begin
  ShowDiagnosticsDialog(self);
end;

procedure TAppMainForm.HandleExportResultsClick(Sender: TObject);
begin
  ExportResultsAsMarkdown;
end;

procedure TAppMainForm.HandleExternalToolClick(Sender: TObject);
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

procedure TAppMainForm.HandleFormClose(Sender: TObject; var Action: TCloseAction);
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

procedure TAppMainForm.HandleDockerGpuButtonClick(Sender: TObject);
begin
  StartDockerStackAsync;
end;

procedure TAppMainForm.HandleSearchCompleted(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>;
  const aError: string);
begin
  if GetCurrentThreadId <> MainThreadID then
  begin
    QueueToMain(procedure
      var
        lForm: TAppMainForm;
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
    UpdateStatus('Search failed: ' + aError);
    Exit;
  end;

  ApplySearchResults(aResults);
end;

procedure TAppMainForm.HandleSearchEditChange(Sender: TObject);
begin
  if fAppSettings.Ui.SearchAsYouType then
  begin
    QueueSearch(False);
  end;
end;

procedure TAppMainForm.HandleSearchEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    QueueSearch(True);
    Key := 0;
  end;
end;

procedure TAppMainForm.HandleSearchHistoryButtonClick(Sender: TObject);
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

procedure TAppMainForm.HandleSearchHistoryItemClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then
  begin
    Exit;
  end;

  SelectHistoryQuery(TMenuItem(Sender).Caption);
end;

procedure TAppMainForm.HandleResultsColumnClick(Sender: TObject; Column: TListColumn);
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

procedure TAppMainForm.HandleResultSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
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

procedure TAppMainForm.HandleResultDoubleClick(Sender: TObject);
begin
  OpenSelectedSkillFile;
end;

procedure TAppMainForm.HandleResultKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
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

procedure TAppMainForm.HandleFormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  lFocusTarget: TMainFormFocusTarget;
begin
  if TryResolveMainFormFocusShortcut(Key, Shift, lFocusTarget) then
  begin
    case lFocusTarget of
      TMainFormFocusTarget.mfftSearch:
        begin
          SearchEdit.SetFocus;
          SearchEdit.SelectAll;
        end;
      TMainFormFocusTarget.mfftResults:
        begin
          if (ResultsListView.Items.Count > 0) and (not Assigned(ResultsListView.Selected)) then
          begin
            ResultsListView.Items[0].Selected := True;
            ResultsListView.Items[0].Focused := True;
          end;
          ResultsListView.SetFocus;
        end;
    end;
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

procedure TAppMainForm.HandleOpenFileClick(Sender: TObject);
begin
  OpenSelectedSkillFile;
end;

procedure TAppMainForm.HandleOpenFolderClick(Sender: TObject);
begin
  OpenSelectedSkillFolder;
end;

procedure TAppMainForm.HandleRelatedListBoxClick(Sender: TObject);
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

procedure TAppMainForm.HandleCopyPathClick(Sender: TObject);
begin
  CopySelectedPathToClipboard;
end;

procedure TAppMainForm.HandleSortButtonClick(Sender: TObject);
var
  lPoint: TPoint;
begin
  lPoint := SortButton.ClientToScreen(Point(0, SortButton.Height));
  SortPopupMenu.Popup(lPoint.X, lPoint.Y);
end;

procedure TAppMainForm.HandleSortMenuItemClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then
  begin
    Exit;
  end;

  SetSortMode(TSearchSortMode(TMenuItem(Sender).Tag));
end;

procedure TAppMainForm.HandleTagToggleButtonClick(Sender: TObject);
var
  lTag: string;
  lSelectedTags: TArray<string>;
begin
  if not TTagFilterDialog.SelectTags(Self, fTagBrowserItems, fSelectedTags.ToStringArray, lSelectedTags) then
  begin
    Exit;
  end;

  fSelectedTags.Clear;
  for lTag in lSelectedTags do
  begin
    fSelectedTags.Add(lTag);
  end;
  UpdateTagFilterUi;
  QueueSearch(True);
end;

procedure TAppMainForm.HandleTrayShowClick(Sender: TObject);
begin
  RestoreFromTray;
end;

procedure TAppMainForm.HandleTrayExitClick(Sender: TObject);
begin
  fTrayState := ApplyTrayExitRequest(fTrayState);
  Close;
end;

procedure TAppMainForm.HandleTrayHotkeyMessage(var Msg: TMessage);
begin
  if Msg.WParam <> cTrayHotkeyId then
  begin
    Exit;
  end;

  RestoreFromTray;
end;

procedure TAppMainForm.HandleTrayIconMessage(var Msg: TMessage);
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

procedure TAppMainForm.HandleHasScriptsClick(Sender: TObject);
begin
  QueueSearch(False);
end;

procedure TAppMainForm.UpdateTagFilterUi;
begin
  TagToggleButton.Hint := Format('Tags|Choose one or more tags to apply. Active tags: %d.|0',
    [fSelectedTags.Count]);
end;

procedure TAppMainForm.HandleTraySettingsClick(Sender: TObject);
var
  lDlg: TConfigDlg;
  lQueueSearch: Boolean;
begin
  lDlg := TConfigDlg.Create(Self);
  try
    lDlg.CheckForUpdatesOnStartup := fAppSettings.Ui.CheckForUpdatesOnStartup;
    lDlg.CloseToTray := fAppSettings.Ui.CloseToTray;
    lDlg.SearchAsYouType := fAppSettings.Ui.SearchAsYouType;
    lDlg.SourcesListPath := fSourcesListPath;
    if lDlg.ShowModal = mrOK then
    begin
      lQueueSearch := (not fAppSettings.Ui.SearchAsYouType) and lDlg.SearchAsYouType;
      fAppSettings.Ui.CheckForUpdatesOnStartup := lDlg.CheckForUpdatesOnStartup;
      fAppSettings.Ui.CloseToTray := lDlg.CloseToTray;
      fAppSettings.Ui.SearchAsYouType := lDlg.SearchAsYouType;
      SaveUiSettings(fSettingsPath, fAppSettings.Ui);
      fAppSettings.UiState := CaptureUiState;
      SaveUiState(fSettingsPath, fAppSettings.UiState);
      if lQueueSearch then
      begin
        QueueSearch(False);
      end;
    end;
    if lDlg.SourcesEdited then
    begin
      UpdateStatus(rsSourcesListSaved);
    end;
  finally
    lDlg.Free;
  end;
end;

procedure TAppMainForm.ShowUpdateAvailableDialog(const aCheckResult: TGitHubReleaseCheckResult);
var
  lPrompt: TUpdatePromptInfo;
begin
  lPrompt := BuildUpdatePromptInfo(aCheckResult.CurrentVersion, aCheckResult.LatestRelease);
  if not TUpdateAvailableDialog.Execute(Self, lPrompt) then
  begin
    Exit;
  end;

  if ShellExecute(Handle, 'open', PChar(lPrompt.ReleaseUrl), nil, nil, SW_SHOWNORMAL) <= 32 then
  begin
    MessageDlg('I could not open the release page automatically. Please open it from GitHub manually.', mtWarning,
      [mbOK], 0);
  end;
end;

procedure TAppMainForm.PreviewBrowserInitialized(Sender: TObject);
begin
  fPreviewBrowserReady := True;
  if Trim(fPendingPreviewHtml) <> '' then
  begin
    PreviewBrowser.LoadHTML(fPendingPreviewHtml);
  end else begin
    ShowEmptyPreview;
  end;
end;

end.
