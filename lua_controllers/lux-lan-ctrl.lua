local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local lan_ctrl = {}

local DHCPV6_MODE = {
  STATELESS = 'Stateless',
  STATEFUL = 'Stateful',
}

local DHCPV6_DNS_MODE = {
  PROXY_DNS = 'Proxy DNS',
  DNS_FROM_ISP = 'DNS From ISP',
  CUSTOM_DNS = 'Custom DNS',
}

local DHCPV6_STATIC_LEASE_STATUS = {
  CONNECTED = 'Connected',
  DISCONNECTED = 'Disconnected',
}

local GENERAL_MODE = {
  ROUTER = 'Router',
  BRIDGE = 'Bridge',
  EOGRE = 'EoGRE',
}

local MAC_ADDRESS_TYPE = {
  AUTO = 0,
  NEW = 1,
}

local ETHERNET_DUPLEX_MODE = {
  FULL = 'Full',
  HALF = 'Half',
}

local ETHERNET_LINK_RATE = {
  ['10MBPS'] = '10Mbps',
  ['100MBPS'] = '100Mbps',
  ['1GBPS'] = '1Gbps',
  ['2.5GBPS'] = '2.5Gbps',
  ['10GBPS'] = '10Gbps',
}

local ETHERNET_STATUS = {
  UP = 'Up',
  DOWN = 'Down',
}

local function query_dhcpv4()
  local result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'dhcpv4',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('DHCPv4 error: %d', result.err_code),
    })
  end
  return result
end

local function query_dhcpv6()
  local result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'dhcpv6',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('DHCPv6 error: %d', result.err_code),
    })
  end
  return result
end

local function query_ethernet()
  local result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'ethernet',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Ethernet error: %d', result.err_code),
    })
  end
  return result
end

local function query_lan_general()
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
  return result
end

local function query_sys_general()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('General error: %d', result.err_code),
    })
  end
  return result
end

local function query_ipv4()
  local result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'ipv4',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('IPv4 error: %d', result.err_code),
    })
  end
  return result
end

local function query_ipv6()
  local result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'ipv6',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('IPv6 error: %d', result.err_code),
    })
  end
  return result
end

function lan_ctrl.get_ethernet_status()
  local ethernet = query_ethernet()
  http:status(200):json({
    linkStatus = util.invert(ETHERNET_STATUS)[ethernet.status]:lower(),
    speed = util.invert(ETHERNET_LINK_RATE)[ethernet.link_rate]:lower(),
    duplex = util.invert(ETHERNET_DUPLEX_MODE)[ethernet.duplex_mode]:lower(),
  })
end

function lan_ctrl.web_trigger_cdt()
  if app_cdt_can_execute() then
    local trigger_res = ubus.connect():call('luxslam', 'lan', {
      cmd = 'set',
      class = 'cdt',
      paramtable = {
        trigger = 1
      },
    }).paramtable
    if trigger_res.err_code ~= nil then
      error({
        code = 500,
        message = string.format('cdt error: %d', trigger_res.err_code),
      })
    end

    util.sleep(15)

    local info_res = ubus.connect():call('luxslam', 'lan', {
      cmd = 'get',
      class = 'cdt',
    }).paramtable
    if info_res.err_code == nil then
    	  -- DC API 4.21: JDC_CB_EVENT_VCT_STATUS OnDemand-BT start
    	  local ABSL_VCT_STATUS_BT_INOTIFY = '/tmp/events_cb/vct_status_bt'
    	  util.safe_execute("echo '' > " .. ABSL_VCT_STATUS_BT_INOTIFY)
    	  -- DC API 4.21: JDC_CB_EVENT_VCT_STATUS OnDemand-BT end
        http:status(200):json({
          link_speed = info_res.link_speed,
          cdt_pairs = info_res.cdt_pairs
        })
    else
      error({
        code = 500,
        message = string.format('cdt error: %d', info_res.err_code),
      })
    end
  else
     error({
        code = 500,
        message = string.format('Unable to execute CDT'),
      })
  end
end

function lan_ctrl.web_get_cdt()
  local info_res = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'cdt',
  }).paramtable
  if info_res.err_code == nil then
    http:status(200):json({
      link_speed = info_res.link_speed,
      cdt_pairs = info_res.cdt_pairs
    })
  else
    error({
      code = 500,
      message = string.format('cdt error: %d', info_res.err_code),
    })
  end
