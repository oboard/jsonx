///|
pub(open) trait JsonxPath {
  to_jsonx_path_iter(Self) -> Iter[String]
}

///|
pub impl JsonxPath for String with to_jsonx_path_iter(self) {
  self.split(".").map(s => s.to_owned())
}

///|
pub impl JsonxPath for StringView with to_jsonx_path_iter(self) {
  self.split(".").map(s => s.to_owned())
}

///|
pub impl JsonxPath for Array[String] with to_jsonx_path_iter(self) {
  self.iter()
}

///|
pub impl JsonxPath for Int with to_jsonx_path_iter(self) {
  [self.to_string()].iter()
}

///|
pub impl JsonxPath for Double with to_jsonx_path_iter(self) {
  [self.to_string()].iter()
}
