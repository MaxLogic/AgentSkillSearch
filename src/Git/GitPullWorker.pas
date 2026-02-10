unit GitPullWorker;

interface

uses
  System.DateUtils, Winapi.Windows;

type
  TGitPullOptions = record
    GitExePath: string;
    GitPullArgs: string;
    GitPullTimeoutSeconds: Integer;
  end;

  TGitPullResult = record
    DurationMs: Integer;
    ExitCode: Integer;
    HeadCommit: string;
    OutputText: string;
    RepoPath: string;
    Status: string;
    TimedOut: Boolean;
    TimestampUtc: string;
  end;

  TGitPullWorker = class
  private
    function BuildEnvironmentBlock: string;
    function ExecuteGitCommand(const aRepoPath, aGitExePath, aArgs: string; const aTimeoutSeconds: Integer): TGitPullResult;
    procedure DrainPipeOutput(const aPipeHandle: THandle; var aOutput: string);
    function ReadHeadCommit(const aRepoPath, aGitExePath: string; const aTimeoutSeconds: Integer): string;
  public
    class function IsThrottled(const aLastPullUtc: string; const aMinPullIntervalMinutes: Integer;
      const aNowUtc: TDateTime): Boolean; static;
    function PullRepo(const aRepoPath: string; const aOptions: TGitPullOptions): TGitPullResult;
  end;

implementation

uses
  System.Classes, System.Diagnostics, System.Math, System.SysUtils;

procedure ApplyEnvironmentOverride(aList: TStringList; const aName, aValue: string);
begin
  aList.Values[aName] := aValue;
end;

function UtcNowIso8601: string;
var
  lUtcNow: TDateTime;
begin
  lUtcNow := TTimeZone.Local.ToUniversalTime(Now);
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', lUtcNow, TFormatSettings.Invariant);
end;

procedure TGitPullWorker.DrainPipeOutput(const aPipeHandle: THandle; var aOutput: string);
var
  lAvailable: Cardinal;
  lBytesRead: Cardinal;
  lBuffer: array[0..4095] of AnsiChar;
  lChunk: AnsiString;
begin
  while True do
  begin
    lAvailable := 0;
    if not PeekNamedPipe(aPipeHandle, nil, 0, nil, @lAvailable, nil) then
    begin
      Exit;
    end;

    if lAvailable = 0 then
    begin
      Exit;
    end;

    if not ReadFile(aPipeHandle, lBuffer[0], Min(Integer(SizeOf(lBuffer)), Integer(lAvailable)), lBytesRead, nil) then
    begin
      Exit;
    end;

    if lBytesRead = 0 then
    begin
      Exit;
    end;

    SetString(lChunk, PAnsiChar(@lBuffer[0]), lBytesRead);
    aOutput := aOutput + string(lChunk);
  end;
end;

function TGitPullWorker.BuildEnvironmentBlock: string;
var
  i: Integer;
  lCurrent: PChar;
  lEntry: string;
  lEnvPtr: PChar;
  lPos: Integer;
  lVars: TStringList;
begin
  lVars := TStringList.Create;
  try
    lVars.CaseSensitive := False;
    lVars.NameValueSeparator := '=';

    lEnvPtr := GetEnvironmentStrings;
    if lEnvPtr <> nil then
    begin
      try
        lCurrent := lEnvPtr;
        while lCurrent^ <> #0 do
        begin
          lEntry := lCurrent;
          if (lEntry <> '') and (lEntry[1] <> '=') then
          begin
            lPos := Pos('=', lEntry);
            if lPos > 1 then
            begin
              lVars.Values[Copy(lEntry, 1, lPos - 1)] := Copy(lEntry, lPos + 1, MaxInt);
            end;
          end;
          Inc(lCurrent, Length(lEntry) + 1);
        end;
      finally
        FreeEnvironmentStrings(lEnvPtr);
      end;
    end;

    ApplyEnvironmentOverride(lVars, 'GIT_TERMINAL_PROMPT', '0');
    ApplyEnvironmentOverride(lVars, 'GCM_INTERACTIVE', 'Never');
    ApplyEnvironmentOverride(lVars, 'GIT_ASKPASS', 'echo');

    Result := '';
    for i := 0 to Pred(lVars.Count) do
    begin
      Result := Result + lVars[i] + #0;
    end;
    Result := Result + #0;
  finally
    lVars.Free;
  end;
end;

function TGitPullWorker.ExecuteGitCommand(const aRepoPath, aGitExePath, aArgs: string;
  const aTimeoutSeconds: Integer): TGitPullResult;
var
  lCommandLine: string;
  lEnvironment: string;
  lExitCode: Cardinal;
  lOutput: string;
  lPipeRead: THandle;
  lPipeWrite: THandle;
  lProcessInfo: TProcessInformation;
  lSecurity: TSecurityAttributes;
  lStartupInfo: TStartupInfo;
  lStopwatch: TStopwatch;
  lTimeoutMs: Integer;
  lWaitResult: Cardinal;