end

function lan_ctrl.get_status()
  local ipv4_info = query_ipv4()
  local ipv6_info = query_ipv6()
  local lan_general = query_lan_general()
  local ethernet = query_ethernet()

  http:status(200):json({
    operation_mode = util.invert(GENERAL_MODE)[lan_general.mode],
    ethernet = {
      link_status = util.invert(ETHERNET_STATUS)[ethernet.status],
      speed = util.invert(ETHERNET_LINK_RATE)[ethernet.link_rate],
      duplex_mode = util.invert(ETHERNET_DUPLEX_MODE)[ethernet.duplex_mode],
    },
    ipv4 = {
      host_ip_v4 = ipv4_info.ip_addr,
      dhcp_mode = ipv4_info.address_assignment,
      subnet_mask = ipv4_info.netmask,
      gw_ip = ipv4_info.default_gateway,
    },
    ipv6 = {
      host_ip_v6 = ipv6_info.ip_addr,
      dhcp_mode = ipv6_info.address_assignment,
      prefix_length = ipv6_info.prefix_length,
      gw_ip = ipv6_info.default_gateway,
    },
  })
end

function lan_ctrl.get_mode()
  local sys_general = query_sys_general()
  local lan_general = query_lan_general()
  local network_info = query_ipv4()

  http:status(200):json({
    host_ip_name = sys_general.host_name,
    operation_mode = util.invert(GENERAL_MODE)[lan_general.mode],
    mac_address_type = util.invert(MAC_ADDRESS_TYPE)[lan_general.manual_mac_addr],
    mac_address = lan_general.mac_addr,
    mtu = tonumber(network_info.mtu),
  })
end

function lan_ctrl.update_mode()
  local body = http.parse_body()
  local mtu = tonumber(body.mtu)
  if not (verify.isInteger(mtu) and mtu >= 1280 and mtu <= 1500) then
   error({
     code = 400,
     message = "Invalid MTU"
   })
  end

  local ipv4_result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'set',
    class = 'ipv4',
    paramtable = {
      mtu = mtu,
    },
  }, { return_error = true })
  if ipv4_result.paramtable.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Update MTU error: %d', ipv4_result.paramtable.err_code),
    })
  end

  local type = MAC_ADDRESS_TYPE[body.mac_address_type]
  local paramtable = {
    mode = GENERAL_MODE[body.operation_mode],
    manual_mac_addr = type,
  }

  if type ~= 0 then
    paramtable.mac_addr = body.mac_address
  end

  local lan_general = query_lan_general()
  local current_mode = lan_general.mode

  local mode_result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'set',
    class = 'general',
    paramtable = paramtable,
  }, { return_error = true })

  if mode_result.paramtable.err_code ~= nil then
    if mode_result.paramtable.err_code == "1001" then
      error({
        code = 500,
        message = "Update mac address error, Unable to set value",
      })
    else
      error({
        code = 500,
        message = string.format('Update LAN error: %d', mode_result.paramtable.err_code),
      })
    end
  end

  if ((current_mode == GENERAL_MODE['ROUTER'] and paramtable.mode == GENERAL_MODE['BRIDGE']) or
      (current_mode == GENERAL_MODE['BRIDGE'] and paramtable.mode == GENERAL_MODE['ROUTER'])) then
    -- EoGRE <-> Bridge/Router: Device will reboot => The IP/MAC/URL filter settings will be applied by 040-luxslam-apply-settings.sh script.
    -- Bridge <-> Router: Device will NOT reboot => It's need to clear or reconfigure IP/MAC/URL filter settings manually.
    util.safe_execute("ubus call luxslam firewall \"{'cmd':'set', 'class':'ip_filter', 'paramtable': {} }\"")
    util.safe_execute("ubus call luxslam firewall \"{'cmd':'set', 'class':'mac_filter', 'paramtable': {} }\"")
    util.safe_execute("ubus call luxslam firewall \"{'cmd':'set', 'class':'url_filter', 'paramtable': {} }\"")
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function lan_ctrl.get_ipv4()
  local network_info = query_ipv4()
  local dhcp_info = query_dhcpv4()

  local static_address_list = util.map(dhcp_info.static_address, function(row)
    return {
      name = row.device_name,
      ip = row.ip_addr,
      mac = row.mac_addr,
    }
  end)
  local lease_resrv_list = util.map(dhcp_info.static_lease, function(row)
    return {
      name = row.device_name,
      ip = row.ip_addr,
      mac = row.mac_addr,
      status = util.to_boolean(row.status),
    }
  end)
  local dns_list = util.split(dhcp_info.dnslist, ',')
  if (network_info ~= nil) then
    http:status(200):json({
      host_ip_v4_type = '',
      host_ip_v4 = network_info.ip_addr,
      subnet_mask = network_info.netmask,
      dhcp_enable = util.to_boolean(dhcp_info.enable),
      dhcp_start_ip = dhcp_info.start_addr,
      dhcp_end_ip = dhcp_info.end_addr,
      primary_dns = dns_list[1],
      secondary_dns = dns_list[2],
      dhcp_lease_time = tonumber(dhcp_info.lease_time),
      static_address_list = static_address_list,
      lease_resrv_list = lease_resrv_list,
    })
  else
    error({
      code = 500,
      message = 'Unknown method',
    })
  end
