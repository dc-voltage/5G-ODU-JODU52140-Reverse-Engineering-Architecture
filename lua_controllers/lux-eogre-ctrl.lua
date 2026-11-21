local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local eogre_ctrl = {}

local IP_ADDRESS_TYPE = {
  IPV4 = 'IPv4',
  IPV6 = 'IPv6',
}

local function query_eogre_rule_list(times)
  if times == nil then
    times = 0
  end

  local result = ubus.connect():call('luxslam', 'eogre', {
    cmd = 'get',
    class = 'rule_list',
  }, { return_error = true })

  if times < 5 and (result == nil or result.paramtable == nil) then
    util.sleep(1)
    return query_eogre_rule_list(times + 1)
  end

  if times > 5 and (result == nil or result.paramtable == nil or result.paramtable.err_code ~= nil) then
    error({
      code = 500,
      message = string.format('EoGRE error: %d', result.paramtable.err_code),
    })
  end

  return result.paramtable.list or {}
end

function eogre_ctrl.get_info()
  local data = query_eogre_rule_list()
  local eogre_rules = util.map(data, function(rule, index)
    return {
      id = index,
      tunnel_name = rule.tunnel_name,
      ip_address_type = util.invert(IP_ADDRESS_TYPE)[rule.ip_version],
      local_endpoint_ip = rule.local_ip_addr,
      remote_endpoint_ip = rule.remote_ip_addr,
      maximum_ethernet_mtu = tonumber(rule.mtu),
      vlan = rule.vlan_id,
      status = util.to_boolean(rule.enable),
    }
  end)
  http:status(200):json({
    eogre_rules = eogre_rules,
  })
end

local function parse_eogre_rule_body(raw_body)
    local body = {}
    body.indexId = raw_body.indexId

    if verify.isString(raw_body.tunnel_name) and #raw_body.tunnel_name > 0 then
        body.tunnel_name = raw_body.tunnel_name
    else
        error({
            code = 400,
            message = 'Invalid field tunnel_name',
        })
    end
    if util.includes(util.keys(IP_ADDRESS_TYPE), raw_body.ip_address_type) then
        body.ip_address_type = raw_body.ip_address_type
        if body.ip_address_type == 'IPV4' then
            local _, err = verify.parse_ip(raw_body.remote_endpoint_ip)
            if err == nil then
                body.remote_endpoint_ip = raw_body.remote_endpoint_ip
            else
                error({
                    code = 400,
                    message = 'Invalid field remote_endpoint_ip',
                })
            end
        else
            --- TODO: verify IPv6
            body.remote_endpoint_ip = raw_body.remote_endpoint_ip
        end
    else
        error({
          code = 400,
          message = 'Invalid field ip_address_type',
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
    if raw_body.vlan then
        local vlan_ids = {}
        local valid = true
        local seen = {}
        for id in string.gmatch(raw_body.vlan, "%d+") do
          local num_id = tonumber(id)
          if num_id and num_id >= 0 and num_id <= 4093 then
              if seen[num_id] then
                  error({
                      code = 400,
                      message = 'Duplicate VLAN ID',
                  })
                  else
                      seen[num_id] = true
                      table.insert(vlan_ids, id)
                  end
              else
                  valid = false
                  break
              end
          end

        if not valid or #vlan_ids == 0 or #vlan_ids > 8 or string.match(raw_body.vlan, ",$") or string.match(raw_body.vlan, "[^%d,]") then
            error({
                code = 400,
                message = 'Invalid field vlan',
            })
        else
            body.vlan = raw_body.vlan
        end
    end
    return body
end

---@param rule_list Array
local function update_eogre_rule_list(rule_list)
  local result = ubus.connect():call('luxslam', 'eogre', {
    cmd = 'set',
    class = 'rule_list',
    paramtable = {
      list = util.map(rule_list, function(row)
        return {
          enable = util.to_boolean(row.enable),
          ip_version = row.ip_version,
          tunnel_name = row.tunnel_name,
          remote_ip_addr = row.remote_ip_addr,
          vlan_id = row.vlan_id,
        }
      end),
    },
  }).paramtable
  if result.err_code ~= nil then
    error({
      code = 500,
      message = string.format('Update EoGRE error: %d', result.err_code),
    })
  end
end

function eogre_ctrl.add_eogre_rule()
  local body = parse_eogre_rule_body(http:parse_body())
  local rule_list = query_eogre_rule_list()
  local exists = util.find(rule_list, function(rule)
    return rule.tunnel_name == body.tunnel_name
  end)
  if exists then
  error({
    code = 429,
    message = 'FILE EXIST',
  })
  end

  table.insert(rule_list, {
    tunnel_name = body.tunnel_name,
    ip_version = IP_ADDRESS_TYPE[body.ip_address_type],
    remote_ip_addr = body.remote_endpoint_ip,
    vlan_id = body.vlan,
    enable = body.status
  })

  update_eogre_rule_list(rule_list)

  http:status(200):json({
      result = 'success',
  })
end

function eogre_ctrl.update_eogre_rule()
  local body = parse_eogre_rule_body(http:parse_body())
  local rule_list = query_eogre_rule_list(1)
  local found = rule_list[body.indexId]

  if not found then
    error({
      code = 400,
      message = 'Not found rule',
    })
  end

  found.tunnel_name = body.tunnel_name
  found.ip_version = IP_ADDRESS_TYPE[body.ip_address_type]
  found.remote_ip_addr = body.remote_endpoint_ip
  found.vlan_id = body.vlan
  found.enable = body.status

  update_eogre_rule_list(rule_list)

  http:status(200):json({
    result = 'SUCCESS'
  })
end

function eogre_ctrl.delete_eogre_rule(env)
  local query = http.parse_query(env)
  local rule_list = query_eogre_rule_list()
  table.remove(rule_list, query.indexId)
  update_eogre_rule_list(rule_list)

  http:status(200):json({
    result = 'SUCCESS',
  })
end

return eogre_ctrl
