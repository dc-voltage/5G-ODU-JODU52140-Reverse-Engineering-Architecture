local ubus = require('lux-ubus')
local http = require('lux-http')
local verify = require('lux-verify')
local util = require('lux-util')
local radvd_ctrl = {}

local ADVERTISE_MODE = {
  UNSOLICITED_MULTICAST = 'Unsolicited Multicast',
  UNICAST_ONLY = 'Unicast Only',
}

local ROUTER_PREFERENCE = {
  LOW = 'Low',
  MEDIUM = 'Medium',
  HIGH = 'High',
}

function radvd_ctrl.get_info()
  local radvd = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'radvd',
  }).paramtable
  if radvd.err_code ~= nil then
    error({
      code = 500,
      message = string.format('RADVD error: %d', radvd.err_code),
    })
  end

  http:status(200):json({
    enabled = util.to_boolean(radvd.enable),
    advertise_mode = util.invert(ADVERTISE_MODE)[radvd.advertise_mode],
    advertise_interval = radvd.advertise_interval,
    ra_flag_managed = util.to_boolean(radvd.m_flag),
    ra_flag_other = util.to_boolean(radvd.o_flag),
    router_preference = util.invert(ROUTER_PREFERENCE)[radvd.router_preference],
    router_lifetime = radvd.router_lifetime,
  })
end

---@param raw_body table
---@return table body
function radvd_ctrl._parse_update_info_body(raw_body)
  local body = {}
  if verify.isBoolean(raw_body.enabled) then
    body.enabled = raw_body.enabled
  else
    error({
      code = 400,
      message = 'Invalid field enabled',
    })
  end
  if util.includes(util.keys(ADVERTISE_MODE), raw_body.advertise_mode) then
    body.advertise_mode = raw_body.advertise_mode
  else
    error({
      code = 400,
      message = 'Invalid field advertise_mode',
    })
  end
  if verify.isBoolean(raw_body.ra_flag_managed) then
    body.ra_flag_managed = raw_body.ra_flag_managed
  else
    error({
      code = 400,
      message = 'Invalid field ra_flag_managed',
    })
  end
  if verify.isBoolean(raw_body.ra_flag_other) then
    body.ra_flag_other= raw_body.ra_flag_other
  else
    error({
      code = 400,
      message = 'Invalid field ra_flag_managed',
    })
  end
  local advertise_interval = tonumber(raw_body.advertise_interval)
  if verify.isInteger(advertise_interval) and advertise_interval >= 10 and advertise_interval <= 1800 then
    body.advertise_interval = advertise_interval
  else
    error({
      code = 400,
      message = 'Invalid field advertise_interval',
    })
  end
  local router_lifetime = tonumber(raw_body.router_lifetime)
  if verify.isInteger(router_lifetime) and router_lifetime >= 30 and router_lifetime <= 9000 then
    body.router_lifetime= router_lifetime
  else
    error({
      code = 400,
      message = 'Invalid field router_lifetime',
    })
  end
  if util.includes(util.keys(ROUTER_PREFERENCE), raw_body.router_preference) then
    body.router_preference = raw_body.router_preference
  else
    error({
      code = 400,
      message = 'Invalid field router_preference',
    })
  end
  return body
end

function radvd_ctrl.update_info()
  local body = radvd_ctrl._parse_update_info_body(http:parse_body())
  local radvd = ubus.connect():call('luxslam', 'lan', {
    cmd = 'set',
    class = 'radvd',
    paramtable = {
      enable = body.enabled,
      advertise_mode = ADVERTISE_MODE[body.advertise_mode],
      advertise_interval = body.advertise_interval,
      m_flag = body.ra_flag_managed,
      o_flag = body.ra_flag_other,
      router_preference = ROUTER_PREFERENCE[body.router_preference],
      router_lifetime = body.router_lifetime,
    },
  }).paramtable
  if radvd.err_code ~= nil then
    error({
      code = 500,
      message = string.format('RADVD error: %d', radvd.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

return radvd_ctrl
