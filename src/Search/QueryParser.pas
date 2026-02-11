unit QueryParser;

interface

type
  TSearchQuery = record
    ExcludedTerms: TArray<string>;
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
  end else begin
    Result := lTerm;
  end;
end;

function BuildFtsMatchExpression(const aQuery: TSearchQuery): string;
var
  i: Integer;
  lTerm: string;
begin
  Result := '';

  for i := 0 to Pred(Length(aQuery.PositiveTerms)) do
  begin
    lTerm := NormalizeFtsTerm(aQuery.PositiveTerms[i]);
    if lTerm = '' then
    begin
      Continue;
    end;

    if Result <> '' then
    begin
      Result := Result + ' AND ';
    end;
    Result := Result + lTerm;
  end;

  if Result = '' then
  begin
    Exit('');
  end;

  for i := 0 to Pred(Length(aQuery.ExcludedTerms)) do
  begin
    lTerm := NormalizeFtsTerm(aQuery.ExcludedTerms[i]);
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

    if StartsText('-', lToken) then
    begin
      AddToken(Result.ExcludedTerms, Copy(lToken, 2, MaxInt));
      Continue;
    end;

    AddToken(Result.PositiveTerms, lToken);
  end;
end;

end.
