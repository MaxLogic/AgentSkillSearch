unit TagFilterDialog;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils,
  Vcl.Buttons, Vcl.CheckLst, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.Menus, Vcl.StdCtrls,
  MaxLogic.StrUtils,
  DatabaseManager;

type
  TTagFilterDialog = class(TForm)
  published
    BalloonHint: TBalloonHint;
    BtnCancel: TBitBtn;
    BtnOK: TBitBtn;
    CheckAllMenuItem: TMenuItem;
    ContentPanel: TPanel;
    FilterEdit: TEdit;
    FilterPanel: TPanel;
    FilterLabel: TStaticText;
    FooterPanel: TPanel;
    HeaderPanel: TPanel;
    PopupMenuTags: TPopupMenu;
    SummaryLabel: TStaticText;
    TagCheckListBox: TCheckListBox;
    TagsLabel: TStaticText;
    TagsPanel: TPanel;
    TitleLabel: TStaticText;
    UncheckAllMenuItem: TMenuItem;
    procedure HandleCheckAllClick(Sender: TObject);
    procedure HandleFilterChange(Sender: TObject);
    procedure HandleTagClickCheck(Sender: TObject);
    procedure HandleUncheckAllClick(Sender: TObject);
  private
    fSelectedTags: TStringList;
    fTags: TArray<TSkillTagInfo>;
    fVisibleIndexes: TArray<Integer>;
    procedure ApplyFilter;
    function BuildTagCaption(const aTag: TSkillTagInfo): string;
    procedure CheckVisibleItems(const aChecked: Boolean);
    function CurrentTagIndex: Integer;
    function IsTagSelected(const aTagName: string): Boolean;
    procedure SetTagSelected(const aTagName: string; const aSelected: Boolean);
    procedure UpdateSummary;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    function GetSelectedTags: TArray<string>;
    procedure LoadTags(const aTags: TArray<TSkillTagInfo>; const aSelectedTags: TArray<string>);
    class function SelectTags(aOwner: TComponent; const aTags: TArray<TSkillTagInfo>;
      const aSelectedTags: TArray<string>; out aResultTags: TArray<string>): Boolean; static;
  end;

implementation

uses
  MaxLogic.BalloonDefaultImageList;

{$R *.dfm}

resourcestring
  rsVisibleTagSummary = '%d of %d tags shown';

constructor TTagFilterDialog.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fSelectedTags := TStringList.Create;
  fSelectedTags.CaseSensitive := False;
  fSelectedTags.Duplicates := dupIgnore;
  fSelectedTags.Sorted := True;
  BalloonHint.Images := TImageListForBalloonForm.Instance.ImageList1;
  BalloonHint.ImageIndex := 0;
  CustomHint := BalloonHint;
  ShowHint := True;
end;

destructor TTagFilterDialog.Destroy;
begin
  fSelectedTags.Free;
  inherited Destroy;
end;

procedure TTagFilterDialog.ApplyFilter;
var
  i: Integer;
  lFilterEx: TFilterEx;
  lFilterText: string;
  lVisibleIndexes: TList<Integer>;
begin
  lFilterText := Trim(FilterEdit.Text);
  lVisibleIndexes := TList<Integer>.Create;
  try
    lFilterEx := Default(TFilterEx);
    if lFilterText <> '' then
    begin
      lFilterEx := TFilterEx.Create(lFilterText);
    end;

    TagCheckListBox.Items.BeginUpdate;
    try
      TagCheckListBox.Clear;
      for i := 0 to Pred(Length(fTags)) do
      begin
        if (lFilterText <> '') and (not lFilterEx.Matches(fTags[i].Name)) then
        begin
          Continue;
        end;

        lVisibleIndexes.Add(i);
        TagCheckListBox.Items.Add(BuildTagCaption(fTags[i]));
        TagCheckListBox.Checked[Pred(TagCheckListBox.Count)] := IsTagSelected(fTags[i].Name);
      end;
    finally
      TagCheckListBox.Items.EndUpdate;
    end;

    fVisibleIndexes := lVisibleIndexes.ToArray;
    UpdateSummary;
  finally
    lVisibleIndexes.Free;
  end;
