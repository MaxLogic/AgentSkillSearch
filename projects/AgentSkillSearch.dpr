program AgentSkillSearch;

{$IFNDEF WIN64}
  {$MESSAGE FATAL 'AgentSkillSearch requires Win64. Build target Win64 is mandatory because our SQLite runtime is x64-only.'}
{$ENDIF}

uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  FireDAC.VCLUI.Wait,
  Vcl.Forms,
  AppPaths in '..\src\AppPaths.pas',
  SettingsModel in '..\src\Config\SettingsModel.pas',
  DatabaseManager in '..\src\Db\DatabaseManager.pas',
  DockerHealthMonitor in '..\src\Docker\DockerHealthMonitor.pas',
  DockerOps in '..\src\Docker\DockerOps.pas',
  ExternalTools in '..\src\ExternalTools.pas',
  GitPullWorker in '..\src\Git\GitPullWorker.pas',
  RepoDetection in '..\src\Git\RepoDetection.pas',
  SkillIndexer in '..\src\Indexer\SkillIndexer.pas',
  SkillTypes in '..\src\Indexer\SkillTypes.pas',
  Logging in '..\src\Logging.pas',
  PipelineCoordinator in '..\src\Pipeline\PipelineCoordinator.pas',
  RelatedSkillActions in '..\src\RelatedSkillActions.pas',
  PathExclusions in '..\src\Scanner\PathExclusions.pas',
  RepoScanner in '..\src\Scanner\RepoScanner.pas',
  ScanEngine in '..\src\Scanner\ScanEngine.pas',
  QueryParser in '..\src\Search\QueryParser.pas',
  SearchController in '..\src\Search\SearchController.pas',
  SearchInteraction in '..\src\Search\SearchInteraction.pas',
  SearchResultActions in '..\src\Search\SearchResultActions.pas',
  SkillSearchService in '..\src\Search\SkillSearchService.pas',
  Chunker in '..\src\Semantic\Chunker.pas',
  Settings in '..\src\Settings.pas',
  SourcesList in '..\src\SourcesList.pas',
  TagBrowserActions in '..\src\TagBrowserActions.pas',
  TrayActions in '..\src\TrayActions.pas',
  ConfigDlg in '..\src\UI\ConfigDlg.pas' {ConfigDlg},
  DiagnosticsForm in '..\src\UI\DiagnosticsForm.pas',
  MainForm in '..\src\UI\MainForm.pas' {AppMainForm},
  PreviewRenderer in '..\src\UI\PreviewRenderer.pas',
  SourcesEditorForm in '..\src\UI\SourcesEditorForm.pas' {SourcesEditorForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TAppMainForm, AppMainForm);
  Application.Run;
end.
