local core = {
    packet = require('packet'),
}
local event = require('event')
local ffi = require('ffi')
local shared = require('shared')
local string = require('string')
local math = require('math')
local os = require('os')
local windower = require('windower')

local pairs = pairs
local type = type
local tonumber = tonumber
local tostring = tostring

packets_server = shared.new('packets')
types_server = shared.new('types')

local packet_types
local parse_types = function()
    packet_types = dofile(windower.package_path .. '\\types.lua')
end

parse_types()

types_server.data = packet_types

local registry = {}
local history = {}

local amend_cdata
amend_cdata = function(cdata, packet, ftype, var_count)
    local count = ftype.count
    if count then
        local limit = (count ~= '*' and count or var_count) - 1
        local base = ftype.base
        if base.fields then
            for i = 0, limit do
                local value = packet[i]
                if value then
                    amend_cdata(cdata[i], value, base, var_count)
                end
            end
        else
            for i = 0, limit do
                local value = packet[i]
                if value then
                    cdata[i] = value
                end
            end
        end
    else
        local fields = ftype.fields
        for key, value in pairs(packet) do
            local value_ftype = fields[key].type
            if not value_ftype.converter and (value_ftype.fields or value_ftype.base) then
                amend_cdata(cdata[key], value, value_ftype, var_count)
            else
                cdata[key] = value
            end
        end
    end
end

local build_cdata
do
    local ffi_new = ffi.new

    build_cdata = function(ftype, values)
        local cdata
        local var_key = ftype.var_key
        local var_data = var_key and values[var_key]
        if not var_data then
            return ffi_new(ftype.name), 0
        end

        if type(var_data) == 'string' then
            local size = ftype.converter == 'string' and #var_data + 1 or #var_data
            return ffi_new(ftype.name, size), size
        end

        local max_key = 0
        for key in pairs(var_data) do
            if key + 1 > max_key then
                max_key = key + 1
            end
        end
        cdata = ffi_new(ftype.name, max_key)

        return cdata, max_key
    end

end

packets_server.env = {}

packets_server.env.get_last = function(path)
    local entry = history[path]
    return entry.packet, entry.info
end

