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

function BuildGitPullRepairActions(const aReason: TGitPullFailureReason): TArray<TGitPullRepairAction>;
function ClassifyGitPullFailure(const aOutput: string): TGitPullFailureReason;

implementation

uses
  System.StrUtils, System.SysUtils;

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

end.
