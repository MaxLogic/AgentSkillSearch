unit PipelineCoordinator;

interface

uses
  System.Diagnostics, System.Generics.Collections,
  DatabaseManager, GitPullWorker, SkillTypes;

type
  TPipelineOptions = record
    AutoCancelAfterMs: Integer;
    DbBatchSize: Integer;
    ExcludePathPatterns: TArray<string>;
    GitExePath: string;
    GitPullArgs: string;
    GitPullTimeoutSeconds: Integer;
    MaxGitPullThreads: Integer;
    MaxIndexThreads: Integer;
    MaxScanThreads: Integer;
    MinPullIntervalMinutes: Integer;
    PullEnabled: Boolean;
    SimulationDelayMs: Integer;
    SkipFolders: string;
    SkillFileName: string;
    TreatWorktreesAsRepos: Boolean;
  end;

  TPipelineRunResult = record
    Cancelled: Boolean;
    ErrorCount: Integer;
    LastError: string;
    ReposFailed: Integer;
    ReposPulled: Integer;
    ReposQueued: Integer;
    ReposThrottled: Integer;
    ReposWritten: Integer;
    SkillsQueued: Integer;
    SkillsWritten: Integer;
  end;

  TPipelineCancellationToken = class
  private
    fCancelFlag: Integer;
  public
    procedure Cancel;
    function IsCancelled: Boolean;
  end;

  TPipelineCoordinator = class
  private
    fCancelToken: TPipelineCancellationToken;
    fDbManager: TDatabaseManager;
    fErrorCount: Integer;
    fExcludedPaths: TDictionary<string, Byte>;
    fLastError: string;
    fOptions: TPipelineOptions;
    fReposFailed: Integer;
    fReposPulled: Integer;
    fReposQueued: Integer;
    fReposThrottled: Integer;
    fReposWritten: Integer;
    fSkillsQueued: Integer;
    fSkillsWritten: Integer;
    fSkipFolderNames: TArray<string>;
    fStopwatch: TStopwatch;
    procedure AddError(const aMessage: string);
    procedure AddExcludedPath(const aPath: string);
    procedure AddRepoDiscovered(aRepos: TList<string>; const aRepoPath: string);
    procedure AddRepoPullResult(aRepoPulls: TList<TRepoPullUpdate>; const aPullResult: TRepoPullUpdate);
    procedure AddSkillDiscovered(aSkills: TList<string>; const aSkillFilePath: string);
    function BuildPullUpdate(const aRepoPath: string; const aPullResult: TGitPullResult): TRepoPullUpdate;
    function BuildThrottledPullUpdate(const aRepoPath, aLastPullUtc: string): TRepoPullUpdate;
    function BuildUniquePaths(const aInput: TList<string>): TArray<string>;
    function IsExcludedPath(const aPath: string): Boolean;
    function IsSkippedDirectory(const aDirectoryPath: string): Boolean;
    function ShouldAutoCancel: Boolean;
    procedure ScanRoot(const aRootPath: string; aRepos: TList<string>; aSkills: TList<string>);
  public
    constructor Create(aDbManager: TDatabaseManager; const aOptions: TPipelineOptions);
    destructor Destroy; override;
    function Run(const aSourceRoots: TArray<string>; aCancelToken: TPipelineCancellationToken): TPipelineRunResult;
  end;

function DefaultPipelineOptions: TPipelineOptions;

implementation

uses
  System.Classes, System.DateUtils, System.IOUtils, System.Math, System.StrUtils, System.SyncObjs, System.SysUtils,
  System.Threading,
  Logging, PathExclusions, RepoDetection, SkillIndexer;

