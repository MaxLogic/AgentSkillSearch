unit Settings;

interface

uses
  SettingsModel;

type
  TSettingsLoadResult = record
    RestoredKeys: TArray<string>;
    Settings: TAppSettings;
    SettingsPath: string;
  end;

function GetSettingsFilePath: string;
function LoadOrCreateSettings(const aSettingsPath: string): TSettingsLoadResult;
function ResolveSettingsPath(const aValue, aBaseDirectory: string): string;

implementation

uses
  System.Classes, System.IOUtils, System.IniFiles, System.SysUtils,
  AppPaths, AutoFree;

function ResolveSettingsPath(const aValue, aBaseDirectory: string): string;
begin
  if TPath.IsPathRooted(aValue) then
  begin
    Result := TPath.GetFullPath(aValue);
  end else begin
    Result := TPath.GetFullPath(TPath.Combine(aBaseDirectory, aValue));
  end;
end;

function GetSettingsFilePath: string;
begin
  Result := TPath.Combine(GetExeDirectory, 'settings.ini');
end;

function GetDefaultSourcesListTemplate: string;
begin
  Result :=
    '# Agent Skill Search sources list' + sLineBreak +
    '# One path per line. Supported comments: # ; //' + sLineBreak +
    '# Example: C:\projects\MaxLogic' + sLineBreak +
    '# Example: \\server\share\skills' + sLineBreak;
end;

function GetDefaultExcludesListTemplate: string;
begin
  Result :=
    '# Agent Skill Search exclusion patterns' + sLineBreak +
    '# Lines are case-insensitive substring or wildcard (*, ?) matches against full paths.' + sLineBreak +
    '# Seeded from diagnostics scan report 2026-02-11 (OpenClaw harness fixtures).' + sLineBreak +
    '*\OpenClaw\skills\skills\oakencore\skillvet\tests\fixtures\*' + sLineBreak +
    '*\OpenClaw\skills\skills\*\tmp\credentials-backup-*\*' + sLineBreak;
end;

procedure EnsureSourcesListTemplate(const aSourcesListPath: string);
begin
  if TFile.Exists(aSourcesListPath) then
  begin
    Exit;
  end;

  ForceDirectories(ExtractFilePath(aSourcesListPath));
  TFile.WriteAllText(aSourcesListPath, GetDefaultSourcesListTemplate, TEncoding.UTF8);
end;

procedure EnsureExcludesListTemplate(const aExcludesListPath: string);
begin
  if TFile.Exists(aExcludesListPath) then
  begin
    Exit;
  end;

  ForceDirectories(ExtractFilePath(aExcludesListPath));
  TFile.WriteAllText(aExcludesListPath, GetDefaultExcludesListTemplate, TEncoding.UTF8);
end;

procedure AddRestoredKey(var aResult: TSettingsLoadResult; const aSection, aKey: string);
var
  lLen: Integer;
begin
  lLen := Length(aResult.RestoredKeys);
  SetLength(aResult.RestoredKeys, lLen + 1);
  aResult.RestoredKeys[lLen] := aSection + '.' + aKey;
end;

function BoolToIniValue(const aValue: Boolean): string;
begin
  if aValue then
  begin
    Result := '1';
  end else begin
    Result := '0';
  end;
end;

function IniValueToBool(const aValue: string; const aDefault: Boolean; out aValid: Boolean): Boolean;
var
  lBoolValue: Boolean;
  lIntValue: Integer;
  lTrimmed: string;
begin
  lTrimmed := Trim(aValue);
  if lTrimmed = '' then
  begin
    aValid := False;
    Exit(aDefault);
  end;

  if TryStrToInt(lTrimmed, lIntValue) then
  begin
    if (lIntValue = 0) or (lIntValue = 1) then
    begin
      aValid := True;
      Exit(lIntValue = 1);
    end;
    aValid := False;
    Exit(aDefault);
  end;

  if TryStrToBool(lTrimmed, lBoolValue) then
  begin
    aValid := True;
    Exit(lBoolValue);
  end;

  aValid := False;
  Result := aDefault;
end;

function ReadRequiredString(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey, aDefault: string): string;
begin
  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, aDefault);
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  Result := Trim(aIni.ReadString(aSection, aKey, aDefault));
  if Result = '' then
  begin
    aIni.WriteString(aSection, aKey, aDefault);
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;
end;

function ReadRequiredInteger(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey: string;
  const aDefault: Integer): Integer;
var
  lRaw: string;
begin
  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, IntToStr(aDefault));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  lRaw := Trim(aIni.ReadString(aSection, aKey, IntToStr(aDefault)));
  if (not TryStrToInt(lRaw, Result)) then
  begin
    aIni.WriteString(aSection, aKey, IntToStr(aDefault));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;
end;

function ReadRequiredFloat(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey: string;
  const aDefault: Double): Double;
var
  lRaw: string;
  lInvariant: TFormatSettings;
