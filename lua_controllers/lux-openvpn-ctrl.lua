local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local openvpn_ctrl = {}

local MODE = {
  SERVER = 'Server',
  CLIENT = 'Client',
}

local ENCRYPTION_ALGORITHM = {
  AES128_SHA256 = 'AES128-SHA254',
  AES256_SHA256 = 'AES256-SHA256',
  AES128_SHA512 = 'AES128-SHA512',
  AES192_SHA256 = 'AES192-SHA256',
}

local AUTH_TYPE = {
  STATIC = 'Static',
  TLS = 'TLS',
}

local IP_ADDRESS_TYPE = {
  IPV4 = 'IPv4',
  IPV6 = 'IPv6',
}

local SCENARIO = {
  TUN = 'TUN (Layer 3)',
  TAP = 'TAP (Layer 2)',
}

local function query_openvpn()
  local openvpn = ubus.connect():call('luxslam', 'openvpn', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  if openvpn.err_code ~= nil then
    error({
      code = 500,
      message = string.format('OpenVPN error: %d', openvpn.err_code),
    })
  end
  return openvpn
end

local function update_openvpn(paramtable)
  local openvpn = ubus.connect():call('luxslam', 'openvpn', {
    cmd = 'set',
    class = 'general',
    paramtable = paramtable,
  }).paramtable
  if openvpn.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Update OpenVPN error: %d', openvpn.err_code),
    })
  end
end

function openvpn_ctrl.get_info()
  local openvpn = query_openvpn()
  local openvpn_rules = util.map(openvpn.rule, function(rule)
    return {
      rule_id = rule.openvpn_id,
      protocol = rule.protocol,
      port = rule.port,
      tunnel_scenario = util.invert(SCENARIO)[rule.tunnel_scenario],
      authorization_type = util.invert(AUTH_TYPE)[rule.auth_type],
      static_key = rule.static_key,
      ip_address_type = util.invert(IP_ADDRESS_TYPE)[rule.ip_version],
      local_endpoint_ip = rule.local_ip_addr,
      remote_endpoint_ip = rule.remote_ip_addr,
      encryption_algorithm = util.invert(ENCRYPTION_ALGORITHM)[rule.encryption_algorithm],
      push_route_option = util.to_boolean(rule.push_route_option),
      netmask = rule.remote_netmask,
      redirect_default_gateway = util.to_boolean(rule.redirect_default_gateway),
      lzo_compression = util.to_boolean(rule.lzo_compression),
      persist_key = util.to_boolean(rule.persist_key),
      persist_tun = util.to_boolean(rule.persist_tun),
      status = util.to_boolean(rule.enable),
    }
  end)
  http:status(200):json({
    status = util.to_boolean(openvpn.enable),
    mode = util.invert(MODE)[openvpn.mode],
    openvpn_rules = openvpn_rules,
  })
end

local function parse_update_openvpn_status_body(raw_body)
  local body = {}
  if not verify.isBoolean(raw_body.status) then
    error({
      code = 400,
      message = 'Invalid field status',
    })
  end
  if not util.includes(util.keys(MODE), raw_body.mode) then
    error({
      code = 400,
      message = 'Invalid field mode',
    })
  end
  return raw_body
end

