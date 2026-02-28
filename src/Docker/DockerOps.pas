unit DockerOps;

interface

uses
  Winapi.Windows;

type
  TDockerCommandResult = record
    ExitCode: Integer;
    OutputText: string;
    Success: Boolean;
    TimedOut: Boolean;
  end;

function CheckDockerHealth(const aHealthCheckCommand: string; const aTimeoutSeconds: Integer = 8): TDockerCommandResult;
function CheckOllamaHealth(const aDockerCheckCommand: string; const aTimeoutSeconds: Integer = 8): TDockerCommandResult;
function RunDockerCommand(const aCommandLine: string; const aTimeoutSeconds: Integer = 30): TDockerCommandResult;
function StartDockerGpuStack(const aStartCommand: string; const aTimeoutSeconds: Integer = 30): TDockerCommandResult;

implementation

uses
  System.Diagnostics, System.Math, System.SysUtils;

const
  cInspectOllamaStateCommand =
    'docker inspect --type container --format "{{if .State.Running}}running{{else}}stopped{{end}}|' +
    '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}" ollama';

procedure DrainPipeOutput(const aPipeHandle: THandle; var aOutput: string);
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

function RunDockerCommand(const aCommandLine: string; const aTimeoutSeconds: Integer): TDockerCommandResult;
var
  lCmdLine: string;
  lExitCode: Cardinal;
  lPipeRead: THandle;
  lPipeWrite: THandle;
  lOutput: string;
  lProcessInfo: TProcessInformation;
  lSecurity: TSecurityAttributes;
  lStartupInfo: TStartupInfo;
  lStopwatch: TStopwatch;
  lTimeoutMs: Integer;
  lWaitResult: Cardinal;
begin
  Result := Default(TDockerCommandResult);
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
    lCmdLine := 'cmd.exe /d /s /c "' + aCommandLine + '"';
    UniqueString(lCmdLine);

    if not CreateProcess(
      nil,
      PChar(lCmdLine),
      nil,
      nil,
      True,
      CREATE_NO_WINDOW,
      nil,
      nil,
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

      Result.ExitCode := Integer(lExitCode);
      Result.OutputText := Trim(lOutput);
      Result.Success := (not Result.TimedOut) and (Result.ExitCode = 0);
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

function StartDockerGpuStack(const aStartCommand: string; const aTimeoutSeconds: Integer): TDockerCommandResult;
begin
  Result := RunDockerCommand(aStartCommand, aTimeoutSeconds);
end;

function CheckDockerHealth(const aHealthCheckCommand: string; const aTimeoutSeconds: Integer): TDockerCommandResult;
begin
  Result := RunDockerCommand(aHealthCheckCommand, aTimeoutSeconds);
end;

function CheckOllamaHealth(const aDockerCheckCommand: string; const aTimeoutSeconds: Integer): TDockerCommandResult;
var
  lContainerHealth: string;
  lContainerState: string;
  lDockerResult: TDockerCommandResult;
  lInspectResult: TDockerCommandResult;
  lSepPos: Integer;
begin
  lInspectResult := RunDockerCommand(cInspectOllamaStateCommand, aTimeoutSeconds);
  if lInspectResult.Success then
  begin
    lContainerState := Trim(lInspectResult.OutputText);
    lContainerHealth := 'none';
    lSepPos := Pos('|', lContainerState);
    if lSepPos > 0 then
    begin
      lContainerHealth := Trim(Copy(lContainerState, lSepPos + 1, MaxInt));
      lContainerState := Trim(Copy(lContainerState, 1, lSepPos - 1));
    end;

    if SameText(lContainerState, 'running') then
    begin
      Result := lInspectResult;
      Result.Success := SameText(lContainerHealth, 'none') or SameText(lContainerHealth, 'healthy');
      if Result.Success then
      begin
        if SameText(lContainerHealth, 'healthy') then
        begin
          Result.OutputText := 'ollama container running (healthy)';
        end else begin
          Result.OutputText := 'ollama container running';
        end;
      end else begin
        Result.OutputText := 'ollama container running but unhealthy (' + lContainerHealth + ')';
      end;
      Exit;
    end;
  end;

  lDockerResult := CheckDockerHealth(aDockerCheckCommand, aTimeoutSeconds);
  if lDockerResult.Success then
  begin
    Result := lInspectResult;
    Result.Success := False;
    Result.TimedOut := lInspectResult.TimedOut;
    Result.ExitCode := lInspectResult.ExitCode;
    if lInspectResult.TimedOut then
    begin
      Result.OutputText := 'ollama container inspection timed out';
    end else begin
      Result.OutputText := 'ollama container is not running';
      if Trim(lInspectResult.OutputText) <> '' then
      begin
        Result.OutputText := Result.OutputText + ' (' + lInspectResult.OutputText + ')';
      end;
    end;
    Exit;
  end;

  Result := lDockerResult;
  Result.Success := False;
  if Result.TimedOut then
  begin
    Result.OutputText := 'docker availability check timed out';
  end else begin
    if Trim(Result.OutputText) = '' then
    begin
      Result.OutputText := 'docker is not available';
    end else begin
      Result.OutputText := 'docker is not available: ' + Result.OutputText;
    end;
  end;
end;

end.
