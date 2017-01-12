-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "string"
require "table"

local suspicious_terms = {"ALTER", "CREATE", "DELETE", "DROP", "EXEC", "EXECUTE", "INSERT", "MERGE", "SELECT", "UPDATE", "SYSTEMROOT"}

function process_message()
    local req = read_message("Fields[request]")
    for _, term in ipairs(suspicious_terms) do
        local is_suspicious = string.match(req, term)
		if is_suspicious then
			local remote_addr = read_message("Fields[remote_addr]")
			add_to_payload(string.format("ALERT: remote address '%s' sent suspicious request '%s'\n", remote_addr, req))
		end
    end
    return 0
end

function timer_event()
    inject_payload("txt", "alerts" )
end
