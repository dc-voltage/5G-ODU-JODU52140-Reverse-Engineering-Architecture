local json = require('luci.jsonc')
local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local logger = require('lux-logger')
local esim_ctrl = {}

local function query_esim(times)
  if times == nil then
    times = 0
  end
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'esim',
  }, { return_error = true })
  if result == nil or result.paramtable.err_code ~= nil then
    if times > 15 then
      local err_code = 0x7f
      if result ~= nil then
        err_code = result.paramtable.err_code
      end
      error({
        code = 500,
        message = string.format('ESIM error: %d', err_code),
        err_code = err_code,
      })
    end
    util.sleep(2)
    logger.warn("Retry call esim")
    if result ~= nil and result.paramtable.err_code == 0xff then
      return query_esim(times)
    end
    return query_esim(times + 1)
  end
  return result.paramtable
end

function esim_ctrl.get_app_network_info()
  local result = query_esim()
  local active_profile = { profile_id = "" }
  if result.operator_name == '' then
    active_profile.operator_name = '__null__'
    active_profile.network_type = '__null__'
  else
    active_profile.operator_name = result.operator_name
    active_profile.network_type = 'NR'
  end
  for _, profile in ipairs(result.profile_info_list or {}) do
    if profile.enable == 1 then
      active_profile.profile_id = tostring(profile.id)
    end
  end
  http.send_with_ending('Content-Type: application/json; charset=utf-8')
  local res_json = json.stringify({
    result = true,
    active_profile = active_profile,
  }):gsub('"__null__"', 'null')
  http.send_with_ending('')
  http.send(res_json)
  logger.debug('Response', res_json)
end

function esim_ctrl.get_eid()
  local status, result = pcall(query_esim)
  if status then
    http:status(200):json({
      result = true,
      eid = result.eid,
    })
  elseif result.err_code == '8201' then
    error({
      type = 'app',
      code = 500,
      message = '',
      app_msg_id = '4352',
      app_error_code = tonumber(result.err_code),
    })
  else
    error({
      type = 'app',
      code = 500,
      message = string.format('Error code: %d', result.err_code or -1),
    })
  end
end

function esim_ctrl.get_default_smdp_address()
  local conn = ubus.connect()
  local result = conn:call('luxslam', '5g', {
    cmd = 'get',
    class = 'smdp',
  }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = true,
      smdpAddress = result.smdp_address,
    })
  else
    error({
      code = 500,
      message = string.format('Error code: %d', result.err_code),
    })
  end
end

function esim_ctrl.set_default_smdp_address()
  local conn = ubus.connect()
  local body = http.parse_body()
  local result = conn:call('luxslam', '5g', {
    cmd = 'set',
    class = 'smdp',
    paramtable = {
      smdp_address = body.smdpAddress,
    },
  }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = true,
      smdpAddress = body.smdpAddress,
    })
  else
    error({
      code = 500,
      message = string.format('Error code: %d', result.err_code),
    })
  end
end

function esim_ctrl.get_default_smdp_address_ini()
  local conn = ubus.connect()
  local result = conn:call('luxslam', '5g', {
    cmd = 'get',
    class = 'smdp',
  }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = true,
      smdpAddressIni = result.smdp_address_ini,
    })
  else
    error({
      code = 500,
      message = string.format('Error code: %d', result.err_code),
    })
  end
end

function esim_ctrl.set_default_smdp_address_ini()
  local conn = ubus.connect()
  local body = http.parse_body()
  local result = conn:call('luxslam', '5g', {
    cmd = 'set',
    class = 'smdp',
    paramtable = {
      smdp_address_ini = body.smdpAddressIni,
    },
  }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = true,
      smdpAddressIni = body.smdpAddressIni,
    })
  else
    error({
      code = 500,
      message = string.format('Error code: %d', result.err_code),
    })
  end
end