function DefaultPipelineOptions: TPipelineOptions;
begin
  Result.AutoCancelAfterMs := 0;
  Result.DbBatchSize := 32;
  Result.GitExePath := 'git.exe';
  Result.GitPullArgs := 'pull --ff-only';
  Result.GitPullTimeoutSeconds := 1800;
  Result.MaxGitPullThreads := 2;
  Result.MaxIndexThreads := 4;
  Result.MaxScanThreads := 4;
  Result.MinPullIntervalMinutes := 1440;
  Result.PullEnabled := True;
  Result.SimulationDelayMs := 0;
  Result.SkipFolders := '.git;node_modules;bin;obj;.vs;.idea;dist;build;.venv;__pycache__';
  Result.SkillFileName := 'SKILL.md';
  Result.TreatWorktreesAsRepos := True;
end;

procedure TPipelineCancellationToken.Cancel;
begin
  TInterlocked.Exchange(fCancelFlag, 1);
end;

function TPipelineCancellationToken.IsCancelled: Boolean;
begin
  Result := TInterlocked.CompareExchange(fCancelFlag, 0, 0) = 1;
end;

constructor TPipelineCoordinator.Create(aDbManager: TDatabaseManager; const aOptions: TPipelineOptions);
begin
  inherited Create;
  fDbManager := aDbManager;
  fOptions := aOptions;
  fExcludedPaths := TDictionary<string, Byte>.Create;
  fSkipFolderNames := SplitString(fOptions.SkipFolders, ';');
end;

destructor TPipelineCoordinator.Destroy;
begin
  fExcludedPaths.Free;
  inherited Destroy;
end;

procedure TPipelineCoordinator.AddError(const aMessage: string);
begin
  TInterlocked.Increment(fErrorCount);
  RecordPipelineError(aMessage);
  TMonitor.Enter(self);
  try
    if fLastError = '' then
    begin
      fLastError := aMessage;
    end;
  finally
    TMonitor.Exit(self);
  end;
end;

procedure TPipelineCoordinator.AddExcludedPath(const aPath: string);
begin
  TMonitor.Enter(fExcludedPaths);
  try
    if fExcludedPaths.ContainsKey(aPath) then
    begin
      Exit;
    end;
    fExcludedPaths.Add(aPath, 1);
  finally
    TMonitor.Exit(fExcludedPaths);
  end;

  RecordPipelineNotice('Excluded path: ' + aPath);
end;

procedure TPipelineCoordinator.AddRepoDiscovered(aRepos: TList<string>; const aRepoPath: string);
begin
  TMonitor.Enter(aRepos);
  try
    aRepos.Add(aRepoPath);
    TInterlocked.Increment(fReposQueued);
  finally
    TMonitor.Exit(aRepos);
  end;
end;

procedure TPipelineCoordinator.AddRepoPullResult(aRepoPulls: TList<TRepoPullUpdate>; const aPullResult: TRepoPullUpdate);
begin
  TMonitor.Enter(aRepoPulls);
  try
    aRepoPulls.Add(aPullResult);
  finally
    TMonitor.Exit(aRepoPulls);
  end;
end;

procedure TPipelineCoordinator.AddSkillDiscovered(aSkills: TList<string>; const aSkillFilePath: string);
begin
  TMonitor.Enter(aSkills);
  try
    aSkills.Add(aSkillFilePath);
    TInterlocked.Increment(fSkillsQueued);
  finally
    TMonitor.Exit(aSkills);
  end;
end;

function TPipelineCoordinator.BuildPullUpdate(const aRepoPath: string; const aPullResult: TGitPullResult): TRepoPullUpdate;
begin
  Result.RootPath := aRepoPath;
  Result.LastPullUtc := aPullResult.TimestampUtc;
  Result.LastPullStatus := aPullResult.Status;
  Result.LastPullOutput := aPullResult.OutputText;
  Result.LastPullDurationMs := aPullResult.DurationMs;
  Result.HeadCommit := aPullResult.HeadCommit;
end;

