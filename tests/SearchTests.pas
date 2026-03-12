unit SearchTests;

interface

procedure RunSearchTests;

implementation

uses
  System.DateUtils, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  AppPaths, DatabaseManager, PreviewRenderer, QueryParser, SearchInteraction, SettingsModel, SkillSearchService,
  SkillTypes;

procedure AssertEqualInt(const aExpected, aActual: Integer; const aMessage: string);
begin
  if aExpected <> aActual then
  begin
    raise Exception.CreateFmt('%s | expected=%d actual=%d', [aMessage, aExpected, aActual]);
  end;
end;

procedure AssertEqualText(const aExpected, aActual, aMessage: string);
begin
  if aExpected <> aActual then
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
  lRootE: string;
begin
  lRootA := 'C:\skills\repo-alpha\retry-patterns';
  lRootB := 'C:\skills\repo-beta\network-basics';
  lRootC := 'C:\skills\repo-gamma\jwt-auth';
  lRootD := 'C:\skills\repo-delta\retry-patterns-copy';
  lRootE := 'C:\skills\repo-epsilon\backoff-basics';
  lLongBody :=
    'How to implement retry with backoff and rate limit in Delphi.' + sLineBreak +
    'Inline html <script>alert(1)</script> should never render as executable markup.' + sLineBreak;
  for i := 1 to 40 do
  begin
    lLongBody := lLongBody + 'Retry loops should include bounded jitter and clear retry limits. ';
  end;

  SetLength(lSkills, 5);
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

  lSkills[4] := BuildSkill(
    lRootE,
    'SKILL.md',
    'Backoff Strategy',
    'Backoff-only guide',
    'resilience',
    'Exponential backoff strategies for flaky services.',
    1,
    2,
    'ps1;sh'
  );

  aDbManager.WriteBatch(nil, lSkills);
end;

procedure TestQueryParserSupportsBooleanOperatorsAndExtensionFilters;
var
  lExpression: string;
  lParsed: TSearchQuery;
begin
  lParsed := ParseSearchQuery('retry', 500);
  AssertEqualInt(500, lParsed.Limit, 'Expected settings-driven default query limit');

  lParsed := ParseSearchQuery('retry has:scripts limit:20');
  AssertEqualInt(1, lParsed.HasScriptsFilter, 'Expected has:scripts include flag');
  AssertEqualInt(20, lParsed.Limit, 'Expected custom query limit');

  lParsed := ParseSearchQuery('retry -has:scripts');
  AssertEqualInt(0, lParsed.HasScriptsFilter, 'Expected -has:scripts exclude flag');

  lParsed := ParseSearchQuery('retry OR backoff');
  lExpression := BuildFtsMatchExpression(lParsed);
  AssertEqualText('(retry* OR backoff*)', lExpression, 'Expected OR expression in FTS query');

  lParsed := ParseSearchQuery('retry or backoff');
  lExpression := BuildFtsMatchExpression(lParsed);
  AssertEqualText('(retry* OR backoff*)', lExpression, 'Expected case-insensitive OR expression in FTS query');

  lParsed := ParseSearchQuery('(retry OR backoff) timeout');
  lExpression := BuildFtsMatchExpression(lParsed);
  AssertEqualText('((retry* OR backoff*) AND timeout*)', lExpression,
    'Expected grouped OR terms to combine with implicit AND');

  lParsed := ParseSearchQuery('retry AND backoff');
  lExpression := BuildFtsMatchExpression(lParsed);
  AssertEqualText('(retry* AND backoff*)', lExpression, 'Explicit AND should preserve AND semantics');
end;

procedure TestSearchInteractionHelpers;
var
  lHistory: TSearchHistorySettings;
  lPreparedCount: Integer;
  lQuery: string;
  lSelectedQuery: string;
