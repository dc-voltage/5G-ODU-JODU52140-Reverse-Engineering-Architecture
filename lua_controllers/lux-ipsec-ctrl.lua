local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local ipsec_ctrl = {}

local ENCAPSULATION_MODE = {
  TUNNEL = 'Tunnel',
  TRANSPORT = 'Transport',
}

local ENCRYPTION_ALGORITHM = {
  AES128_SHA256_DH14 = 'AES128-SHA256-DH14',
  AES256_SHA256_DH14 = 'AES256-SHA256-DH14',
  AES256_SHA512_DH14 = 'AES256-SHA512-DH14',
  AES128_SHA256_DH15 = 'AES128-SHA256-DH15',
}

local IKE_VERSIONS = {
  VERSION_1 = 'Version 1',
  VERSION_2 = 'Version 2',
}

local IP_ADDRESS_TYPE = {
  IPV4 = 'IPv4',
  IPV6 = 'IPv6',
}

local function query_ipsec()
  local ipsec = ubus.connect():call('luxslam', 'ipsec', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  if ipsec.err_code ~= nil then
    error({
      code = 500,
      message = string.format('IPSec error: %d', ipsec.err_code),
    })
  end
  return ipsec
end

local function update_ipsec(paramtable)
  local ipsec = ubus.connect():call('luxslam', 'ipsec', {
    cmd = 'set',
    class = 'general',
    paramtable = paramtable,
  }).paramtable
  if ipsec.err_code ~= nil then
    error({
      code = 500,
      message = string.format('IPSec Update error: %d', ipsec.err_code),
    })
  end
  return ipsec
end

function ipsec_ctrl.get_info()
  local ipsec = query_ipsec()
  local ipsec_rules = util.map(ipsec.rule, function(rule)
    return {
      connection_name = rule.connection_name,
      encapsulation_mode = rule.encapsulation_mode:upper(),
      ip_address_type = rule.address_type:upper(),
      remote_endpoint_ip = rule.remote_ip_addr,
      remote_endpoint_subnet_mask = rule.remote_subnet_mask,
      ipv6_prefix = rule.ipv6_prefix,
      authentication_method = rule.authentication_method,
      psk = rule.psk,
      keep_alive = util.to_boolean(rule.keep_alive),
      keep_alive_interval = rule.keep_alive_interval,
      ike_version = util.invert(IKE_VERSIONS)[rule.ike_version],
      encryption_algorithm = util.invert(ENCRYPTION_ALGORITHM)[rule.encryption_algorithm],
      key_lifetime = rule.key_lifetime,
      status = util.to_boolean(rule.conn_status),
    }
  end)

  http:status(200):json({
    status = util.to_boolean(ipsec.enable),
    ipsec_rules = ipsec_rules,
  })
end

function ipsec_ctrl._parse_update_ipsec_status_body(raw_body)
  local body = {}
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

function ipsec_ctrl._parse_ipsec_rule_body(raw_body)
  local body = {}
  body.old_connection_name = raw_body.old_connection_name
  if verify.isString(raw_body.connection_name) and #raw_body.connection_name > 0 then
    body.connection_name = raw_body.connection_name
  else
    error({
      code = 400,
      message = 'Invalid field connection_name',
    })
  end
  if util.includes(util.keys(ENCAPSULATION_MODE), raw_body.encapsulation_mode) then
    body.encapsulation_mode = raw_body.encapsulation_mode
  else
    error({
      code = 400,
      message = 'Invalid field encapsulation_mode',
    })
  end
  if util.includes(util.keys(IP_ADDRESS_TYPE), raw_body.ip_address_type) then
    body.ip_address_type = raw_body.ip_address_type
    if raw_body.ip_address_type == 'IPV4' then
      local _, err = verify.parse_ip(raw_body.remote_endpoint_ip)
      if err == nil then
        body.remote_endpoint_ip = raw_body.remote_endpoint_ip
      else
        error({
          code = 400,
          message = 'Invalid field remote_endpoint_ip',
        })
      end
      if verify.isValidIpv4SubnetMask(raw_body.remote_endpoint_subnet_mask) then
        body.remote_endpoint_subnet_mask = raw_body.remote_endpoint_subnet_mask
        body.ipv6_prefix = ""
      else
        error({
        code = 400,
        message = 'Invalid field remote_endpoint_subnet_mask',
        })
      end
    else
      --- TODO: verify IPv6
      body.remote_endpoint_ip = raw_body.remote_endpoint_ip
      local ipv6_prefix = tonumber(raw_body.ipv6_prefix)
      if verify.isInteger(ipv6_prefix) and (ipv6_prefix >= 1 and ipv6_prefix <= 128) then
        body.ipv6_prefix = ipv6_prefix
        body.remote_endpoint_subnet_mask = ""
      else
        error({
          code = 400,
          message = 'Invalid field ipv6_prefix',
        })
      end
    end
  else
    error({
      code = 400,
      message = 'Invalid field ip_address_type',
    })
  end
  local auth_method_index = verify.indexOf({'PSK', 'TLS'}, raw_body.authentication_method)
  if auth_method_index > 0 then
    body.authentication_method = raw_body.authentication_method
    if auth_method_index == 1 then
      if verify.isString(raw_body.psk) and #raw_body.psk > 0 then
        body.psk = raw_body.psk
      else
        error({
          code = 400,
          message = 'Invalid field psk',
        })
      end
    else
      body.psk = ""
    end
  else
    error({
      code = 400,
      message = 'Invalid field authentication_method',
    })
  end
  if verify.isBoolean(raw_body.keep_alive) then
    body.keep_alive = raw_body.keep_alive
    if (body.keep_alive) then
      local keep_alive_interval = tonumber(raw_body.keep_alive_interval)
      if verify.isInteger(keep_alive_interval) and (keep_alive_interval >= 0 and keep_alive_interval <= 256) then
        body.keep_alive_interval = keep_alive_interval
      else
        error({
          code = 400,
          message = 'Invalid field keep_alive_interval',
        })
      end
    end
  else
    error({
      code = 400,
      message = 'Invalid field keep_alive',
    })
  end
  if util.includes(util.keys(IKE_VERSIONS), raw_body.ike_version) then
    body.ike_version = raw_body.ike_version
  else
    error({
      code = 400,
      message = 'Invalid field ike_version',
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
  local key_lifetime = tonumber(raw_body.key_lifetime)
  if verify.isInteger(key_lifetime) and (key_lifetime >= 30 and key_lifetime <= 86400) then
    body.key_lifetime = key_lifetime
  else
    error({
      code = 400,
      message = 'Invalid field key_lifetime',
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

function ipsec_ctrl.update_ipsec_status()
  local body = http:parse_body()
  if not verify.isBoolean(body.status) then
    error({
      code = '400',
      message = 'Invalid status',
    })
  end

  update_ipsec({
    enable = body.status
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function ipsec_ctrl.add_ipsec_rule()
  local body = ipsec_ctrl._parse_ipsec_rule_body(http:parse_body())
  local ipsec = query_ipsec()

  local exists = util.find(ipsec.rule, function(row)
    return row.connection_name == body.connection_name
  end)
  if exists then
    error({
      code = 429,
      message = 'FILE EXIST',
    })
  end

  table.insert(ipsec.rule, {
    connection_name = body.connection_name,
    encapsulation_mode = ENCAPSULATION_MODE[body.encapsulation_mode],
    address_type = IP_ADDRESS_TYPE[body.ip_address_type],
    remote_ip_addr = body.remote_endpoint_ip,
    remote_subnet_mask = body.remote_endpoint_subnet_mask,
    ipv6_prefix = body.ipv6_prefix,
    authentication_method = body.authentication_method,
    psk = body.psk,
    keep_alive = body.keep_alive,
    keep_alive_interval = body.keep_alive_interval,
    ike_version = IKE_VERSIONS[body.ike_version],
    encryption_algorithm = ENCRYPTION_ALGORITHM[body.encryption_algorithm],
    key_lifetime = body.key_lifetime,
    conn_status = body.status,
  })

  update_ipsec({
    rule = ipsec.rule
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function ipsec_ctrl.update_ipsec_rule()
  local body = ipsec_ctrl._parse_ipsec_rule_body(http:parse_body())
  local ipsec = query_ipsec()

  local found = util.find(ipsec.rule, function(row)
    return row.connection_name == body.old_connection_name
  end)
  if not found then
    error({
      code = 400,
      message = 'Not found rule',
    })
  end

  local rule = util.map(ipsec.rule, function(row)
    if row.connection_name == body.old_connection_name then
      row.connection_name = body.connection_name
      row.encapsulation_mode = ENCAPSULATION_MODE[body.encapsulation_mode]
      row.address_type = IP_ADDRESS_TYPE[body.ip_address_type]
      row.remote_ip_addr = body.remote_endpoint_ip
      row.remote_subnet_mask = body.remote_endpoint_subnet_mask
      row.ipv6_prefix = body.ipv6_prefix
      row.authentication_method = body.authentication_method
      row.psk = body.psk
      row.keep_alive = body.keep_alive
      row.keep_alive_interval = body.keep_alive_interval
      row.ike_version = IKE_VERSIONS[body.ike_version]
      row.encryption_algorithm = ENCRYPTION_ALGORITHM[body.encryption_algorithm]
      row.key_lifetime = body.key_lifetime
      row.conn_status = body.status
    end
    return row
  end)

  update_ipsec({
    rule = rule
  })

  http:status(200):json({
    result = 'SUCCESS'
  })
end

function ipsec_ctrl.delete_ipsec_rule(env)
  local query = http.parse_query(env)
  local ipsec = query_ipsec()

  local rule = util.filter(ipsec.rule, function(row)
    return row.connection_name ~= query.connection_name
  end)

  update_ipsec({
    rule = rule
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

return ipsec_ctrl
