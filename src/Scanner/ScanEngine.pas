unit ScanEngine;

interface

type
  TScanOptions = record
    MaxScanThreads: Integer;
    QueueDepth: Integer;
    SkillFileName: string;
    SkipFolders: string;
    TreatWorktreesAsRepos: Boolean;
  end;

  TScanResult = record
    RepoRoots: TArray<string>;
    ScannedDirectoryCount: Integer;
    SkillFiles: TArray<string>;
  end;

  TScanEngine = class
  private
    fOptions: TScanOptions;
    function IsSkippedDirectory(const aDirectoryPath: string): Boolean;
  public
    constructor Create(const aOptions: TScanOptions);
    function Scan(const aSourceRoots: TArray<string>): TScanResult;
  end;

function DefaultScanOptions: TScanOptions;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.StrUtils, System.SyncObjs, System.SysUtils,
  RepoDetection;

const
  cStopMarker = '__SCAN_STOP__';

type
  TScanSharedState = class
  private
    fEngine: TScanEngine;
  public
    DirectoriesQueue: TThreadedQueue<string>;
    DiscoveredRepos: TDictionary<string, Byte>;
    DiscoveredSkills: TDictionary<string, Byte>;
    PendingDirectories: Integer;
    ScannedDirectoryCount: Integer;
    StopPublished: Integer;
    WorkerCount: Integer;

    constructor Create(aEngine: TScanEngine; const aOptions: TScanOptions; const aWorkerCount: Integer);
    destructor Destroy; override;

    procedure PublishStopWorkers;
    function PushDirectory(const aDirectoryPath: string): Boolean;

    property Engine: TScanEngine read fEngine;
  end;

  TScanWorkerThread = class(TThread)
  private
    fShared: TScanSharedState;
  protected
    procedure Execute; override;
  public
    constructor Create(aShared: TScanSharedState);
  end;

function DefaultScanOptions: TScanOptions;
begin
  Result.MaxScanThreads := 4;
  Result.QueueDepth := 2048;
  Result.SkillFileName := 'SKILL.md';
  Result.SkipFolders := '.git;node_modules;bin;obj;.vs;.idea;dist;build;.venv;__pycache__';
  Result.TreatWorktreesAsRepos := True;
end;

constructor TScanEngine.Create(const aOptions: TScanOptions);
begin
  inherited Create;
  fOptions := aOptions;
end;

function TScanEngine.IsSkippedDirectory(const aDirectoryPath: string): Boolean;
var
  i: Integer;
  lDirName: string;
  lSkipFolders: TArray<string>;
begin
  lSkipFolders := SplitString(fOptions.SkipFolders, ';');
  lDirName := ExtractFileName(aDirectoryPath);

  for i := 0 to Pred(Length(lSkipFolders)) do
  begin
    if SameText(lDirName, Trim(lSkipFolders[i])) then
    begin
      Exit(True);
    end;
  end;

  Result := False;
end;

constructor TScanSharedState.Create(aEngine: TScanEngine; const aOptions: TScanOptions; const aWorkerCount: Integer);
begin
  inherited Create;
  fEngine := aEngine;
  DirectoriesQueue := TThreadedQueue<string>.Create(aOptions.QueueDepth, 100, 100);
  DiscoveredRepos := TDictionary<string, Byte>.Create;
  DiscoveredSkills := TDictionary<string, Byte>.Create;
  PendingDirectories := 0;
  ScannedDirectoryCount := 0;
  StopPublished := 0;
  WorkerCount := aWorkerCount;
end;

destructor TScanSharedState.Destroy;
begin
  DiscoveredSkills.Free;
  DiscoveredRepos.Free;
  DirectoriesQueue.Free;
  inherited Destroy;
end;

procedure TScanSharedState.PublishStopWorkers;
var
  i: Integer;
begin
  if TInterlocked.CompareExchange(StopPublished, 1, 0) = 0 then
  begin
    for i := 1 to WorkerCount do
    begin
      while DirectoriesQueue.PushItem(cStopMarker) <> wrSignaled do
      begin
        Sleep(1);
      end;
    end;
  end;
end;

function TScanSharedState.PushDirectory(const aDirectoryPath: string): Boolean;
begin
  while DirectoriesQueue.PushItem(aDirectoryPath) <> wrSignaled do
  begin
    Sleep(1);
  end;
  Result := True;
