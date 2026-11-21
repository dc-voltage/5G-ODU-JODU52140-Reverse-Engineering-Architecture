local util = require('lux-util')
local lux_verify = {}

---@param ip string
---@return table? ip_addr
---@return string? error
function lux_verify.parse_ip(ip)
  local _, _, ip1, ip2, ip3, ip4 = string.find(ip, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if ip1 == nil then
    return nil, "Invalid IP"
  end
  local ip_addr = {tonumber(ip1), tonumber(ip2), tonumber(ip3), tonumber(ip4)}
  for _, sub_ip in ipairs(ip_addr) do
    if sub_ip > 0xff then
      return nil, "Invalid IP"
    end
  end
  return ip_addr
end

---@param value any
---@return boolean
function lux_verify.isBoolean(value)
  return type(value) == 'boolean'
end

---@param value Array
---@return integer
function lux_verify.indexOf(array, value)
  for index, _value in ipairs(array) do
    if value == _value then
      return index
    end
  end
  return -1
end

function lux_verify.isInteger(value)
  return type(value) == 'number' and value == math.floor(value)
end

function lux_verify.isString(value)
  return type(value) == 'string'
end

local function toBinaryString(num)
  local output = ''
  local number, remainder

  if (type(num) == 'number') then
    number = num
  elseif (type(num) == 'string') then
    number = tonumber(num)
  else
    return output
  end

  while number > 0 do
    remainder = number % 2
    output = remainder .. output
    number = math.floor(number / 2)
  end

  if output == '' then
    output = '0'
  end

  return output
end

function lux_verify.isValidIpv4SubnetMask(value)
  if type(value) ~= 'string' then
    return false, "Invalid type"
  end
  local _, _, ip1, ip2, ip3, ip4 = string.find(value, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if ip1 == nil or ip2 == nil or ip3 == nil or ip4 == nil then
    return false, "Invalid netmask"
  end
  local ips = {toBinaryString(ip1), toBinaryString(ip2), toBinaryString(ip3), toBinaryString(ip4)}
  local mask = util.join(ips, '')
  local result = util.split(mask, '0')
  local prefix_length = #result[1]
  if prefix_length > 32 then
    return false, "Invalid netmask"
  end
  return true
end

---@param input string
---@param target string
---@return boolean
function lux_verify.startsWith(input, target)
  return string.sub(input, 1, #target) == target
end

function lux_verify.isIPv4(input)
  local pattern = "^%d+%.%d+%.%d+%.%d+$"
  return string.match(input, pattern) ~= nil
end

function lux_verify.isIPv6(input)
  local pattern = "^[a-zA-Z0-9:.]+$"
  return string.match(input, pattern) ~= nil
end

function lux_verify.isDomainName(input)
  local pattern = "^[%w-]+%.[%w-.]+$"
  return string.match(input, pattern) ~= nil
end

function lux_verify.isMacAddress(input)
  local pattern = "%w+:%w+:%w+:%w+:%w+:%w+"
  return string.match(input, pattern) ~= nil
end

function lux_verify.isURL(input)
  local pattern = "^([%w-_%.%?%.:/&=]+)"
  return string.match(input, pattern) ~= nil
end

return lux_verify
