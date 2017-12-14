DAEMON = {
    address = 'localhost',
    port    = 8500,
}

PEERS = {
}

local timer  = require "util.timer";
local stanza = require 'util.stanza'
local serial = require 'util.serialization'
local FC     = require 'freechains'

local CFG = FC.send(0x0500, nil, DAEMON)

CFG.external = CFG.external or {}
CFG.external.prosody = CFG.external.prosody or {
    chains = {}
}
local T = CFG.external.prosody

module:hook("presence/full", function (event)
    local s = event.stanza
    module:log("info", "PRS: %s", tostring(s))
    if s.attr.type == 'unavailable' then
        return  -- disconnecting
    end

    local room, user = string.match(s.attr.to, '([^@]*)@[^/]*/(.*)')
    module:log("info", "PRS: %s %s", room, user)

    local key = room..'.jabber'
    if not T.chains[key] then
        T.chains[key] = {
            zeros = 0,
            cache = {},
        }
        -- configure set
        FC.send(0x0500, CFG, DAEMON)
    end

    -- subscribe
    FC.send(0x0400, {
        chain = {
            key   = key,
            zeros = 0,
            peers = PEERS,
        }
    }, DAEMON)
end)

module:hook("message/bare", function (event)
    local s = event.stanza
    if s.attr.type~='groupchat' or s.attr.freechains=='true' then
        return
    end
    --module:log("info", "MSG: %s", tostring(event.stanza))

    s.attr.freechains = 'true'

    local room = string.match(s.attr.to, '([^@]*)@')
    assert(room)

    local key = room..'.jabber'
    local msg = {
        chain = {
            key   = key,
            zeros = 0,
        },
        payload = serial.serialize(stanza.preserialize(s)),
    }
    module:log("info", "PAY: %s", msg.payload)

    -- publish
    FC.send(0x0300, msg, DAEMON)

    return true
end)

timer.add_task(2, function ()
    local t = {}

    for key, chain in pairs(T.chains) do
        --module:log("info", "MSG: %s/%d", key, chain.zeros)
        for node in FC.get_iter({key=key,zeros=chain.zeros}, chain.cache, DAEMON) do
            chain.cache[node.hash] = true
            if node.pub then
                module:log("info", "PAY: %s", node.pub.payload)
                table.insert(t, 1, stanza.deserialize(serial.deserialize(node.pub.payload)))
            end
        end
    end

    for _, v in ipairs(t) do
        module:send(v)
    end

    -- configure set
    FC.send(0x0500, CFG, DAEMON)

    return 2
end)
