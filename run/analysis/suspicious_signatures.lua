-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

require "string"
require "table"

local suspicious_terms = {"ALTER", "CREATE", "DELETE", "DROP", "EXEC", "EXECUTE", "INSERT", "MERGE", "SELECT", "UPDATE", "SYSTEMROOT"}
local alerts = {}

function process_message()
    local req = read_message("Fields[request]")
    for _, term in pairs(suspicious_terms) do
        local is_suspicious = string.match(req, term)
		if is_suspicious then
			local remote_addr = read_message("Fields[remote_addr]")
			table.insert(alerts, string.format("ALERT: remote address %s sent suspicious request %s", remote_addr, req))
		end
    end
    return 0
end

function timer_event()
    for k, v in pairs(alerts) do
        inject_payload("txt", "alerts", v)
        table.remove(alerts, k)
    end
end
