require "string"
local rex = require "rex_pcre"
local xss = '((\%3C)|<)((\%2F)|\/)*[a-z0-9\%]+((\%3E)|>)'

function process_message()
    local req = read_message("Fields[request]")
    local xss_matches = rex.match(req, xss)
    if xss_matches then
		local remote_addr = read_message("Fields[remote_addr]")
        add_to_payload(string.format("ALERT: xss attempt from %s in request %s\n", remote_addr, req))
    end
    return 0
end

function timer_event()
    inject_payload("txt", "alerts")
end