local function parse_openvpn_rule_body(raw_body)
  local body = {
    rule_id = raw_body.rule_id,
  }
  if verify.indexOf({'UDP', 'TCP'}, raw_body.protocol) > 0 then
    body.protocol = raw_body.protocol
  else
    error({
      code = 400,
      message = 'Invalid field protocol',
    })
  end
  local port = tonumber(raw_body.port)
  if verify.isInteger(port) and (port >= 1024 and port <= 65535) then
    body.port = port
  else
    error({
      code = 400,
      message = 'Invalid field port',
    })
  end
  if util.includes(util.keys(SCENARIO), raw_body.tunnel_scenario) then
    body.tunnel_scenario = raw_body.tunnel_scenario
  else
    error({
      code = 400,
      message = 'Invalid field tunnel_scenario',
    })
  end
  if util.includes(util.keys(AUTH_TYPE), raw_body.authorization_type) then
    body.authorization_type = raw_body.authorization_type
    if raw_body.authorization_type == 'STATIC' then
      if verify.isString(raw_body.static_key) and #raw_body.static_key > 0 then
        body.static_key = raw_body.static_key
      else
        error({
          code = 400,
          message = 'Invalid field static_key',
        })
      end
    else
      body.static_key = ""
    end
  else
    error({
      code = 400,
      message = 'Invalid field authorization_type',
    })
  end
  if util.includes(util.keys(IP_ADDRESS_TYPE), raw_body.ip_address_type) then
    body.ip_address_type = raw_body.ip_address_type
    if body.ip_address_type == 'IPV4' then
      if #raw_body.local_endpoint_ip > 0 then
        local _, err = verify.parse_ip(raw_body.local_endpoint_ip)
        if err == nil then
          body.local_endpoint_ip = raw_body.local_endpoint_ip
        else
          error({
            code = 400,
            message = 'Invalid field local_endpoint_ip',
          })
        end
      else
        body.local_endpoint_ip = raw_body.local_endpoint_ip
      end
      if #raw_body.remote_endpoint_ip > 0 then
        local _, err = verify.parse_ip(raw_body.remote_endpoint_ip)
        if err == nil then
          body.remote_endpoint_ip = raw_body.remote_endpoint_ip
        else
          error({
            code = 400,
            message = 'Invalid field remote_endpoint_ip',
          })
        end
      else
        body.remote_endpoint_ip = raw_body.remote_endpoint_ip
      end
    else
      --- TODO: verify IPv6
      body.local_endpoint_ip = raw_body.local_endpoint_ip
      body.remote_endpoint_ip = raw_body.remote_endpoint_ip
    end
  else
    error({
      code = 400,
      message = 'Invalid field ip_address_type',
    })
  end
  if util.includes(util.keys(ENCRYPTION_ALGORITHM), raw_body.encryption_algorithm) then
    body.encryption_algorithm = raw_body.encryption_algorithm
  else
    error({
      code = 400,
      message = 'Invalid field encryption_algorithm',
    })
  end
  if verify.isBoolean(raw_body.push_route_option) then
    body.push_route_option = raw_body.push_route_option
  else
    error({
      code = 400,
      message = 'Invalid field push_route_option',
    })
  end
  local netmask = raw_body.netmask
  if netmask == nil then
    body.netmask = ''
  else
    if verify.isString(netmask) then
      if #netmask > 0 then
        if verify.isValidIpv4SubnetMask(raw_body.netmask) then
          body.netmask = raw_body.netmask
        else
          error({
            code = 400,
            message = 'Invalid field netmask',
          })
        end
      else
        body.netmask = ''
      end
    else
      error({
        code = 400,
        message = 'Invalid field netmask',
      })
    end
  end
  if verify.isBoolean(raw_body.redirect_default_gateway) then
    body.redirect_default_gateway = raw_body.redirect_default_gateway
  else
    error({
      code = 400,
      message = 'Invalid field redirect_default_gateway',
    })
  end
  if verify.isBoolean(raw_body.lzo_compression) then
    body.lzo_compression = raw_body.lzo_compression
  else
    error({
      code = 400,
      message = 'Invalid field lzo_compression',
    })
  end
  if verify.isBoolean(raw_body.persist_key) then
    body.persist_key = raw_body.persist_key
  else
    error({
      code = 400,
      message = 'Invalid field persist_key',
    })
  end
  if verify.isBoolean(raw_body.persist_tun) then
    body.persist_tun = raw_body.persist_tun
  else
    error({
      code = 400,
      message = 'Invalid field persist_tun',
    })
  end
  if verify.isBoolean(raw_body.status) then
    body.status = raw_body.status
  else
    error({
      code = 400,
      message = 'Invalid field status',
    })
  end
  return body
end

function openvpn_ctrl.update_openvpn_status()
  local body = parse_update_openvpn_status_body(http:parse_body())
  local openvpn = query_openvpn()
  openvpn.enable = body.status
  openvpn.mode = MODE[body.mode]

  update_openvpn(openvpn)

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function openvpn_ctrl.add_openvpn_rule()
  local body = parse_openvpn_rule_body(http:parse_body())
  local openvpn = query_openvpn()

  table.insert(openvpn.rule, {
    openvpn_id = os.time(),
    protocol = body.protocol,
    port = body.port,
    tunnel_scenario = SCENARIO[body.tunnel_scenario],
    auth_type = AUTH_TYPE[body.authorization_type],
    static_key = body.static_key,
    ip_version = IP_ADDRESS_TYPE[body.ip_address_type],
    local_ip_addr = body.local_endpoint_ip,
    remote_ip_addr = body.remote_endpoint_ip,
    encryption_algorithm = ENCRYPTION_ALGORITHM[body.encryption_algorithm],
    push_route_option = body.push_route_option,
    remote_netmask = body.netmask,
    redirect_default_gateway = body.redirect_default_gateway,
    lzo_compression = body.lzo_compression,
    persist_key = body.persist_key,
    persist_tun = body.persist_key,
    enable = body.status,
  })
  update_openvpn(openvpn)

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function openvpn_ctrl.update_openvpn_rule()
  local body = parse_openvpn_rule_body(http:parse_body())
  local openvpn = query_openvpn()

  local found = util.find(openvpn.rule, function(row)
    return row.openvpn_id == body.rule_id
  end)
  if not found then
    error({
      code = 400,
      message = 'Not found rule',
    })
  end

  found.protocol = body.protocol
  found.port = body.port
  found.tunnel_scenario = SCENARIO[body.tunnel_scenario]
  found.auth_type = AUTH_TYPE[body.authorization_type]
  found.static_key = body.static_key
  found.ip_version = IP_ADDRESS_TYPE[body.ip_address_type]
  found.local_ip_addr = body.local_endpoint_ip
  found.remote_ip_addr = body.remote_endpoint_ip
  found.encryption_algorithm = ENCRYPTION_ALGORITHM[body.encryption_algorithm]
  found.push_route_option = body.push_route_option
  found.remote_netmask = body.netmask
  found.redirect_default_gateway = body.redirect_default_gateway
  found.lzo_compression = body.lzo_compression
  found.persist_key = body.persist_key
  found.persist_tun = body.persist_key
  found.enable = body.status

  update_openvpn(openvpn)
  http:status(200):json({
    result = 'SUCCESS',
  })
end

function openvpn_ctrl.delete_openvpn_rule(env)
  local rule_id = http.parse_query(env).rule_id
  local openvpn = query_openvpn()
  local rule = util.filter(openvpn.rule, function(rule)
    return rule.openvpn_id ~= rule_id
  end)
  openvpn.rule = rule
  update_openvpn(openvpn)

  http:status(200):json({
      result = 'SUCCESS',
  })
end

return openvpn_ctrl