begin
  Result := Default(TGitPullResult);
  Result.RepoPath := aRepoPath;

  lPipeRead := 0;
  lPipeWrite := 0;
  lOutput := '';

  lSecurity := Default(TSecurityAttributes);
  lSecurity.nLength := SizeOf(TSecurityAttributes);
  lSecurity.bInheritHandle := True;
  lSecurity.lpSecurityDescriptor := nil;

  if not CreatePipe(lPipeRead, lPipeWrite, @lSecurity, 0) then
  begin
    RaiseLastOSError;
  end;

  try
    if not SetHandleInformation(lPipeRead, HANDLE_FLAG_INHERIT, 0) then
    begin
      RaiseLastOSError;
    end;

    lStartupInfo := Default(TStartupInfo);
    lStartupInfo.cb := SizeOf(TStartupInfo);
    lStartupInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
    lStartupInfo.wShowWindow := SW_HIDE;
    lStartupInfo.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
    lStartupInfo.hStdOutput := lPipeWrite;
    lStartupInfo.hStdError := lPipeWrite;

    lProcessInfo := Default(TProcessInformation);

    lCommandLine := Format('"%s" %s', [aGitExePath, aArgs]);
    UniqueString(lCommandLine);

    lEnvironment := BuildEnvironmentBlock;
    UniqueString(lEnvironment);

    if not CreateProcess(
      nil,
      PChar(lCommandLine),
      nil,
      nil,
      True,
      CREATE_NO_WINDOW or CREATE_UNICODE_ENVIRONMENT,
      PChar(lEnvironment),
      PChar(aRepoPath),
      lStartupInfo,
      lProcessInfo
    ) then
    begin
      RaiseLastOSError;
    end;

    try
      CloseHandle(lPipeWrite);
      lPipeWrite := 0;

      lTimeoutMs := Max(1, aTimeoutSeconds) * 1000;
      lStopwatch := TStopwatch.StartNew;

      while True do
      begin
        DrainPipeOutput(lPipeRead, lOutput);

        lWaitResult := WaitForSingleObject(lProcessInfo.hProcess, 25);
        if lWaitResult = WAIT_OBJECT_0 then
        begin
          Break;
        end;

        if (lTimeoutMs > 0) and (lStopwatch.ElapsedMilliseconds >= lTimeoutMs) then
        begin
          Result.TimedOut := True;
          TerminateProcess(lProcessInfo.hProcess, 124);
          Break;
        end;
      end;

      WaitForSingleObject(lProcessInfo.hProcess, 500);
      DrainPipeOutput(lPipeRead, lOutput);

      if not GetExitCodeProcess(lProcessInfo.hProcess, lExitCode) then
      begin
        lExitCode := Cardinal(-1);
      end;

      Result.DurationMs := lStopwatch.ElapsedMilliseconds;
      Result.ExitCode := Integer(lExitCode);
      Result.OutputText := Trim(lOutput);
    finally
      CloseHandle(lProcessInfo.hThread);
      CloseHandle(lProcessInfo.hProcess);
    end;
  finally
    if lPipeWrite <> 0 then
    begin
      CloseHandle(lPipeWrite);
    end;

    if lPipeRead <> 0 then
    begin
      CloseHandle(lPipeRead);
    end;
  end;
end;

function TGitPullWorker.ReadHeadCommit(const aRepoPath, aGitExePath: string; const aTimeoutSeconds: Integer): string;
var
  lCommitLine: string;
  lResult: TGitPullResult;
  lRowBreak: Integer;
begin
  lResult := ExecuteGitCommand(aRepoPath, aGitExePath, 'rev-parse HEAD', Min(aTimeoutSeconds, 30));
  if lResult.TimedOut or (lResult.ExitCode <> 0) then
  begin
    Exit('');
  end;

  lCommitLine := StringReplace(lResult.OutputText, #13, '', [rfReplaceAll]);
  lRowBreak := Pos(#10, lCommitLine);
  if lRowBreak > 0 then
  begin
    SetLength(lCommitLine, lRowBreak - 1);
  end;

  Result := Trim(lCommitLine);
end;

class function TGitPullWorker.IsThrottled(const aLastPullUtc: string; const aMinPullIntervalMinutes: Integer;
  const aNowUtc: TDateTime): Boolean;
var
  lLastPullUtc: TDateTime;
begin
  if (aMinPullIntervalMinutes <= 0) or (Trim(aLastPullUtc) = '') then
  begin
    Exit(False);
  end;

  if not TryISO8601ToDate(aLastPullUtc, lLastPullUtc, True) then
  begin
    Exit(False);
  end;

  Result := IncMinute(lLastPullUtc, aMinPullIntervalMinutes) > aNowUtc;
end;

function TGitPullWorker.PullRepo(const aRepoPath: string; const aOptions: TGitPullOptions): TGitPullResult;
var
  lRunResult: TGitPullResult;
begin
  lRunResult := ExecuteGitCommand(aRepoPath, aOptions.GitExePath, aOptions.GitPullArgs, aOptions.GitPullTimeoutSeconds);

  Result := lRunResult;
  Result.RepoPath := aRepoPath;
  Result.TimestampUtc := UtcNowIso8601;
  Result.HeadCommit := ReadHeadCommit(aRepoPath, aOptions.GitExePath, aOptions.GitPullTimeoutSeconds);

  if lRunResult.TimedOut then
  begin
    Result.Status := 'failed (timeout)';
    if Result.OutputText = '' then
    begin
      Result.OutputText := Format('git pull timed out after %d seconds.', [aOptions.GitPullTimeoutSeconds]);
    end;
    Exit;
  end;

  if lRunResult.ExitCode = 0 then
  begin
    Result.Status := 'pulled';
  end else begin
    Result.Status := 'failed';
    if Result.OutputText = '' then
    begin
      Result.OutputText := Format('git pull exited with code %d.', [lRunResult.ExitCode]);
    end;
  end;
end;

end.
