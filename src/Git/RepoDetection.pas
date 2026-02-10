unit RepoDetection;

interface

function IsGitRepoRoot(const aDirectory: string; const aTreatWorktreesAsRepos: Boolean; out aIsWorktree: Boolean): Boolean;

implementation

uses
  System.IOUtils;

function IsGitRepoRoot(const aDirectory: string; const aTreatWorktreesAsRepos: Boolean; out aIsWorktree: Boolean): Boolean;
var
  lDotGitDir: string;
  lDotGitFile: string;
begin
  lDotGitDir := TPath.Combine(aDirectory, '.git');
  lDotGitFile := lDotGitDir;

  if TDirectory.Exists(lDotGitDir) then
  begin
    aIsWorktree := False;
    Exit(True);
  end;

  if TFile.Exists(lDotGitFile) then
  begin
    aIsWorktree := True;
    Exit(aTreatWorktreesAsRepos);
  end;

  aIsWorktree := False;
  Result := False;
end;

end.
