unit DockerHealthMonitor;

interface

uses
  System.Classes;

type
  TDockerHealthState = (dhsUnknown, dhsHealthy, dhsUnhealthy);
  TDockerHealthPolledEvent = reference to procedure(const aState: TDockerHealthState; const aDetail: string);

  TDockerHealthMonitor = class
  private
    fCheckCommand: string;
    fDispatchQueued: Integer;
    fIntervalMs: Integer;
    fOnPolled: TDockerHealthPolledEvent;
    fPendingDetail: string;
    fPendingLock: TObject;
    fPendingState: TDockerHealthState;
    fStopping: Integer;
    fThread: TThread;
    procedure DispatchPolled;
    procedure QueuePendingPoll(const aState: TDockerHealthState; const aDetail: string);
  public
    constructor Create(const aCheckCommand: string; const aIntervalMs: Integer;
      const aOnPolled: TDockerHealthPolledEvent);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
  end;

implementation

uses
  System.Math, System.SyncObjs, System.SysUtils,
  DockerOps;

constructor TDockerHealthMonitor.Create(const aCheckCommand: string; const aIntervalMs: Integer;
  const aOnPolled: TDockerHealthPolledEvent);
begin
  inherited Create;
  fCheckCommand := aCheckCommand;
  fDispatchQueued := 0;
  fIntervalMs := Max(1000, aIntervalMs);
  fOnPolled := aOnPolled;
  fPendingDetail := '';
  fPendingLock := TObject.Create;
  fPendingState := TDockerHealthState.dhsUnknown;
  fStopping := 0;
end;

destructor TDockerHealthMonitor.Destroy;
begin
  Stop;
  fPendingLock.Free;
  inherited Destroy;
end;

procedure TDockerHealthMonitor.DispatchPolled;
var
  lDetail: string;
  lOnPolled: TDockerHealthPolledEvent;
  lState: TDockerHealthState;
begin
  if TInterlocked.CompareExchange(fStopping, 0, 0) <> 0 then
  begin
    Exit;
  end;

  TMonitor.Enter(fPendingLock);
  try
    lDetail := fPendingDetail;
    lOnPolled := fOnPolled;
    lState := fPendingState;
    TInterlocked.Exchange(fDispatchQueued, 0);
  finally
    TMonitor.Exit(fPendingLock);
  end;

  if (TInterlocked.CompareExchange(fStopping, 0, 0) <> 0) or (not Assigned(lOnPolled)) then
  begin
    Exit;
  end;

  lOnPolled(lState, lDetail);
end;

procedure TDockerHealthMonitor.QueuePendingPoll(const aState: TDockerHealthState; const aDetail: string);
begin
  if TInterlocked.CompareExchange(fStopping, 0, 0) <> 0 then
  begin
    Exit;
  end;

  TMonitor.Enter(fPendingLock);
  try
    fPendingState := aState;
    fPendingDetail := aDetail;
    if TInterlocked.CompareExchange(fDispatchQueued, 1, 0) = 0 then
    begin
      TThread.Queue(nil, DispatchPolled);
    end;
  finally
    TMonitor.Exit(fPendingLock);
  end;
end;

procedure TDockerHealthMonitor.Start;
begin
  TInterlocked.Exchange(fStopping, 0);

  if Assigned(fThread) then
  begin
    Exit;
  end;

  fThread := TThread.CreateAnonymousThread(
    procedure
    var
      i: Integer;
      lDetail: string;
      lResult: TDockerCommandResult;
      lState: TDockerHealthState;
      lSteps: Integer;
    begin
      while not TThread.CurrentThread.CheckTerminated do
      begin
        lResult := CheckOllamaHealth(fCheckCommand, 8);
        if lResult.Success then
        begin
          lState := TDockerHealthState.dhsHealthy;
          if lResult.OutputText = '' then
          begin
            lDetail := 'healthy';
          end else begin
            lDetail := lResult.OutputText;
          end;
        end else begin
          lState := TDockerHealthState.dhsUnhealthy;
          if lResult.TimedOut then
          begin
            lDetail := 'health check timeout';
          end else begin
            lDetail := lResult.OutputText;
            if Trim(lDetail) = '' then
            begin
              lDetail := Format('health check failed (exit=%d)', [lResult.ExitCode]);
            end;
          end;
        end;

        QueuePendingPoll(lState, lDetail);

        lSteps := Max(1, fIntervalMs div 200);
        for i := 1 to lSteps do
        begin
          if TThread.CurrentThread.CheckTerminated then
          begin
            Exit;
          end;
          Sleep(200);
        end;
      end;
    end
  );
  fThread.FreeOnTerminate := False;
  fThread.Start;
end;

procedure TDockerHealthMonitor.Stop;
begin
  if not Assigned(fThread) then
  begin
    Exit;
  end;

  TInterlocked.Exchange(fStopping, 1);
  TThread.RemoveQueuedEvents(DispatchPolled);
  fThread.Terminate;
  fThread.WaitFor;
  TThread.RemoveQueuedEvents(DispatchPolled);
  TInterlocked.Exchange(fDispatchQueued, 0);
  fThread.Free;
  fThread := nil;
end;

end.
