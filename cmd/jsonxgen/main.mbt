///|
struct JsonxFieldSpec {
  label : String
  field_type : String
  json_key : String
}

///|
struct JsonxStructSpec {
  name : String
  fields : Array[JsonxFieldSpec]
}

///|
fn long_ident_text(id : @moonbitlang/parser/syntax.LongIdent) -> String {
  match id {
    Ident(name~) => name
    Dot(pkg~, id=target) => "@" + pkg + "." + target
  }
}

///|
fn type_list_text(tys : @list.List[@moonbitlang/parser/syntax.Type]) -> String {
  let parts : Array[String] = []
  tys.each(ty => parts.push(type_expr_text(ty)))
  parts.join(",")
}

///|
fn type_expr_text(ty : @moonbitlang/parser/syntax.Type) -> String {
  match ty {
    Name(constr_id~, tys~, ..) =>
      if tys is Empty {
        long_ident_text(constr_id.id)
      } else {
        "\{long_ident_text(constr_id.id)}[\{type_list_text(tys)}]"
      }
    Option(ty=inner, ..) => type_expr_text(inner) + "?"
    Tuple(tys~, ..) => "(\{type_list_text(tys)})"
    _ => "Json"
  }
}

///|
fn recover_attr_raw(
  source : String,
  attr : @moonbitlang/parser/attribute.Attribute,
) -> String {
  let loc = attr.loc
  let parse_pos = fn(s : String) -> (Int, Int) {
    let mut s = s
    if s.has_prefix("\"") && s.length() >= 2 {
      s = s[1:].to_owned()
    }
    if s.has_suffix("\"") && s.length() >= 1 {
      s = s[0:s.length() - 1].to_owned()
    }
    let parts = s.split(":").collect()
    let len = parts.length()
    if len >= 2 {
      let line = @string.parse_int(parts[len - 2]) catch { _ => -1 }
      let col = @string.parse_int(parts[len - 1]) catch { _ => -1 }
      (line, col)
    } else {
      (-1, -1)
    }
  }

  let (sl, sc) = parse_pos(loc.start.to_string())
  let (el, ec) = parse_pos(loc.end.to_string())
  let start_line = sl - 1
  let start_col = sc - 1
  let end_line = el - 1
  let end_col = ec - 1
  let lines = source.split("\n").collect()
  if start_line == end_line && start_line >= 0 && start_line < lines.length() {
    let line = lines[start_line]
    if start_col >= 0 && end_col <= line.length() && start_col <= end_col {
      return line[start_col:end_col].to_owned()
    }
  }
  ""
}

///|
fn attr_raw(
  source : String,
  attr : @moonbitlang/parser/attribute.Attribute,
) -> String {
  if attr.raw.contains("(") {
    attr.raw
  } else {
    let recovered = recover_attr_raw(source, attr)
    if recovered != "" {
      recovered
    } else {
      attr.raw
    }
  }
}

///|
fn extract_quoted_string(raw : String) -> String? {
  guard raw.find("\"") is Some(start_idx) else { return None }
  let tail = raw[start_idx + 1:].to_owned()
  guard tail.find("\"") is Some(end_rel) else { return None }
  Some(raw[start_idx + 1:start_idx + 1 + end_rel].to_owned())
}

///|
fn has_jsonx_struct(
  attrs : @list.List[@moonbitlang/parser/attribute.Attribute],
  source : String,
) -> Bool {
  let mut found = false
  attrs.each(attr => {
    if attr_raw(source, attr).has_prefix("#jsonx.struct") {
      found = true
    }
  })
  found
}

///|
fn json_key_for_field(
  attrs : @list.List[@moonbitlang/parser/attribute.Attribute],
  source : String,
  fallback : String,
) -> String {
  let mut result = fallback
  attrs.each(attr => {
    let raw = attr_raw(source, attr)
    if raw.has_prefix("#jsonx.key") {
      if extract_quoted_string(raw) is Some(value) {
        result = value
      }
    }
  })
  result
}

///|
fn parse_jsonx_structs_from_ast(
  ast : @list.List[@moonbitlang/parser/syntax.Impl],
  source : String,
) -> Array[JsonxStructSpec] {
  let specs : Array[JsonxStructSpec] = []
  ast.each(item => {
    if item is TopTypeDef(type_decl) {
      if type_decl
        is { tycon: name, components: Record(fields~, ..), attrs, .. } {
        guard has_jsonx_struct(attrs, source) else { return }
        let parsed_fields : Array[JsonxFieldSpec] = []
        fields.each(field => {
          if field is { name: { label, .. }, ty, attrs, .. } {
            parsed_fields.push({
              label,
              field_type: type_expr_text(ty),
              json_key: json_key_for_field(attrs, source, label),
            })
          }
        })
        specs.push({ name, fields: parsed_fields })
      }
    }
  })
  specs
}

