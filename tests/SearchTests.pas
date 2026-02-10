unit SearchTests;

interface

procedure RunSearchTests;

implementation

uses
  System.DateUtils, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  AppPaths, DatabaseManager, PreviewRenderer, QueryParser, SkillSearchService, SkillTypes;

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

function UtcNowIso8601: string;
var
  lUtcNow: TDateTime;
begin
  lUtcNow := TTimeZone.Local.ToUniversalTime(Now);
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', lUtcNow, TFormatSettings.Invariant);
end;

function BuildSkill(const aRoot, aFileName, aName, aDescription, aTags, aBody: string; const aHasScripts,
  aScriptsCount: Integer; const aScriptsExts: string): TIndexedSkill;
var
  lSkillFile: string;
begin
  lSkillFile := TPath.Combine(aRoot, aFileName);

  Result := Default(TIndexedSkill);
  Result.SourceId := 1;
  Result.RepoId := 0;
  Result.SkillRoot := aRoot;
  Result.SkillFile := lSkillFile;
  Result.Name := aName;
  Result.Description := aDescription;
  Result.Tags := aTags;
  Result.BodyMarkdown := aBody;
  Result.BodyHash := THashSHA2.GetHashString(aBody, THashSHA2.TSHA2Version.SHA256);
  Result.FileMtimeUtc := UtcNowIso8601;
  Result.IndexedUtc := UtcNowIso8601;
  Result.HasScripts := aHasScripts;
  Result.ScriptsCount := aScriptsCount;
  Result.ScriptsExts := aScriptsExts;
end;

procedure SeedSearchFixture(aDbManager: TDatabaseManager);
var
  i: Integer;
  lLongBody: string;
  lSkills: TArray<TIndexedSkill>;
  lRootA: string;
  lRootB: string;
  lRootC: string;
  lRootD: string;
begin
  lRootA := 'C:\skills\repo-alpha\retry-patterns';
  lRootB := 'C:\skills\repo-beta\network-basics';
  lRootC := 'C:\skills\repo-gamma\jwt-auth';
  lRootD := 'C:\skills\repo-delta\retry-patterns-copy';
  lLongBody :=
    'How to implement retry with backoff and rate limit in Delphi.' + sLineBreak +
    'Inline html <script>alert(1)</script> should never render as executable markup.' + sLineBreak;
  for i := 1 to 40 do
  begin
    lLongBody := lLongBody + 'Retry loops should include bounded jitter and clear retry limits. ';
  end;

  SetLength(lSkills, 4);
  lSkills[0] := BuildSkill(
    lRootA,
    'SKILL.md',
    'Retry Patterns',
    'Delphi retry guide',
    'delphi;network',
    lLongBody,
    1,
    2,
    'ps1;py'
  );

  lSkills[1] := BuildSkill(
    lRootB,
    'SKILL.md',
    'Network Basics',
    'General networking notes',
    'network',
    'This body mentions retry but not in title.',
    0,
    0,
    ''
  );

  lSkills[2] := BuildSkill(
    lRootC,
    'SKILL.md',
    'JWT Auth',
    'Authentication with jwt',
    'security;jwt',
    'JWT authentication details and token handling.',
    1,
    1,
    'js'
  );

  lSkills[3] := BuildSkill(
    lRootD,
    'SKILL.md',
    'Retry Patterns Copy',
    'Copy of retry guide',
    'delphi;network',
    lLongBody,
    1,
    2,
    'ps1;py'
  );

  aDbManager.WriteBatch(nil, lSkills);
end;

procedure TestQueryParserUnderstandsHasScriptsFlag;
var
  lParsed: TSearchQuery;
begin
  lParsed := ParseSearchQuery('retry has:scripts limit:20');
  AssertEqualInt(1, lParsed.HasScriptsFilter, 'Expected has:scripts include flag');
  AssertEqualInt(20, lParsed.Limit, 'Expected custom query limit');

  lParsed := ParseSearchQuery('retry -has:scripts');
  AssertEqualInt(0, lParsed.HasScriptsFilter, 'Expected -has:scripts exclude flag');
end;

