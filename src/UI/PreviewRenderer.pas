unit PreviewRenderer;

interface

function BuildPreviewSnippetHtml(const aSnippet: string): string;
function HighlightPreviewTerms(const aText, aRawQuery: string): string;

implementation

uses
  System.Classes, System.Generics.Collections, System.RegularExpressions, System.StrUtils, System.SysUtils,
  QueryParser;

function EscapeHtml(const aText: string): string;
begin
  Result := StringReplace(aText, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

function RestoreHighlightMarkers(const aText: string): string;
begin
  Result := StringReplace(aText, '[[', '<mark>', [rfReplaceAll]);
  Result := StringReplace(Result, ']]', '</mark>', [rfReplaceAll]);
end;

function ReplaceMarkdownImages(const aText: string): string;
begin
  Result := TRegEx.Replace(aText, '!\[(.*?)\]\((.*?)\)', '[Image: $1]');
  Result := StringReplace(Result, '[Image: ]', '[Image: Image]', [rfReplaceAll]);
end;

function ApplyInlineMarkdown(const aText: string): string;
begin
  Result := ReplaceMarkdownImages(aText);
  Result := EscapeHtml(Result);
  Result := TRegEx.Replace(
    Result,
    '`(.+?)`',
    '<code style="background:#f5f5f5;border-radius:4px;padding:1px 4px;">$1</code>'
  );
  Result := TRegEx.Replace(Result, '\*\*(.+?)\*\*', '<strong>$1</strong>');
  Result := TRegEx.Replace(Result, '(?<!\*)\*(.+?)\*(?!\*)', '<em>$1</em>');
  Result := RestoreHighlightMarkers(Result);
end;

procedure CloseHtmlList(aBuilder: TStringBuilder; var aInList: Boolean);
begin
  if not aInList then
  begin
    Exit;
  end;

  aBuilder.AppendLine('</ul>');
  aInList := False;
end;

function TryParseBulletLine(const aLine: string; out aContent: string): Boolean;
var
  lTrimmed: string;
begin
  lTrimmed := Trim(aLine);
  Result := StartsText('- ', lTrimmed) or StartsText('* ', lTrimmed);
  if Result then
  begin
    aContent := Trim(Copy(lTrimmed, 3, MaxInt));
  end else begin
    aContent := '';
  end;
end;

function TryParseHeadingLine(const aLine: string; out aLevel: Integer; out aContent: string): Boolean;
var
  i: Integer;
  lTrimmed: string;
begin
  aLevel := 0;
  aContent := '';
  lTrimmed := Trim(aLine);

  i := 1;
  while (i <= Length(lTrimmed)) and (lTrimmed[i] = '#') do
  begin
    Inc(aLevel);
    Inc(i);
  end;

  Result := (aLevel >= 1) and (aLevel <= 6) and (i <= Length(lTrimmed)) and (lTrimmed[i] = ' ');
  if Result then
  begin
    aContent := Trim(Copy(lTrimmed, i + 1, MaxInt));
  end else begin
    aLevel := 0;
  end;
end;

function IsCodeFenceLine(const aLine: string; out aLanguage: string): Boolean;
var
  lTrimmed: string;
begin
  lTrimmed := Trim(aLine);
  Result := StartsText('```', lTrimmed);
  if Result then
  begin
    aLanguage := Trim(Copy(lTrimmed, 4, MaxInt));
  end else begin
    aLanguage := '';
  end;
end;

function NormalizeMarkdownText(const aText: string): string;
begin
  Result := StringReplace(aText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

function CollectHighlightTerms(const aRawQuery: string): TArray<string>;
var
  i: Integer;
  j: Integer;
  lAlreadySeen: Boolean;
  lSearchQuery: TSearchQuery;
  lTerms: TList<string>;
begin
  lTerms := TList<string>.Create;
  try
    lSearchQuery := ParseSearchQuery(aRawQuery);
    for i := 0 to Pred(Length(lSearchQuery.PositiveTerms)) do
    begin
      if Trim(lSearchQuery.PositiveTerms[i]) = '' then
      begin
        Continue;
      end;

      lAlreadySeen := False;
      for j := 0 to Pred(lTerms.Count) do
      begin
        if SameText(lTerms[j], lSearchQuery.PositiveTerms[i]) then
        begin
          lAlreadySeen := True;
          Break;
        end;
      end;
      if lAlreadySeen then
      begin
        Continue;
      end;

      lTerms.Add(lSearchQuery.PositiveTerms[i]);
    end;

    Result := lTerms.ToArray;
  finally
    lTerms.Free;
  end;
end;

function HighlightPreviewTerms(const aText, aRawQuery: string): string;
var
  i: Integer;
  j: Integer;
  lTerms: TArray<string>;
  lSwap: string;
begin
  Result := aText;
  lTerms := CollectHighlightTerms(aRawQuery);

  for i := 0 to High(lTerms) do
  begin
    for j := i + 1 to High(lTerms) do
    begin
      if Length(lTerms[j]) > Length(lTerms[i]) then
      begin
        lSwap := lTerms[i];
        lTerms[i] := lTerms[j];
        lTerms[j] := lSwap;
      end;
    end;
  end;

  for i := 0 to High(lTerms) do
  begin
    if Trim(lTerms[i]) = '' then
    begin
      Continue;
    end;

    Result := StringReplace(Result, lTerms[i], '[[' + lTerms[i] + ']]', [rfIgnoreCase, rfReplaceAll]);
  end;
end;

function BuildPreviewSnippetHtml(const aSnippet: string): string;
var
  i: Integer;
  lBuilder: TStringBuilder;
  lContent: string;
  lHeadingLevel: Integer;
  lHeadingText: string;
  lInCodeBlock: Boolean;
  lInList: Boolean;
  lLanguage: string;
  lLines: TStringList;
  lLine: string;
begin
  lLines := TStringList.Create;
  lBuilder := TStringBuilder.Create;
  try
    lLines.Text := NormalizeMarkdownText(aSnippet);
    lInCodeBlock := False;
    lInList := False;

    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i];

      if IsCodeFenceLine(lLine, lLanguage) then
      begin
        CloseHtmlList(lBuilder, lInList);
        if not lInCodeBlock then
        begin
          lBuilder.Append('<pre style="background:#f5f5f5;border-radius:8px;padding:12px;overflow:auto;">');
          lBuilder.Append('<code');
          if lLanguage <> '' then
          begin
            lBuilder.Append(' class="language-').Append(EscapeHtml(lLanguage)).Append('"');
          end;
          lBuilder.AppendLine('>');
          lInCodeBlock := True;
        end else begin
          lBuilder.AppendLine('</code></pre>');
          lInCodeBlock := False;
        end;
        Continue;
      end;

      if lInCodeBlock then
      begin
        lBuilder.AppendLine(RestoreHighlightMarkers(EscapeHtml(lLine)));
        Continue;
      end;

      if Trim(lLine) = '' then
      begin
        CloseHtmlList(lBuilder, lInList);
        Continue;
      end;

      if TryParseHeadingLine(lLine, lHeadingLevel, lHeadingText) then
      begin
        CloseHtmlList(lBuilder, lInList);
        lBuilder.Append('<h').Append(lHeadingLevel).Append('>');
        lBuilder.Append(ApplyInlineMarkdown(lHeadingText));
        lBuilder.Append('</h').Append(lHeadingLevel).AppendLine('>');
        Continue;
      end;

      if TryParseBulletLine(lLine, lContent) then
      begin
        if not lInList then
        begin
          lBuilder.AppendLine('<ul>');
          lInList := True;
        end;

        lBuilder.Append('<li>');
        lBuilder.Append(ApplyInlineMarkdown(lContent));
        lBuilder.AppendLine('</li>');
        Continue;
      end;

      CloseHtmlList(lBuilder, lInList);
      lBuilder.Append('<p>');
      lBuilder.Append(ApplyInlineMarkdown(Trim(lLine)));
      lBuilder.AppendLine('</p>');
    end;

    CloseHtmlList(lBuilder, lInList);
    if lInCodeBlock then
    begin
      lBuilder.AppendLine('</code></pre>');
    end;

    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
    lLines.Free;
  end;
end;

end.
