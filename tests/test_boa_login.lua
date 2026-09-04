-- Unit-Tests für Login-Hilfsfunktionen in "Bank of America.lua".

function WebBanking(_) end

ProtocolWebBanking = "WebBanking"
LoginFailed = "LoginFailed"

AccountTypeGiro = 1
AccountTypeCreditCard = 3

Connection = function()
  return {
    language = "en-US",
    useragent = "test",
    request = function()
      return nil
    end,
    getCookies = function()
      return ""
    end,
  }
end

MM = {
  printStatus = function(msg)
    -- Test-Stubs schlucken Debug-Ausgabe
  end,
  urlencode = function(str)
    return (tostring(str):gsub(" ", "+"))
  end,
  base64Encode = function(data)
    return "b64:" .. data
  end,
  rsaPkcs8decode = function(pemOrDer)
    if type(pemOrDer) == "string" and pemOrDer:find("PUBLIC KEY") then
      return { n = "mod", e = "exp" }
    end
    return nil
  end,
  rsaEncrypt = function(keyTable, plaintext, paddingSpec)
    if keyTable and plaintext and paddingSpec then
      return "cipher:" .. plaintext .. ":" .. paddingSpec
    end
    return nil
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

JSON = function(str)
  return {
    dictionary = function()
      local pageId = str:match('"xswPageId"%s*:%s*"([^"]+)"')
      if pageId then
        return { xswPageId = pageId }
      end
      return {}
    end,
    array = function()
      return {}
    end,
  }
end

dofile("Bank of America.lua")

do
  local result = performPasswordLogin("user123", "secret")
  assertEq(result, "Keine Antwort vom Login-Server.",
    "performPasswordLogin.delegatesToSparta")
end

assertTrue(canUseRsaLogin(), "canUseRsaLogin")

assertTrue(isSignOnSuccessRedirect("https://secure.bankofamerica.com/login/sign-in/signOnSuccessRedirect.go"), "isSignOnSuccessRedirect")
assertTrue(isSignOnCredentialErrorPage("<p>The information you entered doesn't match our records.</p>"), "isSignOnCredentialErrorPage")

local snippet = extractSignOnErrorSnippet("<p class=\"TLu_ERROR\">The information you entered doesn't match our records.</p>")
assertTrue(snippet and snippet:match("doesn't match"), "extractSignOnErrorSnippet")

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

local sessionKey = {
  keyId = "hsm_enc_v1_authhub-key",
  publicKey = "MIIBIjAN",
  algo = "RSA/NONE/OAEPWithSHA256AndMGF1Padding",
}

local envelope = buildCipherEnvelope(sessionKey, "cipherbytes")
assertTrue(envelope ~= nil and envelope:match("^b64:"), "buildCipherEnvelope")

local cipherValue, cipherError = encryptCredential(sessionKey, "user123")
assertTrue(cipherValue ~= nil, "encryptCredential")
if not cipherValue then
  error("encryptCredential returned nil")
end
assertTrue(cipherValue:match("^b64:"), "encryptCredential.base64")
assertEq(cipherError, nil, "encryptCredential.error")

local ra = buildClientSignalsRa()
assertTrue(type(ra) == "string" and ra ~= "", "buildClientSignalsRa")

assertEq(parseLoginApiError('{"errorInfo":[{"code":"invalid","description":"Bad login"}]}'), "Bad login", "parseLoginApiError")
assertTrue(isLoginCompletionOk('{"completion":{"code":"100","value":"ALLOW"}}'), "isLoginCompletionOk")

local contact = extractSecuredContactPoint('{"securedContactPoints":[{"deliveryMethod":"TEXT","maskedContactPoint":{"value":"XXX-1234"}}]}')
if not contact then
  error("extractSecuredContactPoint returned nil")
end
assertEq(contact.deliveryMethod, "TEXT", "extractSecuredContactPoint")

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
    getCookies = function() return "A=1" end,
    request = function() return nil end,
  }
  local connB = {
    language = "",
    useragent = "",
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

print("All BoA login helper tests passed.")
