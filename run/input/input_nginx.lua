require "io"

local clf = require "lpeg.common_log_format"

local msg = {
Timestamp   = nil,
Type        = "logfile",
Hostname    = "localhost",
Logger      = "nginx",
Payload     = nil,
Fields      = nil
}

local grammar = clf.build_nginx_grammar('$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"')
local cnt = 0;
local fn = read_config("input_file")

function process_message()
    local fh = assert(io.open(fn, "rb"))

    for line in fh:lines() do
        local fields = grammar:match(line)
        if fields then
            msg.Timestamp = fields.time
            fields.time = nil
            msg.Fields = fields
            inject_message(msg, fh:seek())
            cnt = cnt + 1
        end
    end
    fh:close()

    return 0, tostring(cnt)
end
