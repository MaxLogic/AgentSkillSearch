unit Logging;

interface

type
  TScanSummary = record
    CompletedUtc: string;
    ErrorCount: Integer;
    ReposFailed: Integer;
    ReposFound: Integer;
    ReposPulled: Integer;
    ReposThrottled: Integer;
    SkillsUnique: Integer;
    SkillsValid: Integer;
    SkillsQueued: Integer;
    SkillsWritten: Integer;
  end;

procedure InitLogging(const aLogPath: string);
procedure LogError(const aMessage: string);
procedure LogInfo(const aMessage: string);
procedure RecordPipelineError(const aMessage: string);
procedure RecordPipelineNotice(const aMessage: string);
procedure RecordScanSummary(const aSummary: TScanSummary);
function BuildDiagnosticsText: string;

implementation

uses
  System.Classes, System.DateUtils, System.IOUtils, System.SyncObjs, System.SysUtils;

var
  gLock: TCriticalSection;
  gLastSummary: TScanSummary;
  gLogPath: string;
  gRecentNotices: TStringList;
  gRecentErrors: TStringList;

function UtcNowIso8601: string;
var
  lUtcNow: TDateTime;
begin
  lUtcNow := TTimeZone.Local.ToUniversalTime(Now);
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', lUtcNow, TFormatSettings.Invariant);
end;

procedure AppendLogLine(const aLevel, aMessage: string);
var
  lLine: string;
begin
  if Trim(gLogPath) = '' then
  begin
    Exit;
  end;

  ForceDirectories(ExtractFilePath(gLogPath));
  lLine := Format('%s [%s] %s%s', [UtcNowIso8601, aLevel, aMessage, sLineBreak]);
  TFile.AppendAllText(gLogPath, lLine, TEncoding.UTF8);
end;

procedure PushRecentError(const aMessage: string);
begin
  gRecentErrors.Add(Format('%s %s', [UtcNowIso8601, aMessage]));
  while gRecentErrors.Count > 40 do
  begin
    gRecentErrors.Delete(0);
  end;
end;

procedure PushRecentNotice(const aMessage: string);
begin
  gRecentNotices.Add(Format('%s %s', [UtcNowIso8601, aMessage]));
  while gRecentNotices.Count > 40 do
  begin
    gRecentNotices.Delete(0);
  end;
end;

procedure InitLogging(const aLogPath: string);
begin
  gLock.Enter;
  try
    gLogPath := aLogPath;
    AppendLogLine('INFO', 'logging initialized');
  finally
    gLock.Leave;
  end;
end;

procedure LogInfo(const aMessage: string);
begin
  gLock.Enter;
  try
    AppendLogLine('INFO', aMessage);
  finally
    gLock.Leave;
  end;
end;

procedure LogError(const aMessage: string);
begin
  gLock.Enter;
  try
    AppendLogLine('ERROR', aMessage);
    PushRecentError(aMessage);
  finally
    gLock.Leave;
  end;
end;

procedure RecordPipelineError(const aMessage: string);
begin
  LogError('pipeline: ' + aMessage);
end;

procedure RecordPipelineNotice(const aMessage: string);
begin
  gLock.Enter;
  try
    AppendLogLine('INFO', 'pipeline: ' + aMessage);
    PushRecentNotice(aMessage);
  finally
    gLock.Leave;
  end;
end;

procedure RecordScanSummary(const aSummary: TScanSummary);
begin
  gLock.Enter;
  try
    gLastSummary := aSummary;
    AppendLogLine(
      'INFO',
      Format(
        'scan summary repos(found=%d,pulled=%d,throttled=%d,failed=%d) skills(found=%d,written=%d,valid=%d,unique=%d) errors=%d',
        [aSummary.ReposFound, aSummary.ReposPulled, aSummary.ReposThrottled, aSummary.ReposFailed,
         aSummary.SkillsQueued, aSummary.SkillsWritten, aSummary.SkillsValid, aSummary.SkillsUnique, aSummary.ErrorCount]
      )
    );
  finally
    gLock.Leave;
  end;
end;

function BuildDiagnosticsText: string;
var
  i: Integer;
  lOutput: TStringList;
begin
  gLock.Enter;
  try
    lOutput := TStringList.Create;
    try
      lOutput.Add('Diagnostics');
      lOutput.Add('');
      lOutput.Add('Log path: ' + gLogPath);
      lOutput.Add('');
      lOutput.Add('Last scan summary:');
      lOutput.Add('  CompletedUtc: ' + gLastSummary.CompletedUtc);
      lOutput.Add(Format('  Repos Found/Pulled/Throttled/Failed: %d / %d / %d / %d',
        [gLastSummary.ReposFound, gLastSummary.ReposPulled, gLastSummary.ReposThrottled, gLastSummary.ReposFailed]));
      lOutput.Add(
        Format(
          '  Skills Found/Written/Valid/Unique: %d / %d / %d / %d',
          [gLastSummary.SkillsQueued, gLastSummary.SkillsWritten, gLastSummary.SkillsValid, gLastSummary.SkillsUnique]
        )
      );
      lOutput.Add(Format('  Errors: %d', [gLastSummary.ErrorCount]));
      lOutput.Add('');
      lOutput.Add('Recent notices:');
      if gRecentNotices.Count = 0 then
      begin
        lOutput.Add('  (none)');
      end else begin
        for i := Pred(gRecentNotices.Count) downto 0 do
        begin
          lOutput.Add('  ' + gRecentNotices[i]);
        end;
      end;
      lOutput.Add('');
      lOutput.Add('Recent errors:');
      if gRecentErrors.Count = 0 then
      begin
        lOutput.Add('  (none)');
      end else begin
        for i := Pred(gRecentErrors.Count) downto 0 do
        begin
          lOutput.Add('  ' + gRecentErrors[i]);
        end;
      end;

      Result := lOutput.Text;
    finally
      lOutput.Free;
    end;
  finally
    gLock.Leave;
  end;
end;

initialization
  gLock := TCriticalSection.Create;
  gRecentNotices := TStringList.Create;
  gRecentErrors := TStringList.Create;
  gLastSummary := Default(TScanSummary);
  gLogPath := '';

finalization
  gRecentNotices.Free;
  gRecentErrors.Free;
  gLock.Free;

end.
