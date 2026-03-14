unit ScanProgressBuffer;

interface

uses
  System.SysUtils,
  PipelineCoordinator;

type
  TScanProgressBuffer = class
  private
    fHasPending: Boolean;
    fLatestProgress: TPipelineProgress;
    fLock: TObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Publish(const aProgress: TPipelineProgress);
    procedure PublishStatus(const aStatusText: string);
    function TryConsume(out aProgress: TPipelineProgress): Boolean;
  end;

implementation

constructor TScanProgressBuffer.Create;
begin
  inherited Create;
  fLock := TObject.Create;
  fLatestProgress := Default(TPipelineProgress);
  fHasPending := False;
end;

destructor TScanProgressBuffer.Destroy;
begin
  fLock.Free;
  inherited Destroy;
end;

procedure TScanProgressBuffer.Publish(const aProgress: TPipelineProgress);
begin
  TMonitor.Enter(fLock);
  try
    fLatestProgress := aProgress;
    fHasPending := True;
  finally
    TMonitor.Exit(fLock);
  end;
end;

procedure TScanProgressBuffer.PublishStatus(const aStatusText: string);
begin
  TMonitor.Enter(fLock);
  try
    fLatestProgress.StatusText := aStatusText;
    fHasPending := True;
  finally
    TMonitor.Exit(fLock);
  end;
end;

function TScanProgressBuffer.TryConsume(out aProgress: TPipelineProgress): Boolean;
begin
  TMonitor.Enter(fLock);
  try
    Result := fHasPending;
    if Result then
    begin
      aProgress := fLatestProgress;
      fHasPending := False;
    end else begin
      aProgress := Default(TPipelineProgress);
    end;
  finally
    TMonitor.Exit(fLock);
  end;
end;

end.
