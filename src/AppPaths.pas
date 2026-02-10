unit AppPaths;

interface

uses
  System.SysUtils;

function GetExeDirectory: string;
function GetProjectRootDirectory: string;
function GetCacheDirectory: string;
function GetCacheDbPath: string;
function GetSqliteDllPath: string;
function GetSourcesListPath: string;

implementation

uses
  System.IOUtils;

function GetExeDirectory: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

function GetProjectRootDirectory: string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(TPath.Combine(GetExeDirectory, '..')));
end;

function GetCacheDirectory: string;
begin
  Result := TPath.Combine(GetExeDirectory, 'cache');
end;

function GetCacheDbPath: string;
begin
  Result := TPath.Combine(GetCacheDirectory, 'SkillCache.db');
end;

function GetSqliteDllPath: string;
begin
  Result := TPath.Combine(GetExeDirectory, 'sqlite3.dll');
end;

function GetSourcesListPath: string;
begin
  Result := TPath.Combine(GetExeDirectory, 'Sources.lst');
end;

end.
