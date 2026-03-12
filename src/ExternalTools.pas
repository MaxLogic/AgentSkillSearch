unit ExternalTools;

interface

uses
  System.Classes,
  Vcl.Menus,
  SettingsModel;

type
  TExternalToolLaunch = record
    CommandLine: string;
    ExecutablePath: string;
    Name: string;
    Parameters: string;
  end;

function BuildExternalToolCommandLine(const aTemplate, aPath: string): string;
function IsExternalToolTemplateValid(const aTemplate: string): Boolean;
procedure PopulateExternalToolsPopupMenu(aPopupMenu: TPopupMenu; const aTools: TArray<TExternalToolSettings>;
  const aOnClick: TNotifyEvent; const aInsertIndex: Integer = 1);
function TryPrepareExternalToolLaunch(const aTools: TArray<TExternalToolSettings>; const aToolIndex: Integer;
  const aPath: string; out aLaunch: TExternalToolLaunch): Boolean; overload;
function TryPrepareExternalToolLaunch(const aTools: TArray<TExternalToolSettings>; const aToolIndex: Integer;
  const aPath, aSearchPath, aPathExt: string; out aLaunch: TExternalToolLaunch): Boolean; overload;
function TryBuildExternalToolCommandLine(const aTemplate, aPath: string; out aCommandLine: string): Boolean;
function TryResolveExternalToolMenuClick(Sender: TObject; const aTools: TArray<TExternalToolSettings>;
  const aPath: string; out aName, aCommandLine: string): Boolean;
function TryResolveExternalTool(const aTools: TArray<TExternalToolSettings>; const aToolIndex: Integer;
  const aPath: string; out aName, aCommandLine: string): Boolean;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils;

function AppendPathIfMissing(const aValue, aExtension: string): string;
begin
  if SameText(ExtractFileExt(aValue), aExtension) then
  begin
    Exit(aValue);
  end;

  Result := aValue + aExtension;
end;

function TryResolveExternalToolExecutable(const aExecutable, aSearchPath, aPathExt: string;
  out aResolvedPath: string): Boolean;
var
  i: Integer;
  lCandidates: TArray<string>;
  lExtensions: TArray<string>;
  lSearchDirectories: TArray<string>;
  lSearchValue: string;
begin
  aResolvedPath := '';
  if Trim(aExecutable) = '' then
  begin
    Exit(False);
  end;

  if TPath.IsPathRooted(aExecutable) or (Pos(PathDelim, aExecutable) > 0) or (Pos('/', aExecutable) > 0) then
  begin
    lSearchDirectories := [ExtractFilePath(aExecutable)];
    lSearchValue := ExtractFileName(aExecutable);
  end else begin
    lSearchDirectories := SplitString(aSearchPath, ';');
    lSearchValue := aExecutable;
  end;

  lExtensions := SplitString(aPathExt, ';');
  SetLength(lCandidates, 1 + Length(lExtensions));
  lCandidates[0] := lSearchValue;
  for i := 0 to Pred(Length(lExtensions)) do
  begin
    lCandidates[i + 1] := AppendPathIfMissing(lSearchValue, Trim(lExtensions[i]));
  end;

  for lSearchValue in lSearchDirectories do
  begin
    for i := 0 to Pred(Length(lCandidates)) do
    begin
      if Trim(lCandidates[i]) = '' then
      begin
        Continue;
      end;

      aResolvedPath := TPath.Combine(Trim(lSearchValue), lCandidates[i]);
      if TFile.Exists(aResolvedPath) then
      begin
        Exit(True);
      end;
    end;
  end;

  if TFile.Exists(aExecutable) then
  begin
    aResolvedPath := TPath.GetFullPath(aExecutable);
    Exit(True);
  end;
  Result := False;
end;

function TrySplitExecutableAndParameters(const aCommandLine: string; out aExecutable, aParameters: string): Boolean;
var
  i: Integer;
  lCommandLine: string;
begin
  aExecutable := '';
  aParameters := '';
  lCommandLine := Trim(aCommandLine);
  if lCommandLine = '' then
  begin
    Exit(False);
  end;

  if StartsStr('"', lCommandLine) then
  begin
    i := PosEx('"', lCommandLine, 2);
    if i <= 1 then
    begin
      Exit(False);
    end;
    aExecutable := Copy(lCommandLine, 2, i - 2);
    aParameters := Trim(Copy(lCommandLine, i + 1, MaxInt));
    Exit(aExecutable <> '');
  end;

  i := Pos(' ', lCommandLine);
  if i <= 0 then
  begin
    aExecutable := lCommandLine;
    Exit(True);
  end;

  aExecutable := Copy(lCommandLine, 1, i - 1);
  aParameters := Trim(Copy(lCommandLine, i + 1, MaxInt));
  Result := aExecutable <> '';
