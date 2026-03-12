unit QueryParser;

interface

type
  TSearchQuery = record
    ExcludedTerms: TArray<string>;
    ExtFilters: TArray<string>;
    FtsTokens: TArray<string>;
    HasScriptsFilter: Integer;
    Limit: Integer;
    NameFilters: TArray<string>;
    PathFilters: TArray<string>;
    PositiveTerms: TArray<string>;
    TagFilters: TArray<string>;
  end;

function DefaultSearchQuery: TSearchQuery; overload;
function DefaultSearchQuery(const aDefaultLimit: Integer): TSearchQuery; overload;
function BuildFtsMatchExpression(const aQuery: TSearchQuery): string;
function ParseSearchQuery(const aRawQuery: string): TSearchQuery; overload;
function ParseSearchQuery(const aRawQuery: string; const aDefaultLimit: Integer): TSearchQuery; overload;

implementation

uses
  System.StrUtils, System.SysUtils;

function DefaultSearchQuery: TSearchQuery;
begin
  Result := DefaultSearchQuery(200);
end;

function DefaultSearchQuery(const aDefaultLimit: Integer): TSearchQuery;
var
  lLimit: Integer;
begin
  lLimit := aDefaultLimit;
  if lLimit <= 0 then
  begin
    lLimit := 200;
  end;

  Result := Default(TSearchQuery);
  Result.HasScriptsFilter := -1;
  Result.Limit := lLimit;
end;

procedure AddToken(var aItems: TArray<string>; const aValue: string);
var
  lLen: Integer;
begin
  if Trim(aValue) = '' then
  begin
    Exit;
  end;

  lLen := Length(aItems);
  SetLength(aItems, lLen + 1);
  aItems[lLen] := Trim(aValue);
end;

function TokenizeQuery(const aRawQuery: string): TArray<string>;
var
  i: Integer;
  lBuffer: string;
  lInQuote: Boolean;
  lToken: string;
