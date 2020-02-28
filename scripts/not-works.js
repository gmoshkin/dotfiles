#!/usr/bin/env node

var foo = (function() {
    function foo(foo) {
        return `foo(${foo})`
    }
    let foo = foo("foo")
    return foo
})()

console.log(foo)