begin
  lInvariant := TFormatSettings.Invariant;

  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, FloatToStr(aDefault, lInvariant));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  lRaw := Trim(aIni.ReadString(aSection, aKey, FloatToStr(aDefault, lInvariant)));
  if (not TryStrToFloat(lRaw, Result, lInvariant)) then
  begin
    aIni.WriteString(aSection, aKey, FloatToStr(aDefault, lInvariant));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;
end;

function ReadRequiredBool(aIni: TMemIniFile; var aResult: TSettingsLoadResult; const aSection, aKey: string;
  const aDefault: Boolean): Boolean;
var
  lRaw: string;
  lValid: Boolean;
begin
  if not aIni.ValueExists(aSection, aKey) then
  begin
    aIni.WriteString(aSection, aKey, BoolToIniValue(aDefault));
    AddRestoredKey(aResult, aSection, aKey);
    Exit(aDefault);
  end;

  lRaw := aIni.ReadString(aSection, aKey, BoolToIniValue(aDefault));
  Result := IniValueToBool(lRaw, aDefault, lValid);
  if not lValid then
  begin
    aIni.WriteString(aSection, aKey, BoolToIniValue(aDefault));
    AddRestoredKey(aResult, aSection, aKey);
    Result := aDefault;
  end;
end;

procedure WriteSettingsRecoveryLog(const aSettings: TAppSettings; const aBaseDirectory: string;
  const aRestoredKeys: TArray<string>);
var
  i: Integer;
  lLine: string;
  lLogPath: string;
begin
  if Length(aRestoredKeys) = 0 then
  begin
    Exit;
  end;

  lLogPath := ResolveSettingsPath(aSettings.General.LogPath, aBaseDirectory);
  ForceDirectories(ExtractFilePath(lLogPath));

  for i := 0 to Pred(Length(aRestoredKeys)) do
  begin
    lLine := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' [settings] restored missing key: ' + aRestoredKeys[i] + sLineBreak;
    TFile.AppendAllText(lLogPath, lLine, TEncoding.UTF8);
  end;
end;

function LoadOrCreateSettings(const aSettingsPath: string): TSettingsLoadResult;
var
  lDefault: TAppSettings;
  lIni: TMemIniFile;
  lSettingsDir: string;
