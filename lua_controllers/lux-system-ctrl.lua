local http = require('lux-http')
local util = require('lux-util')
local ubus = require('lux-ubus')
local verify = require('lux-verify')

local LOG_LEVEL = {
  ERROR = 3,
  WARNING = 4,
  INFO = 6,
  DEBUG = 7,
  ALL = 8,
}
local packet_network_type = {"WAN", "LAN", "ANY"}
local file_size_type = {1, 2, 5, 10, 20}

local ENABLE_STATUS = {
  ENABLED = 1,
  DISABLED = 0,
}

local REBOOT_SCHEDULE_TYPE = {
  NEVER = "Never",
  DAILY = "Daily",
  WEEKLY = "Weekly",
  MONTHLY = "Monthly"
}

local SOC_LOG_TYPE = {
  DEVICE_LOGS = "Device Logs",
  HW_ACCELERATOR_LOGS = "Hardware Accelerator Logs",
}

local SOC_LOG_TYPE_IDX = {
  DEVICE_LOGS = 1,
  HW_ACCELERATOR_LOGS = 2,
}

local SOC_TCP_DUMP_INTERFACE = {
  LAN = 1,
  WAN = 2,
  BRIDGE = 3,
  GRETAP = 4,
  ALL = 5,
}

local SPEED_TEST_LINK_TYPE = {
  UPLINK = 0,
  DOWNLINK = 1,
  BOTH = 2,
}

local SPEED_TEST_LINK_APP_TYPE = {
  UL = 0,
  DL = 1,
  ULDL = 2,
}

local system_ctrl = {}

local function query_soc_log()
  local conn = ubus.connect()
  local sys_log = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'soclogging',
  }, { return_error = true }).paramtable
  if sys_log.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SysLog error: %d', sys_log.err_code),
    })
  end
  return sys_log
end

function system_ctrl.start_online_upgrade()
  local body = http.parse_body()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'set',
    class = 'online_fw_upgrade',
    paramtable = {
      check_status = body.check_status
    },
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SysLog error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'success'
  })
end

function system_ctrl.check_online_download_status()
  -- If the flag exists, it means that download fw is completed.
  local exitcode = util.safe_execute('ls ' .. '/tmp/fota_verify_processing')

  if exitcode == 0 then
    http:status(200):json({
      result = 'SUCCESS',
      status = 'Completed'
    })
  else
    http:status(200):json({
      result = 'SUCCESS',
      status = 'Progressing'
    })
  end
end

function system_ctrl.check_upgrade_status()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'online_fw_upgrade'
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SysLog error: %d', result.err_code),
    })
  end

  http:status(200):json({
    check_status = result.check_status,
    fw_available = util.to_boolean(result.fw_available),
    sw_version = result.sw_version
  })
end

function system_ctrl.check_upgrade_status()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'online_fw_upgrade'
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SysLog error: %d', result.err_code),
    })
  end

  http:status(200):json({
    check_status = result.check_status,
    fw_available = util.to_boolean(result.fw_available),
    sw_version = result.sw_version
  })
end

local UPGRADING_FILE = '/tmp/is_upgrading'
function system_ctrl.is_firmware_upgrade()
  local exitcode = util.safe_execute('ls ' .. UPGRADING_FILE)
  return exitcode == 0
end

