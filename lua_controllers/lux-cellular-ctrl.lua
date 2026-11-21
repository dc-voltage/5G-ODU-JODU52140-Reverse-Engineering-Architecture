local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local device_ctrl = require('lux-device-ctrl')
local verify = require('lux-verify')
local cellular_ctrl = {}

local function getOperatingBand(cell)
  if cell.lte_band ~= "" then
    return cell.lte_band
  elseif cell.nr5g_nsa ~= "" then
    return cell.nr5g_nsa
  elseif cell.nr5g ~= "" then
    return cell.nr5g
  else
    return ""
  end
end

---@param no_filter boolean | nil
local function query_serving_cell(no_filter)
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'serving_cell',
  }, { return_error = true })

  if result == nil or result.paramtable.err_code ~= nil then
    return {}
  end
  if (no_filter == nil or not no_filter) and util.includes({"SEARCH", "LIMSRV"}, result.paramtable.camp_state) then
    return {}
  end

  return result.paramtable
end

local function query_secondary_cell()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'secondary_cell',
  }, { return_error = true })

  if result == nil or result.paramtable.err_code ~= nil then
    return {}
  end

  return result.paramtable
end

local function query_neighbor_cell()
 local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'neighbor_cell',
  }, { return_error = true })

  if result == nil or result.paramtable.err_code ~= nil then
    return {}
  end
  return result.paramtable.filter_list or {}
end

local SIM_STATUS = {
  Attached = 'Working',
  ['No SIM'] = 'NoSim',
  ['PIN Lock'] = 'Locked',
  ['PIN Block'] = 'Blocked',
  Detached = 'Not Provisioned',
  ['Invalid SIM'] = 'Invalid',
}

local function query_sim()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'sim',
  }, { return_error = true })

  if result == nil or result.paramtable.err_code ~= nil then
    return {}
  end

  result.paramtable.sim_status = util.invert(SIM_STATUS)[result.paramtable.sim_status];
  return result.paramtable
end

local function query_sys_general()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'general',
  }, { return_error = true })

  if result == nil or result.paramtable.err_code ~= nil then
    return {}
  end

  return result.paramtable
end

function cellular_ctrl.get_network_info()
  local sim = query_sim()
  local serving_cell = query_serving_cell()
  local secondary_cell = {}
  if #util.keys(serving_cell) > 0 then
    secondary_cell = query_secondary_cell()
  end
  local sys_general = query_sys_general()
  local lux_flags = device_ctrl.query_lux_flags()
  local user_apn_list = serving_cell.user_apn_list
  if lux_flags == nil or lux_flags.LUX_5G_SMS ~= "y" then
    user_apn_list = util.join(util.filter(util.split(serving_cell.user_apn_list, ","), function(apn)
      return apn ~= "ims"
      end)
    , ",")
  end
  http:status(200):json({
    connection_status = sim.sim_status,
    connection_duration = sim.linkup_timestamp,
    hostname = sys_general.host_name,
    operator_name = sys_general.operator_name,
    signal_strength = serving_cell.signal_strength,
    operating_mode = serving_cell.status,
    operating_band = getOperatingBand(serving_cell),
    bandwidth = serving_cell.bandwidth,
    arfcn = serving_cell.nr_arfcn,
    pci = serving_cell.pci,
    plmn = serving_cell.plmn,
    default_apn = serving_cell.default_apn,
    user_apns = user_apn_list,
    global_cell_id = serving_cell.cell_id,
    ncgi = serving_cell.ncgi,
    rrc_state = serving_cell.rrc_state,
    bler = serving_cell.bler,
    modulation = serving_cell.modulation,
    mimo_mode = serving_cell.mimo,
    ss_rsrp = serving_cell.nr_rsrp,
    ss_rsrq = serving_cell.nr_rsrq,
    ss_sinr = serving_cell.nr_sinr,
    secondary_cell = {
      signal_strength = secondary_cell.signal_strength,
      operating_mode = secondary_cell.op_mode,
      operating_band = secondary_cell.band,
      bandwidth = secondary_cell.bandwidth,
      arfcn = secondary_cell.nr_arfcn,
      pci = secondary_cell.pci,
      plmn = secondary_cell.plmn,
      default_apn = secondary_cell.default_apn,
      user_apns = user_apn_list,
      ncgi = secondary_cell.ncgi,
      rrc_state = secondary_cell.rrc_state,
      bler = secondary_cell.bler,
      modulation = secondary_cell.modulation,
      mimo_mode = secondary_cell.mimo,
      ss_rsrp = secondary_cell.ss_rsrp,
      ss_rsrq = secondary_cell.ss_rsrq,
      ss_sinr = secondary_cell.ss_sinr,
    },
  })
