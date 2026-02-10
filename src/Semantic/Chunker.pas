unit Chunker;

interface

type
  TSkillChunk = record
    ChunkHash: string;
    ChunkIndex: Integer;
    ChunkText: string;
  end;

function BuildSkillChunks(const aMarkdown: string): TArray<TSkillChunk>;

implementation

uses
  System.Classes, System.Hash, System.SysUtils;

const
  cChunkMaxChars = 1200;
  cChunkMinChars = 450;

function NormalizeLineEndings(const aText: string): string;
begin
  Result := StringReplace(aText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

function ComputeChunkHash(const aChunkText: string): string;
begin
  Result := THashSHA2.GetHashString(NormalizeLineEndings(aChunkText), THashSHA2.TSHA2Version.SHA256);
end;

function IsHeadingLine(const aLine: string): Boolean;
var
  lTrimmed: string;
begin
  lTrimmed := TrimLeft(aLine);
  Result := (lTrimmed <> '') and (lTrimmed[1] = '#');
end;

procedure AddChunk(var aChunks: TArray<TSkillChunk>; const aChunkText: string);
var
  lChunkText: string;
  lLen: Integer;
begin
  lChunkText := Trim(aChunkText);
  if lChunkText = '' then
  begin
    Exit;
  end;

  lLen := Length(aChunks);
  SetLength(aChunks, lLen + 1);
  aChunks[lLen].ChunkIndex := lLen;
  aChunks[lLen].ChunkText := lChunkText;
  aChunks[lLen].ChunkHash := ComputeChunkHash(lChunkText);
end;

function BuildSkillChunks(const aMarkdown: string): TArray<TSkillChunk>;
var
  i: Integer;
  lBuffer: string;
  lLine: string;
  lLines: TStringList;
begin
  lLines := TStringList.Create;
  try
    lLines.Text := NormalizeLineEndings(aMarkdown);
    lBuffer := '';

    for i := 0 to Pred(lLines.Count) do
    begin
      lLine := lLines[i];

      if IsHeadingLine(lLine) and (Trim(lBuffer) <> '') then
      begin
        AddChunk(Result, lBuffer);
        lBuffer := '';
      end;

      if lBuffer <> '' then
      begin
        lBuffer := lBuffer + sLineBreak;
      end;
      lBuffer := lBuffer + lLine;

      if Length(lBuffer) >= cChunkMaxChars then
      begin
        AddChunk(Result, lBuffer);
        lBuffer := '';
        Continue;
      end;

      if (Trim(lLine) = '') and (Length(lBuffer) >= cChunkMinChars) then
      begin
        AddChunk(Result, lBuffer);
        lBuffer := '';
      end;
    end;

    AddChunk(Result, lBuffer);
    if Length(Result) = 0 then
    begin
      AddChunk(Result, aMarkdown);
    end;
  finally
    lLines.Free;
  end;
end;

end.