function TPipelineCoordinator.BuildThrottledPullUpdate(const aRepoPath, aLastPullUtc: string): TRepoPullUpdate;
begin
  Result.RootPath := aRepoPath;
  Result.LastPullUtc := aLastPullUtc;
  Result.LastPullStatus := 'skipped (throttled)';
  Result.LastPullOutput := '';
  Result.LastPullDurationMs := 0;
  Result.HeadCommit := '';
end;

function TPipelineCoordinator.BuildUniquePaths(const aInput: TList<string>): TArray<string>;
var
  lDict: TDictionary<string, Byte>;
  lValue: string;
begin
  lDict := TDictionary<string, Byte>.Create;
  try
    for lValue in aInput do
    begin
      if not lDict.ContainsKey(lValue) then
      begin
        lDict.Add(lValue, 1);
      end;
    end;

    Result := lDict.Keys.ToArray;
    TArray.Sort<string>(Result);
  finally
    lDict.Free;
  end;
end;

function TPipelineCoordinator.IsExcludedPath(const aPath: string): Boolean;
begin
  Result := IsPathExcluded(aPath, fOptions.ExcludePathPatterns);
end;

function TPipelineCoordinator.IsSkippedDirectory(const aDirectoryPath: string): Boolean;
var
  i: Integer;
  lDirName: string;
begin
  lDirName := ExtractFileName(aDirectoryPath);

  for i := 0 to Pred(Length(fSkipFolderNames)) do
  begin
    if SameText(lDirName, Trim(fSkipFolderNames[i])) then
    begin
      Exit(True);
    end;
  end;

  Result := False;
end;

function TPipelineCoordinator.ShouldAutoCancel: Boolean;
begin
  Result := (fOptions.AutoCancelAfterMs > 0) and
    (fStopwatch.ElapsedMilliseconds >= fOptions.AutoCancelAfterMs);
end;

procedure TPipelineCoordinator.ScanRoot(const aRootPath: string; aRepos: TList<string>; aSkills: TList<string>);
var
  lCurrentDir: string;
  lDirs: TArray<string>;
  lIsWorktree: Boolean;
  lPending: TList<string>;
  lSkillFile: string;
  lSubDir: string;
begin
  lPending := TList<string>.Create;
  try
    lPending.Add(ExcludeTrailingPathDelimiter(TPath.GetFullPath(aRootPath)));

    while (lPending.Count > 0) and (not fCancelToken.IsCancelled) do
    begin
      if ShouldAutoCancel then
      begin
        fCancelToken.Cancel;
      end;

      lCurrentDir := lPending[lPending.Count - 1];
      lPending.Delete(lPending.Count - 1);

      if IsSkippedDirectory(lCurrentDir) then
      begin
        Continue;
      end;

      if IsExcludedPath(lCurrentDir) then
      begin
        AddExcludedPath(lCurrentDir);
        Continue;
      end;

      if IsGitRepoRoot(lCurrentDir, fOptions.TreatWorktreesAsRepos, lIsWorktree) then
      begin
        AddRepoDiscovered(aRepos, lCurrentDir);
      end;

      lSkillFile := TPath.Combine(lCurrentDir, fOptions.SkillFileName);
      if TFile.Exists(lSkillFile) then
      begin
        if IsExcludedPath(lSkillFile) then
        begin
          AddExcludedPath(lSkillFile);
        end else begin
          AddSkillDiscovered(aSkills, lSkillFile);
        end;
      end;

      try
        lDirs := TDirectory.GetDirectories(lCurrentDir);
      except
        on EInOutError do
        begin
          Continue;
        end;
      end;

      for lSubDir in lDirs do
      begin
        if IsExcludedPath(lSubDir) then
        begin
          AddExcludedPath(lSubDir);
          Continue;
        end;

        if not IsSkippedDirectory(lSubDir) then
        begin
          lPending.Add(lSubDir);
        end;
      end;

      if fOptions.SimulationDelayMs > 0 then
      begin
        Sleep(fOptions.SimulationDelayMs);
      end;
    end;
  finally
    lPending.Free;
  end;
