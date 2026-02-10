unit SkillIndexer;

interface

uses
  SkillTypes;

type
  TSkillIndexOptions = record
    ComputeHasScripts: Boolean;
    HasScriptsMaxFilesToScan: Integer;
    HasScriptsSkipFolders: string;
    ScriptExtensions: string;
  end;

function DefaultSkillIndexOptions: TSkillIndexOptions;
function TryBuildIndexedSkill(const aSkillFilePath: string; out aSkill: TIndexedSkill; out aError: string): Boolean; overload;
function TryBuildIndexedSkill(const aSkillFilePath: string; const aOptions: TSkillIndexOptions; out aSkill: TIndexedSkill;
  out aError: string): Boolean; overload;

implementation

uses
  System.Classes, System.DateUtils, System.Generics.Collections, System.Hash, System.IOUtils, System.StrUtils,
  System.SysUtils;

function UtcDateTimeToIso8601(const aUtc: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', aUtc, TFormatSettings.Invariant);
end;

function NormalizeLineEndings(const aBody: string): string;
begin
  Result := StringReplace(aBody, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

function ReadSkillFileText(const aSkillFilePath: string; out aBody: string): Boolean;
begin
  try
    aBody := TFile.ReadAllText(aSkillFilePath, TEncoding.UTF8);
    Exit(True);
  except
    on EEncodingError do
    begin
      try
        aBody := TFile.ReadAllText(aSkillFilePath, TEncoding.ANSI);
        Exit(True);
      except
        Exit(False);
      end;
    end;
    on Exception do
    begin
      Exit(False);
    end;
  end;
end;

function StripQuotes(const aValue: string): string;
var
  lValue: string;
begin
  lValue := Trim(aValue);
  if Length(lValue) >= 2 then
  begin
    if ((lValue[1] = '"') and (lValue[Length(lValue)] = '"')) or
      ((lValue[1] = '''') and (lValue[Length(lValue)] = '''')) then
    begin
      lValue := Copy(lValue, 2, Length(lValue) - 2);
    end;
  end;

  Result := Trim(lValue);
end;

function NormalizeTags(const aValue: string): string;
var
  i: Integer;
  lJoined: string;
  lParts: TArray<string>;
  lRaw: string;
begin
  lRaw := Trim(aValue);
  if (Length(lRaw) >= 2) and (lRaw[1] = '[') and (lRaw[Length(lRaw)] = ']') then
  begin
    lRaw := Copy(lRaw, 2, Length(lRaw) - 2);
  end;

  lRaw := StringReplace(lRaw, ',', ';', [rfReplaceAll]);
  lParts := SplitString(lRaw, ';');

  lJoined := '';
  for i := 0 to Pred(Length(lParts)) do
  begin
    lParts[i] := StripQuotes(lParts[i]);
    if lParts[i] = '' then
    begin
      Continue;
    end;

    if lJoined <> '' then
    begin
      lJoined := lJoined + ';';
    end;
    lJoined := lJoined + lParts[i];
  end;

  Result := lJoined;
end;

function TryExtractFrontMatter(const aBody: string; out aName, aDescription, aTags, aBodyWithoutFrontMatter: string): Boolean;
var
  i: Integer;
  lCloseIndex: Integer;
  lKey: string;
  lLine: string;
  lLines: TStringList;
  lPos: Integer;
  lValue: string;
begin
  aName := '';
  aDescription := '';
  aTags := '';
  aBodyWithoutFrontMatter := aBody;

  lLines := TStringList.Create;
  try
    lLines.Text := aBody;
    if (lLines.Count = 0) or (Trim(lLines[0]) <> '---') then
    begin
      Exit(False);
    end;

    lCloseIndex := -1;
    for i := 1 to Pred(lLines.Count) do
    begin
      if Trim(lLines[i]) = '---' then
      begin
        lCloseIndex := i;
        Break;
      end;
    end;

    if lCloseIndex = -1 then
    begin
      Exit(False);
    end;

    for i := 1 to Pred(lCloseIndex) do
    begin
      lLine := Trim(lLines[i]);
      if lLine = '' then
      begin
        Continue;
      end;

      lPos := Pos(':', lLine);
      if lPos <= 1 then
      begin
        Continue;
      end;

      lKey := LowerCase(Trim(Copy(lLine, 1, lPos - 1)));
      lValue := StripQuotes(Copy(lLine, lPos + 1, MaxInt));

      if lKey = 'name' then
      begin
        aName := lValue;
      end else if lKey = 'description' then
      begin
        aDescription := lValue;
      end else if lKey = 'tags' then
      begin
        aTags := NormalizeTags(lValue);
      end;
    end;

    aBodyWithoutFrontMatter := '';
    for i := lCloseIndex + 1 to Pred(lLines.Count) do
    begin
      aBodyWithoutFrontMatter := aBodyWithoutFrontMatter + lLines[i] + sLineBreak;
    end;

    Result := True;
  finally
    lLines.Free;
  end;
end;

function ExtractSkillName(const aBody: string; const aFallback: string): string;
var
  i: Integer;
  lLine: string;
  lLines: TStringList;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aBody;

    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := Trim(lLines[i]);
      if StartsStr('# ', lLine) then
      begin
        Exit(Trim(Copy(lLine, 3, MaxInt)));
      end;
    end;
  finally
    lLines.Free;
  end;

  Result := aFallback;
end;

function ExtractDescription(const aBody: string): string;
var
  i: Integer;
  lAfterTitle: Boolean;
  lLine: string;
  lLines: TStringList;
  lParagraph: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aBody;
    lAfterTitle := False;
    lParagraph := '';

    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := Trim(lLines[i]);

      if (lLine = '') and (lParagraph <> '') then
      begin
        Break;
      end;

      if StartsStr('# ', lLine) and (not lAfterTitle) then
      begin
        lAfterTitle := True;
        Continue;
      end;

      if StartsText('Tags:', lLine) then
      begin
        Continue;
      end;

      if lLine = '' then
      begin
        Continue;
      end;

      if lParagraph <> '' then
      begin
        lParagraph := lParagraph + ' ';
      end;
      lParagraph := lParagraph + lLine;

      if Length(lParagraph) >= 280 then
      begin
        Break;
      end;
    end;

    Result := Copy(lParagraph, 1, 280);
  finally
    lLines.Free;
  end;
end;

function ExtractTags(const aBody: string): string;
var
  i: Integer;
  lLine: string;
  lLines: TStringList;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aBody;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := Trim(lLines[i]);
      if StartsText('Tags:', lLine) then
      begin
        Exit(NormalizeTags(Copy(lLine, 6, MaxInt)));
      end;
    end;
  finally
    lLines.Free;
  end;

  Result := '';
end;

function IsSkippedDirectory(const aDirectoryPath: string; const aSkipFolders: TDictionary<string, Byte>): Boolean;
var
  lDirName: string;
begin
  lDirName := LowerCase(ExtractFileName(aDirectoryPath));
  Result := aSkipFolders.ContainsKey(lDirName);
end;

procedure ParseSemicolonSet(const aValue: string; const aTrimLeadingDot: Boolean; aItems: TDictionary<string, Byte>);
var
  i: Integer;
  lItem: string;
  lItems: TArray<string>;
begin
  lItems := SplitString(aValue, ';');
  for i := 0 to Pred(Length(lItems)) do
  begin
    lItem := LowerCase(Trim(lItems[i]));
    if lItem = '' then
    begin
      Continue;
    end;

    if aTrimLeadingDot and (Length(lItem) > 1) and (lItem[1] = '.') then
    begin
      lItem := Copy(lItem, 2, MaxInt);
    end;

    if not aItems.ContainsKey(lItem) then
    begin
      aItems.Add(lItem, 1);
    end;
  end;
end;

function BuildExtensionsList(const aExtensions: TDictionary<string, Byte>): string;
var
  lItems: TArray<string>;
begin
  lItems := aExtensions.Keys.ToArray;
  TArray.Sort<string>(lItems);
  Result := string.Join(';', lItems);
end;

procedure ComputeScriptsInfo(const aSkillRoot: string; const aOptions: TSkillIndexOptions; out aHasScripts: Integer;
  out aScriptsCount: Integer; out aScriptsExts: string);
var
  lAllowedExtensions: TDictionary<string, Byte>;
  lDiscoveredExtensions: TDictionary<string, Byte>;
  lDirectory: string;
  lDirectories: TArray<string>;
  lFiles: TArray<string>;
  lPending: TList<string>;
  lScannedFiles: Integer;
  lSkipFolders: TDictionary<string, Byte>;
  lSubDirectory: string;
  lFilePath: string;
  lExtension: string;
begin
  aHasScripts := 0;
  aScriptsCount := 0;
  aScriptsExts := '';

  if not aOptions.ComputeHasScripts then
  begin
    Exit;
  end;

  lAllowedExtensions := TDictionary<string, Byte>.Create;
  lDiscoveredExtensions := TDictionary<string, Byte>.Create;
  lPending := TList<string>.Create;
  lSkipFolders := TDictionary<string, Byte>.Create;
  try
    ParseSemicolonSet(aOptions.ScriptExtensions, True, lAllowedExtensions);
    ParseSemicolonSet(aOptions.HasScriptsSkipFolders, False, lSkipFolders);

    lPending.Add(aSkillRoot);
    lScannedFiles := 0;

    while lPending.Count > 0 do
    begin
      if lScannedFiles >= aOptions.HasScriptsMaxFilesToScan then
      begin
        Break;
      end;

      lDirectory := lPending[lPending.Count - 1];
      lPending.Delete(lPending.Count - 1);

      try
        lFiles := TDirectory.GetFiles(lDirectory);
      except
        on EInOutError do
        begin
          Continue;
        end;
      end;

      for lFilePath in lFiles do
      begin
        Inc(lScannedFiles);
        if lScannedFiles > aOptions.HasScriptsMaxFilesToScan then
        begin
          Break;
        end;

        lExtension := LowerCase(Copy(ExtractFileExt(lFilePath), 2, MaxInt));
        if (lExtension <> '') and lAllowedExtensions.ContainsKey(lExtension) then
        begin
          Inc(aScriptsCount);
          if not lDiscoveredExtensions.ContainsKey(lExtension) then
          begin
            lDiscoveredExtensions.Add(lExtension, 1);
          end;
        end;
      end;

      if lScannedFiles >= aOptions.HasScriptsMaxFilesToScan then
      begin
        Break;
      end;

      try
        lDirectories := TDirectory.GetDirectories(lDirectory);
      except
        on EInOutError do
        begin
          Continue;
        end;
      end;

      for lSubDirectory in lDirectories do
      begin
        if IsSkippedDirectory(lSubDirectory, lSkipFolders) then
        begin
          Continue;
        end;

        lPending.Add(lSubDirectory);
      end;
    end;

    if aScriptsCount > 0 then
    begin
      aHasScripts := 1;
    end;

    aScriptsExts := BuildExtensionsList(lDiscoveredExtensions);
  finally
    lSkipFolders.Free;
    lPending.Free;
    lDiscoveredExtensions.Free;
    lAllowedExtensions.Free;
  end;
end;

function DefaultSkillIndexOptions: TSkillIndexOptions;
begin
  Result.ComputeHasScripts := True;
  Result.HasScriptsMaxFilesToScan := 5000;
  Result.HasScriptsSkipFolders := '.git;node_modules;bin;obj;dist;build;.venv;__pycache__';
  Result.ScriptExtensions := 'py;ps1;bat;cmd;sh;js;ts;lua;rb;pl;go;rs;java;cs;cpp;c;h;pas';
end;

function TryBuildIndexedSkill(const aSkillFilePath: string; out aSkill: TIndexedSkill; out aError: string): Boolean;
begin
  Result := TryBuildIndexedSkill(aSkillFilePath, DefaultSkillIndexOptions, aSkill, aError);
end;

function TryBuildIndexedSkill(const aSkillFilePath: string; const aOptions: TSkillIndexOptions; out aSkill: TIndexedSkill;
  out aError: string): Boolean;
var
  lBody: string;
  lBodyForParsing: string;
  lDescription: string;
  lFallbackName: string;
  lFrontMatterDescription: string;
  lFrontMatterName: string;
  lFrontMatterTags: string;
  lMtimeUtc: TDateTime;
  lName: string;
begin
  aSkill := Default(TIndexedSkill);
  aError := '';

  if not ReadSkillFileText(aSkillFilePath, lBody) then
  begin
    aError := 'Failed to read skill file';
    Exit(False);
  end;

  lBodyForParsing := lBody;
  TryExtractFrontMatter(lBody, lFrontMatterName, lFrontMatterDescription, lFrontMatterTags, lBodyForParsing);

  lFallbackName := ExtractFileName(ExcludeTrailingPathDelimiter(ExtractFileDir(aSkillFilePath)));
  lMtimeUtc := TFile.GetLastWriteTimeUtc(aSkillFilePath);

  lName := lFrontMatterName;
  if lName = '' then
  begin
    lName := ExtractSkillName(lBodyForParsing, lFallbackName);
  end;

  lDescription := lFrontMatterDescription;
  if lDescription = '' then
  begin
    lDescription := ExtractDescription(lBodyForParsing);
  end;

  aSkill.SourceId := 1;
  aSkill.RepoId := 0;
  aSkill.SkillFile := TPath.GetFullPath(aSkillFilePath);
  aSkill.SkillRoot := ExcludeTrailingPathDelimiter(ExtractFileDir(aSkill.SkillFile));
  aSkill.BodyMarkdown := lBody;
  aSkill.BodyHash := THashSHA2.GetHashString(NormalizeLineEndings(lBody), THashSHA2.TSHA2Version.SHA256);
  aSkill.Name := lName;
  aSkill.Description := lDescription;

  if lFrontMatterTags <> '' then
  begin
    aSkill.Tags := lFrontMatterTags;
  end else begin
    aSkill.Tags := ExtractTags(lBodyForParsing);
  end;

  ComputeScriptsInfo(aSkill.SkillRoot, aOptions, aSkill.HasScripts, aSkill.ScriptsCount, aSkill.ScriptsExts);

  aSkill.FileMtimeUtc := UtcDateTimeToIso8601(lMtimeUtc);
  aSkill.IndexedUtc := UtcDateTimeToIso8601(TTimeZone.Local.ToUniversalTime(Now));

  Result := True;
end;

end.
