// Blackbox tests run against the package's public API. Use `@jsonx` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
test "opt" {
  let parsed : Int? = @jsonx.opt(42.0)
  assert_true(parsed is Some(42))
  let failed : Int? = @jsonx.opt("42")
  assert_true(failed is None)
}

///|
test "nul" {
  let null_value : Int?? = @jsonx.nul(null)
  assert_true(null_value is Some(None))
  let parsed : Int?? = @jsonx.nul(7.0)
  assert_true(parsed is Some(Some(7)))
  let failed : Int?? = @jsonx.nul("x")
  assert_true(failed is None)
}

///|
test "get" {
  let obj : Json = {
    "name": "Ada",
    "age": 37.0,
    "enabled": { "name": "nested" },
  }
  let name : String? = @jsonx.get(obj, "name")
  assert_true(name is Some("Ada"))
  let age : Int? = @jsonx.get(obj, "age")
  assert_true(age is Some(37))
  let wrong_type : Int? = @jsonx.get(obj, "name")
  assert_true(wrong_type is None)
  let missing : String? = @jsonx.get(obj, "missing")
  assert_true(missing is None)
  let nested_on_scalar : String? = @jsonx.get(obj, ["enabled", "name"])
  assert_true(nested_on_scalar is Some("nested"))
  let nested_on_scalar2 : String? = @jsonx.get(obj, "enabled.name")
  assert_true(nested_on_scalar2 is Some("nested"))
}

///|
test "sub" {
  let child : Map[String, Json] = { "label": "nested" }
  let obj : Map[String, Json] = {
    "child": Json::object(child),
    "child_text": "nested",
  }
  guard @jsonx.sub(obj, "child") is Some(found) else {
    fail("expected child object")
  }
  assert_true(@jsonx.strf(Json::object(found), "label") is Some("nested"))
  assert_true(@jsonx.sub(obj, "child_text") is None)
  assert_true(@jsonx.sub(obj, "missing") is None)
}

///|
test "str" {
  let value = Json::string("hello")
  assert_true(@jsonx.str(value) is Some("hello"))
  assert_true(@jsonx.str(Json::number(12.0)) is Some("12"))
  assert_true(@jsonx.str(Json::boolean(true)) is None)
}

///|
test "strf" {
  let obj : Json = { "name": "Ada", "count": 3.0, "enabled": true }
  assert_true(@jsonx.strf(obj, "name") is Some("Ada"))
  assert_true(@jsonx.strf(obj, "count") is Some("3"))
  assert_true(@jsonx.strf(obj, "enabled") is None)
  assert_true(@jsonx.strf(obj, "missing") is None)
}

///|
test "int" {
  assert_true(@jsonx.int(12.0) is Some(12))
  assert_true(@jsonx.int("-7") is Some(-7))
  assert_true(@jsonx.int("x") is None)
  assert_true(@jsonx.int(null) is None)
}

///|
test "intf" {
  let obj : Json = { "count": 3.0, "count_text": "42", "bad_count": "x" }
  assert_true(@jsonx.intf(obj, "count") is Some(3))
  assert_true(@jsonx.intf(obj, "count_text") is Some(42))
  assert_true(@jsonx.intf(obj, "bad_count") is None)
  assert_true(@jsonx.intf(obj, "missing") is None)
}

///|
test "strs" {
  let profile : Json = { "name": "Ada", "age": 37.0 }
  let user : Json = { "profile": profile }
  let obj : Json = { "user": user, "flat": "root" }
  assert_true(@jsonx.get(obj, ["user", "profile", "name"]) is Some("Ada"))
  assert_true(@jsonx.get(obj, ["user", "profile", "age"]) is Some(37))
  assert_true(@jsonx.get(obj, ["flat"]) is Some("root"))
  let missing_branch : String? = @jsonx.get(obj, ["user", "missing", "name"])
  assert_true(missing_branch is None)
  let scalar_branch : String? = @jsonx.get(obj, ["flat", "name"])
  assert_true(scalar_branch is None)
  let missing_leaf : String? = @jsonx.get(obj, ["user", "profile", "missing"])
  assert_true(missing_leaf is None)
}
