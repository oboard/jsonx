// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
fn wb_fixture() -> Map[String, Json] {
  let profile : Map[String, Json] = {
    "name": "Ada",
    "age": 37.9,
    "nickname": null,
  }
  let user : Map[String, Json] = {
    "profile": Json::object(profile),
    "enabled": true,
  }
  {
    "user": Json::object(user),
    "count_text": "42",
    "count_bad": "42x",
    "ratio": 12.9,
  }
}

///|
test "coercions use integer projection" {
  let obj = Json::object(wb_fixture())
  assert_true(strf(obj, "ratio") is Some("12"))
  assert_true(intf(obj, "ratio") is Some(12))
  assert_true(intf(obj, "count_text") is Some(42))
  assert_true(intf(obj, "count_bad") is None)
}

///|
test "nullable conversion keeps all three states separate" {
  let missing : String?? = nul(Json::boolean(true))
  assert_true(missing is None)
  let explicit_null : String?? = nul(Json::null())
  assert_true(explicit_null is Some(None))
  let present : String?? = nul(Json::string("value"))
  assert_true(present is Some(Some("value")))
}

///|
test "typed field access rejects mismatched values" {
  let obj = wb_fixture()
  guard sub(obj, "user") is Some(user_obj) else { fail("expected user object") }
  guard user_obj.get("enabled") is Some(enabled) else {
    fail("expected enabled field")
  }
  let enabled_as_bool : Bool? = opt(enabled)
  assert_true(enabled_as_bool is Some(true))
  let enabled_as_string : String? = opt(enabled)
  assert_true(enabled_as_string is None)
}

///|
test "nested string paths require object intermediates" {
  let obj = Json::object(wb_fixture())
  assert_true(get(obj, ["user", "profile", "name"]) is Some("Ada"))
  assert_true(get(obj, ["user", "profile", "age"]) is Some(37))
  let scalar_branch : String? = get(obj, ["user", "enabled", "name"])
  assert_true(scalar_branch is None)
  let scalar_root : String? = get(obj, ["count_text", "value"])
  assert_true(scalar_root is None)
}

///|
test "jsonx path scalar implementations" {
  let obj : Json = {
    "user": { "profile": { "name": "Ada" } },
    "1": "one",
    "2.5": "two-point-five",
  }
  let string_view_path : StringView = "user.profile.name"
  assert_true(get(obj, string_view_path) is Some("Ada"))
  assert_true(get(obj, 1) is Some("one"))
  assert_true(get(obj, 2.5) is Some("two-point-five"))
}
