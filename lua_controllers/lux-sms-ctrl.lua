local ubus = require('lux-ubus')
local http = require('lux-http')
local util = require('lux-util')
local verify = require('lux-verify')
local logger = require('lux-logger')
local sms_ctrl = {}

local MAX_CONTACTS = 200
local MAX_GROUPS = 100

local function query_contact_list()
  local conn = ubus.connect()
  local contacts = util.map(conn:uci_find_many({
    config = 'sms',
    type = 'contact',
  }), function(row)
    return {
      contact_id = row.contact_id,
      group_id = row.group_id,
      group_name = row.group_name,
      name = row.name,
      phone = row.phone
    }
  end)

  return contacts
end


function sms_ctrl.get_sms_settings()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'sms_settings',
  }).paramtable
  if (result.err_code == nil) then
    http:status(200):json({
      center_number = result.center_number,
      sms_report = util.to_boolean(result.sms_report),
      result = "SUCCESS"
    })
  else
    error({
      code = 500,
      message = string.format('SMS Setttings get error: %d', result.err_code),
    })
  end
end

local function parse_sms_settings_body()
  local body = http.parse_body()
  if not body.center_number:match("^[%d%p]*$") then
    error({
      code = 400,
      message = "Invalid center_number",
    })
  end
  if not verify.isBoolean(body.sms_report) then
    error({
      code = 400,
      message = "Invalid sms_report",
    })
  end
  return body
end

function sms_ctrl.set_sms_settings()
  local body = parse_sms_settings_body()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'set',
    class = 'sms_settings',
    paramtable = {
      center_number = body.center_number,
      sms_report = body.sms_report,
    },
  }).paramtable
  if (result.err_code == nil) then
    http:status(200):json({
      result = "SUCCESS"
    })
  else
    error({
      code = 500,
      message = string.format('SMS Setttings set error: %d', result.err_code),
    })
  end
end

local SENT_SMS_STATUS = {
    NO_STATUS = 0,
    DELIVERED = 1,
    NOT_DELIVERED = 2,
    NOT_SENT = 3
}

local DATE_FORMAT = '%Y-%m-%d %H:%M:%S'

function convert_sms_data(item)
  local sms_status_mapping = {
      delivered = SENT_SMS_STATUS.DELIVERED,
      not_delivered = SENT_SMS_STATUS.NOT_DELIVERED,
      delivered_fail = SENT_SMS_STATUS.NOT_DELIVERED,
      not_sent = SENT_SMS_STATUS.NOT_SENT
  }

  local smsData = {
    sms_id = item.sms_id,
    phone_number = item.phone_number,
    sms_content = item.message,
    timestamp = os.date(DATE_FORMAT, item.datetime),
    name = '',
    status = sms_status_mapping[item.status] or SENT_SMS_STATUS.NO_STATUS
  }

  local contact_list = query_contact_list()
  for _, contact in ipairs(contact_list) do
    if contact.phone == item.phone_number then
      smsData.name = contact.name
      break
    end
  end

  return smsData
end

function sms_ctrl.get_inbox_sms()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'sms_inbox',
  }).paramtable
  if (result ~= nil) then
    local smsDataList = {}
    for _, inboxItem in ipairs(result.inbox) do
      local smsData = convert_sms_data(inboxItem)
      table.insert(smsDataList, smsData)
    end

    http:status(200):json({
      sms_list = smsDataList
    })
  else
    error({
      code = 500,
      message = string.format('SMS Inbox get error: %d', result.err_code),
    })
  end
end

function sms_ctrl.delete_inbox_sms(env)
  local sms_ids =  http.parse_query(env).sms_ids
  if type(sms_ids) == "string" then
    sms_ids = {sms_ids}
  end
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'set',
    class = 'sms_inbox',
    paramtable = {
      action = 'Delete',
      inbox = util.map(sms_ids, function(sms_id)
        return {
          sms_id = sms_id,
        }
      end),
    }
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = 'SUCCESS',
    })
  else
    error({
      code = 400,
      message = string.format('SMS Inbox delete error: %d', result.err_code),
    })
  end