begin
  lHistory.MaxItems := 3;
  lHistory.Items := ['jwt', 'backoff'];

  lPreparedCount := 0;
  lQuery := '';
  ExecuteImmediateSearch(
    ' retry tag:docker ',
    lHistory,
    procedure(const aPreparedQuery: string)
    begin
      Inc(lPreparedCount);
      lQuery := aPreparedQuery;
    end
  );
  AssertEqualInt(1, lPreparedCount, 'Expected immediate search to trigger one prepared callback');
  AssertEqualText('retry tag:docker', lQuery, 'Expected trimmed immediate search query');
  AssertEqualInt(3, Length(lHistory.Items), 'Expected history to keep max-item limit');
  AssertEqualText('retry tag:docker', lHistory.Items[0], 'Expected immediate search to promote query to top history');
  AssertEqualText('jwt', lHistory.Items[1], 'Expected previous top history item to shift down');
  AssertEqualText('backoff', lHistory.Items[2], 'Expected oldest retained history item to remain last');

  lPreparedCount := 0;
  lQuery := '';
  lSelectedQuery := '';
  ExecuteHistorySelection(
    'jwt',
    lHistory,
    procedure(const aSelected: string)
    begin
      lSelectedQuery := aSelected;
    end,
    procedure(const aPreparedQuery: string)
    begin
      Inc(lPreparedCount);
      lQuery := aPreparedQuery;
    end
  );
  AssertEqualText('jwt', lSelectedQuery, 'Expected history selection to apply the selected query text');
  AssertEqualInt(1, lPreparedCount, 'Expected history selection to trigger one prepared search');
  AssertEqualText('jwt', lQuery, 'Expected selected history item to trigger the same query');
  AssertEqualText('jwt', lHistory.Items[0], 'Expected selected history query to move to the top');
  AssertEqualText('retry tag:docker', lHistory.Items[1], 'Expected previous top history query to shift down');
  AssertEqualText('backoff', lHistory.Items[2], 'Expected remaining history order to stay stable');

  AssertEqualInt(-1440, ScaleStoredUiValue(-960, 96, 144),
    'Expected negative restored monitor coordinates to scale across DPI changes');
  AssertEqualInt(1080, ScaleStoredUiValue(720, 96, 144), 'Expected positive UI dimensions to scale across DPI');
  AssertEqualInt(0, ScaleStoredUiValue(0, 96, 144), 'Expected zero UI dimensions to remain zero');
end;

