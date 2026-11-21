local logger = require('lux-logger')
local http = require('lux-http')
local route = require('lux-route')

---
---@param env table
function handle_request(env)
  local path, method = http.parse_path_and_method(env)
  logger.info(method, path)
  local status, err = pcall(route.handle_request, env)
  if status == false then
    local error_msg = 'unknown'
    local error_code = 500
    local error_type
    if type(err) == 'table' then
      error_type = err.type
      error_msg = err.message
      error_code = err.code or error_code
      if error_type == 'app' then
        error_code = 200
      end
      logger.error(method, path, error_code, error_msg)
    else
      logger.error(method, path, err)
    end
    if error_type == 'app' then
      http:status(error_code):json({
        result = false,
        msg_id = err.app_msg_id,
        message = error_msg,
        error_code = err.app_error_code,
      })
    else
      http:status(error_code):json({ error = error_msg })
    end
  end
end