begin
  lInQuote := False;
  lBuffer := '';

  for i := 1 to Length(aRawQuery) do
  begin
    if aRawQuery[i] = '"' then
    begin
      lInQuote := not lInQuote;
      Continue;
    end;

    if (not lInQuote) and CharInSet(aRawQuery[i], ['(', ')']) then
    begin
      if lBuffer <> '' then
      begin
        AddToken(Result, lBuffer);
        lBuffer := '';
      end;
      lToken := aRawQuery[i];
      AddToken(Result, lToken);
      Continue;
    end;

    if (not lInQuote) and CharInSet(aRawQuery[i], [#9, #10, #13, ' ']) then
    begin
      if lBuffer <> '' then
      begin
        AddToken(Result, lBuffer);
        lBuffer := '';
      end;
      Continue;
    end;

    lBuffer := lBuffer + aRawQuery[i];
  end;

  if lBuffer <> '' then
  begin
    AddToken(Result, lBuffer);
  end;
end;

function NormalizeFtsTerm(const aTerm: string): string;
var
  i: Integer;
  lCanUsePrefixWildcard: Boolean;
  lTerm: string;
begin
  lTerm := Trim(StringReplace(aTerm, '"', '', [rfReplaceAll]));
  if lTerm = '' then
  begin
    Exit('');
  end;

  if Pos(' ', lTerm) > 0 then
  begin
    Result := '"' + lTerm + '"';
    Exit;
  end;

  lCanUsePrefixWildcard := lTerm[Length(lTerm)] <> '*';
  if lCanUsePrefixWildcard then
  begin
    for i := 1 to Length(lTerm) do
    begin
      if not CharInSet(lTerm[i], ['0'..'9', 'A'..'Z', '_', 'a'..'z']) then
      begin
        lCanUsePrefixWildcard := False;
        Break;
      end;
    end;
  end;

  if lCanUsePrefixWildcard then
  begin
    Result := lTerm + '*';
  end else begin
    Result := lTerm;
  end;
end;

function IsAndOperatorToken(const aToken: string): Boolean;
begin
  Result := SameText(aToken, 'AND');
end;

function IsOrOperatorToken(const aToken: string): Boolean;
begin
  Result := SameText(aToken, 'OR');
end;

function IsOpenParenToken(const aToken: string): Boolean;
begin
  Result := aToken = '(';
end;

function IsCloseParenToken(const aToken: string): Boolean;
begin
  Result := aToken = ')';
end;

function CombineFtsExpressions(const aLeft, aOperator, aRight: string): string;
begin
  if aLeft = '' then
  begin
    Exit(aRight);
  end;
  if aRight = '' then
  begin
    Exit(aLeft);
  end;

  Result := '(' + aLeft + ' ' + aOperator + ' ' + aRight + ')';
end;

function ParseFtsOrExpression(const aTokens: TArray<string>; var aIndex: Integer): string; forward;

function ParseFtsPrimaryExpression(const aTokens: TArray<string>; var aIndex: Integer): string;
var
  lToken: string;
begin
  Result := '';
  if aIndex > High(aTokens) then
  begin
    Exit;
  end;

  lToken := aTokens[aIndex];
  if IsOpenParenToken(lToken) then
  begin
    Inc(aIndex);
    Result := ParseFtsOrExpression(aTokens, aIndex);
    if (aIndex <= High(aTokens)) and IsCloseParenToken(aTokens[aIndex]) then
    begin
      Inc(aIndex);
    end;
    Exit;
  end;

  if IsCloseParenToken(lToken) or IsAndOperatorToken(lToken) or IsOrOperatorToken(lToken) then
  begin
    Exit;
  end;

  Inc(aIndex);
  Result := NormalizeFtsTerm(lToken);
end;

function ParseFtsAndExpression(const aTokens: TArray<string>; var aIndex: Integer): string;
var
  lRight: string;
begin
  Result := ParseFtsPrimaryExpression(aTokens, aIndex);

  while aIndex <= High(aTokens) do
  begin
    if IsCloseParenToken(aTokens[aIndex]) or IsOrOperatorToken(aTokens[aIndex]) then
    begin
      Break;
    end;

    if IsAndOperatorToken(aTokens[aIndex]) then
    begin
      Inc(aIndex);
    end;

    lRight := ParseFtsPrimaryExpression(aTokens, aIndex);
    Result := CombineFtsExpressions(Result, 'AND', lRight);
  end;
end;

function ParseFtsOrExpression(const aTokens: TArray<string>; var aIndex: Integer): string;
var
  lRight: string;
begin
  Result := ParseFtsAndExpression(aTokens, aIndex);

  while (aIndex <= High(aTokens)) and IsOrOperatorToken(aTokens[aIndex]) do
  begin
    Inc(aIndex);
    lRight := ParseFtsAndExpression(aTokens, aIndex);
    Result := CombineFtsExpressions(Result, 'OR', lRight);
  end;
end;

function NormalizeExtFilter(const aValue: string): string;
begin
  Result := Trim(aValue);
  if StartsText('.', Result) then
  begin
    Delete(Result, 1, 1);
  end;
  Result := LowerCase(Result);
end;

function BuildFtsMatchExpression(const aQuery: TSearchQuery): string;
var
  lExpression: string;
  lIndex: Integer;
  lTerm: string;
begin
  Result := '';

  lIndex := 0;
  lExpression := ParseFtsOrExpression(aQuery.FtsTokens, lIndex);
  if lExpression = '' then
  begin
    Exit('');
  end;

  if Length(aQuery.ExcludedTerms) > 0 then
  begin
    Result := '(' + lExpression + ')';
  end else begin
    Result := lExpression;
  end;

  for lIndex := 0 to Pred(Length(aQuery.ExcludedTerms)) do
  begin
    lTerm := NormalizeFtsTerm(aQuery.ExcludedTerms[lIndex]);
    if lTerm = '' then
    begin
      Continue;
    end;

    Result := Result + ' NOT ' + lTerm;
  end;
end;

function ParseSearchQuery(const aRawQuery: string): TSearchQuery;
begin
  Result := ParseSearchQuery(aRawQuery, 200);
end;

function ParseSearchQuery(const aRawQuery: string; const aDefaultLimit: Integer): TSearchQuery;
var
  i: Integer;
  lToken: string;
  lTokens: TArray<string>;
  lValue: Integer;
begin
  Result := DefaultSearchQuery(aDefaultLimit);
  lTokens := TokenizeQuery(aRawQuery);

  for i := 0 to Pred(Length(lTokens)) do
  begin
    lToken := Trim(lTokens[i]);
    if lToken = '' then
    begin
      Continue;
    end;

    if StartsText('limit:', lToken) then
    begin
      if TryStrToInt(Copy(lToken, 7, MaxInt), lValue) and (lValue > 0) then
      begin
        Result.Limit := lValue;
      end;
      Continue;
    end;

    if SameText(lToken, 'has:scripts') then
    begin
      Result.HasScriptsFilter := 1;
      Continue;
    end;

    if SameText(lToken, '-has:scripts') then
    begin
      Result.HasScriptsFilter := 0;
      Continue;
    end;

    if StartsText('name:', lToken) then
    begin
      AddToken(Result.NameFilters, Copy(lToken, 6, MaxInt));
      Continue;
    end;

    if StartsText('tag:', lToken) then
    begin
      AddToken(Result.TagFilters, Copy(lToken, 5, MaxInt));
      Continue;
    end;

    if StartsText('path:', lToken) then
    begin
      AddToken(Result.PathFilters, Copy(lToken, 6, MaxInt));
      Continue;
    end;

    if StartsText('ext:', lToken) then
    begin
      lToken := NormalizeExtFilter(Copy(lToken, 5, MaxInt));
      AddToken(Result.ExtFilters, lToken);
      Continue;
    end;

    if StartsText('-', lToken) then
    begin
      AddToken(Result.ExcludedTerms, Copy(lToken, 2, MaxInt));
      Continue;
    end;

    if IsAndOperatorToken(lToken) or IsOrOperatorToken(lToken) or IsOpenParenToken(lToken) or IsCloseParenToken(lToken)
    then
    begin
      AddToken(Result.FtsTokens, lToken);
      Continue;
    end;

    AddToken(Result.PositiveTerms, lToken);
    AddToken(Result.FtsTokens, lToken);
  end;
end;

end.
