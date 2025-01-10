package main

import (
    "fmt"
    "reflect"
)

func main() {
    inspect_type("string")

    inspect_type(StringAlias("alias"))

    inspect_type(MyString("newtype"))

    inspect_type(MyStruct{})

    fmt.Printf("%x\n", "hello")
}

func inspect_type(v any) {
    typeOf := reflect.TypeOf(v)
    fmt.Printf("=== %v<%#v> ===\n", typeOf, v)

    fmt.Printf("kind: %v\n", typeOf.Kind())
    fmt.Printf("pkg: %v\n", typeOf.PkgPath())
    fmt.Printf("name: %v\n", typeOf.Name())
    fmt.Printf("numMethod: %v\n", typeOf.NumMethod())
    for i := range typeOf.NumMethod() {
        method := typeOf.Method(i)
        fmt.Printf("method(%d): %v\n", i, method)
        fmt.Println("method name:", method.Name)
        res := method.Func.Call([]reflect.Value{reflect.ValueOf(v), reflect.ValueOf(-40)})
        for i, res := range res {
            fmt.Printf("result %d: %v\n", i, res)
        }
    }

    if typeOf.Kind() == reflect.Struct {
        fmt.Printf("numField: %v\n", typeOf.NumField())
        for i := range typeOf.NumField() {
            field := typeOf.Field(i)
            fmt.Printf("field(%d): %#v\n", i, field)
        }
        fmt.Printf("VisibleFields: %#v\n", reflect.VisibleFields(typeOf))
    }

}

//
// MyStruct
//
type Base struct {
    x int
    y float64
    z string
}

type MyStruct struct {
    Base
    field int
    otherField string
}

func (self MyStruct) privMethod() int {
    return 420
}

func (self MyStruct) PubMethod(a int) int {
    return 420 + a
}

//
// MyString
//

// This is a doc comment btw
type MyString string // this is not

type StringAlias = string
