# oboard/jsonx

Small helpers for reading MoonBit `Json` values with typed fallbacks, plus a
code generator for `ToJson` / `FromJson` impls.

## Runtime helpers

Add the package to a `moon.pkg`:

```moonbit nocheck
import {
  "oboard/jsonx"
}
```

`opt` converts a `Json` value through `@json.FromJson` and returns `None`
instead of raising on decode errors.

```mbt check
///|
test "opt" {
  let ok : Int? = @jsonx.opt(42.0)
  assert_true(ok is Some(42))

  let bad : Int? = @jsonx.opt("42")
  assert_true(bad is None)
}
```

`nul` preserves three states for nullable fields: decode failure, explicit
`null`, and a present value.

```mbt check
///|
test "nul" {
  let explicit_null : String?? = @jsonx.nul(null)
  assert_true(explicit_null is Some(None))

  let present : String?? = @jsonx.nul("Ada")
  assert_true(present is Some(Some("Ada")))

  let bad : String?? = @jsonx.nul(true)
  assert_true(bad is None)
}
```

`get`, `strf`, and `intf` read nested object fields. Paths can be dot-separated
strings, string arrays, `StringView`, `Int`, or `Double`.

```mbt check
///|
test "path reads" {
  let obj : Json = {
    "user": { "profile": { "name": "Ada", "age": 37.0 } },
    "items": { "1": "first" },
  }

  let name : String? = @jsonx.get(obj, "user.profile.name")
  assert_true(name is Some("Ada"))

  let age : Int? = @jsonx.get(obj, ["user", "profile", "age"])
  assert_true(age is Some(37))

  assert_true(@jsonx.strf(obj, "items.1") is Some("first"))
  let missing : String? = @jsonx.get(obj, ["user", "missing"])
  assert_true(missing is None)
}
```

`str` and `int` provide small coercions for common JSON input.

```mbt check
///|
test "coercions" {
  assert_true(@jsonx.str(12.0) is Some("12"))
  assert_true(@jsonx.str(true) is None)

  assert_true(@jsonx.int("42") is Some(42))
  assert_true(@jsonx.int("x") is None)
}
```

`sub` is still available when you already have a `Map[String, Json]`.

```mbt check
///|
test "sub object" {
  let obj : Json = {
    "child": { "label": "nested" },
    "text": "nested",
  }

  guard @jsonx.sub(obj, "child") is Some(child) else {
    fail("expected child object")
  }
  assert_true(@jsonx.strf(Json::object(child), "label") is Some("nested"))
  assert_true(@jsonx.sub(obj, "text") is None)
}
```

## Code generation

Mark structs with `#jsonx.struct`. Use `#jsonx.key("...")` when the JSON key
differs from the MoonBit field name.

```mbt nocheck
///|
#jsonx.struct
pub(all) struct Person {
  name : String
  age : Int
  #jsonx.key("method")
  method_ : String
}
```

Run the generator with an input file and an output file:

```bash
moon run cmd/jsonxgen -- -o person.g.mbt person.mbt
```

For the struct above, `jsonxgen` emits:

```mbt nocheck
///|
pub impl ToJson for Person with to_json(self) {
  { "name": self.name, "age": self.age, "method": self.method_ }
}

///|
pub impl FromJson for Person with from_json(json, path) {
  guard json is Object(obj) else {
    raise @json.JsonDecodeError((path, "expected object"))
  }
  let name = match obj.get("name") {
    Some(String(name)) => name
    _ => raise @json.JsonDecodeError((path, "expected string for 'name'"))
  }
  let age = match obj.get("age") {
    Some(Number(age, ..)) => age.to_int()
    _ => raise @json.JsonDecodeError((path, "expected number for 'age'"))
  }
  let method_ = match obj.get("method") {
    Some(String(method_)) => method_
    _ => raise @json.JsonDecodeError((path, "expected string for 'method'"))
  }
  Person::{ name, age, method_ }
}
```

The generator currently emits specialized field checks for `String` and `Int`.
Other field types are decoded through `@json.from_json`.
