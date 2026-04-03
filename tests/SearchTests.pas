unit SearchTests;

interface

procedure RunSearchTests;

implementation

uses
  System.Classes, System.DateUtils, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  AppPaths, DatabaseManager, PreviewEmptyStateHtml, PreviewRenderer, QueryParser, SearchInteraction,
  SearchResultActions, SettingsModel, SkillSearchService, SkillTypes;

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

  lParsed := ParseSearchQuery('tag:"rate limit"');
  AssertEqualInt(1, Length(lParsed.TagFilters), 'Expected quoted multi-word tag filter to stay intact');
  AssertEqualText('rate limit', lParsed.TagFilters[0], 'Expected quoted multi-word tag filter value');
end;

procedure TestSearchInteractionHelpers;
var
  lFocusTarget: TMainFormFocusTarget;
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

  AssertEqualText('tag:docker', AppendTagFilterQuery('', 'docker'),
    'Expected empty query to become a tag filter');
  AssertEqualText('retry tag:docker', AppendTagFilterQuery('retry', 'docker'),
    'Expected clicked tag to append to an existing query');
  AssertEqualText('retry tag:docker', AppendTagFilterQuery(' retry ', 'docker'),
    'Expected clicked tag to append after trimming surrounding spaces');
  AssertEqualText('retry tag:"rate limit"', AppendTagFilterQuery('retry', 'rate limit'),
    'Expected clicked multi-word tag to be quoted');
  AssertEqualText('', BuildSelectedTagsQuery([]), 'Expected empty selected-tag query when nothing is checked');
  AssertEqualText('tag:docker', BuildSelectedTagsQuery(['docker']),
    'Expected one selected tag to become a plain tag clause');
  AssertEqualText('(tag:docker OR tag:"rate limit")', BuildSelectedTagsQuery(['docker', 'rate limit']),
    'Expected multiple selected tags to form one OR group');
  AssertEqualText('(tag:docker OR tag:"rate limit")', BuildSelectedTagsQuery(['docker', 'rate limit', 'docker']),
    'Expected duplicate selected tags to be ignored');
  AssertTrue(TryResolveMainFormFocusShortcut(Ord('L'), [ssCtrl], lFocusTarget),
    'Expected Ctrl+L to resolve to a focus shortcut');
  AssertEqualInt(Ord(TMainFormFocusTarget.mfftSearch), Ord(lFocusTarget),
    'Expected Ctrl+L to focus the search edit');
  AssertTrue(TryResolveMainFormFocusShortcut(Ord('R'), [ssCtrl], lFocusTarget),
    'Expected Ctrl+R to resolve to a focus shortcut');
  AssertEqualInt(Ord(TMainFormFocusTarget.mfftResults), Ord(lFocusTarget),
    'Expected Ctrl+R to focus the results list');
  AssertTrue(not TryResolveMainFormFocusShortcut(Ord('R'), [], lFocusTarget),
    'Expected plain R not to resolve to a focus shortcut');

  AssertEqualInt(-1440, ScaleStoredUiValue(-960, 96, 144),
    'Expected negative restored monitor coordinates to scale across DPI changes');
  AssertEqualInt(1080, ScaleStoredUiValue(720, 96, 144), 'Expected positive UI dimensions to scale across DPI');
  AssertEqualInt(0, ScaleStoredUiValue(0, 96, 144), 'Expected zero UI dimensions to remain zero');
end;

procedure CreateGitResultFixture(const aRepoRoot: string);
var
  lConfigPath: string;
  lHeadPath: string;
  lRemoteHeadPath: string;
begin
  ForceDirectories(TPath.Combine(aRepoRoot, '.git'));
  lConfigPath := TPath.Combine(aRepoRoot, '.git\config');
  lHeadPath := TPath.Combine(aRepoRoot, '.git\HEAD');
  lRemoteHeadPath := TPath.Combine(aRepoRoot, '.git\refs\remotes\origin\HEAD');
  TFile.WriteAllText(
    lConfigPath,
    '[core]' + sLineBreak +
    '	repositoryformatversion = 0' + sLineBreak +
    '	filemode = false' + sLineBreak +
    '	bare = false' + sLineBreak +
    '	logallrefupdates = true' + sLineBreak +
    '[remote "origin"]' + sLineBreak +
    '	url = https://github.com/MaxLogic/AgentSkillSearch.git' + sLineBreak +
    '	fetch = +refs/heads/*:refs/remotes/origin/*' + sLineBreak +
    '[branch "main"]' + sLineBreak +
    '	remote = origin' + sLineBreak +
    '	merge = refs/heads/main' + sLineBreak,
    TEncoding.UTF8
  );
  ForceDirectories(ExtractFilePath(lRemoteHeadPath));
  TFile.WriteAllText(lHeadPath, '0123456789abcdef0123456789abcdef01234567', TEncoding.UTF8);
  TFile.WriteAllText(lRemoteHeadPath, 'ref: refs/remotes/origin/main', TEncoding.UTF8);
