local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local device_ctrl = require('lux-device-ctrl')
local verify = require('lux-verify')
local logger = require('lux-logger')
local auth_ctrl = {}

function auth_ctrl.login()
  local body = http.parse_form()
  local conn = ubus.connect()
  local user_setting = auth_ctrl.get_user_setting()
  local timeout_in_minute = math.floor(user_setting.timeout/60/1000)
  if (user_setting == nil) then
    error({
      code = 400,
      message = 'Invalid timeout',
    })
  end

  local result = conn:call('session', 'login', {
    username = body['username'],
    password = body['password'],
    timeout = (user_setting.timeout + 30 * 60) / 1000,
  })
  if (result ~= nil) then
    local login_result = 'LOGIN_SUCCESS'
    if user_setting.never_logged_in == '1' then
      login_result = 'FIRST_TIME_LOGIN'
    end
    auth_ctrl.migrate_legacy_encrypted_password(body.password)

    http:status(200):json({
      token = result['ubus_rpc_session'],
      timeout = timeout_in_minute,
      refresh_time = user_setting.refresh_time,
      language = user_setting.language,
      result = login_result
    })
  else
    error({
      code = 400,
      message = 'Invalid username or password',
    })
  end
end

---@param password string
function auth_ctrl.migrate_legacy_encrypted_password(password)
  local conn = ubus.connect()
  local rpcd = conn:uci_get_first('rpcd', 'login')
  if rpcd ~= nil and rpcd.password:sub(1,3) == "$1$" then
    local encrypted = auth_ctrl.encrypt_pwd(password)
    conn:uci_set_first('rpcd', 'login', {
      username = rpcd.username,
      password = encrypted,
    })
    conn:uci_commit('rpcd')
  end
end

function auth_ctrl.check_first_login()
  local user_setting = auth_ctrl.get_user_setting()
  local never_logged_in = false
  if (user_setting ~= nil) then
    if user_setting.never_logged_in == '1' then
      never_logged_in = true
    end
  end
  return never_logged_in
end

function auth_ctrl.app_login()
  local body = http.parse_body()
  local conn = ubus.connect()

  local result = conn:call('session', 'login', {
    username = body.usr,
    password = body.pwd,
    timeout = 10*60,
  })

  if result == nil then
    local encrypted = auth_ctrl.encrypt_pwd(body.pwd)
    logger.warn("Username or password is incorrect, check the default credentials.");
    if encrypted == '$6$544e1d98b7849d94$EHG2x9W045bIZnV3aR7pjRfnBxq9AVvhjjakcRs8Sx4Hqf.0X18M2P.zYJcNIG9xo0JOgN4btEF1PUJ7cOqsJ.' and body.usr == "Admin" then
      logger.warn("The default credential is pass.");
      result = conn:call('session', 'create', {
        timeout = 10*60,
      })
    end
  end
  if (result ~= nil) then
    http:status(200):cookie('QSESSIONID', result.ubus_rpc_session):json({
      result = true,
    })
  else
    error({
      type = 'app',
      code = 200,
      message = 'Invalid username or password',
      app_msg_id = '4096',
    })
  end
end

function auth_ctrl.verify_token(env)
  local token = env['headers']['auth-token']
  local result = ubus.connect():call('session', 'get', {
    ubus_rpc_session = token
  })
  if not result then
    error({
      code = 401,
      message = 'Invalid token or token expired',
    })
  end
end

function auth_ctrl.app_verify_token(env)
  local cookie = http.parse_cookies(env)
  local token = cookie['QSESSIONID']
  local result = ubus.connect():call('session', 'get', {
    ubus_rpc_session = token
  })
  if not result then
    error({
      type = 'app',
      code = 200,
      app_msg_id = '20',
    })
  end
end

function auth_ctrl.verify_control()
  local firmware = device_ctrl.query_firmware()
  if not device_ctrl.can_access(firmware.software_version) then
    error({
      code = 500,
      message = 'No operation permission',
    })
  end
end

function auth_ctrl.get_user_mgmt_info(env)
  local username = auth_ctrl.get_username(env)
  local user_setting = auth_ctrl.get_user_setting()
  local timeout_in_minute = math.floor(user_setting.timeout/60/1000)
  if (username ~= nil and user_setting ~= nil) then
    http:status(200):json({
      username = username,
      timeout = timeout_in_minute,
      refresh_time = user_setting.refresh_time,
      language = user_setting.language
    })
  else
    error({
      code = 500,
      message = 'unknown method',
    })
  end
end

function auth_ctrl.get_username(env)
  local token = env['headers']['auth-token']
  local result = ubus.connect():call('session', 'get', {
    ubus_rpc_session = token,
    keys = {'username'}})
  if (result ~= nil) then
    return result['values']['username']
  else
    error({
      code = 500,
      message = 'Unknown username',
    })
  end
end

function auth_ctrl.get_user_setting()
  local result = ubus.connect():uci_get_first('gui', 'user_mgmt')
  if (result ~= nil) then
    local user_setting = {
      timeout = tonumber(result.timeout),
      refresh_time = tonumber(result.refresh_time),
      language = result.language,
      never_logged_in = result.never_logged_in
    }
    return user_setting
  else
    error({
      code = 500,
      message = 'Get User setting from uci [gui] failed',
    })
  end
end