function system_ctrl.init_upgrade()
  local sys_log = query_soc_log()
  if sys_log.status == "In-progess" and util.invert(SOC_LOG_TYPE)[sys_log.log_type] == "HW_ACCELERATOR_LOGS" then
    error({
      code = 500,
      message = string.format('Soc-In-progess'),
    })
  end

  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {
      action = 'FW Upgrade',
      action_filepath = '/usrdata/cache/ufs/update.zip',
    },
  }, { return_error = true })
  if result.paramtable.err_code ~= nil then
    error({
      code = 500,
      message = string.format('error: %d', result.paramtable.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function system_ctrl.check_fota_status()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'device'
  }, { return_error = true })
  if result.paramtable.err_code ~= nil then
    error({
      code = 500,
      message = string.format('error: %d', result.paramtable.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
    check_fw_finished = result.paramtable.check_fw_finished
  })
end

function system_ctrl.firmware_upgrade()
  util.safe_execute('touch ' .. UPGRADING_FILE)
  http:status(200):json({
    result = 'SUCCESS',
  })

  -- DC API 4.22: FOTA Reboot[WebGUI] start
  local conn = ubus.connect()
  conn:uci_set('sys', 'device', {
    reboot_reason = '14',
  })
  conn:uci_commit('sys')
  -- DC API 4.22: FOTA Reboot[WebGUI] end
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {
      action = 'Upgrade Reboot'
    },
  }, { return_error = true })
end

---@return number err_code
---@return string filename
local function get_log_path()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'set',
    class = 'log',
    paramtable = {
      trigger_log = 1
    }
  }).paramtable;
  if result.err_code ~= nil then
    return tonumber(result.err_code) or 0xff, ''
  end
  util.sleep(1)
  local times = 0
  while times < 50 do
    result = conn:call('luxslam', 'sys', {
      cmd = 'get',
      class = 'log'
    }).paramtable
    if result.log_filepath ~= '' then
      return 0, result.log_filepath
    end
    util.sleep(3)
    times = times + 1
  end
  return 0xfd, ''
end

function system_ctrl.get_app_log()
  local err_code, filepath = get_log_path()
  if err_code ~= 0 then
    error({
      type = 'app',
      code = 500,
      app_msg_id = '32',
      app_error_code = err_code,
    })
  end
  local filename = 'log-'..util.generate_id()..'.zip'
  http:status(200):download(filepath, filename)
  ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'log',
    paramtable = {
      remove_tmp_log = true,
    },
  })
end

function system_ctrl.get_log_settings()
  local conn = ubus.connect()
  local sys_log = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'log',
  }).paramtable
  if sys_log.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SysLog error: %d', sys_log.err_code),
    })
  end

  http:status(200):json({
    level = util.invert(LOG_LEVEL)[sys_log.log_level],
    status = util.invert(ENABLE_STATUS)[sys_log.enable],
  })
end

function system_ctrl.get_tcp_dump_settings()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'capture_packets',
  }).paramtable

  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SysLog error: %d', result.err_code),
    })
  end

  http:status(200):json({
      interface = result.interface,
      size = result.file_size,
      status = util.to_boolean(result.enable)
  })
end

local function parse_log_settings_body()
  local body = http.parse_body()
  if not util.includes(util.keys(LOG_LEVEL), body.level) then
    error({
      code = 400,
      message = "Invalid level",
    })
  end
  if not util.includes(util.keys(ENABLE_STATUS), body.status) then
    error({
      code = 400,
      message = "Invalid status",
    })
  end
  return body
end

function system_ctrl.set_log_settings()
  local body = parse_log_settings_body()
  local conn = ubus.connect()
  local sys_log = conn:call('luxslam', 'sys', {
    cmd = 'set',
    class = 'log',
    paramtable = {
      log_level = LOG_LEVEL[body.level],
      enable = ENABLE_STATUS[body.status],
    },
  }).paramtable
  if sys_log.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SysLog error: %d', sys_log.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

local function parse_tcp_dump_settings_body()
  local body = http.parse_body()
  if not util.includes(packet_network_type, body.interface) then
    error({
      code = 400,
      message = "Invalid interface",
    })
  end
  if not util.includes(file_size_type, body.size) then
    error({
      code = 400,
      message = "Invalid size",
    })
  end
  return body
end

function system_ctrl.set_tcp_dump_settings()
  local body = parse_tcp_dump_settings_body()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'set',
    class = 'capture_packets',
    paramtable = {
      file_size = body.size,
      interface = body.interface,
      enable = body.status
    },
  }).paramtable
  if (result.err_code == nil) then
    http:status(200):json({
      result = 'SUCCESS'
    })
  else
    error({
      code = 500,
      message = string.format('Set capture packets error: %d', result.err_code),
    })
  end