do
    local string_sub = string.sub

    packets_server.env.get_lasts = function(start_path)
        local found = {}
        local res = {}
        local res_count = 0
        for path, entry in pairs(history) do
            if start_path == path or start_path .. '/' == string_sub(path, 1, #start_path + 1) and not found[entry] then
                res_count = res_count + 1
                res[res_count] = entry
                found[entry] = true
            end
        end
        return res
    end
end

do
    local event_new = event.new

    packets_server.env.make_event = function(path)
        local events = registry[path]
        if not events then
            events = {}
            registry[path] = events
        end

        local new_event = event_new()
        events[#events + 1] = new_event

        return new_event
    end
end

local get_real_size = function(ftype, var_count)
    return var_count > 0 and ftype.size + ftype.var_size * var_count or ftype.size
end

do
    local string_find = string.find
    local string_sub = string.sub
    local ffi_copy = ffi.copy
    local ffi_string = ffi.string
    local packet_new = core.packet.new
    local packet_inject_incoming = core.packet.inject_incoming
    local packet_inject_outgoing = core.packet.inject_outgoing
    local buffer_type = ffi.typeof('char[?]')

    local build_packet = function(path, values)
        local direction = string_sub(path, 2, 9)
        local next_slash_index = string_find(path, '/', 11)
        local id = tonumber(string_sub(path, 11, next_slash_index and next_slash_index - 1))

        local base_type = packet_types[direction][id]
        local ftype
        local base_types = base_type.types
        if not base_types then
            ftype = base_type
        else
            if not next_slash_index then
                ftype = base_type.base
            else
                local key = string_sub(path, next_slash_index + 1)
                ftype = base_types[tonumber(key) or key] or base_type.base
            end
        end

        local cdata, var_count = build_cdata(ftype, values)

        amend_cdata(cdata, values, ftype, var_count)
        return cdata, direction, id, ftype, var_count
    end

    packets_server.env.inject = function(path, values)
        local cdata, direction, id, ftype, var_count = build_packet(path, values)

        local size = get_real_size(ftype, var_count)

        local buffer = buffer_type(size)
        ffi_copy(buffer, cdata, size)

        local p = packet_new(id, ffi_string(buffer, size))
        if direction == 'incoming' then
            packet_inject_incoming(p)
        else
            packet_inject_outgoing(p)
        end
    end
end

local parse_packet
do
    local math_floor = math.floor
    local math_min = math.min
    local ffi_copy = ffi.copy
    local ffi_new = ffi.new

    local amend_packet
    amend_packet = function(packet, cdata, ftype, var_count)
        local count = ftype.count
        if count then
            local limit = (count ~= '*' and count or var_count) - 1
            local base = ftype.base
            if base.fields then
                for i = 0, limit do
                    packet[i] = amend_packet(packet[i] or {}, cdata[i], base, var_count)
                end
            else
                for i = 0, limit do
                    packet[i] = cdata[i]
                end
            end
        else
            local fields = ftype.fields
            for key, value in pairs(cdata) do
                if type(value) == 'cdata' then
                    packet[key] = amend_packet(packet[key] or {}, value, fields[key].type, var_count)
                else
                    packet[key] = value
                end
            end
        end

        return packet
    end

    local parse_single = function(data, ftype, packet)
        packet = packet or {}

        local data_size = #data
        local type_size = ftype.size
        local var_size = ftype.var_size

        local cdata
        local var_count
        if var_size then
            var_count = math_floor((data_size - type_size) / var_size)
            type_size = type_size + var_count * var_size
            cdata = ffi_new(ftype.name, var_count)
        else
            cdata = ffi_new(ftype.name)
        end
        ffi_copy(cdata, data, math_min(type_size, data_size))

        return amend_packet(packet, cdata, ftype, var_count)
    end

    parse_packet = function(data, ftype)
        if not ftype then
            return {}
        end

        local types = ftype.types
        if not types then
            return parse_single(data, ftype)
        end

        local base_packet = parse_single(data, ftype.base)

        local inner_ftype = types[base_packet[ftype.key]]
        if not inner_ftype then
            return base_packet
        end

        return parse_single(data, inner_ftype, base_packet)
    end
end

local blocked = false
packets_server.env.block = function()
    blocked = true
end

local updated
packets_server.env.update = function(p)
    updated = p
end

local process_packet = function(entry, packet, info, path)
    local events = registry[path]
    if events then
        for i = 1, #events do
            events[i]:trigger(packet, info)
            if blocked then
                info.blocked = blocked
                blocked = false
            end
            if updated then
                for k in pairs(packet) do
                    packet[k] = nil
                end
                for k, v in pairs(updated) do
                    packet[k] = v
                end

                info.modified = true
                updated = nil
            end
        end
    end

    history[path] = entry
end

local make_timestamp
do
    local os_time = os.time

    local last_time = os_time()
    local now_count = 0

    make_timestamp = function()
        local now = os_time()
        if last_time == now then
            now_count = now_count + 1
            return now + now_count / 10000
        end

        now_count = 0
        last_time = now
        return now
    end
end

local handle_packet
do
    local ffi_string = ffi.string

    handle_packet =  function(direction, raw)
        local id = raw.id
        local data = raw.data

        local info = {
            direction = direction,
            id = id,
            data = data,
            blocked = raw.blocked,
            modified = raw.modified,
            injected = raw.injected,
            timestamp = make_timestamp(),
        }

        local ftype = packet_types[direction][id]
        local packet = parse_packet(data, ftype)

        local entry = {
            packet = packet,
            info = info,
        }
        process_packet(entry, packet, info, '')
        local path = '/' .. direction
        process_packet(entry, packet, info, path)
        path = path .. '/' .. id
        process_packet(entry, packet, info, path)

        local finfo = ftype and ftype.info
        local cache = finfo and finfo.cache
        if cache then
            for i = 1, #cache do
                path = path .. '/' .. tostring(packet[cache[i]])
                process_packet(entry, packet, info, path)
            end
        end

        if info.blocked then
            raw.blocked = true
        end

        if info.modified then
            local cdata, var_count = build_cdata(ftype, packet)
            amend_cdata(cdata, packet, ftype, var_count)

            raw.data = ffi_string(cdata, get_real_size(ftype, var_count))
        end
    end
end

core.packet.incoming:register(function(raw)
    handle_packet('incoming', raw)
end)

core.packet.outgoing:register(function(raw)
    handle_packet('outgoing', raw)
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
