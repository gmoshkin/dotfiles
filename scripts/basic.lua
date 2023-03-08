setmetatable(_G, {
    __index = function(t, mod)
        return package.loaded[mod]
    end
})
