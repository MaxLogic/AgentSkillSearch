unit TrayActions;

interface

uses
  Winapi.Messages, Winapi.ShellAPI, Winapi.Windows;

type
  TTrayHotkey = record
    Modifiers: UINT;
    VirtualKey: UINT;
  end;

  TTrayWindowState = record
    ExitRequested: Boolean;
    TrayIconVisible: Boolean;
    WindowVisible: Boolean;
  end;

  TTrayMessageAction = (tmaNone, tmaRestore, tmaShowMenu);

function ApplyHideToTray(const aState: TTrayWindowState): TTrayWindowState;
function ApplyRestoreFromTray(const aState: TTrayWindowState): TTrayWindowState;
function ApplyTrayExitRequest(const aState: TTrayWindowState): TTrayWindowState;
function DefaultTrayWindowState: TTrayWindowState;
function ResolveTrayMessageAction(const aMessageId: LPARAM): TTrayMessageAction;
function ShouldHideToTrayOnClose(const aExitRequested: Boolean): Boolean;
function TryParseTrayHotkey(const aValue: string; out aHotkey: TTrayHotkey; out aError: string): Boolean;

implementation

uses
  System.Classes, System.StrUtils, System.SysUtils;

function ResolvePrimaryHotkeyToken(const aToken: string; out aVirtualKey: UINT): Boolean;
var
  lFunctionIndex: Integer;
  lUpperToken: string;
begin
  lUpperToken := UpperCase(Trim(aToken));
  if (Length(lUpperToken) = 1) and CharInSet(lUpperToken[1], ['A'..'Z', '0'..'9']) then
  begin
    aVirtualKey := Ord(lUpperToken[1]);
    Exit(True);
  end;

  if StartsText('F', lUpperToken) and TryStrToInt(Copy(lUpperToken, 2, MaxInt), lFunctionIndex) and
    (lFunctionIndex >= 1) and (lFunctionIndex <= 24) then
  begin
    aVirtualKey := VK_F1 + UINT(lFunctionIndex - 1);
    Exit(True);
  end;

  Result := False;
end;

function ResolveTrayMessageAction(const aMessageId: LPARAM): TTrayMessageAction;
begin
  case aMessageId of
    WM_LBUTTONDBLCLK, NIN_SELECT, NIN_KEYSELECT:
      begin
        Result := TTrayMessageAction.tmaRestore;
      end;
    WM_CONTEXTMENU, WM_RBUTTONUP:
      begin
        Result := TTrayMessageAction.tmaShowMenu;
      end;
  else
    begin
      Result := TTrayMessageAction.tmaNone;
    end;
  end;
end;

function DefaultTrayWindowState: TTrayWindowState;
begin
  Result := Default(TTrayWindowState);
  Result.WindowVisible := True;
end;

function ApplyHideToTray(const aState: TTrayWindowState): TTrayWindowState;
begin
  Result := aState;
  Result.TrayIconVisible := True;
  Result.WindowVisible := False;
end;

function ApplyRestoreFromTray(const aState: TTrayWindowState): TTrayWindowState;
begin
  Result := aState;
  Result.TrayIconVisible := False;
  Result.WindowVisible := True;
end;

function ApplyTrayExitRequest(const aState: TTrayWindowState): TTrayWindowState;
begin
  Result := aState;
  Result.ExitRequested := True;
end;

function ShouldHideToTrayOnClose(const aExitRequested: Boolean): Boolean;
begin
  Result := not aExitRequested;
end;

function TryParseTrayHotkey(const aValue: string; out aHotkey: TTrayHotkey; out aError: string): Boolean;
var
  i: Integer;
  lHasPrimaryKey: Boolean;
  lParts: TStringList;
  lToken: string;
  lTokenUpper: string;
begin
  aHotkey := Default(TTrayHotkey);
  aError := '';

  if Trim(aValue) = '' then
  begin
    Exit(False);
  end;

  lHasPrimaryKey := False;
  lParts := TStringList.Create;
  try
    lParts.StrictDelimiter := True;
    lParts.Delimiter := '+';
    lParts.DelimitedText := aValue;

    for i := 0 to Pred(lParts.Count) do
    begin
      lToken := Trim(lParts[i]);
      lTokenUpper := UpperCase(lToken);
      if lTokenUpper = '' then
      begin
        Continue;
      end;

      if (lTokenUpper = 'CTRL') or (lTokenUpper = 'CONTROL') then
      begin
        aHotkey.Modifiers := aHotkey.Modifiers or MOD_CONTROL;
        Continue;
      end;
      if lTokenUpper = 'SHIFT' then
      begin
        aHotkey.Modifiers := aHotkey.Modifiers or MOD_SHIFT;
        Continue;
      end;
      if lTokenUpper = 'ALT' then
      begin
        aHotkey.Modifiers := aHotkey.Modifiers or MOD_ALT;
        Continue;
      end;
      if (lTokenUpper = 'WIN') or (lTokenUpper = 'WINDOWS') then
      begin
        aHotkey.Modifiers := aHotkey.Modifiers or MOD_WIN;
        Continue;
      end;

      if lHasPrimaryKey then
      begin
        aError := 'Tray hotkey must include exactly one primary key';
        Exit(False);
      end;

      if not ResolvePrimaryHotkeyToken(lTokenUpper, aHotkey.VirtualKey) then
      begin
        aError := 'Unknown tray hotkey token: ' + lToken;
        Exit(False);
      end;
      lHasPrimaryKey := True;
    end;
  finally
    lParts.Free;
  end;

  if not lHasPrimaryKey then
  begin
    aError := 'Tray hotkey must include a primary key';
    Exit(False);
  end;

  if aHotkey.Modifiers = 0 then
  begin
    aError := 'Tray hotkey must include at least one modifier';
    Exit(False);
  end;

  Result := True;
end;

end.
