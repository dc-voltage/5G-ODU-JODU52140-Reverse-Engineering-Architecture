local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local ubus = require('lux-ubus')
local mac_address_ctrl = {}

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

local function query_mac_address_filter()
  local result = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'get',
    class = 'mac_filter',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('MAC Address Filter error: %d', result.err_code),
    })
  end
  return result
end

local function update_mac_address_filter(paramtable)
  verify_lan_mode()
  local result = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'set',
    class = 'mac_filter',
    paramtable = paramtable,
  }).paramtable

  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('MAC Address Filter update error: %d', result.err_code),
    })
  end
end

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

function mac_address_ctrl.get_available_mac_address_filter()
  verify_lan_mode()
  local dhcpv4 = query_dhcpv4()
  local dhcpv6 = query_dhcpv6()

  local ipv4_lease_resrv_list = util.map(dhcpv4.static_lease, function(row)
    return {
      device_name = row.device_name,
      mac_address = row.mac_addr,
      status = row.status,
    }
  end)
  local ipv6_lease_resrv_list = util.map(dhcpv6.static_lease, function(row)
    return {
      device_name = row.device_name,
      mac_address = row.mac_addr,
      status = row.status == 'Connected',
    }
  end)
  
  local all_list = {}
  local hash = {}
  local output = {}
  
  all_list = ipv4_lease_resrv_list
  for _, row in ipairs(ipv6_lease_resrv_list) do
    table.insert(all_list, row)
  end
  for index, row in ipairs(all_list) do
    if (not hash[row.mac_address]) then
        output[#output+1] = row
        hash[row.mac_address] = true
    end
  end

  http:status(200):json({
    entries = output
  })
end

function mac_address_ctrl.get_info()
  verify_lan_mode()
  local mac_filter = query_mac_address_filter()

  local entries = util.map(mac_filter.filter_list, function(row)
    return {
      mac_address = row.address,
      device_name = row.dev_name,
      mode = util.invert(MODE_STATUS)[row.mode],
    }
  end)

  http:status(200):json({
    mode = util.invert(MODE_STATUS)[mac_filter.mode],
    status = util.to_boolean(mac_filter.enable),
    entries = entries
  })
end

function mac_address_ctrl.update_info()
  verify_lan_mode()
  local body = http.parse_body()
  local mac_address = query_mac_address_filter()

  if not verify.isBoolean(body.status) then
    error({
      code = 400,
      message = 'Invalid field enable',
    })
  end

  update_mac_address_filter({
    mode = MODE_STATUS[body.mode],
    enable = body.status,
    filter_list = mac_address.filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function mac_address_ctrl.create_entry()
  verify_lan_mode()
  local body = http.parse_body()
  local mac_filter = query_mac_address_filter()

  local exists = util.find(mac_filter.filter_list, function(row)
    return row.address == body.mac_address
  end)
  if exists ~= nil then
    error({
      code = 400,
      message = 'FILE EXIST',
    })
  end

  if body.mac_address and not verify.isMacAddress(body.mac_address) then
    error({
      code = 400,
      message = "Invalid mac value",
    })
  end

  table.insert(mac_filter.filter_list, {
    address = body.mac_address,
    dev_name = body.device_name,
    mode = MODE_STATUS[body.mode],
  })

  update_mac_address_filter({
    mode = mac_filter.mode,
    enable = mac_filter.enable,
    filter_list = mac_filter.filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function mac_address_ctrl.delete_mac_address_filter(env)
  verify_lan_mode()
  local query =  http.parse_query(env)
  local mac_filter = query_mac_address_filter()

  local filter_list = util.filter(mac_filter.filter_list, function(row)
    return row.address ~= query.mac_address
  end)

  update_mac_address_filter({
    mode = mac_filter.mode,
    enable = mac_filter.enable,
    filter_list = filter_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

return mac_address_ctrl