end

function sms_ctrl.get_sent_messages()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'sms_send',
  }).paramtable
  if (result ~= nil) then
    local smsDataList = {}
    for _, sendItem in ipairs(result.sent) do
      local smsData = convert_sms_data(sendItem)
      table.insert(smsDataList, smsData)
    end
    http:status(200):json({
      sms_list = smsDataList
    })
  else
    error({
      code = 500,
      message = string.format('SMS Sent get error: %d', result.err_code),
    })
  end
end

function sms_ctrl.delete_sms_sent(env)
  local sms_ids =  http.parse_query(env).sms_ids
  if type(sms_ids) == "string" then
    sms_ids = {sms_ids}
  end
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'set',
    class = 'sms_send',
    paramtable = {
      action = 'Delete',
      sent = util.map(sms_ids, function(sms_id)
        return {
          sms_id = sms_id,
        }
      end),
    }
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = 'SUCCESS',
    })
  else
    error({
      code = 400,
      message = string.format('SMS Sent delete error: %d', result.err_code),
    })
  end
end

---@param error_code string
---@return string
local function get_sms_error_code_message(error_code)
  logger.error(error_code)
  if error_code == '1002' then
    return 'SMS FULL'
  elseif error_code == '1003' then
    return 'INVALID INPUT'
  end
  return 'SMS SEND FAILED'
end

function sms_ctrl.send_sms()
  local body = http.parse_body()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'sms_inbox',
  }).paramtable
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'set',
    class = 'sms_send',
    paramtable = {
      action = 'Send',
      recipients = util.map(body.recipients, function(phone_number)
        return {
          phone_number = phone_number,
        };
      end),
      message = body.message
    }
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = 'SUCCESS',
    })
  else
    error({
      code = 400,
      message = get_sms_error_code_message(result.err_code),
    })
  end
end

function sms_ctrl.app_send_sms()
  local body = http.parse_body()
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'get',
    class = 'sms_inbox',
  }).paramtable
  local result = ubus.connect():call('luxslam', '5g', {
    cmd = 'set',
    class = 'sms_send',
    paramtable = {
      action = 'Send',
      recipients = util.map(util.split(body.recipients, ','), function(phone_number)
        return {
          phone_number = phone_number,
        };
      end),
      message = body.message
    }
  }, { return_error = true }).paramtable or {}
  if result.err_code == nil then
    http:status(200):json({
      result = 'SUCCESS',
    })
  else
    error({
      code = 400,
      message = "Invalid recipients or message",
    })
  end
end

function sms_ctrl.get_contact_list()
  local contacts = query_contact_list()

  if contacts ~= nil then
    http:status(200):json({
      contact_list = contacts
    })
  else
    error({
      code = 500,
      message = 'unknown method',
    })
  end
end

local function is_contact_exist(contact_id, phone)
  local conn = ubus.connect()
  local match = {}
  if contact_id ~= nil then
    match.contact_id = contact_id
  end

  if phone ~= nil then
    match.phone = phone
  end

  local contact = conn:uci_find_one({
    config = 'sms',
    type = 'contact',
    match = match
  });
  if contact ~= nil then
    return true
  end
  return false
end

local function is_group_exist(name)
  local conn = ubus.connect()
  local group = conn:uci_find_one({
    config = 'sms',
    type = 'group',
    match = {
      name = name
    }
  });
  if group ~= nil then
    return true
  end
  return false
end

local function is_max_contact_reached()
  local conn = ubus.connect()
  local contacts = conn:uci_find_many({
    config = 'sms',
    type = 'contact',
  });
  local total_contacts = #contacts
  if total_contacts + 1 > MAX_CONTACTS then
    return true
  end
  return false
end

local function is_max_group_reached()
  local conn = ubus.connect()
  local groups = conn:uci_find_many({
    config = 'sms',
    type = 'group',
  });
  local total_groups = #groups
  if total_groups + 1 > MAX_GROUPS then
    return true
  end
  return false
end

