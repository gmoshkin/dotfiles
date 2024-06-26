bit = require 'bit'
ffi = require 'ffi'
fiber = require 'fiber'
json = require 'json'
yaml = require 'yaml'
log = require 'log'

function import(module)
    rawset(_G, module, require(module))
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
