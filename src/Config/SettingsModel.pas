unit SettingsModel;

interface

type
  TGeneralSettings = record
    CacheDbPath: string;
    LogPath: string;
    MaxGitPullThreads: Integer;
    MaxIndexThreads: Integer;
    MaxScanThreads: Integer;
    MaxSearchThreads: Integer;
    SourcesListPath: string;
  end;

  TGitSettings = record
    GitExePath: string;
    GitPullArgs: string;
    GitPullTimeoutSeconds: Integer;
    MinPullIntervalMinutes: Integer;
    PullEnabled: Boolean;
    SkipFolders: string;
    TreatWorktreesAsRepos: Boolean;
  end;

  TIndexSettings = record
    ComputeHasScripts: Boolean;
    HasScriptsMaxFilesToScan: Integer;
    HasScriptsSkipFolders: string;
    MaxSkillFileBytes: Integer;
    NormalizeLineEndings: Boolean;
    ScriptExtensions: string;
    SkillFileName: string;
  end;

  TSearchSettings = record
    MaxResults: Integer;
    SearchAsYouType: Boolean;
    SearchDebounceMs: Integer;
    SnippetMaxChars: Integer;
  end;

  TSemanticSettings = record
    CandidateRerankCount: Integer;
    EmbeddingCache: Boolean;
    Enabled: Boolean;
    MinScoreToShow: Double;
    Model: string;
    OllamaBaseUrl: string;
    Provider: string;
  end;

  TUiSettings = record
    OpenFileOnEnter: Boolean;
    ShowPreviewPane: Boolean;
  end;

  TAppSettings = record
    General: TGeneralSettings;
    Git: TGitSettings;
    Index: TIndexSettings;
    Search: TSearchSettings;
    Semantic: TSemanticSettings;
    Ui: TUiSettings;
  end;

function DefaultAppSettings: TAppSettings;

implementation

function DefaultAppSettings: TAppSettings;
begin
  Result.General.SourcesListPath := 'Sources.lst';
  Result.General.CacheDbPath := 'cache\SkillCache.db';
  Result.General.LogPath := 'logs\AgentSkillSearch.log';
  Result.General.MaxScanThreads := 6;
  Result.General.MaxGitPullThreads := 3;
  Result.General.MaxIndexThreads := 6;
  Result.General.MaxSearchThreads := 1;

  Result.Git.GitExePath := 'git.exe';
  Result.Git.PullEnabled := True;
  Result.Git.MinPullIntervalMinutes := 1440;
  Result.Git.GitPullTimeoutSeconds := 1800;
  Result.Git.GitPullArgs := 'pull --ff-only';
  Result.Git.SkipFolders := '.git;node_modules;bin;obj;.vs;.idea;dist;build;.venv;__pycache__';
  Result.Git.TreatWorktreesAsRepos := True;

  Result.Index.SkillFileName := 'SKILL.md';
  Result.Index.MaxSkillFileBytes := 2000000;
  Result.Index.ComputeHasScripts := True;
  Result.Index.ScriptExtensions := 'py;ps1;bat;cmd;sh;js;ts;lua;rb;pl;go;rs;java;cs;cpp;c;h;pas';
  Result.Index.HasScriptsMaxFilesToScan := 5000;
  Result.Index.HasScriptsSkipFolders := '.git;node_modules;bin;obj;dist;build;.venv;__pycache__';
  Result.Index.NormalizeLineEndings := True;

  Result.Search.SearchAsYouType := False;
  Result.Search.SearchDebounceMs := 2000;
  Result.Search.MaxResults := 500;
  Result.Search.SnippetMaxChars := 600;

  Result.Semantic.Enabled := True;
  Result.Semantic.Provider := 'ollama';
  Result.Semantic.OllamaBaseUrl := 'http://localhost:11434';
  Result.Semantic.Model := 'mxbai-embed-large';
  Result.Semantic.CandidateRerankCount := 300;
  Result.Semantic.MinScoreToShow := 0.0;
  Result.Semantic.EmbeddingCache := True;

  Result.Ui.ShowPreviewPane := True;
  Result.Ui.OpenFileOnEnter := True;
end;

end.