function esim_ctrl.get_profiles()
  local result = query_esim()
  local profiles = util.map(util.filter(result.profile_info_list or {}, function(row)
    return tonumber(row.profile_class) ~= 0
  end), function(row)
    local status;
    local name = row.profile_name
    if row.enable == 1 then
      status = 'ENABLED'
    else
      status = 'DISABLED'
    end
    if row.profile_nick_name and row.profile_nick_name ~= '' then
      name = row.profile_nick_name
    end
    return {
      service_iccid = row.iccid,
      status = status,
      service_provider = row.service_provider_name,
      name = name,
    }
  end)
  http:status(200):json({
    result = true,
    entries = profiles,
  })
end

function esim_ctrl.get_app_profiles()
  local result = query_esim()
  local profile_info_list = util.map(result.profile_info_list or {}, function(row)
    return {
      id = row.id,
      iccid = row.iccid,
      profile_state = tonumber(row.enable),
      service_provider_name = row.service_provider_name,
      profile_name = row.profile_name,
      profile_class = tonumber(row.profile_class),
      profile_nick_name = row.profile_nick_name or '',
      profile_policy_rules = tonumber(row.profile_policy_rules),
    }
  end)
  http:status(200):json({
    result = true,
    count_profile_info = #profile_info_list,
    number_profile_found = #profile_info_list,
    max_number_profile_info = result.max_number_profile_info,
    profile_info_list = profile_info_list,
  })
end

local function query_installing_state()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'set',
    class = 'esim',
    paramtable = {
      action = 'Get Installing Profile State',
    },
  })
  if type(result) ~= 'table' then
    logger.error(result.paramtable)
  end
  result = result.paramtable or {}
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Query Installing State Error: %d', result.err_code),
    })
  end
  return result.installing_profile_info
end

local function query_installing_state_until_completed()
  local state = query_installing_state()
  logger.info(state.state, state.current_value, state.progress_text, state.error_info)
  while state.state == 1 do
    util.sleep(5)
    state = query_installing_state()
    if type(state) == 'table' then
      logger.info(state.state, state.current_value, state.progress_text, state.error_info)
    end
  end
  return state
end

