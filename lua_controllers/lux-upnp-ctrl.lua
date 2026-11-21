local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local ubus = require('lux-ubus')
local upnp_ctrl = {}

local PROTOCOL_TYPE = {
  BOTH = 'Both',
  UDP = 'UDP',
  TCP = 'TCP',
}

function upnp_ctrl.get_upnp_info()
  local upnp = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'get',
    class = 'upnp',
  }).paramtable
  if upnp.err_code ~= nil then
    error({
      code = 500,
      message = string.format('UPnP error: %d', upnp.err_code),
    })
  end

  http:status(200):json({
    enabled = util.to_boolean(upnp.enable),
  })
end

function upnp_ctrl.update_upnp_status()
  local body = http:parse_body()
  if not verify.isBoolean(body.enabled) then
    error({
      code = 400,
      message = 'Invalid field enable',
    })
  end

  local result = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'set',
    class = 'upnp',
    paramtable = {
      enable = body.enabled,
    },
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('UPnP update error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

local function query_port_forward()
  local port_forward = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'get',
    class = 'port_forward',
  }).paramtable
  if port_forward.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Port forward error: %d', port_forward.err_code),
    })
  end
  return port_forward
end

local function update_port_forward(paramtable)
  local result = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'set',
    class = 'port_forward',
    paramtable = paramtable,
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Port forward update error: %d', result.err_code),
    })
  end
end

function upnp_ctrl.get_port_forward()
  local port_forward = query_port_forward()

  local entries = util.map(port_forward.rule_list, function(row, index)
    return {
      id = index,
      proto = util.invert(PROTOCOL_TYPE)[row.protocol],
      begin = row.wan_port_begin,
      ['end'] = row.wan_port_end,
      ipv4 = row.lan_ip,
      lan = row.lan_port_begin,
      status = util.to_boolean(row.enable),
      description = row.description
    }
  end)

  http:status(200):json({
    enabled = util.to_boolean(port_forward.enable),
    entries = entries,
  })
end

function upnp_ctrl.update_port_forward_status()
  local body = http.parse_body()
  if not verify.isBoolean(body.status) then
    error({
      code = 400,
      message = 'Invalid field enable',
    })
  end
  update_port_forward({
    enable = body.status
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

local function parse_port_forwarding_rule_body()
  local body = http.parse_body()
  if body.ipv4 and not verify.isIPv4(body.ipv4) then
    error({
      code = 400,
      message = "Invalid ipv4 value",
    })
  end

  if not util.includes(util.keys(PROTOCOL_TYPE), body.proto) then
    error({
      code = 400,
      message = "Invalid proto value",
    })
  end

  if body.begin and not verify.isInteger(body.begin) and body.begin < 1 and body.begin > 65535 then
    error({
      code = 400,
      message = "Invalid begin value",
    })
  end

  if body.lan and not verify.isInteger(body.lan) and body.lan < 1 and body.lan > 65535 then
    error({
      code = 400,
      message = "Invalid lan value",
    })
  end

  if body['end'] and not verify.isInteger(body['end']) and body['end'] < 1 and body['end'] > 65535 then
    error({
      code = 400,
      message = "Invalid begin value",
    })
  end

  if not verify.isBoolean(body.status) then
    error({
      code = 400,
      message = "Invalid status",
    })
  end

  return body
end

function upnp_ctrl.create_port_forwarding_rule()
  local body = parse_port_forwarding_rule_body()
  local port_forward = query_port_forward()

  table.insert(port_forward.rule_list, {
    protocol = PROTOCOL_TYPE[body.proto],
    wan_port_begin = body.begin,
    wan_port_end = body['end'],
    lan_ip = body.ipv4,
    lan_port_begin = body.lan,
    enable = body.status,
    description = body.description,
  })

  update_port_forward({
    enable = port_forward.enable,
    rule_list = port_forward.rule_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function upnp_ctrl.update_port_forwarding_rule()
  local body = http.parse_body()
  local port_forward = query_port_forward()

  local found = port_forward.rule_list[body.indexId]
  if not found then
    error({
      code = 400,
      message = 'Not found rule',
    })
  end

  found.protocol = PROTOCOL_TYPE[body.proto]
  found.wan_port_begin = body.begin
  found.wan_port_end = body['end']
  found.lan_ip = body.ipv4
  found.lan_port_begin = body.lan
  found.enable = body.status
  found.description = body.description

  update_port_forward({
    rule_list = port_forward.rule_list,
  })

  http:status(200):json({
    result = 'SUCCESS'
  })
end

function upnp_ctrl.delete_port_forwarding_rule(env)
  local query = http.parse_query(env)
  local port_forward = query_port_forward()
  table.remove(port_forward.rule_list, query.indexId)
  update_port_forward({
    rule_list = port_forward.rule_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

return upnp_ctrl