end

function cellular_ctrl.get_neighbour_cell_cache()
  local neighbor_cell = {}

  -- If the user has not triggered neighbor web, the api will not be called and a null value will be returned directly.
  if util.fileExists("/var/run/neighbor_web_scan") then
    local result = ubus.connect():call('luxslam', '5g', {
      cmd = 'get',
      class = 'neighbor_cell',
      paramtable = {
        action = "cache",
      },
    }, { return_error = true })

    if result == nil or result.paramtable.err_code ~= nil then
      neighbor_cell = {}
    end
    neighbor_cell = result.paramtable.filter_list[1] or {}
  end

  http:status(200):json({
    neighbour_cell = {
      signal_strength = neighbor_cell.signal_strength,
      operating_mode = neighbor_cell.status,
      operating_band = getOperatingBand(neighbor_cell),
      bandwidth = neighbor_cell.bandwidth,
      arfcn = neighbor_cell.nr_arfcn,
      pci = neighbor_cell.pci,
      plmn = neighbor_cell.plmn,
      ncgi = neighbor_cell.ncgi,
      ss_rsrp = neighbor_cell.nr_rsrp,
      ss_rsrq = neighbor_cell.nr_rsrq,
    }
  })
end

function cellular_ctrl.get_neighbour_cell_info()
  -- step 1: trigger scan
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'neighbor_cell',
    paramtable = {
      action = "scan_web",
    },
  }, { return_error = true })

  if result.paramtable.err_code ~= nil then
    error({
      code = 500,
      message = string.format('neighbor cell scan error: %d', result.paramtable.err_code),
    })
  end

  -- step 2: get scan status 0:ready, 1:progress
  util.sleep(2)
  local times = 0
  local state = util.popen('cat /var/run/neighbor_state')
  while string.match(state, '1') and times < 30 do
    util.sleep(2)
    times = times + 1
    state = util.popen('cat /var/run/neighbor_state')
  end

  -- step 3: return cache data
  cellular_ctrl.get_neighbour_cell_cache()
end