end

function system_ctrl.clear_log()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'log',
    paramtable = {
      clear_log = true,
    },
  }).paramtable
  if (result.err_code == nil) then
    http:status(200):json({
      result = 'SUCCESS'
    })
  else
    error({
      code = 500,
      message = string.format('Reset error: %d', result.err_code),
    })
  end
end

function system_ctrl.download_logs()
  local err_code, filepath = get_log_path()
  if err_code ~= 0 then
    error({
      code = 500,
      message = string.format('Get path error: %d', err_code),
    })
  end
  local filename = 'log-'..util.generate_id()..'.tar.gz'
  http:status(200):download(filepath, filename)
  ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'log',
    paramtable = {
      remove_tmp_log = true,
    },
  })
end

function system_ctrl.download_tcp_dump()
  while util.safe_execute('ls /tmp/packet_capture_stop.done') ~= 0 do
    util.sleep(1)
  end

  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'capture_packets'
  }).paramtable
  if (result.err_code ~= nil) then
    error({
      code = 500,
      message = string.format('Get path error: %d', result.err_code),
    })
  end

  local filename = 'JODU52140_Pcap_'..util.generate_id()..'.tar.gz'
  http:status(200):download(result.packets_filepath, filename)
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'capture_packets',
    paramtable = {
      action = 'clear_log',
    },
  }).paramtable
end

function system_ctrl.reset()
  -- DC API 4.21: Factory Reset Reboot[WebGUI] start
  local ABSL_FACTORY_RESET_GUI = '/tmp/absl_factory_reset_gui'
  util.safe_execute('touch ' .. ABSL_FACTORY_RESET_GUI)
  -- DC API 4.21: Factory Reset Reboot[WebGUI] end
  local led_result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'led',
    paramtable = { action = 'Reset' }
  }, { return_error = true }).paramtable
  if led_result.err_code ~= nil then
    error({
      type = 'app',
      code = 500,
      message = string.format('LED Reset error: %d', led_result.err_code),
    })
  end
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {action = 'Reset'}
  }).paramtable
  if (result.err_code == nil) then
    http:status(200):json({
      result = 'SUCCESS'
    })
  else
    error({
      code = 500,
      message = string.format('Reset error: %d', result.err_code),
    })
  end
end

function system_ctrl.app_reset()
  -- SIM-OTA: Factory Reset Reboot[SIM] start
  local ABSL_FACTORY_RESET_GUI = '/tmp/absl_factory_reset_sim'
  util.safe_execute('touch ' .. ABSL_FACTORY_RESET_GUI)
  -- SIM-OTA: Factory Reset Reboot[SIM] end
  local led_result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'led',
    paramtable = { action = 'Reset' }
  }, { return_error = true }).paramtable
  if led_result.err_code ~= nil then
    error({
      type = 'app',
      code = 500,
      message = string.format('LED Reset error: %d', led_result.err_code),
    })
  end
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {action = 'Reset'}
  }, { return_error = true }).paramtable
  if result.err_code == nil then
    http:status(200):json({
      result = true,
    })
  else
    error({
      type = 'app',
      code = 500,
      message = string.format('Reset error: %d', result.err_code),
    })
  end
end

function system_ctrl.reboot()
  -- DC API 4.21: Reboot[WebGUI] start
  local conn = ubus.connect()
  conn:uci_set('sys', 'device', {
    reboot_reason = '2',
  })
  conn:uci_commit('sys')
  -- DC API 4.21: Reboot[WebGUI] end
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {action = 'Reboot'}
  }).paramtable
  if (result.err_code == nil) then
    http:status(200):json({
      result = 'SUCCESS'
    })
  else
    error({
      code = 500,
      message = string.format('Reboot error: %d', result.err_code),
    })
  end
end