end

local function update_dhcpv4(paramtable)
  local result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'set',
    class = 'dhcpv4',
    paramtable = paramtable,
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Update DHCPv4 error: %d', result.err_code),
    })
  end
end

local function parse_update_ipv4_body()
  local body = http.parse_body()
  if body.host_ip_v4 ~= nil and not verify.isIPv4(body.host_ip_v4) then
    error({
      code = 400,
      message = "Invalid ipv4 value",
    })
  end

  if body.subnet_mask ~= nil and not verify.isIPv4(body.subnet_mask) then
    error({
      code = 400,
      message = "Invalid subnet mask value",
    })
  end

  if body.dhcp_start_ip ~= nil and not verify.isIPv4(body.dhcp_start_ip) then
    error({
      code = 400,
      message = "Invalid dhcp start ip value",
    })
  end

  if body.dhcp_end_ip ~= nil and not verify.isIPv4(body.dhcp_end_ip) then
    error({
      code = 400,
      message = "Invalid dhcp end ip value",
    })
  end

  if body.primary_dns ~= nil and not verify.isIPv4(body.primary_dns) then
    error({
      code = 400,
      message = "Invalid primary dns value",
    })
  end

  if body.secondary_dns ~= nil and not verify.isIPv4(body.secondary_dns) then
    error({
      code = 400,
      message = "Invalid secondary dns value",
    })
  end

  if body.dhcp_lease_time ~= nil and not verify.isInteger(body.dhcp_lease_time) and body.dhcp_lease_time < 0 and body.dhcp_lease_time > 604800 then
    error({
      code = 400,
      message = "Invalid dhcp lease time value",
    })
  end

  if body.dhcp_enable ~= nil and not verify.isBoolean(body.dhcp_enable) then
    error({
      code = 400,
      message = "Invalid dhcp enable value",
    })
  end

  return body
end

