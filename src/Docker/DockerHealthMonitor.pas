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
    fIntervalMs: Integer;
    fOnPolled: TDockerHealthPolledEvent;
    fThread: TThread;
    procedure DoPolled(const aState: TDockerHealthState; const aDetail: string);
  public
    constructor Create(const aCheckCommand: string; const aIntervalMs: Integer;
      const aOnPolled: TDockerHealthPolledEvent);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
  end;

implementation

uses
  System.Math, System.SysUtils,
  DockerOps;

constructor TDockerHealthMonitor.Create(const aCheckCommand: string; const aIntervalMs: Integer;
  const aOnPolled: TDockerHealthPolledEvent);
begin
  inherited Create;
  fCheckCommand := aCheckCommand;
  fIntervalMs := Max(1000, aIntervalMs);
  fOnPolled := aOnPolled;
end;

destructor TDockerHealthMonitor.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TDockerHealthMonitor.DoPolled(const aState: TDockerHealthState; const aDetail: string);
begin
  if Assigned(fOnPolled) then
  begin
    fOnPolled(aState, aDetail);
  end;
end;

procedure TDockerHealthMonitor.Start;
begin
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
        lResult := CheckDockerHealth(fCheckCommand, 8);
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

        TThread.Queue(nil,
          procedure
          begin
            DoPolled(lState, lDetail);
          end
        );

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

  fThread.Terminate;
  fThread.WaitFor;
  fThread.Free;
  fThread := nil;
end;

end.
