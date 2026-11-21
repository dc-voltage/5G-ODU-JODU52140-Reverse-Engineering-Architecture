local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local firewall_ctrl = {}

local IP_ADDRESS_TYPE = {
  IPV4 = 'IPv4',
  IPV6 = 'IPv6'
}

function firewall_ctrl.get_info()
  local conn = ubus.connect()
  local firewall = conn:call('luxslam', 'firewall', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  if firewall.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Firewall error: %d', firewall.err_code),
    })
  end

  local dmz = conn:call('luxslam', 'firewall', {
    cmd = 'get',
    class = 'dmz',
  }).paramtable
  if dmz.err_code ~= nil then
    error({
      code = 500,
      message = string.format('DMZ error: %d', dmz.err_code),
    })
  end

  http:status(200):json({
    firewall_enable = util.to_boolean(firewall.enable),
    dmz_enable = util.to_boolean(dmz.enable),
    dmz_ip_type = util.invert(IP_ADDRESS_TYPE)[dmz.ip_version],
    dmz_ip = dmz.ip_addr,
  })
end

---@param raw_body table
---@return table body
function firewall_ctrl._parse_update_info_body(raw_body)
  local body = {}
  if verify.isBoolean(raw_body.firewall_enable) then
    body.firewall_enable = raw_body.firewall_enable
  else
    error({
      code = 400,
      message = 'Invalid field firewall_enable',
    })
  end
  if verify.isBoolean(raw_body.dmz_enable) then
    body.dmz_enable = raw_body.dmz_enable
  else
    error({
      code = 400,
      message = 'Invalid field dmz_enable',
    })
  end
  if (body.dmz_enable) then
    if util.includes(util.keys(IP_ADDRESS_TYPE), raw_body.dmz_ip_type) then
      body.dmz_ip_type = raw_body.dmz_ip_type
    else
      error({
        code = 400,
        message = 'Invalid field dmz_ip_type',
      })
    end
    local _, err = verify.parse_ip(raw_body.dmz_ip)
    if err == nil then
      body.dmz_ip = raw_body.dmz_ip
    else
      error({
        code = 400,
        message = 'Invalid field dmz_ip',
      })
    end
  end
  return body
end

function firewall_ctrl.update_info()
  local body = firewall_ctrl._parse_update_info_body(http:parse_body())
  local conn = ubus.connect()
  local firewall = conn:call('luxslam', 'firewall', {
    cmd = 'set',
    class = 'general',
    paramtable = {
      enable = body.firewall_enable,
    },
  }).paramtable
  if firewall.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Firewall error: %d', firewall.err_code),
    })
  end

  local dmz = conn:call('luxslam', 'firewall', {
    cmd = 'set',
    class = 'dmz',
    paramtable = {
      enable = body.dmz_enable,
      ip_version = IP_ADDRESS_TYPE[body.dmz_ip_type],
      ip_addr = body.dmz_ip,
    },
  }).paramtable
  if dmz.err_code ~= nil then
    error({
      code = 500,
      message = string.format('DMZ error: %d', dmz.err_code),
    })
  end
  http:status(200):json({
    result = 'SUCCESS',
  })
end

return firewall_ctrl
