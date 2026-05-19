///|
pub fn[T : @json.FromJson] opt(value : Json) -> T? {
  Some(@json.from_json(value)) catch {
    _ => None
  }
}

///|
pub fn[T : @json.FromJson] nul(value : Json) -> T?? {
  if value is Null {
    Some(None)
  } else {
    let parsed : T? = opt(value)
    if parsed is Some(v) {
      Some(Some(v))
    } else {
      None
    }
  }
}

///|
fn[U : JsonxPath] at_path(value : Json, path : U) -> Json? {
  let mut current = value
  for key in path.to_jsonx_path_iter() {
    guard current is Object(obj) else { return None }
    guard obj.get(key) is Some(next) else { return None }
    current = next
  }
  Some(current)
}

///|
pub fn[T : @json.FromJson, U : JsonxPath] get(value : Json, path : U) -> T? {
  guard at_path(value, path) is Some(current) else { return None }
  opt(current)
}

///|
pub fn[U : JsonxPath] sub(obj : Json, path : U) -> Map[String, Json]? {
  guard at_path(obj, path) is Some(current) else { return None }
  if current is Object(child) {
    Some(child)
  } else {
    None
  }
}

///|
pub fn str(value : Json) -> String? {
  if value is String(v) {
    Some(v)
  } else if value is Number(v, ..) {
    Some(v.to_int().to_string())
  } else {
    None
  }
}

///|
pub fn[U : JsonxPath] strf(obj : Json, path : U) -> String? {
  guard at_path(obj, path) is Some(current) else { return None }
  str(current)
}

///|
pub fn int(value : Json) -> Int? {
  if value is Number(v, ..) {
    Some(v.to_int())
  } else if value is String(v) {
    (try? @string.parse_int(v)).to_option()
  } else {
    None
  }
}

///|
pub fn[U : JsonxPath] intf(obj : Json, path : U) -> Int? {
  guard at_path(obj, path) is Some(current) else { return None }
  int(current)
}
