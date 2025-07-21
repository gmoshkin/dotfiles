bit = require 'bit'
ffi = require 'ffi'
fiber = require 'fiber'
json = require 'json'
yaml = require 'yaml'
log = require 'log'

function import(module)
    rawset(_G, module, require(module))
    return rawget(_G, module)
end

function hex(num)
    return string.format([[%x]], num)
end

function table.keys(t)
    local res = {}
    for k, _ in pairs(t) do
        table.insert(res, k)
    end
    return res
end

function table.values(t)
    local res = {}
    for _, v in pairs(t) do
        table.insert(res, v)
    end
    return res
end

function table.last(t)
    return t[#t]
end

function lambda(s)
    if type(s) == 'function' then
        return s
    elseif type(s) == 'string' then
        return function(...)
            local n_args = select('#', ...)
            local prelude = {}
            if n_args > 0 then
                table.insert(prelude, 'local _1')
                for i = 2,n_args do
                    table.insert(prelude, ', _' .. i)
                end
                table.insert(prelude, '= ... ')
                table.insert(prelude, 'local _ = _1')
            end
            table.insert(prelude, ';')

            local prelude = table.concat(prelude, ' ')

            local code = prelude .. s
            local res, err = loadstring(code)
            if res then
                return res(...)
            end

            code = prelude .. 'return ' .. s
            return loadstring(code)(...)
        end
    else
        error("expected string or function")
    end
end

function table.map(t, cb)
    local cb = lambda(cb)

    local result = {}
    for k, v in pairs(t) do
        result[k] = cb(k, v)
    end
    return result
end

function table.imap(t, cb)
    local cb = lambda(cb)

    local result = {}
    for k, v in ipairs(t) do
        result[k] = cb(k, v)
    end
    return result
end

function unfuck(t)
    if type(t) ~= 'table' then
        return t
    end

    local unfucked_t = {}
    for k, v in pairs(t) do
        unfucked_t[k] = unfuck(v)
    end
    return unfucked_t
end