///|
fn parse_jsonx_structs(source : String) -> Array[JsonxStructSpec] {
  let (ast, _) = @parser.parse_string(source)
  parse_jsonx_structs_from_ast(ast, source)
}

///|
fn json_string_literal(value : String) -> String {
  "\"" +
  value.replace(old="\\", new="\\\\").replace(old="\"", new="\\\"") +
  "\""
}

///|
fn render_to_json(spec : JsonxStructSpec) -> String {
  let entries : Array[String] = []
  for field in spec.fields {
    entries.push("\{json_string_literal(field.json_key)}: self.\{field.label}")
  }
  "///|\n" +
  "pub impl ToJson for " +
  spec.name +
  " with to_json(self) {\n" +
  "  { " +
  entries.join(", ") +
  " }\n" +
  "}"
}

///|
fn render_from_json_field(field : JsonxFieldSpec) -> String {
  let key = json_string_literal(field.json_key)
  let message = "'\{field.json_key}'"
  match field.field_type {
    "String" =>
      "  let " +
      field.label +
      " = match obj.get(" +
      key +
      ") {\n" +
      "    Some(String(" +
      field.label +
      ")) => " +
      field.label +
      "\n" +
      "    _ => raise @json.JsonDecodeError((path, \"expected string for " +
      message +
      "\"))\n" +
      "  }"
    "Int" =>
      "  let " +
      field.label +
      " = match obj.get(" +
      key +
      ") {\n" +
      "    Some(Number(" +
      field.label +
      ", ..)) => " +
      field.label +
      ".to_int()\n" +
      "    _ => raise @json.JsonDecodeError((path, \"expected number for " +
      message +
      "\"))\n" +
      "  }"
    _ =>
      "  let " +
      field.label +
      " = match obj.get(" +
      key +
      ") {\n" +
      "    Some(value) => @json.from_json(value, path=path.add_key(" +
      key +
      "))\n" +
      "    _ => raise @json.JsonDecodeError((path, \"expected value for " +
      message +
      "\"))\n" +
      "  }"
  }
}

///|
fn render_from_json(spec : JsonxStructSpec) -> String {
  let fields : Array[String] = []
  for field in spec.fields {
    fields.push(render_from_json_field(field))
  }
  let labels = spec.fields.map(field => field.label).join(", ")
  "///|\n" +
  "pub impl FromJson for " +
  spec.name +
  " with from_json(json, path) {\n" +
  "  guard json is Object(obj) else {\n" +
  "    raise @json.JsonDecodeError((path, \"expected object\"))\n" +
  "  }\n" +
  fields.join("\n") +
  "\n" +
  "  " +
  spec.name +
  "::{ " +
  labels +
  " }\n" +
  "}"
}

///|
fn render_jsonx_struct(spec : JsonxStructSpec) -> String {
  render_to_json(spec) + "\n\n" + render_from_json(spec)
}

///|
pub fn generate_jsonx_code(source : String) -> String {
  parse_jsonx_structs(source).map(render_jsonx_struct).join("\n\n")
}

///|
fn main {
  let argv = @sys.get_cli_args()
  let cli_args = if argv.length() > 0 { argv[1:] } else { [] }
  let cmd = @argparse.Command(
    "jsonxgen",
    about="Generate JSON codec impls from #jsonx.struct MoonBit structs",
    options=[
      OptionArg("output-file", short='o', about="Output file", required=true),
    ],
    positionals=[
      PositionArg(
        "input_file",
        about="Input MoonBit source file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )
  let matches = cmd.parse(argv=cli_args, env={}) catch {
    e => {
      println("\{e}")
      return
    }
  }
  let input_file = match matches.values.get("input_file") {
    Some([file, ..]) => file
    _ => {
      println(cmd.render_help())
      return
    }
  }
  let output_file = match matches.values.get("output-file") {
    Some([file, ..]) => file
    _ => {
      println(cmd.render_help())
      return
    }
  }
  try {
    let source = @fs.read_file_to_string(input_file)
    let code = generate_jsonx_code(source)
    @fs.write_string_to_file(output_file, code, encoding="utf8")
    println("Generated \{output_file}")
  } catch {
    IOError(e) => println("IOError: \{e}")
  }
}
