local types = require('memory:types')
local scanner = require('scanner')
local ffi = require('ffi')
require('string')

local scanned = {}

local modules = {'FFXiMain.dll', 'polcore.dll', 'polcoreEU.dll'}

local byte_ptr = ffi.typeof('char**')

local make_field_meta
make_field_meta = function(instance, fields)
    return {
        __index = function(_, label)
            local field
            for _, value in ipairs(fields) do
                if value.label == label then
                    field = value
                end
            end

            if field == nil then
                return nil
            end

            local type = field.type
            if type.count ~= nil and type.cdef ~= 'char' then
                local array = instance[field.cname]
                if type.fields ~= nil then
                    return setmetatable({}, {
                        __index = function(_, index)
                            return setmetatable({}, make_field_meta(array[index], type.fields))
                        end,
                    })
                else
                    return setmetatable({}, {
                        __index = function(_, index)
                            return type.tolua and type.tolua(array[index]) or array[index]
                        end,
                    })
                end
            elseif type.fields ~= nil then
                return setmetatable({}, make_field_meta(instance[field.cname], type.fields))
            end

            return type.tolua and type.tolua(instance[field.cname]) or instance[field.cname]
        end,
        __pairs = function(_)
        end,
    }
end

return setmetatable({}, {
    __index = function(_, name)
        local type = types[name]
        if type == nil then
            return nil
        end

        local base_ptr = scanned[name]
        if base_ptr == nil then

            -- TODO: Remove after scanner allows invalid sigs
            local ptr = scanner.scan(type.signature, name == 'auto_disconnect' and 'polcore.dll' or 'FFXiMain.dll')
            -- local ptr
            -- for _, module in ipairs(modules) do
            --     ptr = scanner.scan(type.signature)
            --     if ptr ~= nil then
            --         break
            --     end
            -- end
            assert(ptr ~= nil, 'Signature ' .. type.signature .. ' not found.')

            for _, offset in ipairs(type.static_offsets) do
                ptr = ffi.cast(byte_ptr, ptr)[offset]
            end

            base_ptr = ptr

            scanned[name] = base_ptr
        end

        local ptr = base_ptr
        for _, offset in ipairs(type.offsets) do
            ptr = ffi.cast(byte_ptr, ptr)[offset]
        end

        return setmetatable({}, make_field_meta(ffi.cast(type.ctype, ptr), type.fields))
    end,
})