-- Function to get expanded IPv6 address
local function get_expanded_ipv6_address(ipv6_address)
  local expanded_array = { '0', '0', '0', '0', '0', '0', '0', '0'}
  local ipv6_array = util.split(ipv6_address, ':')
  local padding_offset = 0

  for i = 1, #ipv6_array do
      if ipv6_array[i] == '' then
          padding_offset = i
          break
      end
      expanded_array[i] = ipv6_array[i]
  end

  if padding_offset ~= 0 then
      for i = 1, #ipv6_array - padding_offset - 1 do
          if ipv6_array[(#ipv6_array + 1) - i] ~= '' then
              expanded_array[(8 + 1) - i] = ipv6_array[(#ipv6_array + 1) - i]
          end
      end
  end

  return table.concat(expanded_array, ':')
end

-- Function to get minimized IPv6 address
local function get_minimized_ipv6_address(ipv6_address)
  local minimized_ipv6_address = ''
  local ipv6_array = util.split(ipv6_address, ':')
  local max_count = 0
  local tmp_count = 0
  local start_index = 0
  local tmp_start_index = 0
  local find_start_index = false

  for i = 1, #ipv6_array do
      ipv6_array[i] = string.format('%x', tonumber(ipv6_array[i], 16))
  end

  for i = 1, #ipv6_array do
      if ipv6_array[i] == '0' then
          if find_start_index == false then
              tmp_count = 1
              tmp_start_index = i
              find_start_index = true
          else
              tmp_count = tmp_count + 1
          end
          if (i == #ipv6_array) and (tmp_count > max_count) then
              max_count = tmp_count
              start_index = tmp_start_index
              tmp_count = 0
              find_start_index = false
          end
      else
          find_start_index = false
          if tmp_count > max_count then
              max_count = tmp_count
              start_index = tmp_start_index
              tmp_count = 0
          end
      end
  end

  local minimizing = false
  for i = 1, #ipv6_array do
      if (i >= start_index) and (i <= start_index + max_count - 1) then
          minimizing = true
      else
          minimizing = false
      end
      if minimizing then
          if max_count == 1 then
              minimized_ipv6_address = minimized_ipv6_address .. '::'
          elseif (i == start_index) or (i == start_index + max_count - 1) then
              minimized_ipv6_address = minimized_ipv6_address .. ':'
          end
      else
          minimized_ipv6_address = minimized_ipv6_address .. ipv6_array[i]
          if (i + 1 <= #ipv6_array) and (i + 1 ~= start_index) then
              minimized_ipv6_address = minimized_ipv6_address .. ':'
          end
      end
  end

  return minimized_ipv6_address
end

-- Function to convert an integer to binary
local function integer_to_binary(n)
  local t = {}

  repeat
      table.insert(t, 1, n % 2)
      n = math.floor(n / 2)
  until n == 0

  return table.concat(t, '')
end

-- Function to convert IPv6 address to binary string
local function ipv6_address_to_binary(ipv6_address)
  local groups = {}

  for group in ipv6_address:gmatch('[a-fA-F0-9]+') do
      local hexs = string.format('%04X', tonumber(group, 16))
      local binarys = {}
      for hex in hexs:gmatch('[a-fA-F0-9]') do
          local binary = string.format('%04d', integer_to_binary(tonumber(hex, 16)))
          table.insert(binarys, binary)
      end
      local binaryString = table.concat(binarys, '')
      table.insert(groups, binaryString)
  end

  return table.concat(groups, ':')
end

-- Function to convert binary string to IPv6 address
local function binary_to_ipv6_address(binarys)
  local groups = {}
  local group = ''

  for i = 1, #binarys, 4 do
      local binary = binarys:sub(i, i + 3)
      if i % 16 == 1 then
          group = ''
      end
      local base16 = string.format('%x', tonumber(binary, 2))
      group = group .. base16
      if (i + 3) % 16 == 0 then
          table.insert(groups, group)
      end
  end

  return table.concat(groups, ':')
end

-- Function to calculate IPv6 prefix from IPv6 address and prefix length
local function calculate_ipv6_prefix(ipv6_address, prefix_length)
  local binary_ip = ipv6_address_to_binary(get_expanded_ipv6_address(ipv6_address))
  local prefix_binary = string.gsub(binary_ip, ':', ''):sub(1, prefix_length)
  local padding = string.rep('0', 128 - prefix_length)
  local prefix_address = binary_to_ipv6_address(prefix_binary .. padding)
  local minimized_ipv6_address = get_minimized_ipv6_address(prefix_address)
  return minimized_ipv6_address .. '/' .. prefix_length
end

function cellular_ctrl.get_network_interface_info()
  local conn = ubus.connect()
  local network = {}
  local ipv4 = {}
  local ipv6 = {}
  local result = conn:call('luxslam', '5g', {
    cmd = 'get',
    class = 'network',
  }, { return_error = true })

  if result ~= nil and result.paramtable.err_code == nil then
    network = result.paramtable
  end

  result = conn:call('luxslam', '5g', {
    cmd = 'get',
    class = 'ipv4',
  }, { return_error = true })

  if result ~= nil and result.paramtable.err_code == nil then
    ipv4 = result.paramtable
  end

  result = conn:call('luxslam', '5g', {
    cmd = 'get',
    class = 'ipv6',
  }, { return_error = true })

  if result ~= nil and result.paramtable.err_code == nil then
    ipv6 = result.paramtable
  end

  http:status(200):json({
    total_uplink_data = network.tx_bytes,
    total_downlink_data = network.rx_bytes,
    total_packet_loss_tx = network.tx_packet_loss,
    total_packet_loss_rx = network.rx_packet_loss,
    ipv4_address = ipv4.ip_addr,
    ipv4_subnet_mask = ipv4.mask,
    ipv4_primary_dns = ipv4.dnslist,
    ipv4_default_gateway = ipv4.default_gateway,
    ipv6_address = ipv6.ip_addr,
    ipv6_subnet_mask = calculate_ipv6_prefix(ipv6.ip_addr, ipv6.prefix_length),
    ipv6_primary_dns = ipv6.dnslist,
    ipv6_default_gateway = ipv6.default_gateway,
    ipv6_clat_ip_address = ipv6.clat_ip,
  })
end

function cellular_ctrl.reset_network_interface_stats()
  http:status(200):json({
    result = 'SUCCESS',
  })
end

local SCAN_MODE = {
  FULL_SCAN = 'Full Scan',
}

function cellular_ctrl.get_config()
  local sim = query_sim()
  http:status(200):json({
    scan_mode = util.invert(SCAN_MODE)[sim.scan],
    scan_operating_mode = sim.status,
    scan_bands = getOperatingBand(sim),
  })
end

local function update_sim(paramtable)
  local sim = ubus.connect():call('luxslam', '5g', {
    cmd = 'set',
    class = 'sim',
    paramtable = paramtable,
  }).paramtable
  if sim.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Update SIM error: %d', sim.err_code),
    })
  end
  return sim
end

function cellular_ctrl.set_config()
  local body = http.parse_body()
  local sim = query_sim()
  sim.scan = SCAN_MODE[body.scan_mode]
  sim.status = body.scan_operating_mode

  if sim.status == 'SA' then
    sim.nr5g = body.scan_bands
  else
    sim.lte_band = body.scan_bands
    sim.nr5g_nsa = body.scan_bands
  end

  update_sim(sim)
  http:status(200):json({
    result = 'SUCCESS',
  })
end

local CONNECTION_TYPE = {
  IPV4 = 'IPv4',
  IPV6 = 'IPv6',
  IPV4_IPV6 = 'IPv4 & IPv6',
}

local DEFAULT_APN_NETWORK_ATTACH_TYPE = {
  AUTO = 'Automatic',
  MANUAL = 'Manual',
}

function cellular_ctrl.get_default_apn()
  local sim = query_sim()

  http:status(200):json({
    apn_network_attach_type = util.invert(DEFAULT_APN_NETWORK_ATTACH_TYPE)[sim.default_apn_network],
    apn_name = sim.default_apn,
    apn_connection_type = util.invert(CONNECTION_TYPE)[sim.default_connection_type],
  })
end

function cellular_ctrl.update_default_apn()
  local body = http.parse_body()

  local paramtable = {
    default_apn_network = DEFAULT_APN_NETWORK_ATTACH_TYPE[body.apn_network_attach_type],
    default_apn = body.apn_name,
    default_connection_type = CONNECTION_TYPE[body.apn_connection_type],
  }
  update_sim(paramtable)
  http:status(200):json({
    result = 'SUCCESS',
  })
end

local APN_TYPE = {
  SYSTEM = 'System',
  USER = 'User',
}

local APN_CONNECTION_TYPE = {
  IPV4 = 'IPv4',
  IPV6 = 'IPv6',
  IPV4_IPV6 = 'IPv4 & IPv6',
}

local ENABLE_STATUS = {
  ENABLED = 1,
  DISABLED = 0,
}

function is_permitted_operation(sim, apn_name)
  for _, row in ipairs(sim.apn_list) do
    if row.apn == apn_name and row.apn_type ~= "System" then
      return true
    end
  end
  return false
end

function cellular_ctrl.list_apns()
  local sim = query_sim()
  local lux_flags = device_ctrl.query_lux_flags()
  local apn_entries = util.map(util.filter(sim.apn_list, function(row)
    if lux_flags ~= nil and lux_flags.LUX_5G_SMS == "y" then
      return row.apn ~= 'sos'
    else
      return not util.includes({'ims', 'sos'}, row.apn)
    end
  end), function(row)
    return {
      apn_name = row.apn,
      apn_status = util.invert(ENABLE_STATUS)[row.apn_enable],
      apn_connection_type = util.invert(APN_CONNECTION_TYPE)[row.apn_connection_type],
      apn_type = util.invert(APN_TYPE)[row.apn_type],
    }
  end)
  http:status(200):json({
    apn_entries = apn_entries
  })
end

function cellular_ctrl.create_apns()
  local body = http:parse_body()
  local sim = query_sim()
  local exists = util.find(sim.apn_list, function(row)
    return row.apn == body.apn_name
  end)
  if exists then
    error({
      code = 429,
      message = 'FILE EXIST',
    })
  end

  table.insert(sim.apn_list, {
    apn = body.apn_name,
    apn_enable = ENABLE_STATUS[body.apn_status],
    apn_connection_type = APN_CONNECTION_TYPE[body.apn_connection_type],
    apn_type = APN_TYPE[body.apn_type],
  })

  update_sim({
    apn_list = sim.apn_list,
  })

  http:status(200):json({
    test = sim.apn_list,
    result = 'SUCCESS',
  })
end

function cellular_ctrl.update_apns()
  local body = http:parse_body()
  local sim = query_sim()

  if not is_permitted_operation(sim, body.apn_name) then
    error({
      code = 400,
      message = 'Cannot edit system default APN.',
    })
  end

  local found = util.find(sim.apn_list, function(row)
    return row.apn == body.apn_name
  end)

  if not found then
    error({
      code = 400,
      message = 'Not found'
    })
  end

  found.apn_enable = ENABLE_STATUS[body.apn_status]
  update_sim({
    apn_list = sim.apn_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

---@param env table
function cellular_ctrl.delete_apns(env)
  local query = http.parse_query(env)
  local sim = query_sim()

  if not is_permitted_operation(sim, query.apn_name) then
    error({
      code = 400,
      message = 'Cannot delete system default APN.',
    })
  end

  local apn_list = util.filter(sim.apn_list, function(row)
    return row.apn ~= query.apn_name
  end)

  update_sim({
    apn_list = apn_list,
  })

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function cellular_ctrl.verify_pin()
--   local body = http.parse_body()
--
--   local sim = ubus.connect():call('luxslam', '5g', {
--     cmd = 'set',
--     class = 'sim',
--     paramtable = {
--       pin = body.pin,
--     },
--   }, { return_error = true }).paramtable
--
--   if sim.err_code ~= nil then
--     http:status(200):json({
--       result = 'SUCCESS',
--       verify_pin_result = 'FAILURE',
--       retry_attempts_left = sim.err_code % 0x30,
--     })
--   else
--     http:status(200):json({
--       result = 'SUCCESS',
--       verify_pin_result = 'SUCCESS',
--     })
--   end
  http:status(200):json({
    result = 'SUCCESS',
  })
end

---@param signal_strength integer | nil
local function getSignalStrengthString(signal_strength)
  signal_strength = signal_strength or 0
  if signal_strength >= -65 and signal_strength < 0 then
    return 'Excellent'
  elseif signal_strength >= -80 and signal_strength <= -66 then
    return 'Very Good'
  elseif signal_strength >= -100 and signal_strength <= -81 then
    return 'Good'
  elseif signal_strength <= -101 then
    return 'Poor'
  else
    return 'No Signal'
  end
end

function cellular_ctrl.get_app_info()
  local sim = query_sim()
  local apn_entries = util.map(sim.apn_list, function(row)
    return {
      name = row.apn,
      status = tostring(row.apn_enable),
      connectionType = row.apn_connection_type,
      apnType = row.apn_type,
    }
  end)
  local serving_cell = query_serving_cell()
  local neighbor_cells = util.map(query_neighbor_cell(), function(row)
    return {
      cellName = row.cell_name,
      physicalCellId = tostring(row.pci),
      signalStrength = getSignalStrengthString(row.signal_strength),
      ['nr-rsrp'] = tostring(row.nr_rsrp),
      ['nr-rsrq'] = tostring(row.nr_rsrq),
      ['nr-sinr'] = tostring(row.nr_sinr),
      band = getOperatingBand(row),
      bandwidth = tostring(row.bandwidth),
      arfcn = tostring(row.nr_arfcn),
      bler = tostring(row.bler),
    }
  end);
  local network = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'network',
  }).paramtable or {};
  local status, esim = pcall(function()
    local esim = ubus.connect():call('luxslam', '5g', {
      cmd = 'get',
      class = 'esim',
    }).paramtable or {}
    return esim;
  end)
  local eSimStatus = '0'
  local eSimActivated = '0'
  if status then
    eSimStatus = '1'
    local profile = util.find(esim.profile_info_list, function(row)
      return row.enable == 1
    end)
    if profile then
      eSimActivated = '1'
    end
  end

  http:status(200):json({
    apnList = apn_entries,
    globalCellId = serving_cell.cell_id,
    iccid = sim.iccid,
    cellName = serving_cell.cell_name,
    physicalCellId = tostring(serving_cell.pci),
    signalStrength = getSignalStrengthString(serving_cell.signal_strength),
    simStatus = sim.sim_status,
    eSimStatus = eSimStatus,
    eSimActivated = eSimActivated,
    sinr = tostring(serving_cell.sinr),
    band = getOperatingBand(serving_cell),
    bandwidth = tostring(serving_cell.bandwidth),
    arfcn = tostring(serving_cell.nr_arfcn),
    bler = tostring(serving_cell.bler),
    uplink = tostring(network.tx_bytes),
    uplinkMax = tostring(network.max_up_data_rate),
    uplinkMin = tostring(network.min_up_data_rate),
    downlink = tostring(network.rx_bytes),
    downlinkMax = tostring(network.max_down_data_rate),
    downlinkMin = tostring(network.min_down_data_rate),
    operatingMode = serving_cell.status,
    rsrp = tostring(serving_cell.rsrp),
    rsrq = tostring(serving_cell.rsrq),
    ['nr-rsrp'] = tostring(serving_cell.nr_rsrp),
    ['nr-rsrq'] = tostring(serving_cell.nr_rsrq),
    ['nr-sinr'] = tostring(serving_cell.nr_sinr),
    neighbour_cell = neighbor_cells,
  })
end

function cellular_ctrl.get_app_cell_list()
  local CELL_LIST = {}
  local serving_cell = query_serving_cell(true)
  if serving_cell.cell_id and serving_cell.cell_id ~= '' then
    table.insert(CELL_LIST, {
      CELL_ID = serving_cell.cell_id,
      IS_SERVING = 1,
    })
  end
  http:status(200):json({
    result = true,
    CELL_LIST = CELL_LIST,
  })
end

function cellular_ctrl.get_app_cell_info()
  local body = http.parse_body()
  local NR_5G = {}
  local serving_cell = query_serving_cell(true)
  if serving_cell.cell_id and serving_cell.cell_id == body.cell_id then
    NR_5G = {
      nr_band = getOperatingBand(serving_cell),
      nr_band_width = tostring(serving_cell.bandwidth) .. 'MHz',
      nr_rsrp = tostring(serving_cell.nr_rsrp) .. 'dBm',
      nr_rsrq = tostring(serving_cell.nr_rsrq) .. 'dB',
      nr_snr = tostring(serving_cell.nr_sinr) .. 'dB',
      nr_pci = tostring(serving_cell.pci),
      nr_tac = tostring(serving_cell.tac),
    }
  else
    local neighbor_cells = query_neighbor_cell()
    for _, neighbor_cell in ipairs(neighbor_cells) do
      if neighbor_cell.global_cell_id == body.cell_id then
        NR_5G = {
          nr_band = getOperatingBand(neighbor_cell),
          nr_band_width = tostring(neighbor_cell.bandwidth) .. 'MHz',
          nr_rsrp = tostring(neighbor_cell.nr_rsrp) .. 'dBm',
          nr_rsrq = tostring(neighbor_cell.nr_rsrq) .. 'dB',
          nr_snr = tostring(neighbor_cell.nr_sinr) .. 'dB',
          nr_pci = tostring(neighbor_cell.pci),
          nr_tac = tostring(neighbor_cell.tac),
        }
      end
    end
  end
  http:status(200):json({
    result = true,
    NR_5G = NR_5G,
  })
end

local function parse_seconds_to_time_object(seconds)
  local SECONDS_PER_MINUTE = 60
  local MINUTES_PER_HOUR = 60
  local HOURS_PER_DAY = 24

  local remaining_seconds = math.floor(seconds);

  local days = math.floor(remaining_seconds / (SECONDS_PER_MINUTE * MINUTES_PER_HOUR * HOURS_PER_DAY));
  remaining_seconds = remaining_seconds % (SECONDS_PER_MINUTE * MINUTES_PER_HOUR * HOURS_PER_DAY);

  local hours = math.floor(remaining_seconds / (SECONDS_PER_MINUTE * MINUTES_PER_HOUR));
  remaining_seconds = remaining_seconds % (SECONDS_PER_MINUTE * MINUTES_PER_HOUR);

  local minutes = math.floor(remaining_seconds / SECONDS_PER_MINUTE);
  remaining_seconds = remaining_seconds % SECONDS_PER_MINUTE;

  return {
    day = tostring(days),
    hour = tostring(hours),
    min = tostring(minutes),
    sec = tostring(remaining_seconds)
  }
end

function cellular_ctrl.get_app_connection_info()
  local conn = ubus.connect()
  local sim = query_sim()
  local ipv4 = conn:call('luxslam', '5g', {
    cmd = 'get',
    class = 'ipv4',
  }).paramtable;
  local ipv6 = conn:call('luxslam', '5g', {
    cmd = 'get',
    class = 'ipv6',
  }).paramtable
  local cwmp = conn:call('luxslam', 'cwmp', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  local has_ipv4_addr = verify.isString(ipv4.ip_addr) and #ipv4.ip_addr > 0
  local has_ipv6_addr = verify.isString(ipv6.ip_addr) and #ipv6.ip_addr > 0
  local time_obj = parse_seconds_to_time_object(sim.linkup_timestamp)
  local time_string = time_obj.day ..
  ' Days, ' .. time_obj.hour .. ' Hr, ' .. time_obj.min .. ' Min, ' .. time_obj.sec .. ' Sec.'
  http:status(200):json({
    internetConnectionStatus = (has_ipv4_addr or has_ipv6_addr) and 'Attached' or '',
    wanIPs = {
      {
        ipv4Address = ipv4.ip_addr,
        ipv6Address = ipv6.ip_addr,
        gateway = ipv4.default_gateway,
        subnetMask = ipv4.mask,
        primaryDNS = ipv4.dnslist,
      },
    },
    connectionDuration = time_string,
    lastSuccessfulACSConnectionTime = tostring(cwmp.last_inform),
  })
end

function cellular_ctrl.get_no_sim_cell_info()
  local CELL_LIST = {}
  local serving_cell = query_serving_cell(true)
  if serving_cell.cell_id and serving_cell.cell_id ~= '' then
    table.insert(CELL_LIST, {
      cellName = serving_cell.cell_name,
      Cell_ID = tostring(serving_cell.cell_id),
      ['nr-rsrp'] = tostring(serving_cell.nr_rsrp),
      ['nr-rsrq'] = tostring(serving_cell.nr_rsrq),
      ['nr-sinr'] = tostring(serving_cell.nr_sinr),
    })
  end
  for _, row in ipairs(query_neighbor_cell()) do
    table.insert(CELL_LIST, {
      cellName = row.cell_name,
      Cell_ID = tostring(row.global_cell_id),
      ['nr-rsrp'] = tostring(row.nr_rsrp),
      ['nr-rsrq'] = tostring(row.nr_rsrq),
      ['nr-sinr'] = tostring(row.nr_sinr),
    })
  end
  http:status(200):json({
    result = true,
    cellInfo = CELL_LIST,
  })
end

return cellular_ctrl