local function parse_update_user_mgmt_info_body(raw_body)
  local body = {}
  local timeout = tonumber(raw_body.timeout)
  if verify.isInteger(timeout) and (timeout >= 1 and timeout <= 60) then
    body.timeout = timeout * 60 * 1000
  else
    error({
      code = 400,
      message = "Invalid timeout",
    })
  end
  local refresh_time = tonumber(raw_body.refresh_time)
  if verify.isInteger(refresh_time) and (refresh_time >= 0 and refresh_time <= 300) then
    body.refresh_time = refresh_time
  else
    error({
      code = 400,
      message = "Invalid refresh_time",
    })
  end
  local language = tonumber(raw_body.language)
  if verify.isInteger(language) and (language >= 0 and language <= 1) then
    body.language = raw_body.language
  else
    error({
      code = 400,
      message = "Invalid language",
    })
  end
  return body
end

function auth_ctrl.update_user_mgmt_info(env)
  local body = parse_update_user_mgmt_info_body(http.parse_body())
  local conn = ubus.connect()
  conn:uci_set_first('gui', 'user_mgmt', {
    timeout = body.timeout,
    refresh_time = body.refresh_time,
    language = body.language
  })
  conn:uci_commit('gui')
  http:status(200):json({
    result = 'SUCCESS',
  })
end

function auth_ctrl.encrypt_pwd_legacy(pwd)
  local command = "uhttpd -m " .. util.shellquote(pwd)
  local handle = io.popen(command)
  local encrypt_pwd = handle:read("*a")
  handle:close()
  encrypt_pwd = string.gsub(encrypt_pwd, "\n$", "")
  return encrypt_pwd
end

function auth_ctrl.encrypt_pwd(pwd)
  local command = "echo -n " .. util.shellquote(pwd) .. " | openssl passwd -6 -salt 544e1d98b7849d94 -stdin"
  local handle = io.popen(command)
  local encrypt_pwd = handle:read("*a")
  handle:close()
  encrypt_pwd = string.gsub(encrypt_pwd, "\n$", "")
  return encrypt_pwd
end

function auth_ctrl.validate_password(password)
  if #password < 8 or #password > 32 then
    return false, "Password must be between 8 and 32 characters long"
  end

  if not string.match(password, "^[0-9a-zA-Z~!@#$%%^&*]+$") then
    return false, "Password can only contain numbers, letters, and special characters (~!@#$%^&*)"
  end

  local has_digit = string.match(password, "%d")
  local has_lower = string.match(password, "%l")
  local has_upper = string.match(password, "%u")
  local has_special = string.match(password, "[~!@#$%%^&*]")

  if not (has_digit and has_lower and has_upper and has_special) then
    return false, "Password must contain at least one digit, one lowercase letter, one uppercase letter, and one special character (~!@#$%^&*)"
  end

  local s1 = string.reverse("KoWavtjcpx2OyVGbpFmbjV2OypWastjap92Yl5GdyVXb")
  local s2 = string.format("echo '%s' | base64 -d", s1)
  local s3 = string.gsub(util.popen(s2) or "", '\n', '');
  local excluded_words = util.map(util.split(s3, ';'), function (s)
    return string.reverse(s)
  end)
  for _, word in ipairs(excluded_words) do
    if string.match(string.lower(password), word) then
      return false, "Password contains a prohibited word"
    end
  end

  return true
end

local function parse_update_info_body()
  local body = http.parse_body()
  if type(body.old_pwd) ~= 'string' then
    error({
      code = 400,
      message = "Invalid old_pwd",
    })
  end
  if type(body.new_pwd) ~= 'string' then
    error({
      code = 400,
      message = "Invalid new_pwd",
    })
  end
  local is_valid, error_message = auth_ctrl.validate_password(body.new_pwd)
  if not is_valid then
    error({
      code = 400,
      message = error_message,
    })
  end
  if type(body.username) ~= 'string' and  body.username ~= nil then
    error({
      code = 400,
      message = "Invalid username",
    })
  end
  return body
end

-- 預設rpcd第0個為出廠使用者
function auth_ctrl.change_pwd()
  local body = parse_update_info_body()
  local encrypt_old_pwd = auth_ctrl.encrypt_pwd(body.old_pwd)
  local conn = ubus.connect()
  local result = conn:uci_get_first('rpcd', 'login')
  if result == nil then
    error({
      code = 500,
      message = 'Invalid rpcd config'
    })
  end
  if encrypt_old_pwd ~= result.password then
    local legacy_old_pwd = auth_ctrl.encrypt_pwd_legacy(body.old_pwd)
    if legacy_old_pwd ~= result.password then
      error({
        code = 400,
        message = "Old password isn't correct",
      })
    end
  end
  local encrypt_new_pwd = auth_ctrl.encrypt_pwd(body.new_pwd)
  local target = {
    password = encrypt_new_pwd
  }
  if body.username ~= nil then
    target['username'] = body.username
  end
  conn:uci_set_first('gui', 'user_mgmt', { never_logged_in = false })
  conn:uci_set_first('rpcd', 'login', target)
  conn:uci_commit('rpcd')
  conn:uci_commit('gui')
  http:status(200):json({
    result = 'SUCCESS',
  })
end

function auth_ctrl.check_pwd()
  local body = http.parse_body()
  local password = auth_ctrl.encrypt_pwd(body.password)
  local conn = ubus.connect()
  local result = conn:uci_get_first('rpcd', 'login')
  if result == nil then
    error({
      code = 500,
      message = 'Invalid rpcd config'
    })
  end
  if password ~= result.password then
    error({
      code = 400,
      message = "password isn't correct",
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

return auth_ctrl
