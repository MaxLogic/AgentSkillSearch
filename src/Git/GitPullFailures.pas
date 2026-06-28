unit GitPullFailures;

interface

type
  TGitPullFailureReason = (gfrUnknown, gfrLocalChanges, gfrDiverged, gfrStaleRemoteRefs, gfrRemoteMissing,
    gfrAuthentication);
  TGitPullRepairActionKind = (gpaStashChanges, gpaDiscardChanges, gpaFetch, gpaResetToUpstream, gpaPruneRemote);

  TGitPullRepairAction = record
    Caption: string;
    IsDestructive: Boolean;
    Kind: TGitPullRepairActionKind;
    RequiresConfirmation: Boolean;
  end;

  TGitPullRepairResult = record
    ActionKind: TGitPullRepairActionKind;
    ExitCode: Integer;
    OutputText: string;
    RepoPath: string;
    Success: Boolean;
  end;

function BuildGitPullRepairActions(const aReason: TGitPullFailureReason): TArray<TGitPullRepairAction>;
function ClassifyGitPullFailure(const aOutput: string): TGitPullFailureReason;
function ExecuteGitPullRepair(const aRepoPath, aGitExePath: string; const aActionKind: TGitPullRepairActionKind;
  const aConfirmed: Boolean): TGitPullRepairResult;
function ExecuteGitPullRepairGroup(const aRepoPaths: TArray<string>; const aGitExePath: string;
  const aActionKind: TGitPullRepairActionKind; const aConfirmed: Boolean): TArray<TGitPullRepairResult>;

implementation

uses
  System.StrUtils, System.SysUtils,
  GitPullWorker;

function BuildAction(const aKind: TGitPullRepairActionKind; const aCaption: string; const aRequiresConfirmation,
  aIsDestructive: Boolean): TGitPullRepairAction;
begin
  Result.Kind := aKind;
  Result.Caption := aCaption;
  Result.RequiresConfirmation := aRequiresConfirmation;
  Result.IsDestructive := aIsDestructive;
end;

function BuildGitPullRepairActions(const aReason: TGitPullFailureReason): TArray<TGitPullRepairAction>;
begin
  case aReason of
    TGitPullFailureReason.gfrLocalChanges:
      Result := [
        BuildAction(TGitPullRepairActionKind.gpaStashChanges, 'Stash changes', False, False),
        BuildAction(TGitPullRepairActionKind.gpaDiscardChanges, 'Discard changes', True, True)
      ];
    TGitPullFailureReason.gfrDiverged:
      Result := [
        BuildAction(TGitPullRepairActionKind.gpaFetch, 'Fetch', False, False),
        BuildAction(TGitPullRepairActionKind.gpaResetToUpstream, 'Reset to upstream', True, True)
      ];
    TGitPullFailureReason.gfrStaleRemoteRefs:
      Result := [BuildAction(TGitPullRepairActionKind.gpaPruneRemote, 'Prune remote refs', False, False)];
  else
    Result := nil;
  end;
end;

function ClassifyGitPullFailure(const aOutput: string): TGitPullFailureReason;
var
  lText: string;
begin
  lText := LowerCase(aOutput);

  if (ContainsText(lText, 'your local changes') and ContainsText(lText, 'would be overwritten')) or
    ContainsText(lText, 'please commit your changes or stash them') or
    ContainsText(lText, 'untracked working tree files would be overwritten') then
  begin
    Exit(TGitPullFailureReason.gfrLocalChanges);
  end;

  if ContainsText(lText, 'some local refs could not be updated') or ContainsText(lText, 'cannot lock ref') or
    ContainsText(lText, 'cannot create ''refs/remotes') then
  begin
    Exit(TGitPullFailureReason.gfrStaleRemoteRefs);
  end;

  if ContainsText(lText, 'not possible to fast-forward') or ContainsText(lText, 'diverging branches') then
  begin
    Exit(TGitPullFailureReason.gfrDiverged);
  end;

  if ContainsText(lText, 'repository not found') then
  begin
    Exit(TGitPullFailureReason.gfrRemoteMissing);
  end;

  if ContainsText(lText, 'authentication failed') or ContainsText(lText, 'terminal prompts disabled') or
    ContainsText(lText, 'could not read username') then
  begin
    Exit(TGitPullFailureReason.gfrAuthentication);
  end;

  Result := TGitPullFailureReason.gfrUnknown;
end;

