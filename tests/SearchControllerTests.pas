unit SearchControllerTests;

interface

procedure RunSearchControllerTests;

implementation

uses
  System.SyncObjs, System.SysUtils,
  SearchController, SkillSearchService;

procedure AssertEqualInt(const aExpected, aActual: Integer; const aMessage: string);
begin
  if aExpected <> aActual then
  begin
    raise Exception.CreateFmt('%s | expected=%d actual=%d', [aMessage, aExpected, aActual]);
  end;
end;

procedure AssertEqualText(const aExpected, aActual: string; const aMessage: string);
begin
  if not SameText(aExpected, aActual) then
  begin
    raise Exception.CreateFmt('%s | expected="%s" actual="%s"', [aMessage, aExpected, aActual]);
  end;
end;

type
  TSearchControllerHarness = class
  private
    fCallbackCount: Integer;
    fDoneEvent: TEvent;
    fLastError: string;
    fLastName: string;
    procedure HandleCompleted(const aGenerationId: Integer; const aResults: TArray<TSkillSearchResult>; const aError: string);
    function ExecuteFakeSearch(const aQuery: string): TArray<TSkillSearchResult>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

constructor TSearchControllerHarness.Create;
begin
  inherited Create;
  fDoneEvent := TEvent.Create(nil, True, False, '');
end;

destructor TSearchControllerHarness.Destroy;
begin
  fDoneEvent.Free;
  inherited Destroy;
end;

function TSearchControllerHarness.ExecuteFakeSearch(const aQuery: string): TArray<TSkillSearchResult>;
begin
  Sleep(40);
  SetLength(Result, 1);
  Result[0] := Default(TSkillSearchResult);
  Result[0].Name := aQuery;
end;

procedure TSearchControllerHarness.HandleCompleted(const aGenerationId: Integer;
  const aResults: TArray<TSkillSearchResult>; const aError: string);
begin
  Inc(fCallbackCount);
  fLastError := aError;
  if Length(aResults) > 0 then
  begin
    fLastName := aResults[0].Name;
  end else begin
    fLastName := '';
  end;
  fDoneEvent.SetEvent;
end;

procedure TSearchControllerHarness.Run;
var
  lController: TSearchController;
begin
  lController := TSearchController.Create(
    function(const aQuery: string): TArray<TSkillSearchResult>
    begin
      Result := ExecuteFakeSearch(aQuery);
    end,
    100
  );
  try
    lController.OnCompleted := HandleCompleted;

    lController.QueueSearch('first');
    Sleep(20);
    lController.QueueSearch('second');
    Sleep(20);
    lController.QueueSearch('third');

    if fDoneEvent.WaitFor(1500) <> wrSignaled then
    begin
      raise Exception.Create('Timed out waiting for debounced search result');
    end;

    AssertEqualInt(1, fCallbackCount, 'Expected only the newest queued search callback');
    AssertEqualText('third', fLastName, 'Expected latest search payload to survive generation filtering');
    AssertEqualText('', fLastError, 'Expected no search error');

    fDoneEvent.ResetEvent;
    fCallbackCount := 0;
    fLastName := '';

    lController.QueueSearch('cancel-me');
    Sleep(25);
    lController.CancelCurrent;
    Sleep(300);

    AssertEqualInt(0, fCallbackCount, 'Cancelled search should not dispatch completion callback');
  finally
    lController.Free;
  end;
end;

procedure RunSearchControllerTests;
var
  lHarness: TSearchControllerHarness;
begin
  lHarness := TSearchControllerHarness.Create;
  try
    lHarness.Run;
  finally
    lHarness.Free;
  end;
end;

end.
