unit SkillIndexer;

interface

uses
  SkillTypes;

function TryBuildIndexedSkill(const aSkillFilePath: string; out aSkill: TIndexedSkill; out aError: string): Boolean;

implementation

uses
  System.DateUtils, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  System.Classes;

function ExtractSkillName(const aBody: string; const aFallback: string): string;
var
  i: Integer;
  lLines: TStringList;
  lLine: string;
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
  lLines: TStringList;
  lLine: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aBody;
    lAfterTitle := False;

    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := Trim(lLines[i]);
      if lLine = '' then
      begin
        Continue;
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

      Result := Copy(lLine, 1, 280);
      Exit;
    end;
  finally
    lLines.Free;
  end;

  Result := '';
end;

function ExtractTags(const aBody: string): string;
var
  i: Integer;
  lLines: TStringList;
  lLine: string;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := aBody;
    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := Trim(lLines[i]);
      if StartsText('Tags:', lLine) then
      begin
        Exit(Trim(Copy(lLine, 6, MaxInt)));
      end;
    end;
  finally
    lLines.Free;
  end;

  Result := '';
end;

function TryBuildIndexedSkill(const aSkillFilePath: string; out aSkill: TIndexedSkill; out aError: string): Boolean;
var
  lBody: string;
  lFallbackName: string;
  lMtimeUtc: TDateTime;
begin
  aSkill := Default(TIndexedSkill);
  aError := '';

  try
    lBody := TFile.ReadAllText(aSkillFilePath, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      aError := 'Failed to read skill file: ' + E.Message;
      Exit(False);
    end;
  end;

  lFallbackName := ExtractFileName(ExtractFileDir(aSkillFilePath));
  lMtimeUtc := TFile.GetLastWriteTimeUtc(aSkillFilePath);

  aSkill.SourceId := 1;
  aSkill.RepoId := 0;
  aSkill.SkillFile := TPath.GetFullPath(aSkillFilePath);
  aSkill.SkillRoot := ExcludeTrailingPathDelimiter(ExtractFileDir(aSkill.SkillFile));
  aSkill.BodyMarkdown := lBody;
  aSkill.BodyHash := THashSHA2.GetHashString(StringReplace(lBody, #13#10, #10, [rfReplaceAll]));
  aSkill.Name := ExtractSkillName(lBody, lFallbackName);
  aSkill.Description := ExtractDescription(lBody);
  aSkill.Tags := ExtractTags(lBody);
  aSkill.FileMtimeUtc := DateToISO8601(lMtimeUtc, False);
  aSkill.IndexedUtc := DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), False);

  Result := True;
end;

end.