function system_ctrl.soc_reboot()
  -- DC API 4.25: Reboot [SOC LOGGING] start
  local conn = ubus.connect()
  conn:uci_set('sys', 'device', {
    reboot_reason = '22',
  })
  conn:uci_commit('sys')
  -- DC API 4.25: Reboot [SOC LOGGING] end
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {action = 'Reboot'}
  }).paramtable
  if (result.err_code == nil) then
    http:status(200):json({
      result = 'SUCCESS'
    })
  else
    error({
      code = 500,
      message = string.format('Reboot error: %d', result.err_code),
    })
  end
end

function system_ctrl.get_health_monitor()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'device'
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('health monitor error: %d', result.err_code),
    })
  end

  if (result ~= nil) then
    local status
    if result.network_monitor == 1 then
      status = "Enabled"
    else
        status = "Disabled"
    end

    http:status(200):json({
      connection_address = result.router_domain_name,
      health_monitor_status = status,
      result = "SUCCESS"
    })
  else
    error({
      code = 500,
      message = 'unknown method',
    })
  end
end

function system_ctrl.set_health_monitor()
  local body = http.parse_body()
  local status
  if body.health_monitor_status == "Enabled" then
    status = 1
  else
      status = 0
  end
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'device',
    paramtable = {
      network_monitor = status
    },
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Set health monitor error: %d', result.err_code),
    })
  end
  http:status(200):json({
    result = 'SUCCESS',
  })
end

function system_ctrl.get_auto_reboot()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'autoreboot'
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('auto reboot error: %d', result.err_code),
    })
  end

  if (result ~= nil) then
    http:status(200):json({
      reboot_time = result.reboot_time,
      reboot_day = result.reboot_day,
      reboot_schedule = util.invert(REBOOT_SCHEDULE_TYPE)[result.schedule],
      result = "SUCCESS"
    })
  else
    error({
      code = 500,
      message = 'unknown method',
    })
  end
end

function system_ctrl.set_auto_reboot()
  local body = http.parse_body()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'autoreboot',
    paramtable = {
      reboot_time = tonumber(body.reboot_time),
      reboot_day = tonumber(body.reboot_day),
      schedule = REBOOT_SCHEDULE_TYPE[body.reboot_schedule],
	  trigger = 'webgui',
    },
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Set auto reboot error: %d', result.err_code),
    })
  end
  http:status(200):json({
    result = 'SUCCESS',
  })
end

function system_ctrl.get_soc_log_settings()
  local sys_log = query_soc_log()

  http:status(200):json({
    result = "SUCCESS",
    status = util.to_boolean(sys_log.enable),
    type = util.invert(SOC_LOG_TYPE)[sys_log.log_type],
    device_file_size = sys_log.tcp_dump_size,
    select_interface = sys_log.tcp_dump_interface,
    repeat_logging_interval = sys_log.time_gap,
    repeat_logging_count = sys_log.repeat_times,
    periodic_interval = sys_log.periodic_time_interval,
    hw_file_size = sys_log.hw_accel_log_size,
    download_logs = sys_log.trigger_soclog,
    clear_logs = sys_log.clear_soclog,
    download_status = sys_log.status,
    log_path = sys_log.log_path
  })
end

local function parse_soc_log_settings_body()
  local body = http.parse_body()
  if not verify.isBoolean(body.status) then
    error({
      code = 400,
      message = "Invalid status",
    })
  end
  if not util.includes(util.keys(SOC_LOG_TYPE), body.type) then
    error({
      code = 400,
      message = "Invalid type",
    })
  end
  return body
end