end;

function TPipelineCoordinator.Run(const aSourceRoots: TArray<string>; aCancelToken: TPipelineCancellationToken): TPipelineRunResult;
var
  i: Integer;
  lBatchRepos: TArray<string>;
  lBatchRepoPulls: TArray<TRepoPullUpdate>;
  lBatchSkills: TArray<TIndexedSkill>;
  lGitOptions: TGitPullOptions;
  lGitPool: TThreadPool;
  lIndexPool: TThreadPool;
  lKnownRepoState: TRepoState;
  lNowUtc: TDateTime;
  lIndexedSkills: TList<TIndexedSkill>;
  lLocalDbManager: TDatabaseManager;
  lReposToPull: TList<string>;
  lReposDiscovered: TList<string>;
  lReposForGit: TArray<string>;
  lRepoPullUpdates: TList<TRepoPullUpdate>;
  lRepoStateReader: TDatabaseManager;
  lScanPool: TThreadPool;
  lSummary: TScanSummary;
  lSkillFilesDiscovered: TList<string>;
  lSkillFilesForIndex: TArray<string>;
begin
  lLocalDbManager := nil;
  lSummary := Default(TScanSummary);
  fReposFailed := 0;
  fReposPulled := 0;
  fReposQueued := 0;
  fReposThrottled := 0;
  fSkillsQueued := 0;
  fReposWritten := 0;
  fSkillsWritten := 0;
  fErrorCount := 0;
  fLastError := '';

  if Assigned(aCancelToken) then
  begin
    fCancelToken := aCancelToken;
  end else begin
    fCancelToken := TPipelineCancellationToken.Create;
  end;
  fStopwatch := TStopwatch.StartNew;

  lReposDiscovered := TList<string>.Create;
  lSkillFilesDiscovered := TList<string>.Create;
  lReposToPull := TList<string>.Create;
  lRepoPullUpdates := TList<TRepoPullUpdate>.Create;
  lIndexedSkills := TList<TIndexedSkill>.Create;
  try
    try
      if Length(aSourceRoots) > 0 then
      begin
        lScanPool := TThreadPool.Create;
        try
          lScanPool.SetMinWorkerThreads(1);
          lScanPool.SetMaxWorkerThreads(Max(1, fOptions.MaxScanThreads));

          TParallel.&For(
            0,
            High(aSourceRoots),
            procedure(aIndex: Integer)
            begin
              try
                if not fCancelToken.IsCancelled then
                begin
                  ScanRoot(aSourceRoots[aIndex], lReposDiscovered, lSkillFilesDiscovered);
                end;
              except
                on E: Exception do
                begin
                  AddError('Scan worker failed: ' + E.Message);
                end;
              end;
            end,
            lScanPool
          );
        finally
          lScanPool.Free;
        end;
      end;

      lReposForGit := BuildUniquePaths(lReposDiscovered);
      lSkillFilesForIndex := BuildUniquePaths(lSkillFilesDiscovered);

      if Length(lReposForGit) > 0 then
      begin
        lNowUtc := TTimeZone.Local.ToUniversalTime(Now);

        lRepoStateReader := TDatabaseManager.Create(fDbManager.DatabasePath, fDbManager.SqliteDllPath);
        try
          lRepoStateReader.Initialize;

          for i := 0 to Pred(Length(lReposForGit)) do
          begin
            if fCancelToken.IsCancelled then
            begin
              Break;
            end;

            if lRepoStateReader.TryGetRepoState(lReposForGit[i], lKnownRepoState) and
              TGitPullWorker.IsThrottled(lKnownRepoState.LastPullUtc, fOptions.MinPullIntervalMinutes, lNowUtc) then
            begin
              AddRepoPullResult(lRepoPullUpdates, BuildThrottledPullUpdate(lReposForGit[i], lKnownRepoState.LastPullUtc));
              TInterlocked.Increment(fReposThrottled);
            end else begin
              lReposToPull.Add(lReposForGit[i]);
            end;
          end;
        finally
          lRepoStateReader.Free;
        end;

        if fOptions.PullEnabled and (lReposToPull.Count > 0) and (not fCancelToken.IsCancelled) then
        begin
          lGitOptions.GitExePath := fOptions.GitExePath;
          lGitOptions.GitPullArgs := fOptions.GitPullArgs;
          lGitOptions.GitPullTimeoutSeconds := fOptions.GitPullTimeoutSeconds;

          lGitPool := TThreadPool.Create;
          try
            lGitPool.SetMinWorkerThreads(1);
            lGitPool.SetMaxWorkerThreads(Max(1, fOptions.MaxGitPullThreads));

            TParallel.&For(
              0,
              lReposToPull.Count - 1,
              procedure(aIndex: Integer)
              var
                lPullResult: TGitPullResult;
                lPullUpdate: TRepoPullUpdate;
                lPullWorker: TGitPullWorker;
                lRepoPath: string;
              begin
                lPullWorker := TGitPullWorker.Create;
                try
                  try
                    if fCancelToken.IsCancelled then
                    begin
                      Exit;
                    end;

                    lRepoPath := lReposToPull[aIndex];
                    lPullResult := lPullWorker.PullRepo(lRepoPath, lGitOptions);
                    lPullUpdate := BuildPullUpdate(lRepoPath, lPullResult);
                    AddRepoPullResult(lRepoPullUpdates, lPullUpdate);

                    if SameText(lPullUpdate.LastPullStatus, 'pulled') then
                    begin
                      TInterlocked.Increment(fReposPulled);
                    end else begin
                      TInterlocked.Increment(fReposFailed);
                      AddError('Git pull failed for "' + lRepoPath + '": ' + lPullUpdate.LastPullStatus + ' ' +
                        lPullUpdate.LastPullOutput);
                    end;

                    if fOptions.SimulationDelayMs > 0 then
                    begin
                      Sleep(fOptions.SimulationDelayMs);
                    end;
                  except
                    on E: Exception do
                    begin
                      TInterlocked.Increment(fReposFailed);
                      AddError('Git worker failed: ' + E.Message);
                    end;
                  end;
                finally
                  lPullWorker.Free;
                end;
              end,
              lGitPool
            );
          finally
            lGitPool.Free;
          end;
        end;
      end;

      if Length(lSkillFilesForIndex) > 0 then
      begin
        lIndexPool := TThreadPool.Create;
        try
          lIndexPool.SetMinWorkerThreads(1);
          lIndexPool.SetMaxWorkerThreads(Max(1, fOptions.MaxIndexThreads));

          TParallel.&For(
            0,
            High(lSkillFilesForIndex),
            procedure(aIndex: Integer)
            var
              lLocalError: string;
              lLocalSkill: TIndexedSkill;
            begin
              try
                if fCancelToken.IsCancelled then
                begin
                  Exit;
                end;

                if TryBuildIndexedSkill(lSkillFilesForIndex[aIndex], lLocalSkill, lLocalError) then
                begin
                  TMonitor.Enter(lIndexedSkills);
                  try
                    lIndexedSkills.Add(lLocalSkill);
                  finally
                    TMonitor.Exit(lIndexedSkills);
                  end;
                end else begin
                  AddError('Skill indexing failed for "' + lSkillFilesForIndex[aIndex] + '": ' + lLocalError);
                end;

                if fOptions.SimulationDelayMs > 0 then
                begin
                  Sleep(fOptions.SimulationDelayMs);
                end;
              except
                on E: Exception do
                begin
                  AddError('Index worker failed: ' + E.Message);
                end;
              end;
            end,
            lIndexPool
          );
        finally
          lIndexPool.Free;
        end;
      end;

      lBatchRepos := lReposForGit;
      lBatchRepoPulls := lRepoPullUpdates.ToArray;
      lBatchSkills := lIndexedSkills.ToArray;

      lLocalDbManager := TDatabaseManager.Create(fDbManager.DatabasePath, fDbManager.SqliteDllPath);
      try
        lLocalDbManager.Initialize;

        i := 0;
        while i < Length(lBatchRepos) do
        begin
          if fCancelToken.IsCancelled then
          begin
            Break;
          end;
          if ShouldAutoCancel then
          begin
            fCancelToken.Cancel;
          end;

          lLocalDbManager.WriteBatch(Copy(lBatchRepos, i, fOptions.DbBatchSize), nil);
          TInterlocked.Add(fReposWritten, Min(fOptions.DbBatchSize, Length(lBatchRepos) - i));
          i := i + fOptions.DbBatchSize;
        end;

        i := 0;
        while i < Length(lBatchRepoPulls) do
        begin
          if fCancelToken.IsCancelled then
          begin
            Break;
          end;
          if ShouldAutoCancel then
          begin
            fCancelToken.Cancel;
          end;

          lLocalDbManager.WriteBatchWithRepoPulls(nil, Copy(lBatchRepoPulls, i, fOptions.DbBatchSize), nil);
          i := i + fOptions.DbBatchSize;
        end;

        i := 0;
        while i < Length(lBatchSkills) do
        begin
          if fCancelToken.IsCancelled then
          begin
            Break;
          end;
          if ShouldAutoCancel then
          begin
            fCancelToken.Cancel;
          end;

          lLocalDbManager.WriteBatch(nil, Copy(lBatchSkills, i, fOptions.DbBatchSize));
          TInterlocked.Add(fSkillsWritten, Min(fOptions.DbBatchSize, Length(lBatchSkills) - i));
          i := i + fOptions.DbBatchSize;
        end;
      except
        on E: Exception do
        begin
          AddError('DB writer failed: ' + E.Message);
        end;
      end;
      lSummary := Default(TScanSummary);
      lSummary.CompletedUtc := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', TTimeZone.Local.ToUniversalTime(Now),
        TFormatSettings.Invariant);
      lSummary.ReposFound := fReposQueued;
      lSummary.ReposPulled := fReposPulled;
      lSummary.ReposThrottled := fReposThrottled;
      lSummary.ReposFailed := fReposFailed;
      lSummary.SkillsQueued := fSkillsQueued;
      lSummary.SkillsWritten := fSkillsWritten;
      if Assigned(lLocalDbManager) then
      begin
        lSummary.SkillsValid := lLocalDbManager.GetValidSkillCount;
        lSummary.SkillsUnique := lLocalDbManager.GetUniqueSkillCount;
      end;
      lSummary.ErrorCount := fErrorCount;
      lLocalDbManager.Free;
      lLocalDbManager := nil;
    except
      on E: Exception do
      begin
        AddError('Pipeline run failed: ' + E.Message);
      end;
    end;

    Result.Cancelled := fCancelToken.IsCancelled;
    Result.ReposFailed := fReposFailed;
    Result.ReposPulled := fReposPulled;
    Result.ReposQueued := fReposQueued;
    Result.ReposThrottled := fReposThrottled;
    Result.SkillsQueued := fSkillsQueued;
    Result.ReposWritten := fReposWritten;
    Result.SkillsWritten := fSkillsWritten;
    Result.ErrorCount := fErrorCount;
    Result.LastError := fLastError;

    RecordScanSummary(lSummary);
  finally
    lIndexedSkills.Free;
    lRepoPullUpdates.Free;
    lReposToPull.Free;
    lSkillFilesDiscovered.Free;
    lReposDiscovered.Free;

    if not Assigned(aCancelToken) then
    begin
      fCancelToken.Free;
      fCancelToken := nil;
    end;
  end;
end;

end.