function sms_ctrl.create_contact()
  local body = http.parse_body()
  local conn = ubus.connect()
  local group_id

  local is_max_contact_reached = is_max_contact_reached()
  if is_max_contact_reached then
    error({ code = 400, message = 'CONTACTS FULL' })
  end

  local is_contact_phone_exist = is_contact_exist(nil, body.phone)
  if is_contact_phone_exist then
    error({ code = 400, message = 'CONTACT EXISTS' })
  end

  if body.is_new_group then
    local is_max_group_reached = is_max_group_reached()
    if is_max_group_reached then
      error({ code = 400, message = 'GROUPS FULL' })
    end
    local is_group_exist = is_group_exist(body.group)
    if is_group_exist then
      error({ code = 400, message = 'GROUP EXISTS' })
    end

    group_id = util.generate_id()
    conn:uci_insert('sms', 'group', {
      group_id = group_id,
      name = body.group,
      description = '',
    })
    conn:uci_commit('sms')
  else
    group_id = body.group_id
  end

  conn:uci_insert('sms', 'contact', {
    contact_id = util.generate_id(),
    name = body.name,
    phone = body.phone,
    group_id = group_id,
    group_name = body.group
  })
  conn:uci_commit('sms')
  http:status(200):json({
    result = 'SUCCESS'
  })
end

function sms_ctrl.update_contact()
  local body = http.parse_body()
  local conn = ubus.connect()
  local group_id

  local original_contact = conn:uci_find_one({
    config = 'sms',
    type = 'contact',
    match = {
      contact_id = body.contact_id
    },
  });

  if original_contact.phone ~= body.phone then
    local is_phone_exist = is_contact_exist(nil, body.phone)
    if is_phone_exist then
      error({ code = 400, message = 'CONTACT EXISTS' })
    end
  end

  if body.is_new_group then
    local is_group_exist = is_group_exist(body.group)
    if is_group_exist then
      error({ code = 400, message = 'GROUP EXISTS' })
    end
    group_id = util.generate_id()
    conn:uci_insert('sms', 'group', {
      group_id = group_id,
      name = body.group,
      description = '',
    })
    conn:uci_commit('sms')
  else
    group_id = body.group_id
  end

  conn:call('uci', 'set', {
    config = 'sms',
    type = 'contact',
    match = {
      contact_id = body.contact_id
    },
    values = {
      contact_id = body.contact_id,
      name = body.name,
      phone = body.phone,
      group_id = group_id,
      group_name = body.group
    }
  });

  conn:uci_commit('sms')
  http:status(200):json({
    result = 'SUCCESS'
  })
end

function sms_ctrl.delete_contact(env)
  local contact_ids =  http.parse_query(env).contact_ids
  local conn = ubus.connect()

  if type(contact_ids) == 'string' then
    contact_ids = {contact_ids}
  end

  for _, id in ipairs(contact_ids) do
    conn:call('uci', 'delete', {
      config = 'sms',
      type = 'contact',
      match = {
        contact_id = id
      },
    });
  end

  conn:uci_commit('sms')
  http:status(200):json({
    result = 'SUCCESS'
  })
end

function sms_ctrl.move_to_group()
  local body = http.parse_body()
  local conn = ubus.connect()

  for _, id in ipairs(body.contact_ids) do
    conn:call('uci', 'set', {
      config = 'sms',
      type = 'contact',
      match = {
        contact_id = id
      },
      values = {
        group_name = body.group_name,
        group_id = body.group_id,
      }
    });
  end

  conn:uci_commit('sms')
  http:status(200):json({
    result = 'SUCCESS'
  })
end

function sms_ctrl.get_group_list()
  local conn = ubus.connect()
  local groups = util.map(conn:uci_find_many({
    config = 'sms',
    type = 'group',
  }), function(row)
    local members = conn:uci_find_many({
      config = 'sms',
      type = 'contact',
      match = {
        group_id = row.group_id,
      },
    });
    return {
      description = row.description,
      group_id = row.group_id,
      name = row.name,
      total_contacts = #members,
    }
  end)
  conn:uci_commit('sms')

  if (groups ~= nil) then
    http:status(200):json({
      group_list = groups
    })
  else
    error({
      code = 500,
      message = 'unknown method',
    })
  end
