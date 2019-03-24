local os = require('os')
local packets = require('packets')
local player = require('player')

local data = {
    ja_recasts = {},
    ma_recasts = {},
}

local ja_recasts = data.ja_recasts
local ma_recasts = data.ma_recasts

local current_time = function()
    return os.clock()
end

packets.incoming[0x028]:register(function(p)
    if p.actor == player.id and p.category == 4 then

        ma_recasts[#ma_recasts + 1] = {
            id = p.param,
            duration = p.recast,
            ts_start = current_time(),
            ts_end = current_time() + p.recast,
        }
    end
end)

packets.incoming[0x119]:register(function(p)
    for i = 1, #p.recasts do

        if p.recasts[i].duration > 0 and p.recasts[i].recast > 0 then

            ja_recasts[#ja_recasts + 1] = {
                id = p.recasts[i].recast,
                duration = p.recasts[i].duration,
                ts_start = current_time(),
                ts_end = current_time() + p.recasts[i].duration,
            }
        end
    end
end)

--[[
Copyright © 2018, Windower Dev Team
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the Windower Dev Team nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE WINDOWER DEV TEAM BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
