local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local device_ctrl = {}

local GENERAL_MODE = {
  ROUTER = 'Router',
  BRIDGE = 'Bridge',
  EoGRE = 'EoGRE'
}

local function query_firmware()
  local firmware = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'firmware',
  }).paramtable
  if firmware.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Firmware error: %d', firmware.err_code),
    })
  end
  return firmware
end
device_ctrl.query_firmware = query_firmware

local function query_device()
  local device = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'device',
  }).paramtable
  if device.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Device error: %d', device.err_code),
    })
  end
  return device
end

local function query_esim()
  local slot = util.popen('luxcmds sys slot')
  if string.match(slot, 'SLOT_2') then
    local result = ubus.connect():call('luxslam', '5g', {
      cmd = 'get',
      class = 'esim',
    }, { return_error = true })
    if result == nil or result.paramtable.err_code ~= nil then
      return nil
    end
    return result.paramtable
  end
  return nil
end

local function query_cpu()
  local cpu = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'cpu',
  }, { return_error = true })

  return cpu.paramtable
end

local function query_memory()
  local memory = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'memory',
  }, { return_error = true })

  return memory.paramtable
end

local function query_network()
  local network = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'network',
  }, { return_error = true })

  return network.paramtable
end

local function query_firewall()
  local firewall = ubus.connect():call('luxslam', 'firewall', {
    cmd = 'get',
    class = 'general',
  }, { return_error = true })

  return firewall.paramtable
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
  local sim = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'sim',
  }).paramtable
  if sim.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SIM error: %d', sim.err_code),
    })
  end
  sim.sim_status = util.invert(SIM_STATUS)[sim.sim_status];
  return sim
end

local function query_lan()
  local lan = ubus.connect():call('luxslam', 'lan', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  if lan.err_code ~= nil then
    error({
      code = 500,
      message = string.format('LAN error: %d', lan.err_code),
    })
  end
  return lan
end

local function query_lux_flags()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'luxflags',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Luxflags error: %d', firmware.err_code),
    })
  end

  return result
end

---@param software_version string
---@return boolean
function device_ctrl.can_access(software_version)
  if string.find(software_version, "REL") then
    if string.find(software_version, "SR$") ~= nil or string.find(software_version, "UR$") ~= nil then
      return true
    end
    return false
  end
  return true
end

function device_ctrl.get_info()
  local conn = ubus.connect()
  local firmware = query_firmware()
  local device = query_device()
  local sim = query_sim()
  local esim = query_esim()
  local eid = nil

  if esim ~= nil then
    eid = esim.eid
  end

  local time = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'time',
  }).paramtable
  if time.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Firmware error: %d', time.err_code),
    })
  end

  local cwmp = conn:call('luxslam', 'cwmp', {
    cmd = 'get',
    class = 'general'
  }).paramtable
  if cwmp.err_code ~= nil then
    error({
      code = 500,
      message = string.format('CWMP error: %d', cwmp.err_code),
    })
  end

  local band = conn:call('luxslam', '5g', {
    cmd = 'get',
    class = 'band'
  }).paramtable
  if band.err_code ~= nil then
    error({
      code = 500,
      message = string.format('band error: %d', band.err_code),
    })
  end

  http:status(200):json({
    local_time = time.current_timestamp,
    odm = device.odm,
    product = device.product_name,
    serial = device.serial_number,
    imei = sim.imei,
    firmware_version = firmware.software_version,
    firmware_creation_date = firmware.build_date,
    hardware_version = device.hardware_version,
    model = device.device_model,
    mac = device.base_macaddr,
    oui = device.oui,
    imsi = sim.imsi,
    msisdn = sim.msisdn,
    iccid = sim.iccid,
    eid = eid,
    frequency_bands_supported = band.nr_5g_band,
    last_successful_acs_connection = cwmp.last_inform
  })
end

function device_ctrl.get_app_info()
  local conn = ubus.connect()
  local firmware = query_firmware()
  local device = query_device()
  local sim = query_sim()

  local general = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  if general.err_code ~= nil then
    error({
      code = 500,
      message = string.format('System General error: %d', general.err_code),
    })
  end

  http:status(200):json({
    firmwareVersion = firmware.software_version,
    hardwareVersion = device.hardware_version,
    hostname = general.host_name,
    imei = sim.imei,
    imsi = sim.imsi,
    mac = device.base_macaddr,
    model = device.device_model,
    serialNumber = device.serial_number,
  })
end

