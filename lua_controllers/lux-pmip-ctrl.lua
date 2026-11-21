local ubus = require('lux-ubus')
local http = require('lux-http')
local verify = require('lux-verify')
local pmip_ctrl = {}

function pmip_ctrl.get_pmipv6()
  local conn = ubus.connect()
  local general = conn:call('luxslam', 'pmip', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  if general.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP general error: %d', general.err_code),
    })
  end

  local dhcpv4 = conn:call('luxslam', 'pmip', {
    cmd = 'get',
    class = 'dhcpv4',
  }).paramtable
  if dhcpv4.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP DHCPv4 error: %d', dhcpv4.err_code),
    })
  end

  local gre_key = conn:call('luxslam', 'pmip', {
    cmd = 'get',
    class = 'gre_key',
  }).paramtable
  if gre_key.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP GRE Key error: %d', gre_key.err_code),
    })
  end

  local ipv4 = conn:call('luxslam', 'pmip', {
    cmd = 'get',
    class = 'ipv4',
  }).paramtable
  if ipv4.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP IPv4 error: %d', ipv4.err_code),
    })
  end

  local ipv6 = conn:call('luxslam', 'pmip', {
    cmd = 'get',
    class = 'ipv6',
  }).paramtable
  if ipv6.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP IPv6 error: %d', ipv6.err_code),
    })
  end

  http:status(200):json({
    pmip_enabled = general.enabled,
    dhcp_server_enabled = dhcpv4.enable,
    subnet_mask = dhcpv4.netmask,
    starting_ip_address = dhcpv4.start_addr,
    primary_dns = dhcpv4.dnslist,
    ending_ip_address = dhcpv4.end_addr,
    tunnel_end_point_ipv4_address = ipv4.ip_addr,
    tunnel_end_point_port = ipv4.port,
    tunnel_end_point_ipv6_address = ipv6.ip_addr,
    apn_configured = ipv6.apn,
    tunnel_end_point_port_v6 = ipv6.tunnel_port,
    dmnp_prefix = ipv6.dmnp_prefix,
    mobile_mode_id = ipv6.imsi,
    dmnp_prefix_length = ipv6.dmnp_prefix_length,
    gre_key_enabled = gre_key.status,
    gre_key = gre_key.key,
  })
end

local function parse_set_pmipv6_body()
  local body = http.parse_body()
  if type(body.pmip_enabled) ~= 'boolean' then
    error({
      code = 400,
      message = "Invalid pmip_enabled",
    })
  end
  if type(body.dhcp_server_enabled) ~= 'boolean' then
    error({
      code = 400,
      message = "Invalid dhcp_server_enabled",
    })
  end
  if type(body.gre_key_enabled) ~= 'boolean' then
    error({
      code = 400,
      message = "Invalid gre_key_enabled",
    })
  end
  local _, err = verify.parse_ip(body.subnet_mask)
  if err ~= nil then
    error({
      code = 400,
      message = "Invalid subnet_mask",
    })
  end
  _, err = verify.parse_ip(body.primary_dns)
  if err ~= nil then
    error({
      code = 400,
      message = "Invalid primary_dns",
    })
  end
  _, err = verify.parse_ip(body.tunnel_end_point_ipv4_address)
  if err ~= nil then
    error({
      code = 400,
      message = "Invalid tunnel_end_point_ipv4_address",
    })
  end
  local start_ip, end_ip
  start_ip, err = verify.parse_ip(body.starting_ip_address)
  if err ~= nil then
    error({
      code = 400,
      message = "Invalid starting_ip_address",
    })
  end
  end_ip, err = verify.parse_ip(body.ending_ip_address)
  if err ~= nil then
    error({
      code = 400,
      message = "Invalid ending_ip_address",
    })
  end
  for i, sub_ip in ipairs(start_ip) do
    if end_ip[i] < sub_ip then
      error({
        code = 400,
        message = "Invalid dhcp range",
      })
    end
  end
  return body
end

function pmip_ctrl.set_pmipv6()
  local body = parse_set_pmipv6_body()
  local conn = ubus.connect()
  local general = conn:call('luxslam', 'pmip', {
    cmd = 'set',
    class = 'general',
    paramtable = {
      enabled = body.pmip_enabled,
    },
  }).paramtable
  if general.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP general error: %d', general.err_code),
    })
  end

  local dhcpv4 = conn:call('luxslam', 'pmip', {
    cmd = 'set',
    class = 'dhcpv4',
    paramtable = {
      enable = body.dhcp_server_enabled,
      netmask = body.subnet_mask,
      start_addr = body.starting_ip_address,
      dnslist = body.primary_dns,
    },
  }).paramtable
  if dhcpv4.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP DHCPv4 error: %d', dhcpv4.err_code),
    })
  end

  local gre_key = conn:call('luxslam', 'pmip', {
    cmd = 'set',
    class = 'gre_key',
    paramtable = {
      status = body.gre_key_enabled,
      key = body.gre_key,
    },
  }).paramtable
  if gre_key.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP GRE Key error: %d', gre_key.err_code),
    })
  end

  local ipv4 = conn:call('luxslam', 'pmip', {
    cmd = 'set',
    class = 'ipv4',
    paramtable = {
      ip_addr = body.tunnel_end_point_ipv4_address,
      port = body.tunnel_end_point_port,
    },
  }).paramtable
  if ipv4.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP IPv4 error: %d', ipv4.err_code),
    })
  end

  local ipv6 = conn:call('luxslam', 'pmip', {
    cmd = 'set',
    class = 'ipv6',
    paramtable = {
      ip_addr = body.tunnel_end_point_ipv6_address,
      apn = body.apn_configured,
      tunnel_port = body.tunnel_end_point_port_v6,
      dmnp_prefix = body.dmnp_prefix,
      imsi = body.mobile_mode_id,
      dmnp_prefix_length = body.dmnp_prefix_length,
    },
  }).paramtable
  if ipv6.err_code ~= nil then
    error({
      code = 500,
      message = string.format('PMIP IPv6 error: %d', ipv6.err_code),
    })
  end
  http:status(200):json({
    result = 'SUCCESS',
  })
end

return pmip_ctrl
