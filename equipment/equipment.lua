local client = require('shared.client')
local resources = require('resources')
local bit = require('bit')
local packets = require('packets')
local table = require('table')

local data, ftype = client.new('items_service', 'equipment')

ftype.base.fields.item.type.fields.item = {
    get = function(data)
        return resources.items[data.id]
    end,
}

ftype.base.fields.equip = {
    data = function(equipment_slot, item)
        local equipped_item = equipment_slot.item
        local bag = item.bag
        local index = item.index
        -- optional: do not send the packet if the item is already equipped
        if equipped_item.bag ~= bag or equipped_item.index ~= index then
            -- required: check that the item is not an empty bag slot
            assert(item.id ~= 0, "invalid item")
            -- required: check that the item is in a bag you're allowed to equip from
            assert(resources.bags[bag].equippable, "invalid item bag")
            -- optional: check that the item has the proper status
            assert(item.status == 0, "invalid item status")
            -- optional: check that the item is allowed to be equipped in this slot
            assert(bit.band(bit.lshift(1, slot), item.item.slots) ~= 0, "invalid item equipment slot")
            packets.outgoing[0x050]:inject({bag_index = index, slot_id = equipment_slot.slot, bag_id = bag})
        end
    end,
}

ftype.base.fields.unequip = {
    data = function(equipment_slot)
        local equipped_item = equipment_slot.item
        -- optional: do not send a packet if no item is equipped already
        if equipped_item.bag ~= 0 or equipped_item.index ~= 0 then
            packets.outgoing[0x050]:inject({bag_index = 0, slot_id = equipment_slot.slot, bag_id = 0})
        end
    end,
}

local equipment = {}

equipment.equip = function(slot_items)
    -- optional: do not equip the exact same item in both earring slots
    local ear1 = slot_items[11]
    local ear2 = slot_items[12]
    if ear1 and ear2 and ear1.index == ear2.index and ear1.id == ear2.id then
        slot_items[11] = nil
    end

    -- optional: do not equip the exact same item in both ring slots
    local ring1 = slot_items[13]
    local ring2 = slot_items[14]
    if ring1 and ring2 and ring1.index == ring2.index and ring1.id == ring2.id then
        slot_items[13] = nil
    end

    local count = 0
    local items = {}
    -- optional: sort the equipment by slot id
    for slot = 0, 15 do
        local item = slot_items[slot]
        if item ~= nil then
            local bag = item and item.bag or 0
            local index = item and item.index or 0
            if item then
                -- required: check that the item is not an empty bag slot
                assert(item.id ~= 0, "invalid item")
                -- required: check that the item is in a bag you're allowed to equip from
                assert(resources.bags[bag].equippable, "invalid item bag")
                -- optional: check that the item is allowed to be equipped in this slot
                assert(bit.band(bit.lshift(1, slot), item.item.slots) ~= 0, "invalid item equipment slot")
            end
            items[count] = {bag_index = index, slot_id = slot, bag_id = bag}
            count = count + 1
        end
    end

    -- optional: do not send a packet with no equipment
    if count > 0 then
        packets.outgoing[0x051]:inject({count = count, equipment = items})
    end
end

local slot_names = {
    main = 0, sub = 1, range = 2, ammo = 3,
    head = 4, neck = 9, ear1 = 11, ear2 = 12,
    body = 5, hands = 6, ring1 = 13, ring2 = 14,
    back = 15, waist = 10, legs = 7, feet = 8,
}

local equipment_mt = {
    __index = function(t, k)
        local index = slot_names[k] or k
        return data[index]
    end,
    __newindex = function(t, k, v)
        local index = slot_names[k] or k
        data[index] = v
    end,
    __pairs = function(t)
        return pairs(data)
    end,
    __ipairs = function(t)
        return ipairs(data)
    end,
    __len = function(t)
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
