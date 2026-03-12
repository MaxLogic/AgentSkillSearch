unit RelatedSkillActions;

interface

uses
  System.SysUtils,
  Vcl.StdCtrls,
  SkillSearchService, SkillTypes;

type
  TRelatedSkillAction = (rsaNone, rsaSelectResult, rsaOpenFile);

  TRelatedSkillNavigation = record
    Action: TRelatedSkillAction;
    ResultIndex: Integer;
    SkillFile: string;
  end;

procedure PopulateRelatedSkillsListBox(aListBox: TListBox; const aItems: TArray<TRelatedSkillResult>);
function TryGetSelectedRelatedSkill(const aListBox: TListBox; const aItems: TArray<TRelatedSkillResult>;
  out aItem: TRelatedSkillResult): Boolean;
function ResolveRelatedSkillNavigation(const aItem: TRelatedSkillResult;
  const aResults: TArray<TSkillSearchResult>): TRelatedSkillNavigation;

implementation

procedure PopulateRelatedSkillsListBox(aListBox: TListBox; const aItems: TArray<TRelatedSkillResult>);
var
  lItem: TRelatedSkillResult;
begin
  if not Assigned(aListBox) then
  begin
    Exit;
  end;

  aListBox.Items.BeginUpdate;
  try
    aListBox.Clear;
    for lItem in aItems do
    begin
      aListBox.Items.Add(lItem.Name + ' [' + lItem.SkillRoot + ']');
    end;
  finally
    aListBox.Items.EndUpdate;
  end;
end;

function TryGetSelectedRelatedSkill(const aListBox: TListBox; const aItems: TArray<TRelatedSkillResult>;
  out aItem: TRelatedSkillResult): Boolean;
begin
  aItem := Default(TRelatedSkillResult);
  Result := Assigned(aListBox) and (aListBox.ItemIndex >= 0) and (aListBox.ItemIndex < Length(aItems));
  if not Result then
  begin
    Exit(False);
  end;

  aItem := aItems[aListBox.ItemIndex];
end;

function ResolveRelatedSkillNavigation(const aItem: TRelatedSkillResult;
  const aResults: TArray<TSkillSearchResult>): TRelatedSkillNavigation;
var
  i: Integer;
begin
  Result := Default(TRelatedSkillNavigation);
  Result.Action := TRelatedSkillAction.rsaOpenFile;
  Result.ResultIndex := -1;
  Result.SkillFile := aItem.SkillFile;

  for i := 0 to Pred(Length(aResults)) do
  begin
    if not SameText(aResults[i].SkillFile, aItem.SkillFile) then
    begin
      Continue;
    end;

    Result.Action := TRelatedSkillAction.rsaSelectResult;
    Result.ResultIndex := i;
    Exit;
  end;
end;

end.
