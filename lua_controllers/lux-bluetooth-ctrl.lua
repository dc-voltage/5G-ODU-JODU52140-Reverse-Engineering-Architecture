local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local bluetooth_ctrl = {}

function bluetooth_ctrl.get_info()
  local conn = ubus.connect()
  local bluetooth = conn:call('luxslam', 'bluetooth', {
    cmd = 'get',
    class = 'general',
  }).paramtable
  http:status(200):json({
    result = 'SUCCESS',
    enabled = util.to_boolean(bluetooth.enable),
    connected_device = bluetooth.connected_device,
  });
end

function bluetooth_ctrl.set_info()
  local body = http.parse_body()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'bluetooth', {
    cmd = 'set',
    class = 'general',
    paramtable = {
      enable = body.enabled,
    },
  }).paramtable or {}
  if (result.err_code == nil) then
    http:status(200):json({
      result = 'SUCCESS',
    })
  else
    error({
      code = 500,
      message = string.format('Error code: %d', result.err_code),
    })
  end
end

function bluetooth_ctrl.disconnect()
  http:status(200):json({
    result = true,
  })
  local conn = ubus.connect()
  conn:call('luxslam', 'bluetooth', {
    cmd = 'set',
    class = 'general',
    paramtable = {
      action = "Reset",
    },
  })
end

return bluetooth_ctrl