function device_ctrl.get_app_esim_device_info()
  local firmware = query_firmware()
  local device = query_device()
  local sim = query_sim()
  local eogre_general = ubus.connect():call('luxslam', 'eogre', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  local eogre_rule = util.find(ubus.connect():call('luxslam', 'eogre', {
    cmd = 'get',
    class = 'rule_list',
  }).paramtable.list, function(rule)
    return rule.status == 0
  end) or {}
  if eogre_general.enable == 0 then
    eogre_rule = {}
  end

  http:status(200):json({
    model = device.device_model,
    SerialNo = device.serial_number,
    IMEI = sim.imei,
    CurrentSoftVer = firmware.software_version,
    eogre_details = {
      Enabled = eogre_general.enable == 1,
      VlanDetail = eogre_rule.vlan_id,
      LocalIP = eogre_rule.local_ip_addr,
      RemoteIP = eogre_rule.remote_ip_addr,
    },
  })
end

function device_ctrl.get_software_info()
  local firmware = query_firmware()
  local graceful = false

  if util.fileExists("/data/graceful_pending") then
    graceful = true
  end

  http:status(200):json({
    firmware_version = firmware.software_version,
    firmware_creation_date = firmware.build_date,
    firmware_upload_path = string.match(firmware.fw_upload_path, "^.+/(.+)$"),
    graceful = graceful
  })
end

function device_ctrl.get_api_reboot()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {
      action = 'Reboot',
    }
  }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = 'SUCCESS',
    })
  else
    error({
      code = 400,
      message = string.format('Reboot error: %d', result.err_code),
    })
  end
end

function device_ctrl.get_app_reboot()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {
      action = 'Reboot',
    }
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = true,
    })
  else
    error({
      type = 'app',
      code = 500,
      message = string.format('Reboot error: %d', result.err_code),
    })
  end
end

function device_ctrl.backup_config()
-- Get new SMS messages from the device to update uci config
  local lux_flags = query_lux_flags()
  if lux_flags ~= nil and  lux_flags.LUX_5G_SMS == 'y' then
    local result = ubus.connect():call('luxslam', '5g', {
      cmd = 'get',
      class = 'sms_inbox',
    }).paramtable
  end

  local filename = 'backup-'..util.generate_id()..'.zip'
  local filepath = '/tmp/'..filename
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {
      action = 'Conf Backup',
      action_filepath = filepath,
    },
  })
  if result == nil or result.paramtable.err_code ~= nil then
    error({
      code = 500,
      message = 'Backup fail',
    })
  end
  http:status(200):download(filepath, filename)
end

function device_ctrl.restore_config()
  -- DC API 4.22: Restore Configuration Reboot[WebGUI] start
  local ABSL_RESTORE_CONFIG_GUI_FLAG = '/tmp/absl_restore_config_gui'
  util.safe_execute('touch ' .. ABSL_RESTORE_CONFIG_GUI_FLAG)
  -- DC API 4.22: Restore Configuration Reboot[WebGUI] end
  local filepath = '/tmp/restore_config.zip'
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {
      action = 'Conf Restore',
      action_filepath = filepath,
    },
  })
  if result == nil or result.paramtable.err_code ~= nil then
    error({
      code = 500,
      message = 'Restore fail',
    })
  end
  http:status(200):json({
    result = 'SUCCESS',
  })
end

function device_ctrl.get_utilization()
  local device = query_device()
  local cpu = query_cpu()
  local memory = query_memory()
  local network = query_network()
  local firewall = query_firewall()

  http:status(200):json({
    fw_status = util.to_boolean(firewall.enable),
    bytes_tx = network.average_up_data_rate,
    bytes_rx = network.average_down_data_rate,
    perf_monitor_rate = device.monitor_duration,
    cpu_current_usage = cpu.current_usage,
    memory_current_usage = memory.current_usage,
    sys_up_time = device.uptime
  })
end

-- deprecated
function device_ctrl.is_connection_alive()
  http:status(200):json({
    result = 'SUCCESS',
  })
end

function device_ctrl.get_init_params()
  local sim = query_sim()
  local lan = query_lan()
  local firmware = query_firmware()
  local device = query_device()
  local lux_flags = query_lux_flags()
  local operating_permission = device_ctrl.can_access(firmware.software_version)

  http:status(200):json({
    sim_status = sim.sim_status,
    lan_operation_mode = util.invert(GENERAL_MODE)[lan.mode],
    device = 'QUECTEL',
    software_version = firmware.software_version,
    software_creation_date = firmware.build_date,
    hardware_version = device.hardware_version,
    model = device.device_model,
    enterprise_status = '1',
    show_last_change_status = '0',
    sw_update_result = 'UNAVAILABLE',
    lan_mode_status_result = 'UNAVAILABLE',
    operating_permission = operating_permission,
    sms_enable = lux_flags ~= nil and  lux_flags.LUX_5G_SMS == 'y'     --Decide whether to enable SMS GUI
  })
end

device_ctrl.query_lux_flags = query_lux_flags
return device_ctrl
