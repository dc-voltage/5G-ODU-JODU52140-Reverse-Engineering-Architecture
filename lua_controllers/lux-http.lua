local json = require('luci.jsonc')
local util = require('lux-util')
local logger = require('lux-logger')

local http = {}

---@param last_value nil or talbe or string
local function get_initial_value(last_value)
  if last_value == nil then
    return ''
  elseif type(last_value) == 'table' then
    last_value[#last_value + 1] = ''
    return last_value
  else
    return {last_value, ''}
  end
end

---@param last_value string or table
---@param value any
local function get_new_value(last_value, value)
  if type(last_value) == 'table' then
    last_value[#last_value] = value
    return last_value
  else
    return value
  end
end

---
--- @param query_string string
--- @return table
local function parse_query_string(query_string)
  local data = {}
  local left = 1
  local separated = '[=&]'
  local key = ''
  local query_string_length = #query_string
  while left < query_string_length do
    local right = string.find(query_string, separated, left)
    if (right ~= nil) then
      if separated == '[=&]' then
        key = string.sub(query_string, left, right - 1)
        data[key] = get_initial_value(data[key])
        if string.sub(query_string, right, right) == '=' then
          separated = '&'
        end
      else
        data[key] = get_new_value(data[key], string.sub(query_string, left, right - 1))
        separated = '[=&]'
      end
      left = right + 1
    else
      if separated == '&' then
        data[key] = get_new_value(data[key], string.sub(query_string, left, query_string_length) or '')
      end
      left = query_string_length
    end
  end
  return data
end

---
--- @return table
function http.parse_form()
  local _ , content = uhttpd.recv()
  local body = {}
  for key, value in pairs(parse_query_string(content)) do
    body[key] = uhttpd.urldecode(value)
  end
  return body
end

---
--- @param env table
--- @return table
function http.parse_query(env)
  return parse_query_string(uhttpd.urldecode(env['QUERY_STRING']))
end

---
--- @param env table
--- @return table
function http.parse_cookies(env)
  local cookies = {}
  for _, key_and_value in ipairs(util.split(env['HTTP_COOKIE'] or '', ';')) do
    local i, j = string.find(key_and_value, '=')
    if i ~= nil then
      local key = string.sub(key_and_value, 1, i - 1)
      key = string.gsub(string.gsub(key, '^[ ]+', ''), '[ ]+$', '')
      local value = string.sub(key_and_value, j + 1, #key_and_value)
      value = string.gsub(string.gsub(value, '^[ ]+', ''), '[ ]+$', '')
      cookies[key] = uhttpd.urldecode(value)
    end
  end
  return cookies
end

---
function http.parse_body()
  local _, content = uhttpd.recv()
  if content == nil then
    return {}
  end
  local data = json.parse(content)
  if (data == nil) then
    error({ code = 400, error = 'Invalid JSON format' })
  end
  return data
end

---
---@param env table
---@return string path
---@return string method
function http.parse_path_and_method(env)
  local path = env['SCRIPT_NAME'] .. (env['PATH_INFO'] or '')
  return path, env['REQUEST_METHOD']
end

---
--- @param text string
function http.send_with_ending(text)
  uhttpd.send(text .. '\r\n')
end

---
--- @param text string
function http.send(text)
  uhttpd.send(text)
end

---
---@param status_code number
function http.status(self, status_code)
  if (status_code == 200) then
    self.send_with_ending('Status: 200 OK')
  elseif (status_code == 400) then
    self.send_with_ending('Status: 400 Bad Request')
  elseif (status_code == 401) then
    self.send_with_ending('Status: 401 Unauthorized')
  elseif (status_code == 403) then
    self.send_with_ending('Status: 403 Forbidden')
  elseif (status_code == 404) then
    self.send_with_ending('Status: 404 Not Found')
  else
    self.send_with_ending('Status: 500 Internal Server Error')
  end
  return self
end

---
---@param data table
function http.json(self, data)
  self.send_with_ending('Content-Type: application/json; charset=utf-8')
  local res_json = json.stringify(data)
  self.send_with_ending('')
  self.send(res_json)
  logger.debug('Response', res_json)
end

---
---@param data Array
function http.ordered_json(self, data)
  self.send_with_ending('Content-Type: application/json; charset=utf-8')
  local res_json = self._to_ordered_json_string(data)
  self.send_with_ending('')
  self.send(res_json)
  logger.debug('Response', res_json)
end

---@param collection Array
---@return string
function http._to_ordered_json_string(collection)
  return string.format('{%s}',  util.join(util.reduce(collection, function(out, row)
    for key, value in pairs(row) do
      local json_key = json.stringify(tostring(key))
      if type(value) == 'table' then
        if #value > 0 then
          table.insert(out, string.format('%s:[%s]', json_key, util.join(util.map(value, function(sub_row)
            return http._to_ordered_json_string(sub_row)
          end)), ','))
        else
          local sub_obj = http._to_ordered_json_string({value})
          if sub_obj == '{}' then
            sub_obj = '[]'
          end
          table.insert(out, string.format('%s:%s', json_key, sub_obj))
        end
      else
        table.insert(out, string.format('%s:%s', json_key, json.stringify(value)))
      end
    end
    return out
  end, {}), ','))
end

local CONTENT_TYPE_MAP = {
  ['.pdf'] = 'application/pdf',
  ['.tar.gz'] = 'application/x-targz',
  ['.tar'] = 'application/x-tar',
  ['.txt'] = 'text/plain',
  ['.zip'] = 'application/zip',
}

---
---@param filename string
function http.attachment(self, filename)
  local extname = util.join(util.map(util.split(filename, '.'), function(value, index)
    if index == 1 then
      return ''
    end
    return value
  end), '.')
  local content_type = CONTENT_TYPE_MAP[extname]
  if content_type == nil then
    error({
      code = 500,
      message = 'Unsupported extname'
    })
  end
  self.send_with_ending(string.format('Content-Type: %s', content_type))
  self.send_with_ending(string.format('Content-Disposition: attachment; filename="%s"\r\n', filename))
  return self
end

---
---@param path string
---@param filename string
function http.download(self, path, filename)
  local fn = io.open(path, 'rb')
  if fn == nil then
    error({ code = 404 })
  end
  self:attachment(filename)
  self.send(fn:read('*all'))
  fn:close()
end

---
---@param name string
---@param value string
function http.cookie(self, name, value)
  self.send_with_ending(string.format('Set-Cookie: %s=%s', name, uhttpd.urlencode(value)))
  return self
end

return http