function system_ctrl.set_soc_log_settings()
  local sys_log = query_soc_log()
  local is_soc_enable = util.to_boolean(sys_log.enable)
  local body = parse_soc_log_settings_body()
  local conn = ubus.connect()
  local paramtable = {}

  --   The backend needs to be customized. If the status of soc status is from enabled->disabled, do not set other parameters.
  if not (is_soc_enable and not body.status) then
    paramtable.tcp_dump_size = body.device_file_size
    paramtable.tcp_dump_interface = SOC_TCP_DUMP_INTERFACE[body.select_interface]
    paramtable.time_gap = body.repeat_logging_interval
    paramtable.repeat_times = body.repeat_logging_count
    paramtable.periodic_time_interval = body.periodic_interval
    paramtable.hw_accel_log_size = body.hw_file_size
  end

  -- If it is a device log, use enable in the field of enable when setting.
  -- If it is hw log, use hw_accel_log_enable for the enable field when setting
  -- There is no need to set the Log Type, the backend will determine it based on enable.
  if body.type == "DEVICE_LOGS" then
    paramtable.enable = body.status
  else
    paramtable.hw_accel_log_enable = body.status
  end

-- With the back -end design, need to add FLAG to the HW log and display it correctly
  if body.type == "HW_ACCELERATOR_LOGS" and util.to_boolean(sys_log.enable) ~= body.status then
    util.safe_execute('touch /tmp/web_soclogging_reboot_flag')
  end

  local sys_log = conn:call('luxslam', 'sys', {
    cmd = 'set',
    class = 'soclogging',
    paramtable = paramtable,
  }, { return_error = true }).paramtable
  if sys_log.err_code ~= nil then
    error({
      code = 500,
      message = string.format('SysLog error: %d', sys_log.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS'
  })
end

function system_ctrl.clear_soc_log()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'soclogging',
    paramtable = {
      clear_soclog = 1,
    },
  }, { return_error = true }).paramtable

  if (result.err_code == nil) then
    http:status(200):json({
      result = 'SUCCESS'
    })
  else
    error({
      code = 500,
      message = string.format('Reset error: %d', result.err_code),
    })
  end
end

local function check_soc_log_exists(times)
  local exitcode = util.safe_execute('ls ' .. '/usrdata/soclogging/soc_logging.tgz')
  if times == nil then
    times = 0
  end

  if times > 30 then
    error({
      code = 500,
      message = string.format('File not exist')
    })
  end

  if exitcode == 0 then
    return true
  else
    util.sleep(2)
    return check_soc_log_exists(times + 1)
  end
end

function system_ctrl.download_soc_logs()
  local sys_log = query_soc_log()
  if sys_log.periodic_time_interval > 0 then
    local conn = ubus.connect()
    local trigger_log = conn:call('luxslam', 'sys', {
      cmd = 'set',
      class = 'soclogging',
      paramtable = {
        trigger_soclog = 1
      },
    }, { return_error = true }).paramtable
    if trigger_log.err_code ~= nil then
      error({
        code = 500,
        message = string.format('SysLog error: %d', sys_log.err_code),
      })
    end
  end

  local file_exist = check_soc_log_exists()
  local filepath = '/usrdata/soclogging/soc_logging.tgz'
  local filename = 'SOClogging_'..util.generate_id()..'.tar.gz'
  http:status(200):download(filepath, filename)
end

function system_ctrl.get_speed_test_status()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'sys', {
    cmd = 'get',
    class = 'speedtest'
  }, { return_error = true }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('get speed test error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
    status = result.status,
    uplink_data_rate = result.uplinkDatarate,
    downlink_data_rate = result.downlinkDatarate,
    test_completion_time = result.testCompletionTime,
    check_speedtest_finished = result.check_speedtest_finished,
  })
end

local function parse_start_speed_test_body()
  local body = http.parse_body()

  if not util.includes(util.keys(SPEED_TEST_LINK_TYPE), body.link_type) then
    error({
      code = 400,
      message = "Invalid link type",
    })
  end

  if not verify.isIPv4(body.server_url) and not verify.isIPv6(body.server_url) and not verify.isDomainName(body.server_url) then
    error({
      code = 400,
      message = "Invalid server url",
    })
  end

  if body.omit_time ~= nil and (not verify.isInteger(body.omit_time) or body.omit_time < 0 or body.omit_time > 60) then
    error({
      code = 400,
      message = "Invalid omit time value",
    })
  end

  if body.server_port ~= nil and (not verify.isInteger(body.server_port) or body.server_port < 1024 or body.server_port > 49151) then
    error({
      code = 400,
      message = "Invalid server port value",
    })
  end

  if body.test_duration ~= nil and (not verify.isInteger(body.test_duration) or body.test_duration < 15 or body.test_duration > 600) then
    error({
      code = 400,
      message = "Invalid test duratione value",
    })
  end

  return body
