local http = require('lux-http')
local util = require('lux-util')
local ubus = require('lux-ubus')
local verify = require('lux-verify')
local diagnostic_ctrl = {}

local routing_table_type = {"IPv4", "IPv6"}

local function parse_format_body()
  local body = http.parse_body()
  if (verify.isIPv4(body.value) or verify.isIPv6(body.value) or verify.isDomainName(body.value)) then
    return body
  end

  error({
    code = 400,
    message = "Invalid value",
  })
end

local function parse_routing_table_body()
  local body = http.parse_body()
  if not util.includes(routing_table_type, body.value) then
    error({
      code = 400,
      message = "Invalid value",
    })
  end
  return body
end

function diagnostic_ctrl.get_ping_traceroute_status()
  local body = http.parse_body()
  local conn = ubus.connect()
  local result

  if body.type == 'PING' then
    result = conn:call('luxslam', 'diagnostic', {
        cmd = 'get',
        class = 'ping',
    }).paramtable
  elseif body.type == 'TRACEROUTE' then
    result = conn:call('luxslam', 'diagnostic', {
      cmd = 'get',
      class = 'traceroute',
    }).paramtable
  end

  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('get status error: %d', result.err_code),
    })
  end
  http:status(200):json({
    result = 'SUCCESS',
    status = result.status
  })
end

function diagnostic_ctrl.start_ping_traceroute()
  local body = parse_format_body()
  local conn = ubus.connect()
  local result

  if body.type == 'PING' then
    result = conn:call('luxslam', 'diagnostic', {
      cmd = 'set',
      class = 'ping',
      paramtable = {
        domain_name = body.value,
        start = '1'
      },
    }).paramtable
  elseif body.type == 'TRACEROUTE' then
    result = conn:call('luxslam', 'diagnostic', {
      cmd = 'set',
      class = 'traceroute',
      paramtable = {
        domain_name = body.value,
        start = '1'
      },
    }).paramtable
  end

  if result and result.err_code ~= nil  then
    error({
      code = 500,
      message = string.format('start error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function diagnostic_ctrl.get_ping_traceroute6_status()
  local body = http.parse_body()
  local conn = ubus.connect()
  local result

  if body.type == 'PING6' then
    result = conn:call('luxslam', 'diagnostic', {
        cmd = 'get',
        class = 'ping6',
    }).paramtable
  elseif body.type == 'TRACEROUTE6' then
    result = conn:call('luxslam', 'diagnostic', {
      cmd = 'get',
      class = 'traceroute6',
    }).paramtable
  end

  http:status(200):json({
    result = 'SUCCESS',
    status = result.status
  })
end

function diagnostic_ctrl.start_ping_traceroute6()
  local body = parse_format_body()
  local conn = ubus.connect()
  local result

  if body.type == 'PING6' then
    result = conn:call('luxslam', 'diagnostic', {
      cmd = 'set',
      class = 'ping6',
      paramtable = {
        domain_name = body.value,
        start = '1'
      },
    }).paramtable
  elseif body.type == 'TRACEROUTE6' then
    result = conn:call('luxslam', 'diagnostic', {
      cmd = 'set',
      class = 'traceroute6',
      paramtable = {
        domain_name = body.value,
        start = '1'
      },
    }).paramtable
  end

  if result and result.err_code ~= nil  then
    error({
      code = 500,
      message = string.format('start error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function diagnostic_ctrl.get_dns_lookup_status()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'diagnostic', {
    cmd = 'get',
    class = 'dns',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('get status error: %d', result.err_code),
    })
  end
  http:status(200):json({
    result = 'SUCCESS',
    status = result.status
  })
end

function diagnostic_ctrl.dns_lookup()
  local body = parse_format_body()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'diagnostic', {
    cmd = 'set',
    class = 'dns',
    paramtable = {
      internet_name = body.value,
      start = '1'
    },
  }).paramtable

  if result and result.err_code ~= nil  then
    error({
      code = 500,
      message = string.format('start error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function diagnostic_ctrl.get_display_routing_table_status()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'diagnostic', {
    cmd = 'get',
    class = 'routing_table',
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('get status error: %d', result.err_code),
    })
  end
  http:status(200):json({
    result = 'SUCCESS',
    status = result.status
  })
end

function diagnostic_ctrl.display_routing_table()
  local body = parse_routing_table_body()
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'diagnostic', {
    cmd = 'set',
    class = 'routing_table',
    paramtable = {
      address_family = body.value,
      start = '1'
    },
  }).paramtable

  if result and result.err_code ~= nil  then
    error({
      code = 500,
      message = string.format('start error: %d', result.err_code),
    })
  end

  http:status(200):json({
    result = 'SUCCESS',
  })
end

function diagnostic_ctrl.print_result_message()
  local fn = io.open('/tmp/lux_sal_diagnostic_res.txt', 'rb')
  if fn == nil then
    error({ code = 404 })
  end

  http:status(200):json({
    result = 'SUCCESS',
    message = fn:read('*all')
  })
  fn:close()
end

function diagnostic_ctrl.is_connecton_alive()
  -- TBD
  http:status(200):json({
    result = 'SUCCESS',
  })
end

return diagnostic_ctrl
