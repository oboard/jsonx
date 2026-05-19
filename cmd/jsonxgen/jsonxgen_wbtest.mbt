///|
test "generate json codecs for jsonx struct" {
  let source =
    #|///|
    #|#jsonx.struct
    #|pub(all) struct Person {
    #|  name : String
    #|  age : Int
    #|  #jsonx.key("method")
    #|  method_ : String
    #|}
  let expected =
    #|///|
    #|pub impl ToJson for Person with to_json(self) {
    #|  { "name": self.name, "age": self.age, "method": self.method_ }
    #|}
    #|
    #|///|
    #|pub impl FromJson for Person with from_json(json, path) {
    #|  guard json is Object(obj) else {
    #|    raise @json.JsonDecodeError((path, "expected object"))
    #|  }
    #|  let name = match obj.get("name") {
    #|    Some(String(name)) => name
    #|    _ => raise @json.JsonDecodeError((path, "expected string for 'name'"))
    #|  }
    #|  let age = match obj.get("age") {
    #|    Some(Number(age, ..)) => age.to_int()
    #|    _ => raise @json.JsonDecodeError((path, "expected number for 'age'"))
    #|  }
    #|  let method_ = match obj.get("method") {
    #|    Some(String(method_)) => method_
    #|    _ => raise @json.JsonDecodeError((path, "expected string for 'method'"))
    #|  }
    #|  Person::{ name, age, method_ }
    #|}
  inspect(generate_jsonx_code(source), content=expected)
}

///|
test "ignore structs without jsonx marker" {
  let source =
    #|///|
    #|pub(all) struct Person {
    #|  name : String
    #|}
  inspect(generate_jsonx_code(source), content="")
}

///|
test "generate fallback decoders for non-primitive fields" {
  let source =
    #|///|
    #|#jsonx.struct
    #|pub(all) struct Payload {
    #|  tags : Array[String]
    #|  note : String?
    #|  owner : @pkg.User
    #|}
  let code = generate_jsonx_code(source)
  inspect(code.contains("path=path.add_key(\"tags\")"), content="true")
  inspect(code.contains("path=path.add_key(\"note\")"), content="true")
  inspect(code.contains("path=path.add_key(\"owner\")"), content="true")
  inspect(code.contains("expected value for 'tags'"), content="true")
}
