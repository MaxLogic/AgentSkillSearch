unit SourcesListTests;

interface

procedure RunSourcesListTests;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils, System.UITypes,
  Vcl.Forms,
  SourcesEditorForm, SourcesList;

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

procedure AssertTrue(const aCondition: Boolean; const aMessage: string);
begin
  if not aCondition then
  begin
    raise Exception.Create(aMessage);
  end;
end;

procedure TestCommentsAndPathNormalization;
var
  lBaseDir: string;
  lListFile: string;
  lResult: TSourcesListParseResult;
  lRootDir: string;
  lUtf8: TStringList;
begin
  lRootDir := TPath.Combine(TPath.GetTempPath, 'SkillSearchTests');
  lBaseDir := TPath.Combine(lRootDir, 'base');
  lListFile := TPath.Combine(lRootDir, 'Sources.lst');

  ForceDirectories(lBaseDir);

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('  # comment');
    lUtf8.Add('; comment too');
    lUtf8.Add('// comment too');
    lUtf8.Add('');
    lUtf8.Add('relative\repo');
    lUtf8.Add('C:\Windows');
    lUtf8.Add('\\server\share\repo');
    lUtf8.SaveToFile(lListFile, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lResult := ParseSourcesListFile(lListFile, lBaseDir);

  AssertEqualInt(3, Length(lResult.ValidPaths), 'Valid path count mismatch');
  AssertEqualInt(0, Length(lResult.Issues), 'Issue count mismatch');
  AssertTrue(Pos('relative', lResult.ValidPaths[0]) > 0, 'Relative path was not normalized');
  AssertTrue(SameText('C:\Windows', lResult.ValidPaths[1]), 'Absolute path changed unexpectedly');
  AssertTrue(StartsStr('\\', lResult.ValidPaths[2]), 'UNC path was not preserved');
end;

procedure TestInvalidPathHandling;
var
  lBaseDir: string;
  lListFile: string;
  lResult: TSourcesListParseResult;
  lRootDir: string;
  lUtf8: TStringList;
begin
  lRootDir := TPath.Combine(TPath.GetTempPath, 'SkillSearchTestsInvalid');
  lBaseDir := TPath.Combine(lRootDir, 'base');
  lListFile := TPath.Combine(lRootDir, 'Sources.lst');

  ForceDirectories(lBaseDir);

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('valid\repo');
    lUtf8.Add('bad*path');
    lUtf8.Add('bad?path');
    lUtf8.Add('  // comment');
    lUtf8.SaveToFile(lListFile, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lResult := ParseSourcesListFile(lListFile, lBaseDir);

  AssertEqualInt(1, Length(lResult.ValidPaths), 'Valid path count mismatch for invalid case');
  AssertEqualInt(2, Length(lResult.Issues), 'Invalid paths should be reported as issues');
  AssertTrue(Pos('invalid characters', LowerCase(lResult.Issues[0].Reason)) > 0, 'Expected invalid char issue');
end;

procedure TestUsableSourcePathsRequireExistingDirectories;
var
  lBaseDir: string;
  lExistingDir: string;
  lListFile: string;
  lResult: TSourcesListParseResult;
  lRootDir: string;
  lUtf8: TStringList;
begin
  lRootDir := TPath.Combine(TPath.GetTempPath, 'SkillSearchTestsUsable');
  lBaseDir := TPath.Combine(lRootDir, 'base');
  lExistingDir := TPath.Combine(lBaseDir, 'existing-repo');
  lListFile := TPath.Combine(lRootDir, 'Sources.lst');

  ForceDirectories(lExistingDir);

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('missing-repo');
    lUtf8.Add('existing-repo');
    lUtf8.SaveToFile(lListFile, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lResult := LoadUsableSourcesListFile(lListFile, lBaseDir);

  AssertEqualInt(1, Length(lResult.ValidPaths), 'Only existing directories should remain usable');
  AssertTrue(SameText(lExistingDir, lResult.ValidPaths[0]), 'Existing directory path mismatch');
  AssertEqualInt(1, Length(lResult.Issues), 'Missing directories should be reported as issues');
  AssertTrue(
    Pos('does not exist', LowerCase(lResult.Issues[0].Reason)) > 0,
    'Missing directory should report a does-not-exist issue'
  );
end;

procedure TestUsableSourcePathsCanBeEmpty;
var
  lBaseDir: string;
  lListFile: string;
  lResult: TSourcesListParseResult;
  lRootDir: string;
  lUtf8: TStringList;
begin
  lRootDir := TPath.Combine(TPath.GetTempPath, 'SkillSearchTestsUsableEmpty');
  lBaseDir := TPath.Combine(lRootDir, 'base');
  lListFile := TPath.Combine(lRootDir, 'Sources.lst');

  ForceDirectories(lBaseDir);

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('missing-a');
    lUtf8.Add('missing-b');
    lUtf8.SaveToFile(lListFile, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lResult := LoadUsableSourcesListFile(lListFile, lBaseDir);

  AssertEqualInt(0, Length(lResult.ValidPaths), 'No usable source paths should remain when all directories are missing');
  AssertEqualInt(2, Length(lResult.Issues), 'Each missing directory should be reported as an issue');
end;

procedure TestUsableSourcePathsRejectDuplicateEntries;
var
  lBaseDir: string;
  lExistingDir: string;
  lListFile: string;
  lResult: TSourcesListParseResult;
  lRootDir: string;
  lUtf8: TStringList;
begin
  lRootDir := TPath.Combine(TPath.GetTempPath, 'SkillSearchTestsUsableDuplicates');
  lBaseDir := TPath.Combine(lRootDir, 'base');
  lExistingDir := TPath.Combine(lBaseDir, 'existing-repo');
  lListFile := TPath.Combine(lRootDir, 'Sources.lst');

  ForceDirectories(lExistingDir);

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('existing-repo');
    lUtf8.Add('existing-repo');
    lUtf8.SaveToFile(lListFile, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lResult := LoadUsableSourcesListFile(lListFile, lBaseDir);

  AssertEqualInt(1, Length(lResult.ValidPaths), 'Expected duplicate source paths to collapse to one usable entry');
  AssertEqualText(lExistingDir, lResult.ValidPaths[0], 'Expected duplicate test to keep the existing normalized path');
  AssertEqualInt(1, Length(lResult.Issues), 'Expected duplicate source path to be reported as an issue');
  AssertTrue(Pos('duplicate', LowerCase(lResult.Issues[0].Reason)) > 0, 'Expected duplicate-path issue text');
end;

procedure TestValidateNewSourcePathRejectsDuplicatesAndMissingDirectories;
var
  lBaseDir: string;
  lError: string;
  lExistingDir: string;
  lExistingPaths: TArray<string>;
  lMissingPath: string;
  lNormalizedPath: string;
  lNewDir: string;
  lRootDir: string;
begin
  lRootDir := TPath.Combine(TPath.GetTempPath, 'SkillSearchSourcesValidation');
  lBaseDir := TPath.Combine(lRootDir, 'base');
  lExistingDir := TPath.Combine(lBaseDir, 'existing-repo');
  lNewDir := TPath.Combine(lBaseDir, 'new-repo');
  lMissingPath := TPath.Combine(lBaseDir, 'missing-repo');
  ForceDirectories(lExistingDir);
  ForceDirectories(lNewDir);

  SetLength(lExistingPaths, 1);
  lExistingPaths[0] := lExistingDir;

  AssertTrue(
    TryValidateNewSourcePath('new-repo', lBaseDir, lExistingPaths, lNormalizedPath, lError),
    'Expected a valid existing directory to be accepted'
  );
  AssertEqualText(lNewDir, lNormalizedPath, 'Expected valid path to be normalized against the base directory');

  AssertTrue(
    not TryValidateNewSourcePath('existing-repo', lBaseDir, lExistingPaths, lNormalizedPath, lError),
    'Expected duplicate source path to be rejected'
  );
  AssertTrue(Pos('duplicate', LowerCase(lError)) > 0, 'Expected duplicate-path validation message');

  AssertTrue(
    not TryValidateNewSourcePath(lMissingPath, lBaseDir, lExistingPaths, lNormalizedPath, lError),
    'Expected missing source path to be rejected'
  );
  AssertTrue(Pos('does not exist', LowerCase(lError)) > 0, 'Expected missing-directory validation message');
end;

procedure TestSaveSourcesListFileWritesUtf8Paths;
var
  lLines: TStringList;
  lListFile: string;
  lPaths: TArray<string>;
  lRootDir: string;
begin
  lRootDir := TPath.Combine(TPath.GetTempPath, 'SkillSearchSourcesSave');
  ForceDirectories(lRootDir);
  lListFile := TPath.Combine(lRootDir, 'Sources.lst');

  SetLength(lPaths, 2);
  lPaths[0] := 'C:\skills\alpha';
  lPaths[1] := 'C:\skills\beta';
  SaveSourcesListFile(lListFile, lPaths);

  lLines := TStringList.Create;
  try
    lLines.LoadFromFile(lListFile, TEncoding.UTF8);
    AssertEqualInt(2, lLines.Count, 'Expected saved sources list to contain one line per source path');
    AssertEqualText(lPaths[0], lLines[0], 'Expected saved sources list to preserve the first path');
    AssertEqualText(lPaths[1], lLines[1], 'Expected saved sources list to preserve the second path');
  finally
    lLines.Free;
  end;
end;

procedure TestSourcesEditorFormAddsRemovesAndSavesPaths;
var
  lBaseDir: string;
  lExistingDir: string;
  lForm: TSourcesEditorForm;
  lListFile: string;
  lNewDir: string;
  lReloaded: TSourcesListParseResult;
  lRootDir: string;
  lUtf8: TStringList;
begin
  lRootDir := TPath.Combine(TPath.GetTempPath, 'SkillSearchSourcesEditorForm');
  lBaseDir := TPath.Combine(lRootDir, 'base');
  lExistingDir := TPath.Combine(lBaseDir, 'existing-repo');
  lNewDir := TPath.Combine(lBaseDir, 'new-repo');
  lListFile := TPath.Combine(lRootDir, 'Sources.lst');
  ForceDirectories(lExistingDir);
  ForceDirectories(lNewDir);

  lUtf8 := TStringList.Create;
  try
    lUtf8.Add('existing-repo');
    lUtf8.Add('missing-repo');
    lUtf8.SaveToFile(lListFile, TEncoding.UTF8);
  finally
    lUtf8.Free;
  end;

  lForm := TSourcesEditorForm.Create(nil);
  try
    lForm.InitializeEditor(lListFile, lBaseDir);
    AssertEqualInt(1, lForm.fPathsListBox.Items.Count,
      'Expected editor to list only usable source paths from Sources.lst');
    AssertTrue(Pos('ignored', LowerCase(lForm.fInlineMessageLabel.Caption)) > 0,
      'Expected editor to show an inline warning for filtered source lines');

    lForm.fPathEdit.Text := 'missing-two';
    lForm.HandleAddButtonClick(nil);
    AssertTrue(Pos('does not exist', LowerCase(lForm.fInlineMessageLabel.Caption)) > 0,
      'Expected inline validation message for missing source path');

    lForm.fPathEdit.Text := 'new-repo';
    lForm.HandleAddButtonClick(nil);
    AssertEqualInt(2, lForm.fPathsListBox.Items.Count, 'Expected editor Add to append the new source path');
    AssertEqualText(lNewDir, lForm.fPathsListBox.Items[1], 'Expected editor Add to normalize the new source path');

    lForm.fPathsListBox.ItemIndex := 0;
    lForm.HandleRemoveButtonClick(nil);
    AssertEqualInt(1, lForm.fPathsListBox.Items.Count, 'Expected editor Remove to delete the selected source path');
    AssertEqualText(lNewDir, lForm.fPathsListBox.Items[0], 'Expected only the newly added source path to remain');

    lForm.HandleSaveButtonClick(nil);
    AssertTrue(lForm.ModalResult = System.UITypes.mrOk, 'Expected editor Save to close with mrOk');
  finally
    lForm.Free;
  end;

  lReloaded := LoadUsableSourcesListFile(lListFile, lBaseDir);
  AssertEqualInt(1, Length(lReloaded.ValidPaths), 'Expected saved Sources.lst to reload as one usable source path');
  AssertEqualText(lNewDir, lReloaded.ValidPaths[0], 'Expected saved Sources.lst to contain the edited source path');
end;

procedure RunSourcesListTests;
begin
  TestCommentsAndPathNormalization;
  TestInvalidPathHandling;
  TestUsableSourcePathsRequireExistingDirectories;
  TestUsableSourcePathsCanBeEmpty;
  TestUsableSourcePathsRejectDuplicateEntries;
  TestValidateNewSourcePathRejectsDuplicatesAndMissingDirectories;
  TestSaveSourcesListFileWritesUtf8Paths;
  TestSourcesEditorFormAddsRemovesAndSavesPaths;
end;

end.
