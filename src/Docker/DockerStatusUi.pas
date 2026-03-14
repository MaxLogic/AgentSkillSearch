unit DockerStatusUi;

interface

uses
  DockerHealthMonitor;

type
  TDockerStatusUiState = record
    AlertText: string;
    ShowAlert: Boolean;
    StatusText: string;
  end;

function BuildDockerStatusUiState(const aHealthState: TDockerHealthState; const aHealthDetail,
  aStartFailureMessage: string; const aStartInProgress: Boolean): TDockerStatusUiState;

implementation

uses
  System.StrUtils, System.SysUtils;

function BuildUnavailableStatusText(const aHealthDetail, aStartFailureMessage: string): string;
var
  lDetail: string;
begin
  lDetail := Trim(aStartFailureMessage);
  if lDetail = '' then
  begin
    lDetail := Trim(aHealthDetail);
  end;

  if ContainsText(lDetail, 'docker is not available') or ContainsText(lDetail, 'docker availability check') then
  begin
    Exit('Docker: unavailable');
  end;

  if ContainsText(lDetail, 'ollama') then
  begin
    Exit('Ollama: unavailable');
  end;

  Result := 'Ollama: unavailable';
end;

function BuildAlertText(const aHealthDetail, aStartFailureMessage: string): string;
var
  lDetail: string;
begin
  lDetail := Trim(aStartFailureMessage);
  if lDetail <> '' then
  begin
    Exit(lDetail);
  end;

  lDetail := Trim(aHealthDetail);
  if ContainsText(lDetail, 'docker is not available') or ContainsText(lDetail, 'docker availability check') then
  begin
    Exit('Docker is not running. Start the local stack to enable Ollama.');
  end;

  if ContainsText(lDetail, 'ollama') then
  begin
    Exit('Ollama is not running. Start the local stack to enable semantic search.');
  end;

  Result := 'Docker or Ollama is not running. Start the local stack now.';
end;

function BuildDockerStatusUiState(const aHealthState: TDockerHealthState; const aHealthDetail,
  aStartFailureMessage: string; const aStartInProgress: Boolean): TDockerStatusUiState;
begin
  Result.AlertText := '';
  Result.ShowAlert := False;

  if aStartInProgress then
  begin
    Result.StatusText := 'Ollama: starting...';
    Exit;
  end;

  case aHealthState of
    TDockerHealthState.dhsHealthy:
      begin
        Result.StatusText := 'Ollama: running';
      end;
    TDockerHealthState.dhsUnhealthy:
      begin
        Result.StatusText := BuildUnavailableStatusText(aHealthDetail, aStartFailureMessage);
        Result.AlertText := BuildAlertText(aHealthDetail, aStartFailureMessage);
        Result.ShowAlert := True;
      end;
  else
    begin
      if Trim(aStartFailureMessage) <> '' then
      begin
        Result.StatusText := BuildUnavailableStatusText(aHealthDetail, aStartFailureMessage);
        Result.AlertText := BuildAlertText(aHealthDetail, aStartFailureMessage);
        Result.ShowAlert := True;
      end else begin
        Result.StatusText := 'Ollama: checking...';
      end;
    end;
  end;
end;

end.
