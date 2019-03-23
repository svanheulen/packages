local os = require('os')
local packets = require('packets')
local player = require('player')

local data = {
    ja_recasts = {},
    ma_recasts = {},
}

packets.incoming[0x028]:register(function(p)
    local t = data.ma_recasts

    if p.actor == player.id and p.category == 4 then
        t[#t + 1] = {
            id = p.param,
            duration = p.recast,
            ts_start = os.clock(),
            ts_end = os.clock() + p.recast,
        }
    end
end)

packets.incoming[0x119]:register(function(p)

    for i = 1, #p.recasts do
        local t = p.recasts[i]

        if t.duration > 0 and t.recast > 0 then
            local s = data.ja_recasts

            s[#s + 1] = {
                id = t.recast,
                duration = t.duration,
                ts_start = os.clock(),
                ts_end = os.clock() + t.duration,
            }
        end
    end
end)