function BuildBlockedRepairResult(const aRepoPath: string; const aActionKind: TGitPullRepairActionKind): TGitPullRepairResult;
begin
  Result.ActionKind := aActionKind;
  Result.ExitCode := -1;
  Result.OutputText := 'Repair requires confirmation.';
  Result.RepoPath := aRepoPath;
  Result.Success := False;
end;

function RunRepairCommand(const aRepoPath, aGitExePath, aArgs: string;
  const aActionKind: TGitPullRepairActionKind): TGitPullRepairResult;
var
  lGitResult: TGitPullResult;
  lWorker: TGitPullWorker;
begin
  lWorker := TGitPullWorker.Create;
  try
    try
      lGitResult := lWorker.ExecuteGitCommand(aRepoPath, aGitExePath, aArgs, 120);
    except
      on E: Exception do
      begin
        Result.ActionKind := aActionKind;
        Result.ExitCode := -1;
        Result.OutputText := E.Message;
        Result.RepoPath := aRepoPath;
        Result.Success := False;
        Exit;
      end;
    end;
  finally
    lWorker.Free;
  end;

  Result.ActionKind := aActionKind;
  Result.ExitCode := lGitResult.ExitCode;
  Result.OutputText := lGitResult.OutputText;
  Result.RepoPath := aRepoPath;
  Result.Success := (not lGitResult.TimedOut) and (lGitResult.ExitCode = 0);
end;

function RunRepairCommandSequence(const aRepoPath, aGitExePath: string; const aActionKind: TGitPullRepairActionKind;
  const aArgs: TArray<string>): TGitPullRepairResult;
var
  i: Integer;
  lStep: TGitPullRepairResult;
begin
  Result.ActionKind := aActionKind;
  Result.ExitCode := 0;
  Result.OutputText := '';
  Result.RepoPath := aRepoPath;
  Result.Success := True;

  for i := 0 to Pred(Length(aArgs)) do
  begin
    lStep := RunRepairCommand(aRepoPath, aGitExePath, aArgs[i], aActionKind);
    if Trim(lStep.OutputText) <> '' then
    begin
      if Result.OutputText <> '' then
      begin
        Result.OutputText := Result.OutputText + sLineBreak;
      end;
      Result.OutputText := Result.OutputText + lStep.OutputText;
    end;

    Result.ExitCode := lStep.ExitCode;
    Result.Success := lStep.Success;
    if not Result.Success then
    begin
      Break;
    end;
  end;
end;

function ExecuteGitPullRepair(const aRepoPath, aGitExePath: string; const aActionKind: TGitPullRepairActionKind;
  const aConfirmed: Boolean): TGitPullRepairResult;
begin
  case aActionKind of
    TGitPullRepairActionKind.gpaStashChanges:
      Result := RunRepairCommand(aRepoPath, aGitExePath, 'stash push -u -m "AgentSkillSearch repair stash"', aActionKind);
    TGitPullRepairActionKind.gpaFetch:
      Result := RunRepairCommand(aRepoPath, aGitExePath, 'fetch --all --prune', aActionKind);
    TGitPullRepairActionKind.gpaPruneRemote:
      Result := RunRepairCommand(aRepoPath, aGitExePath, 'remote prune origin', aActionKind);
    TGitPullRepairActionKind.gpaDiscardChanges:
      begin
        if not aConfirmed then
        begin
          Exit(BuildBlockedRepairResult(aRepoPath, aActionKind));
        end;
        Result := RunRepairCommandSequence(aRepoPath, aGitExePath, aActionKind, ['reset --hard', 'clean -fd']);
      end;
    TGitPullRepairActionKind.gpaResetToUpstream:
      begin
        if not aConfirmed then
        begin
          Exit(BuildBlockedRepairResult(aRepoPath, aActionKind));
        end;
        Result := RunRepairCommandSequence(aRepoPath, aGitExePath, aActionKind,
          ['fetch --all --prune', 'reset --hard @{u}', 'clean -fd']);
      end;
  else
    Result := BuildBlockedRepairResult(aRepoPath, aActionKind);
  end;
end;

function ExecuteGitPullRepairGroup(const aRepoPaths: TArray<string>; const aGitExePath: string;
  const aActionKind: TGitPullRepairActionKind; const aConfirmed: Boolean): TArray<TGitPullRepairResult>;
var
  i: Integer;
begin
  SetLength(Result, Length(aRepoPaths));
  for i := 0 to Pred(Length(aRepoPaths)) do
  begin
    Result[i] := ExecuteGitPullRepair(aRepoPaths[i], aGitExePath, aActionKind, aConfirmed);
  end;
end;

end.