end

function sms_ctrl.create_group()
  local body = http.parse_body()
  local conn = ubus.connect()

  local is_max_group_reached = is_max_group_reached()
  if is_max_group_reached then
    error({ code = 400, message = 'GROUPS FULL' })
  end

  local is_group_exist = is_group_exist(body.name)
  if is_group_exist then
    error({ code = 400, message = 'GROUP EXISTS' })
  end

  conn:uci_insert('sms', 'group', {
    group_id = util.generate_id(),
    name = body.name,
    description = body.description,
  })
  conn:uci_commit('sms')
  http:status(200):json({
    result = 'SUCCESS'
  })
end

function sms_ctrl.update_group()
  local body = http.parse_body()
  local conn = ubus.connect()
  local group = conn:uci_find_one({
    config = 'sms',
    type = 'group',
    match = {
      group_id = body.group_id,
    },
  });
  if group == nil then
    error({ code = 400, message = 'INVALID INPUT' })
  end

  if group.name ~= body.name then
    local is_name_exist = is_group_exist(body.name)
    if is_name_exist then
      error({ code = 400, message = 'GROUP EXISTS' })
    end
  end

  conn:call('uci', 'set', {
    config = 'sms',
    type = 'group',
    match = {
      group_id = body.group_id,
    },
    values = {
      group_id = body.group_id,
      name = body.name,
      description = body.description,
    },
  })
  conn:uci_commit('sms')
  http:status(200):json({
    result = 'SUCCESS'
  })
end

local function clean_contact_group(group_id)
  local conn = ubus.connect()
  conn:call('uci', 'set', {
    config = 'sms',
    type = 'contact',
    match = {
      group_id = group_id
    },
    values = {
      group_id = '0',
      group_name = ''
    }
  })

  conn:uci_commit('sms')

  return
end

function sms_ctrl.delete_group(env)
  local group_ids =  http.parse_query(env).group_ids
  local conn = ubus.connect()

  if type(group_ids) == 'string' then
    group_ids = {group_ids}
  end

  for _, id in ipairs(group_ids) do
    local is_group_used = conn:uci_find_one({
      config = 'sms',
      type = 'contact',
      match = {
        group_id = id,
      },
    });
    if is_group_used ~= nil then
      clean_contact_group(id)
    end
  end

  for _, id in ipairs(group_ids) do
    conn:call('uci', 'delete', {
      config = 'sms',
      type = 'group',
      match = {
        group_id = id
      },
    });
  end

  conn:uci_commit('sms')
  http:status(200):json({
    result = 'SUCCESS'
  })
end

function sms_ctrl.send_group_sms()
  local body = http.parse_body()
  local conn = ubus.connect()
  local recipients = util.map(conn:uci_find_many({
    config = 'sms',
    type = 'contact',
    match = {
      group_id = body.group_id,
    },
  }), function(row)
    return {
      phone_number = row.phone,
    }
  end)
  if #recipients == 0 then
    error({
      code = 400,
      message = 'GROUP EMPTY',
    })
  end

  local batch_size = 10
  local total_batches = math.ceil(#recipients / batch_size)

  for i = 1, total_batches do
    local start_index = (i - 1) * batch_size + 1
    local end_index = math.min(i * batch_size, #recipients)
    local batch_recipients = { unpack(recipients, start_index, end_index) }

    local result = ubus.connect():call('luxslam', '5g', {
      cmd = 'set',
      class = 'sms_send',
      paramtable = {
        action = 'Send',
        recipients = batch_recipients,
        message = body.message
      }
    }, { return_error = true }).paramtable or {}

    if result.err_code ~= nil then
      error({
        code = 400,
        message = get_sms_error_code_message(result.err_code),
      })
    end
  end

  http:status(200):json({
    result = 'SUCCESS'
  })
end

return sms_ctrl
