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

procedure RunSourcesListTests;
begin
  TestCommentsAndPathNormalization;
  TestInvalidPathHandling;
end;

end.
