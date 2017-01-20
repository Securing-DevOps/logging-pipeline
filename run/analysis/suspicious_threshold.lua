require "string"
require "circular_buffer"

local rex = require "rex_pcre"
local xss = '((\%3C)|<)((\%2F)|\/)*[a-z0-9\%]+((\%3E)|>)'

-- client_stats stores traffic statistics per IP
-- by storing a 5 minutes circular buffer for each IP
-- If no traffic is received after 5 minutes, the stats
-- for a given IP are garbage collected.
local client_stats = {}

function ipv4_str_to_int(ipstr)
  local o1,o2,o3,o4 = ipstr:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
  local num = 2^24*o1 + 2^16*o2 + 2^8*o3 + o4
  return num
end

function process_message()
  local req = read_message("Fields[request]")
  local xss_matches = rex.match(req, xss)
  if not xss_matches then
    return 0
  end

  local ip = ipv4_str_to_int(read_message("Fields[remote_addr]"))
  local t = read_message("Timestamp")
  local cb = client_stats[ip]

  -- if this is the first time we see the IP,
  -- create a new circular buffer
  if not cb then
      cb = circular_buffer.new(5, 1, 60)
  end
  cb:add(t, 1, 1)

  -- sum up attempt over the last 5 minutes and if more than
  -- 50, send an alert payload
  local count = 0
  for _, v in ipairs(cb:get_range(1)) do
    if v > 0 then
      count = count + v
    end
  end
  if count > 50 then
    add_to_payload(
      string.format("ALERT: %d repeated xss attempts from %s\n",
        count, read_message("Fields[remote_addr]")))
  end

  -- store the circular buffer in the table
  client_stats[ip] = cb
  return 0
end

function timer_event()
  inject_payload("txt", "xss_threshold")
  for ip, cb in ipairs(client_stats) do
    local vals = cb:get_range(1)
    local isempty = true
    for _, v in ipairs(vals) do
      if v > 0 then
        isempty = false
      end
    end
    if isempty then client_stats[ip] = {} end
  end
end