procedure TestSearchFiltersAndRanking;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lResults: TArray<TSkillSearchResult>;
  lSearchServiceShortSnippet: TSkillSearchService;
  lSearchService: TSkillSearchService;
  lSkillState: TSkillState;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchSearchFixture');
  if TDirectory.Exists(lFixtureRoot) then
  begin
    TDirectory.Delete(lFixtureRoot, True);
  end;
  ForceDirectories(lFixtureRoot);

  lDbPath := TPath.Combine(lFixtureRoot, 'cache\SkillCache.db');
  lDbManager := TDatabaseManager.Create(lDbPath, GetSqliteDllPath);
  try
    lDbManager.Initialize;
    SeedSearchFixture(lDbManager);
    AssertTrue(
      lDbManager.TryGetSkillState('C:\skills\repo-beta\network-basics\SKILL.md', lSkillState),
      'Expected seeded network basics skill row'
    );
    AssertEqualInt(0, lSkillState.HasScripts, 'Seeded non-script skill should keep has_scripts=0');
  finally
    lDbManager.Free;
  end;

  lSearchService := TSkillSearchService.Create(lDbPath, GetSqliteDllPath);
  try
    lResults := lSearchService.Search('retry');
    AssertTrue(Length(lResults) >= 2, 'Expected at least two retry matches');
    AssertTrue(SameText(lResults[0].Name, 'Retry Patterns'), 'Name match should outrank body-only match');
    AssertEqualInt(2, lResults[0].DuplicateCount, 'Expected duplicate collapse count for same body_hash');
    AssertTrue(ContainsText(lResults[0].DuplicatePaths, 'repo-delta'),
      'Expected duplicate paths list to include collapsed location');

    lResults := lSearchService.Search('retry has:scripts');
    AssertEqualInt(1, Length(lResults), 'has:scripts should keep only script-enabled retry skills');
    AssertEqualInt(1, lResults[0].HasScripts, 'Result should have has_scripts=1');
    AssertEqualInt(2, lResults[0].DuplicateCount, 'has:scripts result should preserve duplicate collapse details');

    lResults := lSearchService.Search('retry -has:scripts');
    AssertEqualInt(1, Length(lResults), '-has:scripts should keep only non-script retry skills');
    AssertEqualInt(0, lResults[0].HasScripts, 'Result should have has_scripts=0');

    lResults := lSearchService.Search('retry -jwt');
    AssertTrue(Length(lResults) >= 1, 'Expected retry results with jwt excluded');
    AssertTrue(not ContainsText(lResults[0].Name, 'JWT'), 'Excluded term should remove jwt item from top results');

    lResults := lSearchService.Search('"rate limit" limit:1 path:repo-alpha tag:delphi');
    AssertEqualInt(1, Length(lResults), 'Limit/path/tag filters should narrow to one result');
    AssertTrue(ContainsText(lResults[0].SkillRoot, 'repo-alpha'), 'Path filter mismatch');
    AssertTrue(Length(lResults[0].Snippet) <= 600, 'Default snippet max chars should be enforced');
    AssertTrue(ContainsText(lResults[0].Snippet, '[['), 'Expected snippet highlight markers for FTS hits');
    AssertTrue(ContainsText(lResults[0].Snippet, ']]'), 'Expected snippet highlight markers for FTS hits');
  finally
    lSearchService.Free;
  end;

  lSearchServiceShortSnippet := TSkillSearchService.Create(lDbPath, GetSqliteDllPath, 80);
  try
    lResults := lSearchServiceShortSnippet.Search('retry');
    AssertTrue(Length(lResults) >= 1, 'Expected at least one retry result with short snippet cap');
    AssertTrue(Length(lResults[0].Snippet) <= 80, 'Configured short snippet cap should be enforced');
  finally
    lSearchServiceShortSnippet.Free;
  end;
end;

procedure TestPreviewSnippetHtmlIsSanitizedAndHighlighted;
var
  lHtml: string;
begin
  lHtml := BuildPreviewSnippetHtml('Before [[retry]] <script>alert(1)</script> after');
  AssertTrue(ContainsText(lHtml, '<mark>retry</mark>'), 'Expected highlight markers to render as <mark>');
  AssertTrue(not ContainsText(lHtml, '<script>'), 'Expected raw script tags to be escaped');
  AssertTrue(ContainsText(lHtml, '&lt;script&gt;alert(1)&lt;/script&gt;'),
    'Expected escaped script content in snippet HTML');
end;

procedure RunSearchTests;
begin
  TestQueryParserUnderstandsHasScriptsFlag;
  TestSearchFiltersAndRanking;
  TestPreviewSnippetHtmlIsSanitizedAndHighlighted;
end;

end.
