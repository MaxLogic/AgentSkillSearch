unit SourcesListTests;

interface

procedure RunSourcesListTests;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  SourcesList;

procedure AssertEqualInt(const aExpected, aActual: Integer; const aMessage: string);
begin
  if aExpected <> aActual then
  begin
    raise Exception.CreateFmt('%s | expected=%d actual=%d', [aMessage, aExpected, aActual]);
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

procedure RunSourcesListTests;
begin
  TestCommentsAndPathNormalization;
  TestInvalidPathHandling;
  TestUsableSourcePathsRequireExistingDirectories;
  TestUsableSourcePathsCanBeEmpty;
end;

end.
