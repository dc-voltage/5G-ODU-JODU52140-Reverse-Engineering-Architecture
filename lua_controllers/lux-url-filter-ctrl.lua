local http = require('lux-http')
local util = require('lux-util')
local ubus = require('lux-ubus')
local verify = require('lux-verify')
local url_filter_ctrl = {}

local MODE_STATUS = {
  ALLOW = 'Allow only',
  DENY = 'Deny',
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

local function query_url_filter()
  local url_filter = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'get',
    class = 'url_filter',
  }).paramtable
  if url_filter.err_code ~= nil then
    error({
      code = 500,
      message = string.format('URL Filter error: %d', url_filter.err_code),
    })
  end
  return url_filter
end

local function update_url_filter(paramtable)
  local result = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'set',
    class = 'url_filter',
    paramtable = paramtable,
  }).paramtable

  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('URL Filter update error: %d', result.err_code),
    })
  end
end

function url_filter_ctrl.get_info()
  verify_lan_mode()
  local url_filter = query_url_filter()

  local entries = util.map(url_filter.filter_list, function(row)
    return {
      url = row.url,
      mode = util.invert(MODE_STATUS)[row.mode],
    }
  end)

  http:status(200):json({
    mode = util.invert(MODE_STATUS)[url_filter.mode],
    status = util.to_boolean(url_filter.enable),
    entries = entries
  })
end

local function parse_url_filter_body()
  local body = http.parse_body()
  if not util.includes(util.keys(MODE_STATUS), body.mode) then
    error({
      code = 400,
      message = "Invalid mode",
    })
  end

  if body.url ~= nil and not verify.isURL(body.url) then
    error({
      code = 400,
      message = "Invalid url value",
    })
  end

  if body.status ~= nil and not verify.isBoolean(body.status) then
    error({
      code = 400,
      message = "Invalid status",
    })
  end

  return body
end

function url_filter_ctrl.update_info()
  verify_lan_mode()
  local body = parse_url_filter_body()
  local url_filter = query_url_filter()

  update_url_filter({
    mode = MODE_STATUS[body.mode],
    enable = body.status,
    filter_list = url_filter.filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function url_filter_ctrl.create_entry()
  verify_lan_mode()
  local body = parse_url_filter_body()
  local url_filter = query_url_filter()

  local exists = util.find(url_filter.filter_list, function(row)
    return row.url == body.url
  end)
  if exists ~= nil then
    error({
      code = 400,
      message = 'FILE EXIST',
    })
  end

  table.insert(url_filter.filter_list, {
    url = body.url,
    mode = MODE_STATUS[body.mode],
  })

  update_url_filter({
    mode = url_filter.mode,
    enable = url_filter.enable,
    filter_list = url_filter.filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function url_filter_ctrl.delete_entry(env)
  verify_lan_mode()
  local query = http.parse_query(env)
  local url = uhttpd.urldecode(query.url);
  local url_filter = query_url_filter()

  local filter_list = util.filter(url_filter.filter_list, function(row)
    return row.url ~= url
  end)

  update_url_filter({
    mode = url_filter.mode,
    enable = url_filter.enable,
    filter_list = filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

return url_filter_ctrl
