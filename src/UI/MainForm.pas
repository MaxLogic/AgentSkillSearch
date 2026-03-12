unit MainForm;

interface

uses
  System.Classes, System.Types, Vcl.ComCtrls, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.Menus, Vcl.StdCtrls,
  VCL.TMSFNCWebBrowser,
  DatabaseManager, DockerHealthMonitor, DockerOps, ExternalTools, PipelineCoordinator, SearchController, SearchInteraction,
  SearchResultActions, SettingsModel, SkillSearchService;

type
  TMainForm = class(TForm)
  published
    fSearchPanel: TPanel;
    fSearchActionsPanel: TPanel;
    fSearchFieldPanel: TPanel;
    fSearchEdit: TEdit;
    fSearchHistoryButton: TButton;
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
    fSortButton: TButton;
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
    fSortPopupMenu: TPopupMenu;
    fSearchHistoryPopupMenu: TPopupMenu;
    fExportResultsMenuItem: TMenuItem;
    fOpenFileMenuItem: TMenuItem;
    fOpenFolderMenuItem: TMenuItem;
    fCopyPathMenuItem: TMenuItem;
  private
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
    procedure StartDockerStackAsync;
    function ResolveSearchHelpImagePath: string;
    function BuildEffectiveQuery: string;
    procedure CaptureWindowBounds(out aLeft, aTop, aWidth, aHeight: Integer);
    function CaptureUiState: TUiStateSettings;
    function ClampWindowRectToWorkArea(const aBounds: TRect): TRect;
    procedure BuildSortMenu;
    procedure ConfigureColumns;
    procedure CopySelectedPathToClipboard;
    procedure DispatchSearchQuery(const aQuery: string; const aImmediate: Boolean);
    function EscapeHtml(const aText: string): string;
    procedure ExportResultsAsMarkdown;
    function GetSelectedSkillFile: string;
    function GetSelectedSkillRoot: string;
    function IsResultSelectionValid: Boolean;
    procedure LoadUiState;
    procedure OpenSelectedSkillFile;
    procedure OpenSelectedSkillFolder;
    procedure PopulateExternalToolsMenu;
    procedure QueueSearch(const aImmediate: Boolean);
    procedure RefreshCountPanels;
    procedure RefreshInventoryCounters;
    procedure RenderResultsList(const aPreferredSkillFile: string);
    procedure RenderPreview(const aResult: TSkillSearchResult);
    procedure SaveRuntimeState;
    function ScaleStoredUiValue(const aValue, aStoredPPI: Integer): Integer;
    procedure SelectHistoryQuery(const aQuery: string);
    function SerializeColumnWidths: string;
    procedure SetSortMode(const aSortMode: TSearchSortMode; const aResortResults: Boolean = True);
    procedure ShowEmptyPreview;
    function TryLoadSourceRoots(out aSourceRoots: TArray<string>): Boolean;
    procedure UpdateStatus(const aText: string);
    procedure UpdateSortUi;
    procedure UpdateSearchHistoryMenu;
    procedure WaitForWorkerThread(var aThread: TThread);
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
      aFailure: string);
    procedure HandleOpenFileClick(Sender: TObject);
    procedure HandleOpenFolderClick(Sender: TObject);
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

resourcestring
  rsScanBlockedEditSourcesList = 'Scan blocked: edit Sources.lst and retry.';
  rsScanNeedsSourcesListEdit =
    'Scan cannot start because %s does not contain any usable source directories.' + sLineBreak + sLineBreak +
    'Edit the file first, save it, and then retry Scan.';

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
  lSemanticOptions: TSemanticSearchOptions;
  lSettings: TSettingsLoadResult;
begin
  inherited Create(aOwner);
  AppMainForm := Self;

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
  LoadSearchHelpImage;
  PopulateExternalToolsMenu;

  fSearchAsYouTypeCheckBox.Checked := fAppSettings.UiState.SearchAsYouType;
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
  fDockerStartThread := nil;
  fDockerHealthState := TDockerHealthState.dhsUnknown;
  fDockerHealthLabel.Caption := 'Ollama: checking...';
  fDockerHealthLabel.Hint := '';
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

  QueueSearch(True);
end;

destructor TMainForm.Destroy;
begin
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
  for i := 0 to Pred(fResultsListView.Columns.Count) do
  begin
    if Result <> '' then
    begin
      Result := Result + ';';
    end;
    Result := Result + IntToStr(fResultsListView.Columns[i].Width);
  end;
end;

function TMainForm.CaptureUiState: TUiStateSettings;
begin
  Result := fAppSettings.UiState;
  Result.CurrentPPI := CurrentPPI;
  Result.DuplicateInfoWidth := fDuplicateInfoPanel.Width;
  Result.LastQuery := Trim(fSearchEdit.Text);
  Result.ResultSortMode := SearchSortModeToString(fCurrentSortMode);
  Result.ResultsColumnWidths := SerializeColumnWidths;
  Result.ResultsPaneWidth := fResultsPanePanel.Width;
  Result.SearchAsYouType := fSearchAsYouTypeCheckBox.Checked;
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

  fSearchEdit.Text := fAppSettings.UiState.LastQuery;
  fSearchAsYouTypeCheckBox.Checked := fAppSettings.UiState.SearchAsYouType;

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
    fResultsPanePanel.Width := ScaleStoredUiValue(fAppSettings.UiState.ResultsPaneWidth, lStoredPPI);
  end;
  if fAppSettings.UiState.DuplicateInfoWidth > 0 then
  begin
    fDuplicateInfoPanel.Width := ScaleStoredUiValue(fAppSettings.UiState.DuplicateInfoWidth, lStoredPPI);
  end;

  if Trim(fAppSettings.UiState.ResultsColumnWidths) <> '' then
  begin
    lParts := SplitString(fAppSettings.UiState.ResultsColumnWidths, ';');
    for i := 0 to Pred(Length(lParts)) do
    begin
      if i >= fResultsListView.Columns.Count then
      begin
        Break;
      end;
      fResultsListView.Columns[i].Width := ScaleStoredUiValue(StrToIntDef(Trim(lParts[i]), 0), lStoredPPI);
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
  fPreviewBrowser.LoadHTML('<html><body><p>No skill selected.</p></body></html>');
  fDuplicateInfoMemo.Lines.Text := 'No duplicate details available.';
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