end;

procedure TestSearchResultActions;
var
  lMarkdown: string;
  lMarkdownSkillRoots: string;
  lRepoRoot: string;
  lResults: TArray<TSkillSearchResult>;
  lSortMode: TSearchSortMode;
begin
  lRepoRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchGitUrlFixture');
  if TDirectory.Exists(lRepoRoot) then
  begin
    TDirectory.Delete(lRepoRoot, True);
  end;
  ForceDirectories(lRepoRoot);
  CreateGitResultFixture(lRepoRoot);

  SetLength(lResults, 3);

  lResults[0] := Default(TSkillSearchResult);
  lResults[0].Name := 'Zulu Skill';
  lResults[0].SkillFile := TPath.Combine(lRepoRoot, 'skills\zulu\SKILL.md');
  lResults[0].SkillRoot := TPath.Combine(lRepoRoot, 'skills\zulu');
  lResults[0].Description := 'Zulu description';
  lResults[0].FinalScore := 1.5;
  lResults[0].IndexedUtc := '2026-03-10T08:00:00Z';

  lResults[1] := Default(TSkillSearchResult);
  lResults[1].Name := 'Alpha Skill';
  lResults[1].SkillFile := TPath.Combine(lRepoRoot, 'skills\alpha\SKILL.md');
  lResults[1].SkillRoot := TPath.Combine(lRepoRoot, 'skills\alpha');
  lResults[1].Description := 'Alpha description';
  lResults[1].FinalScore := 0.5;
  lResults[1].IndexedUtc := '2026-03-12T08:00:00Z';

  lResults[2] := Default(TSkillSearchResult);
  lResults[2].Name := 'Bravo Skill';
  lResults[2].SkillFile := TPath.Combine(lRepoRoot, 'skills\bravo\SKILL.md');
  lResults[2].SkillRoot := TPath.Combine(lRepoRoot, 'skills\bravo');
  lResults[2].Description := 'Bravo description';
  lResults[2].FinalScore := 1.0;
  lResults[2].IndexedUtc := '2026-03-11T08:00:00Z';

  AssertTrue(TryParseSearchSortMode('date-indexed-desc', lSortMode), 'Expected date-indexed sort mode to parse');
  AssertEqualText('date-indexed-desc', SearchSortModeToString(TSearchSortMode.ssmDateIndexedDesc),
    'Expected date-indexed sort mode to round-trip');
  AssertEqualInt(Integer(TSearchSortMode.ssmScore), Integer(DefaultSearchSortMode),
    'Expected score sort to remain the default');

  SortSearchResults(lResults, TSearchSortMode.ssmNameAsc);
  AssertEqualText('Alpha Skill', lResults[0].Name, 'Expected name sort ascending');
  SortSearchResults(lResults, TSearchSortMode.ssmNameDesc);
  AssertEqualText('Zulu Skill', lResults[0].Name, 'Expected name sort descending');
  SortSearchResults(lResults, TSearchSortMode.ssmPathAsc);
  AssertEqualText(TPath.Combine(lRepoRoot, 'skills\alpha'), lResults[0].SkillRoot, 'Expected path sort ascending');
  SortSearchResults(lResults, TSearchSortMode.ssmDateIndexedDesc);
  AssertEqualText('Alpha Skill', lResults[0].Name, 'Expected newest indexed result first');
  SortSearchResults(lResults, TSearchSortMode.ssmScore);
  AssertEqualText('Zulu Skill', lResults[0].Name, 'Expected highest-score result first');

  lMarkdown := BuildResultsMarkdownList(lResults);
  AssertEqualText(
    '- [Zulu Skill](https://github.com/MaxLogic/AgentSkillSearch/blob/main/skills/zulu/SKILL.md) - Zulu description' +
    sLineBreak +
    '- [Bravo Skill](https://github.com/MaxLogic/AgentSkillSearch/blob/main/skills/bravo/SKILL.md) - Bravo description' +
    sLineBreak +
    '- [Alpha Skill](https://github.com/MaxLogic/AgentSkillSearch/blob/main/skills/alpha/SKILL.md) - Alpha description',
    lMarkdown,
    'Expected markdown export list for git URLs'
  );
  lMarkdownSkillRoots := BuildResultsMarkdownListForSkillRoots(lResults);
  AssertEqualText(
    '- [Zulu Skill](' + TPath.Combine(lRepoRoot, 'skills\zulu') + ') - Zulu description' + sLineBreak +
    '- [Bravo Skill](' + TPath.Combine(lRepoRoot, 'skills\bravo') + ') - Bravo description' + sLineBreak +
    '- [Alpha Skill](' + TPath.Combine(lRepoRoot, 'skills\alpha') + ') - Alpha description',
    lMarkdownSkillRoots,
    'Expected markdown export list for local skill directories'
  );
  AssertTrue(not TryBuildResultsMarkdownList(nil, lMarkdown), 'Expected empty export list to report no export payload');
  AssertEqualText('', lMarkdown, 'Expected empty export list markdown to stay empty');
  AssertTrue(not TryBuildResultsMarkdownListForSkillRoots(nil, lMarkdownSkillRoots),
    'Expected empty local-path export list to report no export payload');
  AssertEqualText('', lMarkdownSkillRoots, 'Expected empty local-path export list markdown to stay empty');
  AssertTrue(not ShouldShowDuplicateDetails(0), 'Expected no duplicate panel for zero duplicates');
  AssertTrue(not ShouldShowDuplicateDetails(1), 'Expected no duplicate panel for canonical-only result');
  AssertTrue(ShouldShowDuplicateDetails(2), 'Expected duplicate panel when duplicate paths exist');
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