procedure TestSearchFiltersAndRanking;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lResults: TArray<TSkillSearchResult>;
  lSemanticOptions: TSemanticSearchOptions;
  lSemanticSearchService: TSkillSearchService;
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
    AssertEqualInt(5, lDbManager.GetValidSkillCount, 'Expected valid skills count to include all seeded rows');
    AssertEqualInt(4, lDbManager.GetUniqueSkillCount, 'Expected unique skills count after body_hash dedup');
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

    lResults := lSearchService.Search('net basi');
    AssertTrue(Length(lResults) >= 1, 'Prefix query should match network basics skill');
    AssertTrue(SameText(lResults[0].Name, 'Network Basics'),
      'Prefix query should rank the network basics name match first');

    lResults := lSearchService.Search('"rate limit" limit:1 path:repo-alpha tag:delphi');
    AssertEqualInt(1, Length(lResults), 'Limit/path/tag filters should narrow to one result');
    AssertTrue(ContainsText(lResults[0].SkillRoot, 'repo-alpha'), 'Path filter mismatch');
    AssertTrue(Length(lResults[0].Snippet) <= 600, 'Default snippet max chars should be enforced');
    AssertTrue(ContainsText(lResults[0].Snippet, '[['), 'Expected snippet highlight markers for FTS hits');
    AssertTrue(ContainsText(lResults[0].Snippet, ']]'), 'Expected snippet highlight markers for FTS hits');

    lResults := lSearchService.Search('retry OR backoff');
    AssertEqualInt(3, Length(lResults), 'OR query should match retry-only, backoff-only, and combined skills');
    AssertTrue(ContainsText(lResults[0].Name, 'Retry'), 'Combined retry/backoff skill should still rank first');
    AssertTrue(
      SameText(lResults[1].Name, 'Backoff Strategy') or SameText(lResults[2].Name, 'Backoff Strategy'),
      'Expected backoff-only skill to match OR query'
    );
    AssertTrue(
      SameText(lResults[1].Name, 'Network Basics') or SameText(lResults[2].Name, 'Network Basics'),
      'Expected retry-only skill to match OR query'
    );

    lResults := lSearchService.Search('retry AND backoff');
    AssertEqualInt(1, Length(lResults), 'Explicit AND should keep only skills containing both terms');
    AssertTrue(SameText(lResults[0].Name, 'Retry Patterns'),
      'Explicit AND should keep the combined retry/backoff skill');

    lResults := lSearchService.Search('retry backoff');
    AssertEqualInt(1, Length(lResults), 'Implicit multi-term search should still require both terms');
    AssertTrue(SameText(lResults[0].Name, 'Retry Patterns'),
      'Implicit multi-term search should keep the combined retry/backoff skill');

    lResults := lSearchService.Search('ext:py');
    AssertEqualInt(1, Length(lResults), 'ext:py should keep only py-enabled skills');
    AssertTrue(SameText(lResults[0].Name, 'Retry Patterns'), 'ext:py should return the py-enabled fixture');

    lResults := lSearchService.Search('ext:ps1 ext:sh');
    AssertEqualInt(1, Length(lResults), 'Multiple ext filters should AND-combine');
    AssertTrue(SameText(lResults[0].Name, 'Backoff Strategy'),
      'Expected ps1+sh filter to keep only the matching skill');

    lResults := lSearchService.Search('ext:java');
    AssertEqualInt(0, Length(lResults), 'Unknown ext filter should exclude non-matching skills');
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

  lSemanticOptions := DefaultSemanticSearchOptions;
  lSemanticOptions.Enabled := True;
  lSemanticOptions.OllamaBaseUrl := 'http://127.0.0.1:9';
  lSemanticOptions.Model := 'mxbai-embed-large';
  lSemanticOptions.CandidateRerankCount := 10;

  lSemanticSearchService := TSkillSearchService.Create(lDbPath, GetSqliteDllPath, 600, lSemanticOptions);
  try
    lResults := lSemanticSearchService.Search('retry');
    AssertTrue(Length(lResults) >= 2, 'Fallback search should still return lexical results');
    AssertTrue(SameText(lResults[0].Name, 'Retry Patterns'),
      'Fallback behavior should preserve lexical ordering when semantic provider is unavailable');
  finally
    lSemanticSearchService.Free;
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

  lHtml := BuildPreviewSnippetHtml(
    '## Preview Title' + sLineBreak + sLineBreak +
    'Some **bold** and *italic* [[retry]] text.' + sLineBreak + sLineBreak +
    '- first item' + sLineBreak +
    '- second item' + sLineBreak + sLineBreak +
    '```delphi' + sLineBreak +
    'ShowMessage(''retry'');' + sLineBreak +
    '```' + sLineBreak + sLineBreak +
    '![remote](https://example.com/image.png)'
  );
  AssertTrue(ContainsText(lHtml, '<h2>Preview Title</h2>'), 'Expected markdown headings to render as HTML headings');
  AssertTrue(ContainsText(lHtml, '<strong>bold</strong>'), 'Expected bold markdown to render as <strong>');
  AssertTrue(ContainsText(lHtml, '<em>italic</em>'), 'Expected italic markdown to render as <em>');
  AssertTrue(ContainsText(lHtml, '<ul>') and ContainsText(lHtml, '<li>first item</li>'),
    'Expected bullet list markdown to render as an unordered list');
  AssertTrue(ContainsText(lHtml, '<pre') and ContainsText(lHtml, 'ShowMessage'),
    'Expected fenced code blocks to render inside <pre><code>');
  AssertTrue(not ContainsText(lHtml, 'https://example.com/image.png'),
    'Expected remote image URLs to be blocked from the rendered preview');
  AssertTrue(ContainsText(lHtml, 'remote'), 'Expected remote image alt text or placeholder to remain visible');
end;

procedure RunSearchTests;
begin
  TestQueryParserSupportsBooleanOperatorsAndExtensionFilters;
  TestSearchInteractionHelpers;
  TestSearchFiltersAndRanking;
  TestPreviewSnippetHtmlIsSanitizedAndHighlighted;
end;

end.
