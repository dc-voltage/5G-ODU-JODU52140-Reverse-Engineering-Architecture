local util = require('lux-util')

local logger = {
  DEBUG = 10,
  INFO = 20,
  WARN = 30,
  ERROR = 40,
}

local _log_level = (os.getenv('APP_LOG_LEVEL') or logger.DEBUG) + 0

---
---@param log_level_flag string
---@param message string
local function write_file(log_level_flag, message)
  local priority = 6
  if log_level_flag == 'ERROR' then
    priority = 3
  elseif log_level_flag == 'WARN' then
    priority = 4
  elseif log_level_flag == 'INFO' then
    priority = 6
  elseif log_level_flag == 'DEBUG' then
    priority = 7
  end
  util.safe_execute(string.format('logger -t http -p %d %s', priority, util.shellquote(message)))
end

---
---@param t table
---@return string
local function format_message(t)
  local output = ''
  for i, v in ipairs(t)
    do
      if (i == 1)
      then
        output = tostring(v)
      else
        output = output .. ' ' .. tostring(v)
      end
    end
  return output
end

function logger.debug(...)
  if (_log_level <= logger.DEBUG)
  then
    write_file('DEBUG', format_message(arg))
  end
end

function logger.info(...)
  if (_log_level <= logger.INFO)
  then
    write_file('INFO', format_message(arg))
  end
end

function logger.warn(...)
  if (_log_level <= logger.WARN)
  then
    write_file('WARN', format_message(arg))
  end
end

function logger.error(...)
  if (_log_level <= logger.ERROR)
  then
    write_file('ERROR', format_message(arg))
  end
end

return logger