end;

function TTagFilterDialog.BuildTagCaption(const aTag: TSkillTagInfo): string;
begin
  Result := Format('%s (%d)', [aTag.Name, aTag.SkillCount]);
end;

procedure TTagFilterDialog.CheckVisibleItems(const aChecked: Boolean);
var
  i: Integer;
  lTagIndex: Integer;
begin
  for i := 0 to Pred(TagCheckListBox.Count) do
  begin
    TagCheckListBox.Checked[i] := aChecked;
    lTagIndex := fVisibleIndexes[i];
    SetTagSelected(fTags[lTagIndex].Name, aChecked);
  end;
end;

function TTagFilterDialog.CurrentTagIndex: Integer;
begin
  Result := -1;
  if (TagCheckListBox.ItemIndex < 0) or (TagCheckListBox.ItemIndex >= Length(fVisibleIndexes)) then
  begin
    Exit;
  end;

  Result := fVisibleIndexes[TagCheckListBox.ItemIndex];
end;

function TTagFilterDialog.GetSelectedTags: TArray<string>;
var
  lSelectedTags: TList<string>;
  lTag: TSkillTagInfo;
begin
  lSelectedTags := TList<string>.Create;
  try
    for lTag in fTags do
    begin
      if IsTagSelected(lTag.Name) then
      begin
        lSelectedTags.Add(lTag.Name);
      end;
    end;
    Result := lSelectedTags.ToArray;
  finally
    lSelectedTags.Free;
  end;
end;

procedure TTagFilterDialog.HandleCheckAllClick(Sender: TObject);
begin
  CheckVisibleItems(True);
end;

procedure TTagFilterDialog.HandleFilterChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TTagFilterDialog.HandleTagClickCheck(Sender: TObject);
var
  lTagIndex: Integer;
begin
  lTagIndex := CurrentTagIndex;
  if lTagIndex < 0 then
  begin
    Exit;
  end;

  SetTagSelected(fTags[lTagIndex].Name, TagCheckListBox.Checked[TagCheckListBox.ItemIndex]);
end;

procedure TTagFilterDialog.HandleUncheckAllClick(Sender: TObject);
begin
  CheckVisibleItems(False);
end;

function TTagFilterDialog.IsTagSelected(const aTagName: string): Boolean;
begin
  Result := fSelectedTags.IndexOf(aTagName) >= 0;
end;

procedure TTagFilterDialog.LoadTags(const aTags: TArray<TSkillTagInfo>; const aSelectedTags: TArray<string>);
var
  lSelectedTag: string;
begin
  fTags := Copy(aTags);
  fSelectedTags.Clear;
  for lSelectedTag in aSelectedTags do
  begin
    SetTagSelected(lSelectedTag, True);
  end;
  ApplyFilter;
end;

class function TTagFilterDialog.SelectTags(aOwner: TComponent; const aTags: TArray<TSkillTagInfo>;
  const aSelectedTags: TArray<string>; out aResultTags: TArray<string>): Boolean;
var
  lDialog: TTagFilterDialog;
begin
  aResultTags := Copy(aSelectedTags);
  lDialog := TTagFilterDialog.Create(aOwner);
  try
    lDialog.LoadTags(aTags, aSelectedTags);
    Result := lDialog.ShowModal = mrOk;
    if Result then
    begin
      aResultTags := lDialog.GetSelectedTags;
    end;
  finally
    lDialog.Free;
  end;
end;

procedure TTagFilterDialog.SetTagSelected(const aTagName: string; const aSelected: Boolean);
var
  lIndex: Integer;
begin
  lIndex := fSelectedTags.IndexOf(aTagName);
  if aSelected then
  begin
    if lIndex < 0 then
    begin
      fSelectedTags.Add(aTagName);
    end;
  end else begin
    if lIndex >= 0 then
    begin
      fSelectedTags.Delete(lIndex);
    end;
  end;
end;

procedure TTagFilterDialog.UpdateSummary;
begin
  SummaryLabel.Caption := Format(rsVisibleTagSummary, [Length(fVisibleIndexes), Length(fTags)]);
end;

end.
