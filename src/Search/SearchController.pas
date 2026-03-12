unit SearchController;

interface

uses
  System.SyncObjs,
  SkillSearchService;

type
  TSearchCompletedEvent = procedure(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>;
    const aError: string) of object;

  TSearchExecutor = reference to function(const aQuery: string): TArray<TSkillSearchResult>;

  TSearchController = class
  private
    fActiveTaskCount: Integer;
    fDebounceMs: Integer;
    fExecutorLock: TCriticalSection;
    fExecutor: TSearchExecutor;
    fGenerationCounter: Integer;
    fIdleEvent: TEvent;
    fLatestQueuedGeneration: Integer;
    fOnCompleted: TSearchCompletedEvent;
    fShutdownRequested: Integer;
    function GetCurrentGeneration: Integer;
  public
    constructor Create(const aExecutor: TSearchExecutor; const aDebounceMs: Integer);
    destructor Destroy; override;
    procedure CancelCurrent;
    function QueueSearch(const aQuery: string; const aDebounceOverrideMs: Integer = -1): Integer;
    property CurrentGeneration: Integer read GetCurrentGeneration;
    property OnCompleted: TSearchCompletedEvent read fOnCompleted write fOnCompleted;
  end;

implementation

uses
  System.Classes, System.Threading, System.SysUtils;

constructor TSearchController.Create(const aExecutor: TSearchExecutor; const aDebounceMs: Integer);
begin
  inherited Create;
  fActiveTaskCount := 0;
  fExecutor := aExecutor;
  fExecutorLock := TCriticalSection.Create;
  fDebounceMs := aDebounceMs;
  fGenerationCounter := 0;
  fIdleEvent := TEvent.Create(nil, True, True, '');
  fLatestQueuedGeneration := 0;
  fShutdownRequested := 0;
end;

destructor TSearchController.Destroy;
begin
  TInterlocked.Exchange(fShutdownRequested, 1);
  CancelCurrent;
  fOnCompleted := nil;
  if TInterlocked.CompareExchange(fActiveTaskCount, 0, 0) > 0 then
  begin
    fIdleEvent.WaitFor(INFINITE);
  end;
  fIdleEvent.Free;
  fExecutorLock.Free;
  inherited Destroy;
end;

function TSearchController.GetCurrentGeneration: Integer;
begin
  Result := TInterlocked.CompareExchange(fLatestQueuedGeneration, 0, 0);
end;

procedure TSearchController.CancelCurrent;
var
  lGeneration: Integer;
begin
  lGeneration := TInterlocked.Increment(fGenerationCounter);
  TInterlocked.Exchange(fLatestQueuedGeneration, lGeneration);
end;

function TSearchController.QueueSearch(const aQuery: string; const aDebounceOverrideMs: Integer): Integer;
var
  lDebounceMs: Integer;
  lGeneration: Integer;
begin
  if TInterlocked.CompareExchange(fShutdownRequested, 0, 0) <> 0 then
  begin
    Exit(GetCurrentGeneration);
  end;

  lGeneration := TInterlocked.Increment(fGenerationCounter);
  TInterlocked.Exchange(fLatestQueuedGeneration, lGeneration);

  if aDebounceOverrideMs >= 0 then
  begin
    lDebounceMs := aDebounceOverrideMs;
  end else begin
    lDebounceMs := fDebounceMs;
  end;

  TInterlocked.Increment(fActiveTaskCount);
  fIdleEvent.ResetEvent;
  TTask.Run(
    procedure
    var
      lCurrentGeneration: Integer;
      lError: string;
      lResults: TArray<TSkillSearchResult>;
    begin
      try
        try
          if lDebounceMs > 0 then
          begin
            Sleep(lDebounceMs);
          end;
          if TInterlocked.CompareExchange(fShutdownRequested, 0, 0) <> 0 then
          begin
            Exit;
          end;

          lCurrentGeneration := TInterlocked.CompareExchange(fLatestQueuedGeneration, 0, 0);
          if lGeneration <> lCurrentGeneration then
          begin
            Exit;
          end;

          fExecutorLock.Enter;
          try
            if TInterlocked.CompareExchange(fShutdownRequested, 0, 0) <> 0 then
            begin
              Exit;
            end;

            lResults := fExecutor(aQuery);
            lError := '';
          finally
            fExecutorLock.Leave;
          end;
        except
          on E: Exception do
          begin
            lResults := nil;
            lError := E.Message;
          end;
        end;

        if TInterlocked.CompareExchange(fShutdownRequested, 0, 0) <> 0 then
        begin
          Exit;
        end;

        lCurrentGeneration := TInterlocked.CompareExchange(fLatestQueuedGeneration, 0, 0);
        if lGeneration <> lCurrentGeneration then
        begin
          Exit;
        end;

        if Assigned(fOnCompleted) then
        begin
          fOnCompleted(lGeneration, lResults, lError);
        end;
      finally
        if TInterlocked.Decrement(fActiveTaskCount) = 0 then
        begin
          fIdleEvent.SetEvent;
        end;
      end;
    end
  );

  Result := lGeneration;
end;

end.