end

function system_ctrl.start_speed_test()
  local body = parse_start_speed_test_body()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'speedtest',
    paramtable = {
      server = body.server_url,
      port = body.server_port,
      omit_sec = body.omit_time,
      max_bitrate_Mbits = 0,
      transmit_sec = body.test_duration,
      link_type = SPEED_TEST_LINK_TYPE[body.link_type],
    },
  }, { return_error = true }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('start speed test error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function system_ctrl.stop_speed_test()
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'speedtest',
    paramtable = {
      action = "Cancel",
    },
  }, { return_error = true }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('stop speed test error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

local function rpc_query_speed_test_status(times)
  if times == nil then
    times = 0
  end
  local result = ubus.connect():call('luxslam', 'sys', {
    cmd = 'get',
    class = 'speedtest'
  }, { return_error = true }).paramtable
  if result.err_code ~= nil then
    error({
      code = 403,
      message = string.format('Something went wrong, try again')
    })
  end
  if result.check_speedtest_finished ~= 1 then
    util.sleep(2)
    return rpc_query_speed_test_status(times + 1)
  end

  return result
end

local function parse_rpc_speed_test_param()
  local body = http.parse_form()

  if not util.includes(util.keys(SPEED_TEST_LINK_APP_TYPE), body.type) then
    error({
      code = 400,
      message = "Invalid request",
    })
  end

  if not verify.isIPv4(body.serverURL) and not verify.isIPv6(body.serverURL) and not verify.isDomainName(body.serverURL) then
    error({
      code = 400,
      message = "Invalid request",
    })
  end

  if body.omitTime ~= nil and (tonumber(body.omitTime) < 0 or tonumber(body.omitTime) > 60) then
    error({
      code = 400,
      message = "Invalid request",
    })
  end

  if body.port ~= nil and (tonumber(body.port) < 1024 or tonumber(body.port) > 49151) then
    error({
      code = 400,
      message = "Invalid request",
    })
  end

  if body.duration ~= nil and (tonumber(body.duration) < 15 or tonumber(body.duration) > 600) then
    error({
      code = 400,
      message = "Invalid request",
    })
  end

  return body
end

function system_ctrl.trigger_rpc_speed_test()
  local body = parse_rpc_speed_test_param()
  local trigger_res = ubus.connect():call('luxslam', 'sys', {
    cmd = 'set',
    class = 'speedtest',
    paramtable = {
      server = body['serverURL'],
      port = tonumber(body['port']),
      omit_sec = tonumber(body['omitTime']),
      max_bitrate_Mbits = 0,
      transmit_sec = tonumber(body['duration']),
      link_type = SPEED_TEST_LINK_APP_TYPE[body['type']],
    },
  }, { return_error = true }).paramtable
  if trigger_res.err_code ~= nil then
    error({
      code = 403,
      message = string.format('Something went wrong, try again')
    })
  end

  local speed_test_res = rpc_query_speed_test_status()
  local status = (speed_test_res.status == 0) and "Pass" or "Fail"
  http:status(200):json({
    status = status,
    dataRateUL = tostring(speed_test_res.uplinkDatarate),
    dataRateDL = tostring(speed_test_res.downlinkDatarate),
    timestamp = speed_test_res.testCompletionTime,
    type = body.type
  })
end

function system_ctrl.is_connecton_alive()
  -- TBD
  http:status(200):json({
    result = 'SUCCESS',
  })
end

return system_ctrl
