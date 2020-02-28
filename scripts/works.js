#!/usr/bin/env node

var foo = (function() {
    function foo(foo) {
        return `foo(${foo})`
    }
    var foo = foo("foo")
    return foo
})()

console.log(foo)