end;

constructor TScanWorkerThread.Create(aShared: TScanSharedState);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  fShared := aShared;
end;

procedure TScanWorkerThread.Execute;
var
  lCurrentDir: string;
  lDirectoryList: TArray<string>;
  lIsWorktree: Boolean;
  lSkillPath: string;
  lSubDir: string;
begin
  while True do
  begin
    if fShared.DirectoriesQueue.PopItem(lCurrentDir) <> wrSignaled then
    begin
      Continue;
    end;

    if SameText(lCurrentDir, cStopMarker) then
    begin
      Exit;
    end;

    try
      if not fShared.Engine.IsSkippedDirectory(lCurrentDir) then
      begin
        if IsGitRepoRoot(lCurrentDir, fShared.Engine.fOptions.TreatWorktreesAsRepos, lIsWorktree) then
        begin
          TMonitor.Enter(fShared.DiscoveredRepos);
          try
            if not fShared.DiscoveredRepos.ContainsKey(lCurrentDir) then
            begin
              fShared.DiscoveredRepos.Add(lCurrentDir, 1);
            end;
          finally
            TMonitor.Exit(fShared.DiscoveredRepos);
          end;
        end;

        lSkillPath := TPath.Combine(lCurrentDir, fShared.Engine.fOptions.SkillFileName);
        if TFile.Exists(lSkillPath) then
        begin
          TMonitor.Enter(fShared.DiscoveredSkills);
          try
            if not fShared.DiscoveredSkills.ContainsKey(lSkillPath) then
            begin
              fShared.DiscoveredSkills.Add(lSkillPath, 1);
            end;
          finally
            TMonitor.Exit(fShared.DiscoveredSkills);
          end;
        end;

        lDirectoryList := TDirectory.GetDirectories(lCurrentDir);
        for lSubDir in lDirectoryList do
        begin
          if fShared.Engine.IsSkippedDirectory(lSubDir) then
          begin
            Continue;
          end;

          TInterlocked.Increment(fShared.PendingDirectories);
          fShared.PushDirectory(lSubDir);
        end;

        TInterlocked.Increment(fShared.ScannedDirectoryCount);
      end;
    finally
      if TInterlocked.Decrement(fShared.PendingDirectories) = 0 then
      begin
        fShared.PublishStopWorkers;
      end;
    end;
  end;
end;

function TScanEngine.Scan(const aSourceRoots: TArray<string>): TScanResult;
var
  i: Integer;
  lShared: TScanSharedState;
  lWorkerCount: Integer;
  lWorkers: TArray<TScanWorkerThread>;
  lRootPath: string;
begin
  lWorkerCount := fOptions.MaxScanThreads;
  if lWorkerCount < 1 then
  begin
    lWorkerCount := 1;
  end;

  lShared := TScanSharedState.Create(self, fOptions, lWorkerCount);
  try
    for i := 0 to Pred(Length(aSourceRoots)) do
    begin
      lRootPath := TPath.GetFullPath(aSourceRoots[i]);
      if IsSkippedDirectory(lRootPath) then
      begin
        Continue;
      end;

      TInterlocked.Increment(lShared.PendingDirectories);
      lShared.PushDirectory(lRootPath);
    end;

    if lShared.PendingDirectories = 0 then
    begin
      lShared.PublishStopWorkers;
    end;

    SetLength(lWorkers, lWorkerCount);
    for i := 0 to Pred(Length(lWorkers)) do
    begin
      lWorkers[i] := TScanWorkerThread.Create(lShared);
      lWorkers[i].Start;
    end;

    for i := 0 to Pred(Length(lWorkers)) do
    begin
      lWorkers[i].WaitFor;
      lWorkers[i].Free;
    end;

    Result.RepoRoots := lShared.DiscoveredRepos.Keys.ToArray;
    TArray.Sort<string>(Result.RepoRoots);

    Result.SkillFiles := lShared.DiscoveredSkills.Keys.ToArray;
    TArray.Sort<string>(Result.SkillFiles);

    Result.ScannedDirectoryCount := lShared.ScannedDirectoryCount;
  finally
    lShared.Free;
  end;
end;

end.