function TMainForm.GetSelectedSkillRoot: string;
var
  lIndex: Integer;
begin
  if not IsResultSelectionValid then
  begin
    Exit('');
  end;

  lIndex := fResultsListView.Selected.Index;
  Result := fResults[lIndex].SkillRoot;
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
  fSortPopupMenu.Items.Clear;
  for lSortMode := Low(TSearchSortMode) to High(TSearchSortMode) do
  begin
    lItem := TMenuItem.Create(fSortPopupMenu);
    lItem.AutoCheck := False;
    lItem.Caption := cSortCaptions[lSortMode];
    lItem.RadioItem := True;
    lItem.Tag := Ord(lSortMode);
    lItem.OnClick := HandleSortMenuItemClick;
    fSortPopupMenu.Items.Add(lItem);
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
  fSortButton.Caption := 'Sort: ' + cSortLabels[fCurrentSortMode];
  for i := 0 to Pred(fSortPopupMenu.Items.Count) do
  begin
    fSortPopupMenu.Items[i].Checked := fSortPopupMenu.Items[i].Tag = Ord(fCurrentSortMode);
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
  PopulateExternalToolsPopupMenu(fPopupMenu, fAppSettings.ExternalTools, HandleExternalToolClick, 1);
end;

procedure TMainForm.DispatchSearchQuery(const aQuery: string; const aImmediate: Boolean);
begin
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
  fSearchHistoryPopupMenu.Items.Clear;
  for i := 0 to Pred(Length(fSearchHistory.Items)) do
  begin
    lItem := TMenuItem.Create(fSearchHistoryPopupMenu);
    lItem.Caption := fSearchHistory.Items[i];
    lItem.OnClick := HandleSearchHistoryItemClick;
    fSearchHistoryPopupMenu.Items.Add(lItem);
  end;

  fSearchHistoryButton.Enabled := Length(fSearchHistory.Items) > 0;
end;

procedure TMainForm.SelectHistoryQuery(const aQuery: string);
begin
  ExecuteHistorySelection(
    aQuery,
    fSearchHistory,
    procedure(const aSelectedQuery: string)
    begin
      fSearchEdit.Text := aSelectedQuery;
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
  fResultsListView.Items.BeginUpdate;
  try
    fResultsListView.Items.Clear;
    for i := 0 to Pred(Length(fResults)) do
    begin
      lItem := fResultsListView.Items.Add;
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
    fResultsListView.Items.EndUpdate;
  end;

  if fResultsListView.Items.Count = 0 then
  begin
    ShowEmptyPreview;
    Exit;
  end;

  if lSelectedIndex < 0 then
  begin
    lSelectedIndex := 0;
  end;
  fResultsListView.Items[lSelectedIndex].Selected := True;
  fResultsListView.Items[lSelectedIndex].Focused := True;
  RenderPreview(fResults[lSelectedIndex]);
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
  UpdateStatus('Starting Ollama container...');
end;

procedure TMainForm.EndDockerStart;
begin
  fDockerStartHourGlass := nil;
  fDockerGpuButton.Enabled := True;
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
  );
  fDockerStartThread.FreeOnTerminate := False;
  fDockerStartThread.Start;
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
    RefreshCountPanels;
    fStatusBar.Panels[cStatusPanelLastScan].Text := 'Last scan: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
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
end;

procedure TMainForm.HandleDockerGpuButtonClick(Sender: TObject);
begin
  StartDockerStackAsync;
end;

procedure TMainForm.HandleSearchCompleted(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>;
  const aError: string);
begin
  if GetCurrentThreadId <> MainThreadID then
  begin
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

        lForm.HandleSearchCompleted(aGenerationId, aResults, aError);
      end
    );
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

procedure TMainForm.HandleSearchHistoryButtonClick(Sender: TObject);
var
  lPoint: TPoint;
begin
  if fSearchHistoryPopupMenu.Items.Count = 0 then
  begin
    UpdateStatus('No recent queries yet.');
    Exit;
  end;

  lPoint := fSearchHistoryButton.ClientToScreen(Point(0, fSearchHistoryButton.Height));
  fSearchHistoryPopupMenu.Popup(lPoint.X, lPoint.Y);
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

procedure TMainForm.HandleSortButtonClick(Sender: TObject);
var
  lPoint: TPoint;
begin
  lPoint := fSortButton.ClientToScreen(Point(0, fSortButton.Height));
  fSortPopupMenu.Popup(lPoint.X, lPoint.Y);
end;

procedure TMainForm.HandleSortMenuItemClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then
  begin
    Exit;
  end;

  SetSortMode(TSearchSortMode(TMenuItem(Sender).Tag));
end;

procedure TMainForm.HandleHasScriptsClick(Sender: TObject);
begin
  QueueSearch(False);
end;

end.