local function sync_send_pending_notification()
  local conn = ubus.connect()
  local result = conn:call('luxslam', '5g', {
    cmd = 'set',
    class = 'esim',
    paramtable = {
      action = 'Send Pending Notifications',
    },
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil then
    local state = query_installing_state_until_completed()
    if state.error_info ~= '' then
      logger.error('Send Pending Notification Fail', state.error_info)
    end
  else
    logger.error('Send Pending Notification Fail', result.err_code);
  end
end

---@param error_info string
---@return string
local function get_esim_error_info_message(error_info)
  local lpa_error_code, error_type, detail_error_mask, subject_code, reason_code, extra_info = unpack(util.split(error_info, ','))
  logger.info(lpa_error_code, error_type, detail_error_mask, subject_code, reason_code, extra_info)
  if error_type == '2' then
    return 'INTERNAL_SERVER_FAILURE'
  elseif type(lpa_error_code) == 'string' and lpa_error_code:lower() == '230a' then
    return 'INVALID_ACTIVATION_CODE'
  elseif detail_error_mask == '7' or detail_error_mask == '3' then
    return util.join({'PROCESSING_FAILURE', subject_code, reason_code}, '/')
  end
  return extra_info
end

---@param error_code string
---@return string
local function get_esim_error_code_message(error_code)
  logger.error(error_code)
  if error_code == '8970' then
    return 'INVALID_ACTIVATION_CODE'
  end
  return util.join({'LPA_ERROR_CODE', error_code}, '/')
end

---@param error_info string
---@return string
local function get_app_error_code(error_info)
  local lpa_error_code, error_type, detail_error_mask, subject_code, reason_code, extra_info = unpack(util.split(error_info, ','))
  logger.info(lpa_error_code, error_type, detail_error_mask, subject_code, reason_code, extra_info)
  if detail_error_mask ~= '7' then
    return tostring(tonumber(lpa_error_code, 16))
  end
  local mapping_code = subject_code .. '.' .. reason_code
  return util.join(util.map(util.split(mapping_code, '.'), function(value, index)
    if index == 1 then
      return value
    end
    if #value >= 2 then
      return value
    end
    return '0' .. value
  end), '')
end

function esim_ctrl.install_profile_by_default_smdp()
  local body = http.parse_body()
  local old_esim = query_esim()
  local result = ubus:connect():call('luxslam', '5g', {
    cmd = 'set',
    class = 'esim',
    paramtable = {
      action = 'Install By Default SMDP',
      auto_enable_profile = body.auto_enable_profile,
    },
  }).paramtable or {}
  local state = query_installing_state_until_completed()
  if state.error_info ~= '' then
    logger.error(state.error_info)
    error({
      type = 'app',
      code = 500,
      app_msg_id = '4352',
      app_error_code = get_app_error_code(state.error_info),
    })
  end
  local profile
  local esim = query_esim()
  if #old_esim.profile_info_list < #esim.profile_info_list then
    profile = util.last(esim.profile_info_list)
  end
  if profile then
    if body.auto_enable_profile then
      ubus.connect():call('luxslam', '5g', {
        cmd = 'set',
        class = 'esim',
        paramtable = {
          action = 'Update Profile',
          profile_info_list = {{
            iccid = profile.iccid,
            enable = 1,
          }},
        },
      })
    end
    if state.error_info ~= '' then
      logger.error(state.error_info)
      error({
        type = 'app',
        code = 500,
        app_msg_id = '4352',
        app_error_code = get_app_error_code(state.error_info),
      })
    end
  else
    result.err_code = 128
  end
  if result.err_code == nil then
    http:status(200):json({
      result = true,
    })
  else
    error({
      type = 'app',
      code = 500,
      message = string.format('Error code: %d', result.err_code),
    })
  end
end

function esim_ctrl.install_profile()
  local body = http.parse_body()
  local conn = ubus.connect()
  local activation_code = string.gsub(body.activation_code, '^%s+', '')
  activation_code = string.gsub(body.activation_code, '%s+$', '')
  local s = string.find(activation_code, "^[%d%u]+$")
  if s == nil then
    error({
      code = 500,
      message = 'INVALID_ACTIVATION_CODE',
    })
  end
  local result = conn:call('luxslam', '5g', {
    cmd = 'set',
    class = 'esim',
    paramtable = {
      action = 'Install With Activation Code',
      activation_code = activation_code,
    },
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil then
    local state = query_installing_state_until_completed()
    if state.error_info ~= '' then
      logger.error(state.error_info)
      error({
        code = 500,
        message = get_esim_error_info_message(state.error_info),
      })
    end
    http:status(200):json({
      result = true,
    })
  else
    error({
      code = 500,
      message = get_esim_error_code_message(result.err_code),
    })
  end
end

function esim_ctrl.app_install_profile()
  local body = http.parse_body()
  local conn = ubus.connect()
  local result = conn:call('luxslam', '5g', {
    cmd = 'set',
    class = 'esim',
    paramtable = {
      action = 'Install With Activation Code',
      activation_code = string.gsub(body.activation_code, '^%s+', ''),
    },
  }).paramtable or {}
  if result.err_code == nil then
    local state = query_installing_state_until_completed()
    if state.error_info ~= '' then
      logger.error(state.error_info)
      error({
        type = 'app',
        code = 500,
        app_msg_id = '4352',
        app_error_code = get_app_error_code(state.error_info),
      })
    end
    http:status(200):json({
      result = true,
    })
  else
    error({
      type = 'app',
      code = 500,
      app_msg_id = '4352',
      app_error_code = result.err_code,
    })
  end
end

function esim_ctrl.add_profile()
  local body = http.parse_body()
  local old_esim = query_esim()
  local conn = ubus.connect()
  local activation_code = string.gsub(body.activation_code, '^%s+', '')
  activation_code = string.gsub(body.activation_code, '%s+$', '')
  local s = string.find(activation_code, "^[%d%u]+$")
  if s == nil then
    error({
      code = 500,
      message = 'INVALID_ACTIVATION_CODE',
    })
  end
  local result = conn:call('luxslam', '5g', {
    cmd = 'set',
    class = 'esim',
    paramtable = {
      action = 'Install With Activation Code',
      activation_code = activation_code,
    },
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil then
    local state = query_installing_state_until_completed()
    if state.error_info ~= '' then
      logger.error(state.error_info)
      error({
        code = 500,
        message = get_esim_error_info_message(state.error_info),
      })
    end
    local profile
    local esim = query_esim()
    if #old_esim.profile_info_list < #esim.profile_info_list then
      profile = util.last(esim.profile_info_list)
    end
    if profile ~= nil then
      local update_body = {
        iccid = profile.iccid,
      }
      if body.status == 'ENABLED' then
        update_body.enable = 1
      end
      if body.name ~= nil and body.name ~= '' then
        update_body.profile_nick_name = body.name
      end
      if #util.keys(update_body) > 1 then
        ubus.connect():call('luxslam', '5g', {
          cmd = 'set',
          class = 'esim',
          paramtable = {
            action = 'Update Profile',
            profile_info_list = {update_body},
          },
        })
      end
    else
      logger.error('Missing profile')
    end
    http:status(200):json({
      result = true,
    })
  else
    error({
      code = 500,
      message = get_esim_error_code_message(result.err_code),
    })
  end
end

---@param func function
local function retry_when_profile_cat_busy(func)
  local result = {}
  for _=1,10 do
    result = func()
    if result.err_code == '8451' then
      logger.error("Profile cat busy: ", result.err_code)
      util.sleep(2)
    else
      break
    end
  end
  return result
end

---@param service_iccid string
function esim_ctrl.update_profile(service_iccid)
  local body = http.parse_body()
  local conn = ubus.connect()
  local update_body = {
    iccid = service_iccid,
  }
  if body.state ~= nil then
    update_body.enable = body.state
  end
  if body.profile_nick_name ~= nil and #body.profile_nick_name > 0 then
    update_body.profile_nick_name = body.profile_nick_name
  end
  local result = retry_when_profile_cat_busy(function()
    return conn:call('luxslam', '5g', {
      cmd = 'set',
      class = 'esim',
      paramtable = {
        action = 'Update Profile',
        profile_info_list = {update_body},
      },
    }, { return_error = true }).paramtable or {}
  end)
  if result.err_code ~= nil then
    logger.warn("Update profile return error:", result.err_code)
    if result.err_code == '254' then
      query_installing_state_until_completed()
    end
  end
  http:status(200):json({
    result = true,
  })
end

---@param service_iccid string
function esim_ctrl.delete_profile(service_iccid)
  local conn = ubus.connect()
  local result = conn:call('luxslam', '5g', {
    cmd = 'set',
    class = 'esim',
    paramtable = {
      action = 'Delete Profile',
      profile_info_list = {{
        iccid = service_iccid,
      }},
    },
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil or result.err_code == '8457' then
    http:status(200):json({
      result = true,
    })
  else
    error({
      code = 500,
      message = string.format('Error code: %d', result.err_code),
    })
  end
end

function esim_ctrl.get_euicc_info()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'esim_euicc',
  }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = true,
      euicc_info_data = result.info_data,
    })
  else
    error({
      type = 'app',
      code = 500,
      app_msg_id = '4352',
      app_error_code = result.err_code,
    })
  end
end

function esim_ctrl.reset_memory()
  local body = http.parse_body()
  local conn = ubus.connect()
  local result = conn:call('luxslam', '5g', {
    cmd = 'set',
    class = 'esim',
    paramtable = {
      action = 'Reset',
      reset_option = body.reset_option
    },
  }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = true,
    })
  else
    error({
      type = 'app',
      code = 500,
      app_msg_id = '4352',
      app_error_code = result.err_code,
    })
  end
end

function esim_ctrl.get_profile_install_state()
  local result = query_installing_state();
  local install_state = result.state;
  if install_state == 0 then
    local led = ubus.connect():call('luxslam', 'sys', {
      cmd = 'get',
      class = 'led',
    }, { return_error = true })
    if led.paramtable.esim_profile_exist == 1 then
      install_state = 100
    else
      install_state = 1000
    end
  end
  http:status(200):json({
    result = true,
    install_state = install_state,
    data = {
      progress_text = result.progress_text,
      value_min = result.min_value,
      value_max = result.max_value,
      current_value = result.current_value,
    },
  })
end

function esim_ctrl.send_pending_notification()
  sync_send_pending_notification()
  http:status(200):json({
    result = true,
  })
end

return esim_ctrl