function lan_ctrl.update_ipv4()
  local body = parse_update_ipv4_body()
  local ipv4_result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'set',
    class = 'ipv4',
    paramtable = {
      ip_addr = body.host_ip_v4,
      netmask = body.subnet_mask,
    },
  }).paramtable
  if ipv4_result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('IPv4 error: %d', ipv4_result.err_code),
    })
  end

  update_dhcpv4({
    enable = body.dhcp_enable,
    start_addr = body.dhcp_start_ip,
    end_addr = body.dhcp_end_ip,
    dnslist = util.join({body.primary_dns, body.secondary_dns}),
    lease_time = tonumber(body.dhcp_lease_time)
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

local function parse_ipv4_static_address_body()
  local body = http.parse_body()

  if body.ip and not verify.isIPv4(body.ip) then
    error({
      code = 400,
      message = "Invalid ip value",
    })
  end

  if body.mac and not verify.isMacAddress(body.mac) then
    error({
      code = 400,
      message = "Invalid mac value",
    })
  end

  return body
end

function lan_ctrl.create_ipv4_static_address()
  local body = parse_ipv4_static_address_body()
  local dhcpv4 = query_dhcpv4()
  local exists = util.find(dhcpv4.static_address, function(row)
    return row.ip_addr == body.ip or row.mac_addr == body.mac
  end)
  if exists then
    error({
      code = 400,
      message = 'FILE EXIST',
    })
  end

  table.insert(dhcpv4.static_address, {
    device_name = body.name,
    ip_addr = body.ip,
    mac_addr = body.mac,
  })

  update_dhcpv4(dhcpv4)

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function lan_ctrl.update_ipv4_static_address()
  local body = parse_ipv4_static_address_body()
  local dhcpv4 = query_dhcpv4()
  local found = util.find(dhcpv4.static_address, function(row)
    return row.ip_addr == body.old_ip
  end)
  if not found then
    error({
      code = 400,
      message = 'Not found IP',
    })
  end
  local list_without_found = util.filter(dhcpv4.static_address, function(row)
    return row.ip_addr ~= body.old_ip
  end)
  local exists = util.find(list_without_found, function(row)
    return row.ip_addr == body.ip or row.mac_addr == body.mac
  end)
  if exists then
    error({
      code = 400,
      message = 'FILE EXIST',
    })
  end

  found.device_name = body.name
  found.ip_addr = body.ip
  found.mac_addr = body.mac

  update_dhcpv4(dhcpv4)

  http:status(200):json({
    result = 'SUCCESS',
  })
end

---@param env table
function lan_ctrl.delete_ipv4_static_address(env)
  local query = http.parse_query(env)
  local dhcpv4 = query_dhcpv4()

  local static_address = util.filter(dhcpv4.static_address, function(row)
    return row.ip_addr ~= query.ip
  end)
  dhcpv4.static_address = static_address

  update_dhcpv4(dhcpv4)

  http:status(200):json({
    result = 'SUCCESS',
  })
end

---@param env table
function lan_ctrl.delete_ipv4_lease_reservation(env)
  local query = http.parse_query(env)
  local dhcpv4 = query_dhcpv4()

  local static_lease = util.filter(dhcpv4.static_lease, function(row)
    return row.ip_addr ~= query.ip
  end)
  dhcpv4.static_lease = static_lease

  update_dhcpv4(dhcpv4)

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function lan_ctrl.get_ipv6()
  local network_info = query_ipv6()
  local dhcp_info = query_dhcpv6()
  local dns_list = util.split(dhcp_info.dnslist, ',')
  local lease_resrv_list = util.map(dhcp_info.static_lease, function(row)
    return {
      name = row.hostname,
      ip = row.ip_addr,
      mac = row.mac_addr,
      status = util.invert(DHCPV6_STATIC_LEASE_STATUS)[row.status],
    }
  end)

  http:status(200):json({
    gw_ip = network_info.ip_addr,
    ipv6_prefix_length = network_info.prefix_length,
    dhcpv6_server = util.invert(DHCPV6_MODE)[dhcp_info.mode],
    dhcp_lease_time = dhcp_info.lease_time,
    dhcp_server_preference = dhcp_info.preference,
    dns_mode = util.invert(DHCPV6_DNS_MODE)[dhcp_info.dns_mode],
    primary_dns = dns_list[1],
    secondary_dns = dns_list[2],
    prefix_delegation = util.to_boolean(dhcp_info.prefix_delegation),
    lease_resrv_list = lease_resrv_list,
  })
end

local function parse_update_ipv6_body()
  local body = http.parse_body()
  if body.dns_mode ~= nil and not util.includes(util.keys(DHCPV6_DNS_MODE), body.dns_mode) then
    error({
      code = 400,
      message = "Invalid dns mode",
    })
  end

  if body.dhcpv6_server ~= nil and not util.includes(util.keys(DHCPV6_MODE), body.dhcpv6_server) then
    error({
      code = 400,
      message = "Invalid dhcpv6 server value",
    })
  end

  if body.primary_dns ~= nil and body.primary_dns and not verify.isIPv6(body.primary_dns) then
    error({
      code = 400,
      message = "Invalid primary dns value",
    })
  end

  if body.secondary_dns ~= nil and body.secondary_dns and not verify.isIPv6(body.secondary_dns) then
    error({
      code = 400,
      message = "Invalid secondary dns value",
    })
  end

  if body.dhcp_lease_time ~= nil and (not verify.isInteger(body.dhcp_lease_time) or body.dhcp_lease_time < 120 or body.dhcp_lease_time > 86400) then
    error({
      code = 400,
      message = "Invalid dhcp lease time value",
    })
  end

  if body.prefix_delegation ~= nil and not verify.isBoolean(body.prefix_delegation) then
    error({
      code = 400,
      message = "Invalid prefix delegation value",
    })
  end

  return body
end

function lan_ctrl.update_ipv6()
  local body = parse_update_ipv6_body()
  local dhcpv6 = query_dhcpv6()

  local dhcpv6_result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'set',
    class = 'dhcpv6',
    paramtable = {
      dns_mode = DHCPV6_DNS_MODE[body.dns_mode],
      mode = DHCPV6_MODE[body.dhcpv6_server],
      lease_time = body.dhcp_lease_time,
      dnslist = util.join({body.primary_dns, body.secondary_dns}),
      prefix_delegation = body.prefix_delegation,
      static_lease = dhcpv6.static_lease,
    },
  }).paramtable
  if dhcpv6_result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('DHCPv6 error: %d', dhcpv6_result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

---@param env table
function lan_ctrl.delete_ipv6_lease_reservation(env)
  local query = http.parse_query(env)
  local dhcpv6 = query_dhcpv6()

  local static_lease = util.filter(dhcpv6.static_lease, function(row)
    return row.ip_addr ~= query.ip
  end)
  dhcpv6.static_lease = static_lease

  local result = ubus.connect():call('luxslam', 'lan', {
    cmd = 'set',
    class = 'dhcpv6',
    paramtable = dhcpv6,
  }).paramtable;

  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Update DHCPv6 error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function lan_ctrl.trigger_cdt()
  ubus.connect():call('luxslam', 'lan', {
    cmd = 'set',
    class = 'cdt',
    paramtable = {
      trigger = 1,
    },
  })
  http:status(200):json({
    result = 'SUCCESS',
  })
end

function lan_ctrl.get_cdt()
  local cdt = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'cdt',
  }).paramtable;
  local cdt_pairs = util.map(cdt.cdt_pairs, function(row)
    return {
      pair = row.pair,
      length = tostring(row.length) .. 'm',
      status = row.status,
      distanceToFault = tostring(row.distanceToFault) .. 'm',
    }
  end)
  http:status(200):json({
    linkSpeed = tostring(cdt.link_speed) .. 'Mbps',
    cdt_pairs = cdt_pairs,
  })