procedure TestFindRelatedSkills;
var
  lDbManager: TDatabaseManager;
  lDbPath: string;
  lFixtureRoot: string;
  lRelated: TArray<TRelatedSkillResult>;
  lSemanticOptions: TSemanticSearchOptions;
  lSearchService: TSkillSearchService;
begin
  lFixtureRoot := TPath.Combine(TPath.GetTempPath, 'SkillSearchRelatedFixture');
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
  finally
    lDbManager.Free;
  end;

  lSemanticOptions := DefaultSemanticSearchOptions;
  lSemanticOptions.Enabled := True;
  lSemanticOptions.Model := 'deterministic-v1';
  lSearchService := TSkillSearchService.Create(lDbPath, GetSqliteDllPath, 600, 200, lSemanticOptions);
  try
    lRelated := lSearchService.FindRelatedSkills('C:\skills\repo-alpha\retry-patterns\SKILL.md');
    AssertTrue(Length(lRelated) >= 1, 'Expected at least one related skill');
    AssertEqualText('Retry Patterns Copy', lRelated[0].Name, 'Expected duplicate body to rank as the closest skill');
  finally
    lSearchService.Free;
  end;
end;

procedure TestPreviewEmptyStateHtml;
var
  lHtml: string;
begin
  lHtml := GetPreviewEmptyStateHtml;
  AssertTrue(ContainsText(lHtml, 'Pick a skill on the left and <strong>I''ll crack it open.</strong>'),
    'Expected casual empty-state prompt in preview HTML');
  AssertTrue(ContainsText(lHtml, 'heroLottie'), 'Expected hero lottie host in preview HTML');
  AssertTrue(ContainsText(lHtml, 'miniLottie'), 'Expected accent lottie host in preview HTML');
  AssertTrue(ContainsText(lHtml, 'Ctrl+R'), 'Expected keyboard hint in preview HTML');
  AssertTrue(ContainsText(lHtml, 'https://cdnjs.cloudflare.com/ajax/libs/bodymovin/5.12.2/lottie.min.js'),
    'Expected lottie runtime script in preview HTML');
end;

procedure RunSearchTests;
begin
  TestQueryParserSupportsBooleanOperatorsAndExtensionFilters;
  TestSearchInteractionHelpers;
  TestSearchResultActions;
  TestSearchFiltersAndRanking;
  TestPreviewSnippetHtmlIsSanitizedAndHighlighted;
  TestPreviewEmptyStateHtml;
  TestFindRelatedSkills;
end;

end.
