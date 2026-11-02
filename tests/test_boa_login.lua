-- Unit-Tests für Login-Hilfsfunktionen in "Bank of America.lua".

function WebBanking(_) end

ProtocolWebBanking = "WebBanking"
LoginFailed = "LoginFailed"

AccountTypeGiro = 1
AccountTypeCreditCard = 3

setCookieCalls = {}

Connection = function()
  return {
    language = "en-US",
    useragent = "test",
    request = function()
      return nil
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end

LocalStorage = {}

MM = {
  printStatus = function(msg)
    -- Test-Stubs schlucken Debug-Ausgabe
  end,
  urlencode = function(str)
    return (tostring(str):gsub(" ", "+"))
  end,
}

local function assertEq(actual, expected, label)
  if actual == expected then
    print("OK    " .. label .. " = " .. tostring(actual))
  else
    print("FAIL  " .. label .. ": expected=" .. tostring(expected) .. ", actual=" .. tostring(actual))
    os.exit(1)
  end
end

local function assertTrue(value, label)
  if value then
    print("OK    " .. label)
  else
    print("FAIL  " .. label)
    os.exit(1)
  end
end

-- Minimaler JSON-Decoder für Tests (MoneyMoney stellt in der App ein eigenes JSON bereit).
local function decodeJson(str)
  local pos = 1

  local function skipWs()
    pos = str:find("[^ \t\r\n]", pos) or (#str + 1)
  end

  local parseValue

  local function parseString()
    local out = {}
    pos = pos + 1
    while true do
      local c = str:sub(pos, pos)
      if c == "" then error("unterminated string") end
      if c == '"' then pos = pos + 1; break end
      if c == "\\" then
        local e = str:sub(pos + 1, pos + 1)
        local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
        if e == "u" then
          out[#out + 1] = utf8.char(tonumber(str:sub(pos + 2, pos + 5), 16))
          pos = pos + 6
        else
          out[#out + 1] = map[e] or error("bad escape")
          pos = pos + 2
        end
      else
        out[#out + 1] = c
        pos = pos + 1
      end
    end
    return table.concat(out)
  end

  function parseValue()
    skipWs()
    local c = str:sub(pos, pos)
    if c == "{" then
      local obj = {}
      pos = pos + 1
      skipWs()
      if str:sub(pos, pos) == "}" then pos = pos + 1; return obj end
      while true do
        skipWs()
        local k = parseString()
        skipWs()
        if str:sub(pos, pos) ~= ":" then error("expected :") end
        pos = pos + 1
        obj[k] = parseValue()
        skipWs()
        local d = str:sub(pos, pos)
        pos = pos + 1
        if d == "}" then return obj end
        if d ~= "," then error("expected , or }") end
      end
    elseif c == "[" then
      local arr = {}
      pos = pos + 1
      skipWs()
      if str:sub(pos, pos) == "]" then pos = pos + 1; return arr end
      while true do
        arr[#arr + 1] = parseValue()
        skipWs()
        local d = str:sub(pos, pos)
        pos = pos + 1
        if d == "]" then return arr end
        if d ~= "," then error("expected , or ]") end
      end
    elseif c == '"' then
      return parseString()
    elseif str:sub(pos, pos + 3) == "true" then
      pos = pos + 4; return true
    elseif str:sub(pos, pos + 4) == "false" then
      pos = pos + 5; return false
    elseif str:sub(pos, pos + 3) == "null" then
      pos = pos + 4; return nil
    else
      local num = str:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
      if not num or num == "" then error("unexpected token at " .. pos) end
      pos = pos + #num
      return tonumber(num)
    end
  end

  return parseValue()
end

JSON = function(str)
  return {
    dictionary = function() return decodeJson(str) end,
    array = function() return decodeJson(str) end,
  }
end

dofile("Bank of America.lua")

local credSummary = boaDebugSummarizeCredentials("user123", "secret")
assertTrue(credSummary:match("onlineId%.len=7"), "boaDebugSummarizeCredentials.onlineId")
assertTrue(credSummary:match("passcode%.len=6"), "boaDebugSummarizeCredentials.passcode")
assertTrue(credSummary:match("WARN") == nil, "boaDebugSummarizeCredentials.noWarn")

local emptySummary = boaDebugSummarizeCredentials("", "")
assertTrue(emptySummary:match("WARN onlineId leer"), "boaDebugSummarizeCredentials.emptyUser")
assertTrue(emptySummary:match("WARN passcode leer"), "boaDebugSummarizeCredentials.emptyPass")

local blockedMsg = directLoginUnavailableMessage()
assertTrue(blockedMsg:match("Cookie%-Import"), "directLoginUnavailableMessage")
assertTrue(blockedMsg:match("WebbankingBrowser"), "directLoginUnavailableMessage.browser")

assertTrue(isAuthenticatedAccountPage('<html>Ending in 1234 balance</html>'), "isAuthenticatedAccountPage.ok")
assertTrue(not isAuthenticatedAccountPage('<html>Sign In</html>'), "isAuthenticatedAccountPage.login")
assertTrue(
  not isAuthenticatedAccountPage('<html>Learn how to balance your financial goals</html>'),
  "isAuthenticatedAccountPage.genericBalance")

local missingMfaState = InitializeSession2(
  ProtocolWebBanking,
  "Bank of America",
  2,
  {"user123", "secret"},
  true)
local authFailures = {}
local function checkAuthError(value, label)
  if type(value) == "string" and value ~= "" and value ~= LoginFailed then
    print("OK    " .. label)
  else
    authFailures[#authFailures + 1] = label .. "=" .. tostring(value)
    print("FAIL  " .. label)
  end
end
checkAuthError(missingMfaState, "InitializeSession2.missingMfaState.transient")

local noResponse = InitializeSession2(
  ProtocolWebBanking,
  "Bank of America",
  1,
  {"user123", "COOKIE:SMSESSION=value"},
  true)
checkAuthError(noResponse, "cookieImport.noResponse.error")

Connection = function()
  return {
    request = function()
      return "<html><body>Unexpected response</body></html>"
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end
local unexpectedResponse = InitializeSession2(
  ProtocolWebBanking,
  "Bank of America",
  1,
  {"user123", "COOKIE:SMSESSION=value"},
  true)
checkAuthError(unexpectedResponse, "cookieImport.unexpectedResponse.error")

-- Gespeicherte Sitzung, aber keine Antwort (Netzwerk): keine Cookie-Anforderung.
Connection = function()
  return {
    request = function() return nil end,
    setCookie = function(self, cookie) table.insert(setCookieCalls, cookie) end,
    getCookies = function() return "SMSESSION=stored" end,
  }
end
LocalStorage = {}
local unreachableSession = InitializeSession2(
  ProtocolWebBanking, "Bank of America", 1, {"user123", "secret"}, true)
assertTrue(
  type(unreachableSession) == "string"
    and unreachableSession:find("nicht erreichbar", 1, true) ~= nil
    and unreachableSession:find("Cookie-Import", 1, true) == nil,
  "InitializeSession2.unreachableNoCookiePrompt")

-- Gespeicherte Sitzung, Server zeigt Login-Seite: Cookie-Anforderung bleibt.
Connection = function()
  return {
    request = function() return "<html>Sign In</html>" end,
    setCookie = function(self, cookie) table.insert(setCookieCalls, cookie) end,
    getCookies = function() return "SMSESSION=stored" end,
  }
end
LocalStorage = {}
local expiredSession = InitializeSession2(
  ProtocolWebBanking, "Bank of America", 1, {"user123", "secret"}, true)
assertTrue(
  type(expiredSession) == "string" and expiredSession:find("Cookie-Import erforderlich", 1, true) ~= nil,
  "InitializeSession2.expiredAsksCookies")
if #authFailures > 0 then
  error("Auth error classification failed: " .. table.concat(authFailures, ", "))
end

local parsedTransactions = parseTransactionsFromPage([[
<tbody class="trans-tbody-wrap">
<tr>
  <td class="trans-date-cell">08/31/2026</td>
  <td class="trans-desc-cell"><span>Test transaction</span></td>
  <td class="trans-amount-cell">$12.34</td>
  <td><span class="icon-type-purchase"></span></td>
</tr>
</tbody>
]], nil, nil, nil)
local transaction = parsedTransactions[1]
assertTrue(transaction ~= nil, "parseTransactionRow.contract")
if not transaction then
  error("parseTransactionRow returned nil")
end
assertEq(transaction.valueDate, transaction.bookingDate, "parseTransactionRow.valueDate")
assertEq(transaction.valutaDate, nil, "parseTransactionRow.noValutaDate")

local pendingTransactions = parseTransactionsFromPage([[
<tbody class="trans-tbody-wrap">
<tr>
  <td class="trans-date-cell">Pending</td>
  <td class="trans-desc-cell"><span>Pending transaction</span></td>
  <td class="trans-amount-cell">$12.34</td>
  <td><span class="icon-type-purchase"></span></td>
</tr>
</tbody>
]], nil, nil, nil)
assertEq(pendingTransactions[1].booked, false, "parseTransactionRow.pendingNotBooked")

local missingDateOk, missingDateError = pcall(parseTransactionsFromPage, [[
<tbody class="trans-tbody-wrap">
<tr>
  <td class="trans-desc-cell"><span>Missing date</span></td>
  <td class="trans-amount-cell">$12.34</td>
  <td><span class="icon-type-purchase"></span></td>
</tr>
</tbody>
]], nil, nil, nil)
assertEq(missingDateOk, false, "parseTransactionRow.rejectsMissingDate")
assertTrue(
  type(missingDateError) == "string"
    and missingDateError:find("Umsatzdatum", 1, true) ~= nil,
  "parseTransactionRow.missingDateMessage")

local invalidAmountOk, invalidAmountError = pcall(parseTransactionsFromPage, [[
<tbody class="trans-tbody-wrap">
<tr>
  <td class="trans-date-cell">08/31/2026</td>
  <td class="trans-desc-cell"><span>Invalid amount</span></td>
  <td class="trans-amount-cell">$..</td>
  <td><span class="icon-type-purchase"></span></td>
</tr>
</tbody>
]], nil, nil, nil)
assertEq(invalidAmountOk, false, "parseTransactionRow.rejectsInvalidAmount")
assertTrue(
  type(invalidAmountError) == "string"
    and invalidAmountError:find("Umsatzbetrag", 1, true) ~= nil,
  "parseTransactionRow.invalidAmountMessage")

Connection = function()
  return {
    request = function()
      return "<html><body>Account Overview</body></html>"
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end
assertEq(
  InitializeSession2(
    ProtocolWebBanking,
    "Bank of America",
    1,
    {"account-discovery", "COOKIE:SMSESSION=value"},
    true),
  nil,
  "ListAccounts.setup")
local undiscoveredAccounts = ListAccounts({})
assertEq(type(undiscoveredAccounts), "string", "ListAccounts.noDummyAccount")

Connection = function()
  return {
    request = function()
      return '<html><body><a href="/card/">Credit Card Ending in 1234</a></body></html>'
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end
assertEq(
  InitializeSession2(
    ProtocolWebBanking,
    "Bank of America",
    1,
    {"credit-card-discovery", "COOKIE:SMSESSION=value"},
    true),
  nil,
  "ListAccounts.creditCardSetup")
local fallbackCreditCards = ListAccounts({})
assertEq(fallbackCreditCards[1].type, AccountTypeCreditCard, "ListAccounts.fallbackCreditCardType")

Connection = function()
  return {
    request = function()
      return '<div class="checking-account">Checking Account <span>Ending in 4321</span></div>'
        .. '<div class="promotion">Apply for a Credit Card today</div>'
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end
InitializeSession2(
  ProtocolWebBanking,
  "Bank of America",
  1,
  {"checking-discovery", "COOKIE:SMSESSION=value"},
  true)
local scopedChecking = ListAccounts({})
assertEq(scopedChecking[1].type, AccountTypeGiro, "ListAccounts.scopesFallbackType")

Connection = function()
  return {
    request = function()
      return nil
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end
InitializeSession2(
  ProtocolWebBanking,
  "Bank of America",
  1,
  {"refresh-failure", "COOKIE:SMSESSION=value"},
  true)
local refreshOk, refreshError = pcall(RefreshAccount, {accountNumber = "1234"}, nil)
assertEq(refreshOk, false, "RefreshAccount.propagatesFailure")
assertTrue(
  type(refreshError) == "string" and refreshError:match("abruf") ~= nil,
  "RefreshAccount.failureMessage")

Connection = function()
  return {
    request = function()
      return "<html><body>Account Overview</body></html>"
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end
InitializeSession2(
  ProtocolWebBanking,
  "Bank of America",
  1,
  {"missing-balance", "COOKIE:SMSESSION=value"},
  true)
local missingBalanceOk, missingBalanceError = pcall(
  RefreshAccount,
  {accountNumber = "1234", type = AccountTypeGiro},
  nil)
assertEq(missingBalanceOk, false, "RefreshAccount.rejectsMissingBalance")
assertTrue(
  type(missingBalanceError) == "string"
    and missingBalanceError:match("Kontostand") ~= nil,
  "RefreshAccount.missingBalanceMessage")

Connection = function()
  return {
    request = function()
      return '<html><body>Sign In Statement Balance:<span class="TL_NPI_L1">$42.00</span></body></html>'
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end
InitializeSession2(
  ProtocolWebBanking,
  "Bank of America",
  1,
  {"login-page-balance", "COOKIE:SMSESSION=value"},
  true)
local loginPageOk, loginPageError = pcall(
  RefreshAccount,
  {accountNumber = "1234", type = AccountTypeGiro},
  nil)
assertEq(loginPageOk, false, "RefreshAccount.rejectsLoginPage")
assertTrue(
  type(loginPageError) == "string"
    and loginPageError:match("authentifiziert") ~= nil,
  "RefreshAccount.loginPageMessage")

local statementPayload =
  [[{"documentList":[{"docId":"missing-name","date":"2026-08-31"}]}]]
Connection = function()
  return {
    request = function(_, _, url)
      if url and url:find("gatherDocuments", 1, true) then
        return statementPayload
      end
      return "<html><body>Account Overview</body></html>"
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end
assertEq(
  InitializeSession2(
    ProtocolWebBanking,
    "Bank of America",
    1,
    {"statement-date", "COOKIE:SMSESSION=value"},
    true),
  nil,
  "GetAvailableStatements.setup")
local incompleteStatementOk, incompleteStatementError = pcall(
  fetchStatementDocuments,
  "adx-token",
  nil)
assertEq(incompleteStatementOk, false, "GetAvailableStatements.rejectsIncompleteDocument")
assertTrue(
  type(incompleteStatementError) == "string"
    and incompleteStatementError:find("unvollständig", 1, true) ~= nil,
  "GetAvailableStatements.incompleteDocumentMessage")

statementPayload =
  [[{"documentList":[{"docId":"invalid-date","docDisplayName":"Statement","date":"invalid"}]}]]
local invalidStatementDateOk, invalidStatementDateError = pcall(
  fetchStatementDocuments,
  "adx-token",
  nil)
assertEq(invalidStatementDateOk, false, "GetAvailableStatements.rejectsInvalidDate")
assertTrue(
  type(invalidStatementDateError) == "string"
    and invalidStatementDateError:find("Auszugsdatum", 1, true) ~= nil,
  "GetAvailableStatements.invalidDateMessage")

statementPayload =
  [[{"documentList":[{"docId":"invalid-calendar","docDisplayName":"Statement","date":"2026-02-31"}]}]]
local invalidCalendarDateOk = pcall(fetchStatementDocuments, "adx-token", nil)
assertEq(invalidCalendarDateOk, false, "GetAvailableStatements.rejectsInvalidCalendarDate")

statementPayload = [[{"documents":[
  {"docId":"statement-1","docDisplayName":"January","date":"2026-01-31"},
  {"docId":"statement-2","docDisplayName":"February","date":"2026-02-28"}
]}]]
local nestedDocuments = fetchStatementDocuments("adx-token", nil)
assertEq(#nestedDocuments, 2, "GetAvailableStatements.parsesAllNestedDocuments")

-- Multi-login: two accountKeys keep distinct connections in the map
do
  local connA = {
    language = "",
    useragent = "",
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function() return "A=1" end,
    request = function() return nil end,
  }
  local connB = {
    language = "",
    useragent = "",
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function() return "B=1" end,
    request = function() return nil end,
  }
  local created = 0
  Connection = function()
    created = created + 1
    if created == 1 then return connA end
    if created == 2 then return connB end
    return {
      language = "",
      useragent = "",
      setCookie = function(self, cookie)
        table.insert(setCookieCalls, cookie)
      end,
      getCookies = function() return "" end,
      request = function() return nil end,
    }
  end
  LocalStorage = {}
  restoreLoginConnection("user-a")
  assertEq(LocalStorage.connectionsByAccount["user-a"].connection, connA, "multiLogin.map.userA")
  restoreLoginConnection("user-b")
  assertEq(LocalStorage.connectionsByAccount["user-b"].connection, connB, "multiLogin.map.userB")
  assertEq(LocalStorage.connectionsByAccount["user-a"].connection, connA, "multiLogin.map.userA.kept")
  assertEq(LocalStorage.connectionAccountKey, "user-b", "multiLogin.activeKey.userB")
  restoreLoginConnection("user-a")
  assertEq(LocalStorage.connection, connA, "multiLogin.reusesUserA")
  assertEq(LocalStorage.connectionAccountKey, "user-a", "multiLogin.activeKey.userA")
end

-- Cookie-Persistenz: Erfolgreicher Import wird gespeichert und ohne neuen Import wiederverwendet.
local authedHtml = "<html>Ending in 1234 balance</html>"
local loginHtml = "<html><body>Unexpected response</body></html>"
local currentPage = authedHtml
Connection = function()
  return {
    request = function()
      return currentPage
    end,
    setCookie = function(self, cookie)
      table.insert(setCookieCalls, cookie)
    end,
    getCookies = function()
      return ""
    end,
  }
end

LocalStorage = {}
setCookieCalls = {}
local importResult = InitializeSession2(
  ProtocolWebBanking, "Bank of America", 1,
  {"user123", "COOKIE:SMSESSION=value"}, true)
assertEq(importResult, nil, "persist.importReturnsNil")
assertEq(setCookieCalls[1], "SMSESSION=value", "persist.setCookie")
assertEq(LocalStorage.connectionsByAccount["user123"].importedCookies, "SMSESSION=value", "persist.storedCookies")

setCookieCalls = {}
local reuseResult = InitializeSession2(
  ProtocolWebBanking, "Bank of America", 1,
  {"user123", "COOKIE:SMSESSION=other"}, true)
assertEq(reuseResult, nil, "persist.reuseGivesNil")
assertEq(#setCookieCalls, 0, "persist.reuseSkipsImport")

currentPage = loginHtml
local expiredResult = InitializeSession2(
  ProtocolWebBanking, "Bank of America", 1,
  {"user123", ""}, true)
assertTrue(expiredResult ~= nil and expiredResult:find("abgelaufen", 1, true) ~= nil, "persist.expiredAsksForCookies")
currentPage = authedHtml

-- Cookie-Vorrang: ein frischer Cookie der Connection ersetzt den gespeicherten Import.
do
  local sentCookie = nil
  local reusedConnection = {
    getCookies = function() return "SMSESSION=fresh" end,
    setCookie = function(self, cookie) table.insert(setCookieCalls, cookie) end,
    request = function(self, method, url, body, contentType, headers)
      sentCookie = headers and headers["Cookie"]
      return "<html>Sign In</html>"
    end,
  }
  LocalStorage = {
    connectionsByAccount = {
      ["cookie-precedence"] = {
        connection = reusedConnection,
        importedCookies = "SMSESSION=old",
      },
    },
  }
  InitializeSession2(
    ProtocolWebBanking, "Bank of America", 1,
    {"cookie-precedence", "secret"}, true)
  assertTrue(sentCookie ~= nil and sentCookie:find("SMSESSION=fresh", 1, true) ~= nil,
    "restoreImportedCookies.connectionCookieWins")
  assertTrue(sentCookie ~= nil and sentCookie:find("SMSESSION=old", 1, true) == nil,
    "restoreImportedCookies.noStaleImport")
  LocalStorage = {}
end

print("All BoA login helper tests passed.")
