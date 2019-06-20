local client = require('shared.client')
local resources = require('resources')
local bit = require('bit')
local packets = require('packets')

local data, ftype = client.new('items_service', 'equipment')

ftype.base.fields.item.type.fields.item = {
    get = function(data)
        return resources.items[data.id]
    end,
}

local equippable = {[0] = true, [8] = true, [10] = true, [11] = true, [12] = true}

ftype.base.fields.equip = {
    data = function(equipment_slot, item)
        local bag = item.bag
        local index = item.index
        if equipment_slot.item.bag ~= bag or equipment_slot.item.index ~= index then
            local slot = equipment_slot.slot
            assert(equippable[bag], 'Cannot equip from this bag (bag = ' .. bag .. ')')
            assert(item.id ~= 0, 'Cannot equip from an empty bag slot (bag = ' .. bag .. ', index = ' .. index .. ')')
            assert(item.status == 0, 'Cannot equip an item with this status (status = ' .. item.status .. ')')
            assert(bit.band(bit.lshift(1, slot), item.item.slots) ~= 0, 'Cannot equip that item in this slot (slot = ' .. slot .. ', item.id = ' .. item.id .. ')')

            packets.outgoing[0x050]:inject({bag_index = index, slot_id = slot, bag_id = bag})
        end
    end,
}

ftype.base.fields.unequip = {
    data = function(equipment_slot)
        if equipment_slot.item.bag ~= 0 or equipment_slot.item.index ~= 0 then
            packets.outgoing[0x050]:inject({bag_index = 0, slot_id = equipment_slot.slot, bag_id = 0})
        end
    end,
}

local equipment = {}

equipment.equip = function(_, slot_items)
    local ear1 = slot_items[11]
    local ear2 = slot_items[12]
    if ear1 and ear2 and ear1.index == ear2.index and ear1.id == ear2.id then
        slot_items[11] = nil
    end

    local ring1 = slot_items[13]
    local ring2 = slot_items[14]
    if ring1 and ring2 and ring1.index == ring2.index and ring1.id == ring2.id then
        slot_items[13] = nil
    end

    local count = 0
    local items = {}
    for i = 0, 15 do
        local item = slot_items[i]
        if item then
            local bag = item.bag
            local index = item.index
            if bag ~= 0 or index ~= 0 then
                assert(equippable[bag], 'Cannot equip from this bag (bag = ' .. bag .. ')')
                assert(item.id ~= 0, 'Cannot equip from an empty bag slot (bag = ' .. bag .. ', index = ' .. index .. ')')
                assert(bit.band(bit.lshift(1, i), item.item.slots) ~= 0, 'Cannot equip that item in this slot (slot = ' .. i .. ', item.id = ' .. item.id .. ')')
            end
            items[count] = {bag_index = index, slot_id = i, bag_id = bag}
            count = count + 1
        end
    end

    if count > 0 then
        packets.outgoing[0x051]:inject({count = count, equipment = items})
    end
end

equipment.slot = {
    main = 0, sub = 1, range = 2, ammo = 3,
    head = 4, neck = 9, ear1 = 11, ear2 = 12,
    body = 5, hands = 6, ring1 = 13, ring2 = 14,
    back = 15, waist = 10, legs = 7, feet = 8,
}

local equipment_mt = {
    __index = function(_, k)
        return data[k]
    end,
    __newindex = function(_, k, v)
        data[k] = v
    end,
    __pairs = function(_)
        return pairs(data)
    end,
    __ipairs = function(_)
        return ipairs(data)
    end,
    __len = function(_)
        return #data
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
