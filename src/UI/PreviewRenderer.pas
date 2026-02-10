unit PreviewRenderer;

interface

function BuildPreviewSnippetHtml(const aSnippet: string): string;

implementation

uses
  System.SysUtils;

function EscapeHtml(const aText: string): string;
begin
  Result := StringReplace(aText, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;', [rfReplaceAll]);
end;

function BuildPreviewSnippetHtml(const aSnippet: string): string;
begin
  Result := EscapeHtml(aSnippet);
  Result := StringReplace(Result, '[[', '<mark>', [rfReplaceAll]);
  Result := StringReplace(Result, ']]', '</mark>', [rfReplaceAll]);
  Result := StringReplace(Result, sLineBreak, '<br/>', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '<br/>', [rfReplaceAll]);
end;

end.
