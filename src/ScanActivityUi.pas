unit ScanActivityUi;

interface

type
  TScanActivitySnapshot = record
    ElapsedMs: Int64;
    ReposFailed: Integer;
    ReposFound: Integer;
    ReposPulled: Integer;
    ReposThrottled: Integer;
    SkillsFound: Integer;
    SkillsWritten: Integer;
    StatusText: string;
  end;

function BuildScanActivitySummary(const aSnapshot: TScanActivitySnapshot): string;

implementation

uses
  System.SysUtils;

function FormatElapsed(const aElapsedMs: Int64): string;
var
  lHours: Int64;
  lMinutes: Int64;
  lSeconds: Int64;
  lTotalSeconds: Int64;
begin
  lTotalSeconds := aElapsedMs div 1000;
  lHours := lTotalSeconds div 3600;
  lMinutes := (lTotalSeconds div 60) mod 60;
  lSeconds := lTotalSeconds mod 60;
  if lHours > 0 then
  begin
    Result := Format('%.2d:%.2d:%.2d', [lHours, lMinutes, lSeconds]);
  end else begin
    Result := Format('00:%.2d:%.2d', [lMinutes, lSeconds]);
  end;
end;

function BuildScanActivitySummary(const aSnapshot: TScanActivitySnapshot): string;
begin
  Result := Format(
    'Repos: %d found, %d pulled, %d throttled, %d failed | Skills: %d found, %d written | Elapsed: %s',
    [
      aSnapshot.ReposFound,
      aSnapshot.ReposPulled,
      aSnapshot.ReposThrottled,
      aSnapshot.ReposFailed,
      aSnapshot.SkillsFound,
      aSnapshot.SkillsWritten,
      FormatElapsed(aSnapshot.ElapsedMs)
    ]
  );
  if Trim(aSnapshot.StatusText) <> '' then
  begin
    Result := Result + ' | Stage: ' + Trim(aSnapshot.StatusText);
  end;
end;

end.
