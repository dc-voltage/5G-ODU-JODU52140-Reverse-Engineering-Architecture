local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local alg_ctrl = {}

function alg_ctrl.get_info()
  local result = ubus.connect():call('luxslam', 'alg', {
    cmd = 'get',
    class = 'services',
  }).paramtable
  if (result.err_code == nil) then
    http:status(200):json({
      sip_enable = util.to_boolean(result.ftp_enable),
      rtsp_enable = util.to_boolean(result.rtsp_enable),
      h323_enable = util.to_boolean(result.h323_enable),
      ftp_enable = util.to_boolean(result.ftp_enable),
      tftp_enable = util.to_boolean(result.tftp_enable),
      pptp_passthrough_enable = util.to_boolean(result.pptp_passthrough_enable),
      l2tp_passthrough_enable = util.to_boolean(result.l2tp_passthrough_enable),
      ipsec_passthrough_enable = util.to_boolean(result.ipsec_passthrough_enable),
    })
  else
    error({
      code = 500,
      message = string.format('Error code: %d', result.err_code),
    })
  end
end

---@param raw_body table
---@return table body
function alg_ctrl._parse_update_info_body(raw_body)
  local body = {}
  if verify.isBoolean(raw_body.sip_enable) then
    body.sip_enable = raw_body.sip_enable
  else
    error({
      code = 400,
      message = 'Invalid field sip_enable',
    })
  end
  if verify.isBoolean(raw_body.rtsp_enable) then
    body.rtsp_enable = raw_body.rtsp_enable
  else
    error({
      code = 400,
      message = 'Invalid field rtsp_enable',
    })
  end
  if verify.isBoolean(raw_body.h323_enable) then
    body.h323_enable = raw_body.h323_enable
  else
    error({
      code = 400,
      message = 'Invalid field h323_enable',
    })
  end
  if verify.isBoolean(raw_body.ftp_enable) then
    body.ftp_enable = raw_body.ftp_enable
  else
    error({
      code = 400,
      message = 'Invalid field ftp_enable',
    })
  end
  if verify.isBoolean(raw_body.tftp_enable) then
    body.tftp_enable = raw_body.tftp_enable
  else
    error({
      code = 400,
      message = 'Invalid field tftp_enable',
    })
  end
  if verify.isBoolean(raw_body.pptp_passthrough_enable) then
    body.pptp_passthrough_enable = raw_body.pptp_passthrough_enable
  else
    error({
      code = 400,
      message = 'Invalid field pptp_passthrough_enable',
    })
  end
  if verify.isBoolean(raw_body.l2tp_passthrough_enable) then
    body.l2tp_passthrough_enable = raw_body.l2tp_passthrough_enable
  else
    error({
      code = 400,
      message = 'Invalid field l2tp_passthrough_enable',
    })
  end
  if verify.isBoolean(raw_body.ipsec_passthrough_enable) then
    body.ipsec_passthrough_enable = raw_body.ipsec_passthrough_enable
  else
    error({
      code = 400,
      message = 'Invalid field ipsec_passthrough_enable',
    })
  end
  return body
end

function alg_ctrl.update_info()
  local body = alg_ctrl._parse_update_info_body(http.parse_body())
  local conn = ubus.connect()
  local result = conn:call('luxslam', 'alg', {
    cmd = 'set',
    class = 'services',
    paramtable = {
      sip_enable = body.sip_enable,
      rtsp_enable = body.rtsp_enable,
      h323_enable = body.h323_enable,
      ftp_enable = body.ftp_enable,
      tftp_enable = body.tftp_enable,
      pptp_passthrough_enable = body.pptp_passthrough_enable,
      l2tp_passthrough_enable = body.l2tp_passthrough_enable,
      ipsec_passthrough_enable = body.ipsec_passthrough_enable,
    },
  }).paramtable
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

return alg_ctrl
