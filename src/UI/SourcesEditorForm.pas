unit SourcesEditorForm;

interface

uses
  System.Classes,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls,
  SourcesList;

type
  TSourcesEditorForm = class(TForm)
    fActionsPanel: TPanel;
    fAddButton: TButton;
    fBrowseButton: TButton;
    fCancelButton: TButton;
    fContentPanel: TPanel;
    fEntryPanel: TPanel;
    fHeaderLabel: TStaticText;
    fInlineMessageLabel: TStaticText;
    fListToolsPanel: TPanel;
    fPathEdit: TEdit;
    fPathLabel: TStaticText;
    fPathsListBox: TListBox;
    fPathsListLabel: TStaticText;
    fPathsPanel: TPanel;
    fRemoveButton: TButton;
    fSaveButton: TButton;
    procedure HandleAddButtonClick(Sender: TObject);
    procedure HandleBrowseButtonClick(Sender: TObject);
    procedure HandlePathEditChange(Sender: TObject);
    procedure HandlePathsListBoxClick(Sender: TObject);
    procedure HandleRemoveButtonClick(Sender: TObject);
    procedure HandleSaveButtonClick(Sender: TObject);
  private
    fBaseDirectory: string;
    fSourcesListPath: string;
    function CurrentPaths: TArray<string>;
    procedure LoadSources;
    procedure SetInlineMessage(const aText: string; const aIsError: Boolean = True);
    procedure UpdateUiState;
  public
    procedure InitializeEditor(const aSourcesListPath, aBaseDirectory: string);
    class function Execute(aOwner: TComponent; const aSourcesListPath, aBaseDirectory: string): Boolean;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Vcl.FileCtrl, Vcl.Graphics;

{$R *.dfm}

resourcestring
  rsSourcesListLoadIssues = 'Ignored %d invalid Sources.lst lines while loading.';
  rsSourcesListMissing = '%s does not exist yet. Save to create it.';
  rsSourcesListSaveFailed = 'Unable to save Sources.lst: %s';
  rsSourceFolderCaption = 'Select source folder';

class function TSourcesEditorForm.Execute(aOwner: TComponent; const aSourcesListPath, aBaseDirectory: string): Boolean;
var
  lForm: TSourcesEditorForm;
begin
  lForm := TSourcesEditorForm.Create(aOwner);
  try
    lForm.InitializeEditor(aSourcesListPath, aBaseDirectory);
    Result := lForm.ShowModal = mrOk;
  finally
    lForm.Free;
  end;
end;

function TSourcesEditorForm.CurrentPaths: TArray<string>;
var
  i: Integer;
begin
  SetLength(Result, fPathsListBox.Items.Count);
  for i := 0 to Pred(fPathsListBox.Items.Count) do
  begin
    Result[i] := fPathsListBox.Items[i];
  end;
end;

procedure TSourcesEditorForm.InitializeEditor(const aSourcesListPath, aBaseDirectory: string);
begin
  fSourcesListPath := aSourcesListPath;
  fBaseDirectory := TPath.GetFullPath(aBaseDirectory);
  LoadSources;
end;

procedure TSourcesEditorForm.LoadSources;
var
  i: Integer;
  lParseResult: TSourcesListParseResult;
begin
  fPathsListBox.Items.BeginUpdate;
  try
    fPathsListBox.Clear;
    if TFile.Exists(fSourcesListPath) then
    begin
      lParseResult := LoadUsableSourcesListFile(fSourcesListPath, fBaseDirectory);
      for i := 0 to Pred(Length(lParseResult.Entries)) do
      begin
        fPathsListBox.Items.Add(lParseResult.Entries[i].NormalizedPath);
      end;

      if Length(lParseResult.Issues) > 0 then
      begin
        SetInlineMessage(Format(rsSourcesListLoadIssues, [Length(lParseResult.Issues)]), False);
      end else begin
        SetInlineMessage('', False);
      end;
    end else begin
      SetInlineMessage(Format(rsSourcesListMissing, [ExtractFileName(fSourcesListPath)]), False);
    end;
  finally
    fPathsListBox.Items.EndUpdate;
  end;

  UpdateUiState;
end;

procedure TSourcesEditorForm.SetInlineMessage(const aText: string; const aIsError: Boolean);
begin
  fInlineMessageLabel.Caption := aText;
  if aIsError then
  begin
    fInlineMessageLabel.Font.Color := clMaroon;
  end else begin
    fInlineMessageLabel.Font.Color := clGrayText;
  end;
end;

procedure TSourcesEditorForm.UpdateUiState;
begin
  fAddButton.Enabled := Trim(fPathEdit.Text) <> '';
  fRemoveButton.Enabled := fPathsListBox.ItemIndex >= 0;
end;

procedure TSourcesEditorForm.HandleAddButtonClick(Sender: TObject);
var
  lError: string;
  lNormalizedPath: string;
  lPaths: TArray<string>;
begin
  lPaths := CurrentPaths;
  if not TryValidateNewSourcePath(fPathEdit.Text, fBaseDirectory, lPaths, lNormalizedPath, lError) then
  begin
    SetInlineMessage(lError);
    if Showing and fPathEdit.Visible and fPathEdit.Enabled then
    begin
      fPathEdit.SetFocus;
      fPathEdit.SelectAll;
    end;
    Exit;
  end;

  fPathsListBox.Items.Add(lNormalizedPath);
  fPathsListBox.ItemIndex := fPathsListBox.Items.Count - 1;
  fPathEdit.Clear;
  SetInlineMessage('', False);
  UpdateUiState;
end;

procedure TSourcesEditorForm.HandleBrowseButtonClick(Sender: TObject);
var
  lDirectory: string;
begin
  lDirectory := Trim(fPathEdit.Text);
  if lDirectory = '' then
  begin
    lDirectory := fBaseDirectory;
  end;

  if not SelectDirectory(rsSourceFolderCaption, '', lDirectory, [TSelectDirExtOpt.sdNewUI], Self) then
  begin
    Exit;
  end;

  fPathEdit.Text := lDirectory;
  if Showing and fPathEdit.Visible and fPathEdit.Enabled then
  begin
    fPathEdit.SetFocus;
    fPathEdit.SelectAll;
  end;
  SetInlineMessage('', False);
  UpdateUiState;
end;

procedure TSourcesEditorForm.HandlePathEditChange(Sender: TObject);
begin
  SetInlineMessage('', False);
  UpdateUiState;
end;

procedure TSourcesEditorForm.HandlePathsListBoxClick(Sender: TObject);
begin
  UpdateUiState;
end;

procedure TSourcesEditorForm.HandleRemoveButtonClick(Sender: TObject);
var
  lIndex: Integer;
begin
  lIndex := fPathsListBox.ItemIndex;
  if lIndex < 0 then
  begin
    Exit;
  end;

  fPathsListBox.Items.Delete(lIndex);
  if lIndex >= fPathsListBox.Items.Count then
  begin
    fPathsListBox.ItemIndex := fPathsListBox.Items.Count - 1;
  end else begin
    fPathsListBox.ItemIndex := lIndex;
  end;

  SetInlineMessage('', False);
  UpdateUiState;
end;

procedure TSourcesEditorForm.HandleSaveButtonClick(Sender: TObject);
begin
  try
    SaveSourcesListFile(fSourcesListPath, CurrentPaths);
    ModalResult := mrOk;
  except
    on E: Exception do
    begin
      SetInlineMessage(Format(rsSourcesListSaveFailed, [E.Message]));
    end;
  end;
end;

end.
