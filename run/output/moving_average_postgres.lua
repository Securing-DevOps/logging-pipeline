require "math"
require "string"
require "os"

local dbdriver= require "luasql.postgres"
local dbenv   = assert (dbdriver.postgres())
local dbcon   = assert (dbenv:connect(read_config("postgres_dsn")))
assert(dbcon:execute"CREATE TABLE IF NOT EXISTS analyzer_high_rate_clients(ts TIMESTAMP WITH TIME ZONE, mvg_avg NUMERIC)")

function process_message()
  local average = read_message("Payload")
  local ts = read_message("Timestamp")
  assert(dbcon:execute(string.format(
    [[INSERT INTO analyzer_high_rate_clients(ts, mvg_avg) VALUES('%s', '%s')]],
    os.date("%c", math.floor(ts/1e9)), average)))
  return 0
end