end


function app_cdt_can_execute()
  local last_call_file = "/tmp/app_last_cdt_call.log"
  local last_call_time = 0

  local file = io.open(last_call_file, "r")
  if file then
      last_call_time = tonumber(file:read("*a") or 0)
      file:close()
  end

  if last_call_time == 0 then
      file = io.open(last_call_file, "w")
      if file then
          last_call_time = os.time()
          file:write(tostring(last_call_time))
          file:close()
          return true
      else
          return false
      end
  end

  local current_time = os.time()

  if current_time - last_call_time < 60 then
      return false
  end

  file = io.open(last_call_file, "w")
  if file then
      file:write(tostring(current_time))
      file:close()
  end

  return true
end

function lan_ctrl.app_get_cdt()
  if app_cdt_can_execute() then
    ubus.connect():call('luxslam', 'lan', {
      cmd = 'set',
      class = 'cdt',
      paramtable = {
        trigger = 1,
      },
    })

    util.sleep(15)

    local cdt = ubus.connect():call('luxslam', 'lan', {
      cmd = 'get',
      class = 'cdt',
    }).paramtable;
    if cdt.err_code == nil then
	  -- DC API 4.21: JDC_CB_EVENT_VCT_STATUS OnDemand-BT start
	  local ABSL_VCT_STATUS_BT_INOTIFY = '/tmp/events_cb/vct_status_bt'
	  util.safe_execute("echo '' > " .. ABSL_VCT_STATUS_BT_INOTIFY)
	  -- DC API 4.21: JDC_CB_EVENT_VCT_STATUS OnDemand-BT end
      local rtn = {
        result = true,
        Link_Speed = cdt.link_speed,
      }
      
      for pair_index, row in ipairs(cdt.cdt_pairs) do
          rtn["Pair_" .. pair_index .. "_distance_to_fault"] = row.distanceToFault
          rtn["Pair_" .. pair_index .. "_length"] = row.length
          rtn["Pair_" .. pair_index .. "_pair"] =  tostring(row.pair)
          rtn["Pair_" .. pair_index .. "_status"] =  tostring(row.status)
      end
      http:status(200):json(rtn)
    else
      error({
        type = 'app',
        code = 500,
        app_msg_id = '32',
      })
    end
  else
    error({
      type = 'app',
      code = 500,
      app_msg_id = '32',
    })
  end
end

return lan_ctrl
