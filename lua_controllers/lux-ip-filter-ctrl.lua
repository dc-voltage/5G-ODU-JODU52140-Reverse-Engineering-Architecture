local http = require('lux-http')
local util = require('lux-util')
local ubus = require('lux-ubus')
local verify = require('lux-verify')
local ip_filter_ctrl = {}

local MODE_STATUS = {
  ALLOW = 'Allow only',
  DENY = 'Deny',
}

local IP_ADDRESS_TYPE = {
  IPV4 = 'IPv4',
  IPV6 = 'IPv6',
}

local function verify_lan_mode()
  local result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('General error: %d', result.err_code),
    })
  end

  if result.mode ~= 'Router' then
    error({
      code = 400,
      message = string.format('It is currently not in router mode and cannot be controlled.'),
    })
  end
end

local function query_ip_filter()
  local ip_filter = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'get',
    class = 'ip_filter',
  }).paramtable
  if ip_filter.err_code ~= nil then
    error({
      code = 500,
      message = string.format('IP Filter error: %d', ip_filter.err_code),
    })
  end
  return ip_filter
end

local function update_ip_filter(paramtable)
  local result = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'set',
    class = 'ip_filter',
    paramtable = paramtable,
  }).paramtable

  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('IP Filter update error: %d', result.err_code),
    })
  end
end

function ip_filter_ctrl.get_info()
  verify_lan_mode()
  local ip_filter = query_ip_filter()

  local entries = util.map(ip_filter.filter_list, function(row)
    return {
      ip_address = row.ip_addr,
      ip_address_type = row.ip_version:upper(),
      mode = util.invert(MODE_STATUS)[row.mode],
    }
  end)

  http:status(200):json({
    mode = util.invert(MODE_STATUS)[ip_filter.mode],
    status = util.to_boolean(ip_filter.enable),
    entries = entries
  })
end

function ip_filter_ctrl.update_info()
  verify_lan_mode()
  local body = http.parse_body()
  local ip_filter = query_ip_filter()

  if not verify.isBoolean(body.status) then
    error({
      code = 400,
      message = 'Invalid field enable',
    })
  end

  update_ip_filter({
    mode = MODE_STATUS[body.mode],
    enable = body.status,
    filter_list = ip_filter.filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

local function parse_ip_address_body()
  local body = http.parse_body()
  if not verify.isIPv4(body.ip_address) and not verify.isIPv6(body.ip_address) then
    error({
      code = 400,
      message = "Invalid ip value",
    })
  end

  return body
end

function ip_filter_ctrl.create_entry()
  verify_lan_mode()
  local body = parse_ip_address_body()
  local ip_filter = query_ip_filter()
  local exists = util.find(ip_filter.filter_list, function(row)
    return row.ip_addr == body.ip_address
  end)
  if exists ~= nil then
    error({
      code = 400,
      message = 'FILE EXIST',
    })
  end

  table.insert(ip_filter.filter_list, {
    ip_addr = body.ip_address,
    ip_version = IP_ADDRESS_TYPE[body.ip_address_type],
    mode = MODE_STATUS[body.mode],
  })

  update_ip_filter({
    mode = ip_filter.mode,
    enable = ip_filter.enable,
    filter_list = ip_filter.filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function ip_filter_ctrl.delete_entry(env)
  verify_lan_mode()
  local query =  http.parse_query(env)
  local ip_filter = query_ip_filter()

  local filter_list = util.filter(ip_filter.filter_list, function(row)
    return row.ip_addr ~= query.ip_address
  end)

  update_ip_filter({
    mode = ip_filter.mode,
    enable = ip_filter.enable,
    filter_list = filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

return ip_filter_ctrl
