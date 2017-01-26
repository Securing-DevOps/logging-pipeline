require "circular_buffer"
require "cuckoo_filter"
require "os"
require "math"
require "string"

local mv_avg_min  = read_config("moving_average_minutes")
local max_cli_min = read_config("max_clients_per_min")

local reqcnt = circular_buffer.new(mv_avg_min, 1, 60)
local seenip = {}

function ipv4_str_to_int(ipstr)
  local o1,o2,o3,o4 = ipstr:match("(%d+)%.(%d+)%.(%d+)%.(%d+)")
  local num = 2^24*o1 + 2^16*o2 + 2^8*o3 + o4
  return num
end

function process_message()
  -- increment the counter of request at the message timestamp
  local t = read_message("Timestamp")
  reqcnt:add(t, 1, 1)

  -- convert the timestamp of the message in minutes
  local current_minute = os.date("%Y%m%d%H%M", math.floor(t/1e9))

  -- retrieve the cuckoo filter containing the list of IPs
  -- that have been seen within the last minute and check if
  -- the current IP is present. If not, add it.
  local cf = seenip[current_minute]
  if not cf then
    -- create a cuckoo filter with max 1024 entries
    cf = cuckoo_filter.new(max_cli_min)
  end
  local remote_addr = read_message("Fields[remote_addr]")
  local ip = ipv4_str_to_int(remote_addr)
  if not cf:query(ip) then
    cf:add(ip)
    seenip[current_minute] = cf
  end

  -- compare the rate of the current IP with the 
  return 0
end

local most_recent_avg = 0

function timer_event()
  local last_ts = math.floor(reqcnt:current_time()/1e9)
  -- if new data has been received, recalculate the moving average
  if last_ts > most_recent_avg then
    local reqcounts = reqcnt:get_range(1)
    local average = 0.0
    for i = 1,mv_avg_min do
      -- get the seenip timestamp based on the timestamp of the newest
      -- row in the reqcount circular buffer
      local ts = os.date("%Y%m%d%H%M", last_ts - (60*(i-1)))
      local cf = seenip[ts]
      if cf then
        if reqcounts[i] > 0 then
          local weighted_avg = average * i
          local current_avg = reqcounts[i] / cf:count()
          average = (weighted_avg + current_avg) / (i + 1)
        end
      end
    end
    inject_payload("float", "moving_average", average)
    most_recent_avg = last_ts
  end

  -- garbage collection: remove entries that are older
  -- than mv_avg_min minutes
  local now = os.time(os.date("*t"))
  local earliest = os.date("%Y%m%d%H%M", now - (60 * mv_avg_min))
  for ts, _ in pairs(seenip) do
    if ts < earliest then
      seenip[ts] = nil
    end
  end
end
