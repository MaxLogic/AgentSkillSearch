unit AppUpdateActions;

interface

uses
  SettingsModel,
  MaxLogic.GitHubReleaseChecker;

const
  cUpdateRepoOwner = 'MaxLogic';
  cUpdateRepoName = 'AgentSkillSearch';

type
  TUpdatePromptInfo = record
    CurrentVersion: string;
    LatestVersion: string;
    ReleaseName: string;
    ReleaseUrl: string;
    Headline: string;
    BodyText: string;
    DetailText: string;
  end;

function BuildReleasePageFallbackUrl: string;
function BuildUpdatePromptInfo(const aCurrentVersion: string; const aRelease: TGitHubReleaseInfo): TUpdatePromptInfo;
function NormalizeCurrentAppVersion(const aVersion: string): string;
function ShouldCheckForUpdatesOnStartup(const aUiSettings: TUiSettings): Boolean;
function ShouldPromptForAppUpdate(const aResult: TGitHubReleaseCheckResult): Boolean;

implementation

uses
  System.SysUtils;

function BuildReleasePageFallbackUrl: string;
begin
  Result := 'https://github.com/' + cUpdateRepoOwner + '/' + cUpdateRepoName + '/releases';
end;

function NormalizeCurrentAppVersion(const aVersion: string): string;
begin
  Result := Trim(aVersion);
  if (Result <> '') and (Result[1] <> 'v') and (Result[1] <> 'V') then
  begin
    Exit(Result);
  end;

  if (Result <> '') and ((Result[1] = 'v') or (Result[1] = 'V')) then
  begin
    Delete(Result, 1, 1);
  end;
end;

function BuildUpdatePromptInfo(const aCurrentVersion: string; const aRelease: TGitHubReleaseInfo): TUpdatePromptInfo;
var
  lDisplayName: string;
begin
  Result := Default(TUpdatePromptInfo);
  Result.CurrentVersion := NormalizeCurrentAppVersion(aCurrentVersion);
  Result.LatestVersion := aRelease.TagName;
  Result.ReleaseName := aRelease.DisplayName;
  Result.ReleaseUrl := Trim(aRelease.HtmlUrl);
  if Result.ReleaseUrl = '' then
  begin
    Result.ReleaseUrl := BuildReleasePageFallbackUrl;
  end;

  lDisplayName := Result.ReleaseName;
  if lDisplayName = '' then
  begin
    lDisplayName := Result.LatestVersion;
  end;

  Result.Headline := 'A fresh build just landed.';
  Result.BodyText :=
    'Good news: there is a newer Agent Skill Search release waiting for us. ' +
    'No dramatic cliffhanger, just a tidier build ready to be picked up.';
  Result.DetailText :=
    Format('Current: %s   Latest: %s   Release: %s', [Result.CurrentVersion, Result.LatestVersion, lDisplayName]);
end;

function ShouldCheckForUpdatesOnStartup(const aUiSettings: TUiSettings): Boolean;
begin
  Result := aUiSettings.CheckForUpdatesOnStartup;
end;

function ShouldPromptForAppUpdate(const aResult: TGitHubReleaseCheckResult): Boolean;
var
  lCurrentVersion: string;
begin
  lCurrentVersion := NormalizeCurrentAppVersion(aResult.CurrentVersion);
  Result :=
    (aResult.Status = TGitHubReleaseCheckStatus.gcsSuccess) and
    (lCurrentVersion <> '') and
    (Trim(aResult.LatestRelease.TagName) <> '') and
    (TMaxGitHubReleaseChecker.CompareVersionTags(aResult.LatestRelease.TagName, lCurrentVersion) > 0);
end;

end.
