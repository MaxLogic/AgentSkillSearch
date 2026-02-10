unit PipelineCoordinator;

interface

uses
  System.Diagnostics, System.Generics.Collections,
  DatabaseManager, SkillTypes;

type
  TPipelineOptions = record
    AutoCancelAfterMs: Integer;
    DbBatchSize: Integer;
    MaxGitPullThreads: Integer;
    MaxIndexThreads: Integer;
    MaxScanThreads: Integer;
    SimulationDelayMs: Integer;
    SkipFolders: string;
    SkillFileName: string;
    TreatWorktreesAsRepos: Boolean;
  end;

  TPipelineRunResult = record
    Cancelled: Boolean;
    ErrorCount: Integer;
    LastError: string;
    ReposQueued: Integer;
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
    fLastError: string;
    fOptions: TPipelineOptions;
    fReposQueued: Integer;
    fReposWritten: Integer;
    fSkillsQueued: Integer;
    fSkillsWritten: Integer;
    fSkipFolderNames: TArray<string>;
    fStopwatch: TStopwatch;
    procedure AddError(const aMessage: string);
    procedure AddRepoDiscovered(aRepos: TList<string>; const aRepoPath: string);
    procedure AddSkillDiscovered(aSkills: TList<string>; const aSkillFilePath: string);
    function BuildUniquePaths(const aInput: TList<string>): TArray<string>;
    function IsSkippedDirectory(const aDirectoryPath: string): Boolean;
    function ShouldAutoCancel: Boolean;
    procedure ScanRoot(const aRootPath: string; aRepos: TList<string>; aSkills: TList<string>);
  public
    constructor Create(aDbManager: TDatabaseManager; const aOptions: TPipelineOptions);
    function Run(const aSourceRoots: TArray<string>; aCancelToken: TPipelineCancellationToken): TPipelineRunResult;
  end;

function DefaultPipelineOptions: TPipelineOptions;

implementation

uses
  System.Classes, System.IOUtils, System.Math, System.StrUtils, System.SyncObjs, System.SysUtils,
  System.Threading,
  RepoDetection, SkillIndexer;

function DefaultPipelineOptions: TPipelineOptions;
begin
  Result.AutoCancelAfterMs := 0;
  Result.MaxScanThreads := 4;
  Result.MaxGitPullThreads := 2;
  Result.MaxIndexThreads := 4;
  Result.DbBatchSize := 32;
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
  fSkipFolderNames := SplitString(fOptions.SkipFolders, ';');
end;

procedure TPipelineCoordinator.AddError(const aMessage: string);
begin
  TInterlocked.Increment(fErrorCount);
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

      if IsGitRepoRoot(lCurrentDir, fOptions.TreatWorktreesAsRepos, lIsWorktree) then
      begin
        AddRepoDiscovered(aRepos, lCurrentDir);
      end;

      lSkillFile := TPath.Combine(lCurrentDir, fOptions.SkillFileName);
      if TFile.Exists(lSkillFile) then
      begin
        AddSkillDiscovered(aSkills, lSkillFile);
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
  lBatchSkills: TArray<TIndexedSkill>;
  lIndexedSkills: TList<TIndexedSkill>;
  lLocalDbManager: TDatabaseManager;
  lReposDiscovered: TList<string>;
  lReposForGit: TArray<string>;
  lReposPrepared: TList<string>;
  lSkillFilesDiscovered: TList<string>;
  lSkillFilesForIndex: TArray<string>;
begin
  fReposQueued := 0;
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
  lReposPrepared := TList<string>.Create;
  lIndexedSkills := TList<TIndexedSkill>.Create;
  try
    if Length(aSourceRoots) > 0 then
    begin
      TParallel.For(
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
        end
      );
    end;

    lReposForGit := BuildUniquePaths(lReposDiscovered);
    lSkillFilesForIndex := BuildUniquePaths(lSkillFilesDiscovered);

    if Length(lReposForGit) > 0 then
    begin
      TParallel.For(
        0,
        High(lReposForGit),
        procedure(aIndex: Integer)
        begin
          try
            TMonitor.Enter(lReposPrepared);
            try
              lReposPrepared.Add(lReposForGit[aIndex]);
            finally
              TMonitor.Exit(lReposPrepared);
            end;

            if fOptions.SimulationDelayMs > 0 then
            begin
              Sleep(fOptions.SimulationDelayMs);
            end;
          except
            on E: Exception do
            begin
              AddError('Git worker failed: ' + E.Message);
            end;
          end;
        end
      );
    end;

    if Length(lSkillFilesForIndex) > 0 then
    begin
      TParallel.For(
        0,
        High(lSkillFilesForIndex),
        procedure(aIndex: Integer)
        var
          lLocalError: string;
          lLocalSkill: TIndexedSkill;
        begin
          try
            if TryBuildIndexedSkill(lSkillFilesForIndex[aIndex], lLocalSkill, lLocalError) then
            begin
              TMonitor.Enter(lIndexedSkills);
              try
                lIndexedSkills.Add(lLocalSkill);
              finally
                TMonitor.Exit(lIndexedSkills);
              end;
            end else begin
              AddError('Skill indexing failed: ' + lLocalError);
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
        end
      );
    end;

    lBatchRepos := lReposPrepared.ToArray;
    lBatchSkills := lIndexedSkills.ToArray;

    lLocalDbManager := TDatabaseManager.Create(fDbManager.DatabasePath, fDbManager.SqliteDllPath);
    try
      lLocalDbManager.Initialize;

      i := 0;
      while i < Length(lBatchRepos) do
      begin
        if fCancelToken.IsCancelled and (i > 0) then
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
      while i < Length(lBatchSkills) do
      begin
        if fCancelToken.IsCancelled and (i > 0) then
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
    lLocalDbManager.Free;

    Result.Cancelled := fCancelToken.IsCancelled;
    Result.ReposQueued := fReposQueued;
    Result.SkillsQueued := fSkillsQueued;
    Result.ReposWritten := fReposWritten;
    Result.SkillsWritten := fSkillsWritten;
    Result.ErrorCount := fErrorCount;
    Result.LastError := fLastError;
  finally
    lIndexedSkills.Free;
    lReposPrepared.Free;
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