begin
  lDefault := DefaultAppSettings;
  Result.SettingsPath := aSettingsPath;

  lSettingsDir := IncludeTrailingPathDelimiter(ExtractFilePath(aSettingsPath));
  ForceDirectories(lSettingsDir);

  lIni := TMemIniFile.Create(aSettingsPath, TEncoding.UTF8);
  try
    Result.Settings.General.SourcesListPath := ReadRequiredString(lIni, Result, 'General', 'SourcesListPath',
      lDefault.General.SourcesListPath);
    Result.Settings.General.CacheDbPath := ReadRequiredString(lIni, Result, 'General', 'CacheDbPath',
      lDefault.General.CacheDbPath);
    Result.Settings.General.ExcludesListPath := ReadRequiredString(lIni, Result, 'General', 'ExcludesListPath',
      lDefault.General.ExcludesListPath);
    Result.Settings.General.LogPath := ReadRequiredString(lIni, Result, 'General', 'LogPath',
      lDefault.General.LogPath);
    Result.Settings.General.MaxScanThreads := ReadRequiredInteger(lIni, Result, 'General', 'MaxScanThreads',
      lDefault.General.MaxScanThreads);
    Result.Settings.General.MaxGitPullThreads := ReadRequiredInteger(lIni, Result, 'General', 'MaxGitPullThreads',
      lDefault.General.MaxGitPullThreads);
    Result.Settings.General.MaxIndexThreads := ReadRequiredInteger(lIni, Result, 'General', 'MaxIndexThreads',
      lDefault.General.MaxIndexThreads);
    Result.Settings.General.MaxSearchThreads := ReadRequiredInteger(lIni, Result, 'General', 'MaxSearchThreads',
      lDefault.General.MaxSearchThreads);

    Result.Settings.Git.GitExePath := ReadRequiredString(lIni, Result, 'Git', 'GitExePath', lDefault.Git.GitExePath);
    Result.Settings.Git.PullEnabled := ReadRequiredBool(lIni, Result, 'Git', 'PullEnabled', lDefault.Git.PullEnabled);
    Result.Settings.Git.MinPullIntervalMinutes := ReadRequiredInteger(lIni, Result, 'Git',
      'MinPullIntervalMinutes', lDefault.Git.MinPullIntervalMinutes);
    Result.Settings.Git.GitPullTimeoutSeconds := ReadRequiredInteger(lIni, Result, 'Git',
      'GitPullTimeoutSeconds', lDefault.Git.GitPullTimeoutSeconds);
    Result.Settings.Git.GitPullArgs := ReadRequiredString(lIni, Result, 'Git', 'GitPullArgs',
      lDefault.Git.GitPullArgs);
    Result.Settings.Git.SkipFolders := ReadRequiredString(lIni, Result, 'Git', 'SkipFolders',
      lDefault.Git.SkipFolders);
    Result.Settings.Git.TreatWorktreesAsRepos := ReadRequiredBool(lIni, Result, 'Git', 'TreatWorktreesAsRepos',
      lDefault.Git.TreatWorktreesAsRepos);

    Result.Settings.Index.SkillFileName := ReadRequiredString(lIni, Result, 'Index', 'SkillFileName',
      lDefault.Index.SkillFileName);
    Result.Settings.Index.MaxSkillFileBytes := ReadRequiredInteger(lIni, Result, 'Index', 'MaxSkillFileBytes',
      lDefault.Index.MaxSkillFileBytes);
    Result.Settings.Index.ComputeHasScripts := ReadRequiredBool(lIni, Result, 'Index', 'ComputeHasScripts',
      lDefault.Index.ComputeHasScripts);
    Result.Settings.Index.ScriptExtensions := ReadRequiredString(lIni, Result, 'Index', 'ScriptExtensions',
      lDefault.Index.ScriptExtensions);
    Result.Settings.Index.HasScriptsMaxFilesToScan := ReadRequiredInteger(lIni, Result, 'Index',
      'HasScriptsMaxFilesToScan', lDefault.Index.HasScriptsMaxFilesToScan);
    Result.Settings.Index.HasScriptsSkipFolders := ReadRequiredString(lIni, Result, 'Index',
      'HasScriptsSkipFolders', lDefault.Index.HasScriptsSkipFolders);
    Result.Settings.Index.NormalizeLineEndings := ReadRequiredBool(lIni, Result, 'Index', 'NormalizeLineEndings',
      lDefault.Index.NormalizeLineEndings);

    Result.Settings.Docker.StartGpuCommand := ReadRequiredString(lIni, Result, 'Docker', 'StartGpuCommand',
      lDefault.Docker.StartGpuCommand);
    Result.Settings.Docker.HealthCheckCommand := ReadRequiredString(lIni, Result, 'Docker', 'HealthCheckCommand',
      lDefault.Docker.HealthCheckCommand);

    Result.Settings.Search.SearchAsYouType := ReadRequiredBool(lIni, Result, 'Search', 'SearchAsYouType',
      lDefault.Search.SearchAsYouType);
    Result.Settings.Search.SearchDebounceMs := ReadRequiredInteger(lIni, Result, 'Search', 'SearchDebounceMs',
      lDefault.Search.SearchDebounceMs);
    Result.Settings.Search.MaxResults := ReadRequiredInteger(lIni, Result, 'Search', 'MaxResults',
      lDefault.Search.MaxResults);
    Result.Settings.Search.SnippetMaxChars := ReadRequiredInteger(lIni, Result, 'Search', 'SnippetMaxChars',
      lDefault.Search.SnippetMaxChars);

    Result.Settings.Semantic.Enabled := ReadRequiredBool(lIni, Result, 'Semantic', 'Enabled',
      lDefault.Semantic.Enabled);
    Result.Settings.Semantic.Provider := ReadRequiredString(lIni, Result, 'Semantic', 'Provider',
      lDefault.Semantic.Provider);
    Result.Settings.Semantic.OllamaBaseUrl := ReadRequiredString(lIni, Result, 'Semantic', 'OllamaBaseUrl',
      lDefault.Semantic.OllamaBaseUrl);
    Result.Settings.Semantic.Model := ReadRequiredString(lIni, Result, 'Semantic', 'Model', lDefault.Semantic.Model);
    Result.Settings.Semantic.CandidateRerankCount := ReadRequiredInteger(lIni, Result, 'Semantic',
      'CandidateRerankCount', lDefault.Semantic.CandidateRerankCount);
    Result.Settings.Semantic.MinScoreToShow := ReadRequiredFloat(lIni, Result, 'Semantic', 'MinScoreToShow',
      lDefault.Semantic.MinScoreToShow);
    Result.Settings.Semantic.EmbeddingCache := ReadRequiredBool(lIni, Result, 'Semantic', 'EmbeddingCache',
      lDefault.Semantic.EmbeddingCache);

    Result.Settings.Ui.ShowPreviewPane := ReadRequiredBool(lIni, Result, 'UI', 'ShowPreviewPane',
      lDefault.Ui.ShowPreviewPane);
    Result.Settings.Ui.OpenFileOnEnter := ReadRequiredBool(lIni, Result, 'UI', 'OpenFileOnEnter',
      lDefault.Ui.OpenFileOnEnter);

    lIni.UpdateFile;
  finally
    lIni.Free;
  end;

  EnsureSourcesListTemplate(ResolveSettingsPath(Result.Settings.General.SourcesListPath, lSettingsDir));
  EnsureExcludesListTemplate(ResolveSettingsPath(Result.Settings.General.ExcludesListPath, lSettingsDir));
  WriteSettingsRecoveryLog(Result.Settings, lSettingsDir, Result.RestoredKeys);
end;

end.
