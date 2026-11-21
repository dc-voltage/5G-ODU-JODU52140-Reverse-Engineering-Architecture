local ubus = require('ubus')

local lux_ubus = {}

function lux_ubus.connect()
  return lux_ubus
end

---
---@param path string
---@param method string
---@param message table
---@param option nil | table
function lux_ubus:call(path, method, message, option)
  option = option or {}
  local return_error = option.return_error or false
  if return_error then
    return ubus.connect():call_return_error(path, method, message)
  end
  return ubus.connect():call(path, method, message)
end

---
---@param config string
---@param stype nil or string
---@param option nil or string
---@return nil or string or number or table
function lux_ubus:uci_get_first(config, stype, option)
  local values = self:call('uci', 'get', {
    config = config,
    type = stype,
  }).values
  local min_index = 0xffffffff
  local result
  for _, value in pairs(values) do
    if value['.index'] < min_index then
      min_index = value['.index']
      result = value
    end
  end
  if stype == nil then
    return result
  elseif option == nil then
    return result
  elseif type(result) == 'table' then
    return result[option]
  else
    return result
  end
end

---
---@param config string
---@param stype string
---@param values table
function lux_ubus:uci_set_first(config, stype, values)
  local old_values = self:uci_get_first(config, stype)
  if old_values == nil then
    error({
      code = 500,
      message = 'Invalid config',
    })
  end
  local section = old_values['.name']
  return self:call('uci', 'set', {
    config = config,
    type = stype,
    section = section,
    values = values,
  })
end

---
---@param config string
---@param section string
---@return table
function lux_ubus:uci_get(config, section)
  local result = self:call('uci', 'get', {
    config = config,
    section = section,
  })
  if result == nil then
    return result
  end
  return result.values
end

---
---@param config string
---@param section string
---@param values table
---@return table
function lux_ubus:uci_set(config, section, values)
  local result = self:call('uci', 'set', {
    config = config,
    section = section,
    values = values,
  })
  return result
end

---
---@param query table
---@return nil or table
function lux_ubus:uci_find_one(query)
  local values = self:call('uci', 'get', query).values
  for _, value in pairs(values) do
    return value
  end
  return nil
end

---
---@param query table
---@return table
function lux_ubus:uci_find_many(query)
  local values = self:call('uci', 'get', query).values
  local result = {}
  for _, value in pairs(values) do
    table.insert(result, value)
  end
  return result
end


---
---@param config string
---@param stype string
---@param section string
---@param values table
function lux_ubus:uci_upsert(config, stype, section, values)
  local result = self:call('uci', 'add', {
    config = config,
    type = stype,
    name = section,
    values = values,
  })
  return result
end

---
---@param config string
---@param stype string
---@param values table
function lux_ubus:uci_insert(config, stype, values)
  local result = self:call('uci', 'add', {
    config = config,
    type = stype,
    values = values,
  })
  return result
end

---
---@param config string
---@param stype string
---@return table
function lux_ubus:uci_get_all_by_type(config, stype)
  local result = self:call('uci', 'get', {
    config = config,
    type = stype,
  })
  local output = {}
  local i = 0
  for _, value in pairs(result.values) do
    i = i + 1
    output[i] = value
  end
  return output
end

---
---@param config string
---@param section string
---@return table
function lux_ubus:uci_delete(config, section)
  local result = self:call('uci', 'delete', {
    config = config,
    section = section,
  })
  return result
end

---
---@param config string
function lux_ubus:uci_commit(config)
  return self:call('uci', 'commit', {
    config = config
  })
end

return lux_ubus