end;

function IsExternalToolTemplateValid(const aTemplate: string): Boolean;
begin
  Result := Pos('{path}', LowerCase(Trim(aTemplate))) > 0;
end;

function BuildExternalToolCommandLine(const aTemplate, aPath: string): string;
begin
  Result := StringReplace(Trim(aTemplate), '{path}', '"' + aPath + '"', [rfIgnoreCase, rfReplaceAll]);
end;

procedure PopulateExternalToolsPopupMenu(aPopupMenu: TPopupMenu; const aTools: TArray<TExternalToolSettings>;
  const aOnClick: TNotifyEvent; const aInsertIndex: Integer);
var
  i: Integer;
  lInsertIndex: Integer;
  lItem: TMenuItem;
begin
  if not Assigned(aPopupMenu) or (Length(aTools) = 0) then
  begin
    Exit;
  end;

  lInsertIndex := aInsertIndex;
  lItem := TMenuItem.Create(aPopupMenu);
  lItem.Caption := '-';
  aPopupMenu.Items.Insert(lInsertIndex, lItem);
  Inc(lInsertIndex);

  for i := 0 to Pred(Length(aTools)) do
  begin
    lItem := TMenuItem.Create(aPopupMenu);
    lItem.Caption := aTools[i].Name;
    lItem.Tag := i;
    lItem.OnClick := aOnClick;
    aPopupMenu.Items.Insert(lInsertIndex, lItem);
    Inc(lInsertIndex);
  end;
end;

function TryBuildExternalToolCommandLine(const aTemplate, aPath: string; out aCommandLine: string): Boolean;
begin
  aCommandLine := '';
  if (Trim(aPath) = '') or not IsExternalToolTemplateValid(aTemplate) then
  begin
    Exit(False);
  end;

  aCommandLine := BuildExternalToolCommandLine(aTemplate, aPath);
  Result := Trim(aCommandLine) <> '';
end;

function TryPrepareExternalToolLaunch(const aTools: TArray<TExternalToolSettings>; const aToolIndex: Integer;
  const aPath: string; out aLaunch: TExternalToolLaunch): Boolean;
begin
  Result := TryPrepareExternalToolLaunch(
    aTools,
    aToolIndex,
    aPath,
    GetEnvironmentVariable('PATH'),
    GetEnvironmentVariable('PATHEXT'),
    aLaunch
  );
end;

function TryPrepareExternalToolLaunch(const aTools: TArray<TExternalToolSettings>; const aToolIndex: Integer;
  const aPath, aSearchPath, aPathExt: string; out aLaunch: TExternalToolLaunch): Boolean;
var
  lCommandLine: string;
  lExecutable: string;
  lName: string;
  lParameters: string;
  lPathExt: string;
begin
  aLaunch := Default(TExternalToolLaunch);
  if not TryResolveExternalTool(aTools, aToolIndex, aPath, lName, lCommandLine) then
  begin
    Exit(False);
  end;

  if not TrySplitExecutableAndParameters(lCommandLine, lExecutable, lParameters) then
  begin
    Exit(False);
  end;

  lPathExt := aPathExt;
  if Trim(lPathExt) = '' then
  begin
    lPathExt := '.COM;.EXE;.BAT;.CMD';
  end;
  if not TryResolveExternalToolExecutable(lExecutable, aSearchPath, lPathExt, aLaunch.ExecutablePath) then
  begin
    Exit(False);
  end;

  aLaunch.CommandLine := lCommandLine;
  aLaunch.Name := lName;
  aLaunch.Parameters := lParameters;
  Result := True;
end;

function TryResolveExternalToolMenuClick(Sender: TObject; const aTools: TArray<TExternalToolSettings>;
  const aPath: string; out aName, aCommandLine: string): Boolean;
var
  lToolIndex: Integer;
begin
  if not (Sender is TMenuItem) then
  begin
    aName := '';
    aCommandLine := '';
    Exit(False);
  end;

  lToolIndex := TMenuItem(Sender).Tag;
  Result := TryResolveExternalTool(aTools, lToolIndex, aPath, aName, aCommandLine);
end;

function TryResolveExternalTool(const aTools: TArray<TExternalToolSettings>; const aToolIndex: Integer;
  const aPath: string; out aName, aCommandLine: string): Boolean;
begin
  aName := '';
  aCommandLine := '';
  if (aToolIndex < 0) or (aToolIndex >= Length(aTools)) then
  begin
    Exit(False);
  end;

  aName := aTools[aToolIndex].Name;
  Result := TryBuildExternalToolCommandLine(aTools[aToolIndex].CommandTemplate, aPath, aCommandLine);
  if not Result then
  begin
    aName := '';
  end;
end;

end.
