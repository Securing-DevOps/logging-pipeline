require "string"
require "table"
local rex = require "rex_pcre"

local suspicious_terms = {
  "ALTER",
  "CREATE",
  "DELETE",
  "DROP",
  "EXEC",
  "EXECUTE",
  "INSERT",
  "MERGE",
  "SELECT",
  "UPDATE",
  "SYSTEMROOT"
}

local suspicious_regexes = {
  xss      = "((\%3C)|<)((\%2F)|\/)*[a-z0-9\%]+((\%3E)|>)",
  imgsrc   = "((\%3C)|<)((\%69)|i|(\%49))((\%6D)|m|(\%4D))((\%67)|g|(\%47))[^\n]+((\%3E)|>)",
  sqli     = "\w*((\%27)|(\'))((\%6F)|o|(\%4F))((\%72)|r|(\%52))",
  sqlimeta = "((\%3D)|(=))[^\n]*((\%27)|(\')|(\-\-)|(\%3B)|(;))",
}

function process_message()
  local req = read_message("Fields[request]")
  local remote_addr = read_message("Fields[remote_addr]")
  for _, term in ipairs(suspicious_terms) do
    local is_suspicious = string.match(req, term)
    if is_suspicious then
      add_to_payload(
        string.format("ALERT: suspicious term %s from %s in request %s\n",
          term, remote_addr, req))
    end
  end
  for label, regex in pairs(suspicious_regexes) do
    local xss_matches = rex.match(req, regex)
    if xss_matches then
      add_to_payload(
        string.format("ALERT: %s attempt from %s in request %s\n",
          label, remote_addr, req))
    end
  end
  return 0
end

function timer_event()
  inject_payload("txt", "alerts")
end
