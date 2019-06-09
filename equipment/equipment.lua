local client = require('shared.client')
local resources = require('resources')

local data, ftype = client.new('items_service', 'equipment')

ftype.base.fields.item.type.fields.item = {
    get = function(data)
        return resources.items[data.id]
    end,
}

local check_equippable = function(slot, item)
    if item then
        assert(item.id ~= 0, "invalid item")
        assert(resources.bags[item.bag].equippable, "invalid item bad")
        assert(item.status == 0, "invalid item status")
        assert(bit.band(bit.lshift(1, slot), item.item.slots) ~= 0, "invalid item equipment slot")
    end
end

ftype.base.fields.equip = {
    data = function(self, item)
        local bag = item and item.bag or 0
        local index = item and item.index or 0
        if self.item.bag ~= bag or self.item.index ~= index then
            check_equippable(self.slot, item)
            packets.outgoing[0x050]:inject({bag_index=index, slot_id=self.slot, bag_id=bag})
        end
    end,
}

local equipment = {
    data = data,
    slot_names = {
        main = 0, sub = 1, range = 2, ammo = 3,
        head = 4, neck = 9, ear1 = 11, ear2 = 12,
        body = 5, hands = 6, ring1 = 13, ring2 = 14,
        back = 15, waist = 10, legs = 7, feet = 8,
    },
}

equipment.equip = function(self, slot_items)
    local ear1, ear2 = slot_items[11], slot_items[12]
    if ear1 and ear2 and ear1.index == ear2.index and ear1.id == ear2.id then
        ear1 = nil
    end

    local ring1, ring2 = slot_items[13], slot_items[14]
    if ring1 and ring2 and ring1.index == ring2.index and ring1.id == ring2.id then
        ring1 = nil
    end

    local items = {}
    for slot, item in pairs(slot_items) do
        local index = item and item.index or 0
        local bag = item and item.bag or 0
        if self[slot].item.bag ~= bag or self[slot].item.index ~= index then
            check_equippable(slot, item)
            table.insert(items, {bag_index=index, slot_id=slot, bag_id=bag})
        end
    end

    if #items > 1 then
        table.sort(items, function (a, b)
            return a.slot_id < b.slot_id
        end)
        packets.outgoing[0x051]:inject({count=#items, equipment=items})
    elseif #items == 1 then
        packets.outgoing[0x050]:inject(items[1])
    end
end

local equipment_mt = {
    __index = function(table, key)
        local index = table.slot_names[key] or key
        return table.data[index]
    end,
    __newindex = function(table, key, value)
        local index = table.slot_names[key] or key
        data[index] = value
    end,
    __pairs = function(table)
        return pairs(table.data)
    end,
    __ipairs = function(table)
        return ipairs(table.data)
    end,
    __len = function(table)
        return #table.data
    end
}

return setmetatable(equipment, equipment_mt)

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
