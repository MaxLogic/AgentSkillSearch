unit RepoScanner;

interface

uses
  DatabaseManager;

type
  TRepoScanner = class
  private
    fDbManager: TDatabaseManager;
    fSkipFolderNames: TArray<string>;
    fTreatWorktreesAsRepos: Boolean;
    function IsSkippedDirectory(const aDirectory: string): Boolean;
    procedure RecordRepoRoot(const aRepoRoot: string);
  public
    constructor Create(const aTreatWorktreesAsRepos: Boolean; const aSkipFolders: string; aDbManager: TDatabaseManager);
    function ScanForRepoRoots(const aRootPath: string): TArray<string>;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  RepoDetection;

constructor TRepoScanner.Create(const aTreatWorktreesAsRepos: Boolean; const aSkipFolders: string;
  aDbManager: TDatabaseManager);
begin
  inherited Create;
  fTreatWorktreesAsRepos := aTreatWorktreesAsRepos;
  fSkipFolderNames := SplitString(aSkipFolders, ';');
  fDbManager := aDbManager;
end;

function TRepoScanner.IsSkippedDirectory(const aDirectory: string): Boolean;
var
  i: Integer;
  lName: string;
begin
  lName := ExtractFileName(aDirectory);

  for i := 0 to Pred(Length(fSkipFolderNames)) do
  begin
    if SameText(lName, Trim(fSkipFolderNames[i])) then
    begin
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure TRepoScanner.RecordRepoRoot(const aRepoRoot: string);
begin
  if Assigned(fDbManager) then
  begin
    fDbManager.UpsertRepoRoot(aRepoRoot);
  end;
end;

function TRepoScanner.ScanForRepoRoots(const aRootPath: string): TArray<string>;
var
  lCanonicalRoot: string;
  lCurrentDir: string;
  lDirectories: TArray<string>;
  lDiscovered: TDictionary<string, Byte>;
  lIsWorktree: Boolean;
  lPending: TList<string>;
  lRoot: string;
  lSubDir: string;
begin
  lDiscovered := TDictionary<string, Byte>.Create;
  lPending := TList<string>.Create;
  try
    lRoot := ExcludeTrailingPathDelimiter(TPath.GetFullPath(aRootPath));
    lPending.Add(lRoot);

    while lPending.Count > 0 do
    begin
      lCurrentDir := lPending[lPending.Count - 1];
      lPending.Delete(lPending.Count - 1);

      if IsSkippedDirectory(lCurrentDir) then
      begin
        Continue;
      end;

      if IsGitRepoRoot(lCurrentDir, fTreatWorktreesAsRepos, lIsWorktree) then
      begin
        lCanonicalRoot := ExcludeTrailingPathDelimiter(TPath.GetFullPath(lCurrentDir));
        if not lDiscovered.ContainsKey(lCanonicalRoot) then
        begin
          lDiscovered.Add(lCanonicalRoot, 1);
          RecordRepoRoot(lCanonicalRoot);
        end;
      end;

      try
        lDirectories := TDirectory.GetDirectories(lCurrentDir);
      except
        on EInOutError do
        begin
          Continue;
        end;
      end;

      for lSubDir in lDirectories do
      begin
        if not IsSkippedDirectory(lSubDir) then
        begin
          lPending.Add(lSubDir);
        end;
      end;
    end;

    Result := lDiscovered.Keys.ToArray;
    TArray.Sort<string>(Result);
  finally
    lPending.Free;
    lDiscovered.Free;
  end;
end;

end.
