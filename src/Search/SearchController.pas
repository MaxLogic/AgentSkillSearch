unit SearchController;

interface

uses
  SkillSearchService;

type
  TSearchCompletedEvent = procedure(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>;
    const aError: string) of object;

  TSearchExecutor = reference to function(const aQuery: string): TArray<TSkillSearchResult>;

  TSearchController = class
  private
    fDebounceMs: Integer;
    fExecutor: TSearchExecutor;
    fGenerationCounter: Integer;
    fLatestQueuedGeneration: Integer;
    fOnCompleted: TSearchCompletedEvent;
    function GetCurrentGeneration: Integer;
  public
    constructor Create(const aExecutor: TSearchExecutor; const aDebounceMs: Integer);
    procedure CancelCurrent;
    function QueueSearch(const aQuery: string; const aDebounceOverrideMs: Integer = -1): Integer;
    property CurrentGeneration: Integer read GetCurrentGeneration;
    property OnCompleted: TSearchCompletedEvent read fOnCompleted write fOnCompleted;
  end;

implementation

uses
  System.Classes, System.SyncObjs, System.Threading, System.SysUtils;

constructor TSearchController.Create(const aExecutor: TSearchExecutor; const aDebounceMs: Integer);
begin
  inherited Create;
  fExecutor := aExecutor;
  fDebounceMs := aDebounceMs;
  fGenerationCounter := 0;
  fLatestQueuedGeneration := 0;
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
  lGeneration := TInterlocked.Increment(fGenerationCounter);
  TInterlocked.Exchange(fLatestQueuedGeneration, lGeneration);

  if aDebounceOverrideMs >= 0 then
  begin
    lDebounceMs := aDebounceOverrideMs;
  end else begin
    lDebounceMs := fDebounceMs;
  end;

  TTask.Run(
    procedure
    var
      lCurrentGeneration: Integer;
      lError: string;
      lResults: TArray<TSkillSearchResult>;
    begin
      if lDebounceMs > 0 then
      begin
        Sleep(lDebounceMs);
      end;

      lCurrentGeneration := TInterlocked.CompareExchange(fLatestQueuedGeneration, 0, 0);
      if lGeneration <> lCurrentGeneration then
      begin
        Exit;
      end;

      try
        lResults := fExecutor(aQuery);
        lError := '';
      except
        on E: Exception do
        begin
          lResults := nil;
          lError := E.Message;
        end;
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
    end
  );

  Result := lGeneration;
end;

end.
