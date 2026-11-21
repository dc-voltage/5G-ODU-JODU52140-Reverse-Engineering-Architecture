local lux_util = {}

---@param command string
---@return string? output
function lux_util.popen(command)
  local pp = io.popen(command)
  if pp == nil then
    return nil
  end
  local data = pp:read("*a")
  pp:close()
  return data
end

---@param command string
---@return integer exitcode
function lux_util.safe_execute(command)
  return os.execute(command .. '>/dev/null 2>&1') / 256
end

---@param value string?
function lux_util.shellquote(value)
	return string.format("'%s'", string.gsub(value or "", "'", "'\\''"))
end

function lux_util.generate_id()
  return string.format('%06x%04x', os.time(), math.random(0, 0xFFFFFF))
end

---@param value any
function lux_util.to_boolean(value)
  return not lux_util.includes({0, false, ''}, value)
end

---@param collection Array
---@param iteratee function
---@return Array
function lux_util.map(collection, iteratee)
  local output = {}
  for index, row in ipairs(collection) do
    output[index] = iteratee(row, index, collection)
  end
  return output
end

---@param collection Array
---@param iteratee function
---@param accumulator any
---@return any
function lux_util.reduce(collection, iteratee, accumulator)
  local result = accumulator
  for index, row in ipairs(collection) do
    result = iteratee(result, row, index, collection)
  end
  return result
end

---@param input string
---@param separator nil or string
---@return Array
function lux_util.split(input, separator)
  if type(input) ~= "string" then
    return {}
  end
  if separator == nil then
    separator = ','
  elseif separator == '.' then
    separator = '%.'
  end
  local output = {}
  local i = 1
  local j, k = string.find(input, separator)
  while j ~= nil do
    local sub = string.sub(input, i, j-1)
    table.insert(output, sub)
    i = k + 1
    j, k = string.find(input, separator, i)
  end
  -- insert last substring (after last separator)
  table.insert(output, string.sub(input, i))
  return output
end

---@param array Array
---@param separator nil or string
---@return string
function lux_util.join(array, separator)
  if separator == nil then
    separator = ','
  end
  local output = ''
  for index, value in ipairs(array) do
    if index > 1 then
      output = output..separator..value
    else
      output = value
    end
  end
  return output
end

---@param collection Array
---@param predicate function
function lux_util.find(collection, predicate)
  for _, value in ipairs(collection) do
    if predicate(value) then
      return value
    end
  end
  return nil
end

---@param collection Array
---@param predicate function
function lux_util.filter(collection, predicate)
  local output = {}
  for index, value in ipairs(collection) do
    if predicate(value, index) then
      table.insert(output, value)
    end
  end
  return output
end

---@param array Array
function lux_util.last(array)
  return array[#array]
end

---@param object table
function lux_util.keys(object)
  local output = {}
  for key, _ in pairs(object) do
    table.insert(output, key)
  end
  return output
end

---@param object table
function lux_util.values(object)
  local output = {}
  for _, value in pairs(object) do
    table.insert(output, value)
  end
  return output
end

---@param object table
function lux_util.invert(object)
  local output = {}
  for key, value in pairs(object) do
    output[value] = key
  end
  return output
end

---@param collection table
---@return boolean
function lux_util.includes(collection, value)
  for _, v in ipairs(collection) do
    if v == value then
      return true
    end
  end
  return false
end

---@param n number
function lux_util.sleep(n)
  os.execute("sleep " .. tonumber(n))
end

---@param name string
function lux_util.fileExists(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

return lux_util
