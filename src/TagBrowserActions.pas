unit TagBrowserActions;

interface

uses
  System.SysUtils,
  Vcl.StdCtrls,
  DatabaseManager;

procedure PopulateTagListBox(aListBox: TListBox; const aTags: TArray<TSkillTagInfo>);
function TryGetSelectedTag(const aListBox: TListBox; const aTags: TArray<TSkillTagInfo>; out aTag: string): Boolean;

implementation

procedure PopulateTagListBox(aListBox: TListBox; const aTags: TArray<TSkillTagInfo>);
var
  lTag: TSkillTagInfo;
begin
  if not Assigned(aListBox) then
  begin
    Exit;
  end;

  aListBox.Items.BeginUpdate;
  try
    aListBox.Clear;
    for lTag in aTags do
    begin
      aListBox.Items.Add(Format('%s (%d)', [lTag.Name, lTag.SkillCount]));
    end;
  finally
    aListBox.Items.EndUpdate;
  end;
end;

function TryGetSelectedTag(const aListBox: TListBox; const aTags: TArray<TSkillTagInfo>; out aTag: string): Boolean;
begin
  aTag := '';
  Result := Assigned(aListBox) and (aListBox.ItemIndex >= 0) and (aListBox.ItemIndex < Length(aTags));
  if not Result then
  begin
    Exit(False);
  end;

  aTag := aTags[aListBox.ItemIndex].Name;
end;

end.
