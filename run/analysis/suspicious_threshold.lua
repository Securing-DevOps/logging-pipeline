require "string"
require "circular_buffer"

local rex = require "rex_pcre"
local xss = '((\%3C)|<)((\%2F)|\/)*[a-z0-9\%]+((\%3E)|>)'

-- client_stats stores traffic statistics per IP
-- by storing a 5 minutes circular buffer for each IP
-- If no traffic is received after 5 minutes, the stats
-- for a given IP are garbage collected.
local client_stats = {}

-- client_violations countain a count of recorded violations
-- for each client IP. A violation is recorded when a client
-- triggers the violations_threshold
local client_violations = {}

local threshold = read_config("violations_threshold")

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

  local remote_addr = read_message("Fields[remote_addr]")
  local ip = ipv4_str_to_int(remote_addr)
  local t = read_message("Timestamp")
  local cb = client_stats[ip]

  -- if this is the first time we see the IP,
  -- create a new circular buffer
  if not cb then
      cb = circular_buffer.new(5, 1, 60)
  end
  cb:add(t, 1, 1)

  -- sum up violations over the last 5 minutes
  local count = 0
  local vals = cb:get_range(1)
  for i=1,5 do
    if vals[i] > 0 then
      count = count + vals[i]
    end
  end

  -- only send one violation per threshold increments
  -- if the threshold is 20, send it at 20, 40, 60, ...
  local pv = client_violations[ip]
  if pv then
    pv = pv + 1
  else
    pv = 1
  end
  if count >= (threshold * pv) then
    add_to_payload(
      string.format("ALERT: %d repeated xss attempts from %s\n",
        count, read_message("Fields[remote_addr]")))
    client_violations[ip] = pv
  end

  -- store the circular buffer in the table
  client_stats[ip] = cb
  return 0
end

function timer_event()
  inject_payload("txt", "xss_threshold")
  for ip, cb in pairs(client_stats) do
    local vals = cb:get_range(1)
    local isempty = true
    for i=1, 5 do
      if vals[i] > 0 then
        isempty = false
      end
    end
    if isempty then
      client_stats[ip] = nil
      client_violations[ip] = nil
    end
  end
end
