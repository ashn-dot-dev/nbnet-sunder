#!/usr/bin/env python3
import argparse
import json
import re
import subprocess

INDENT = " " * 4

RE_TYPE_FUN = re.compile(r"(.+)\((.+)\)")
RE_TYPE_ARR = re.compile(r"(.*)\[(\d+)\]")
RE_TYPE_PTR = re.compile(r"(.*)\*")
RE_TYPE_UXX = re.compile(r"unsigned (.+)")

# Mapping of excplicit declarations/definitions.
EXPLICIT = {
    "Word": "alias Word = u32;",
}

# Function pointer typedefs.
FUNCTION_PTR_TYPEDEFS = {
    "NBN_RPC_Func",
    "NBN_ChannelBuilder",
    "NBN_ChannelDestructor",
    "NBN_MessageSerializer",
    "NBN_MessageBuilder",
    "NBN_MessageDestructor",
    "NBN_Driver_StopFunc",
    "NBN_Driver_RecvPacketsFunc",
    "NBN_Driver_ClientStartFunc",
    "NBN_Driver_ClientSendPacketFunc",
    "NBN_Driver_ServerStartFunc",
    "NBN_Driver_ServerSendPacketToFunc",
    "NBN_Driver_ServerRemoveConnection",
    "NBN_Stream_SerializeUInt",
    "NBN_Stream_SerializeUInt64",
    "NBN_Stream_SerializeInt",
    "NBN_Stream_SerializeFloat",
    "NBN_Stream_SerializeBool",
    "NBN_Stream_SerializePadding",
    "NBN_Stream_SerializeBytes",
}

def identifier(s):
    # Set of Sunder keywords to be substituted.
    # Updated as necessary.
    KEYWORDS = {"func"}
    # Substitute `<identifier>` for `<identifier>_` if the identifier would be
    # a reserved keyword.
    return f"{s}_" if s in KEYWORDS else s

def generate_type(s):
    s = s.replace("const ", "").strip()
    s = s.replace("struct ", "").strip()
    s = s.replace("union ", "").strip()
    s = s.replace("enum ", "").strip()
    if s == "...":
        return "[]any" # Sunder does not have a replacement for varargs.
    match = RE_TYPE_FUN.match(s)
    if match:
        params = [generate_type(t) for t in match[2].split(",")] if match[2] != "void" else ""
        return f"func({', '.join(params)}) {generate_type(match[1])}"
    match = RE_TYPE_ARR.match(s)
    if match:
        return f"[{match[2]}]{generate_type(match[1])}"
    match = RE_TYPE_PTR.match(s)
    if match:
        return f"*{generate_type(match[1])}" if match[1].strip() != "void" else "*any"
    match = RE_TYPE_UXX.match(s)
    if match:
        return f"u{match[1]}"
    if s == "int":
        return "sint"
    if s == "short":
        return "sshort"
    if s == "long":
        return "slong"
    if s == "long long":
        return "slonglong"
    return s.strip()

def generate_type_function_pointer(s):
    # The qualified type will be reported by clang as:
    #
    #   rettype (*)(argtype1, argtype2, etc)'
    #
    # Removing the "(*)" and feeding the result through `generate_type`
    # should produce the proper Sunder function type:
    #
    #   int (*)(NBN_Stream *, unsigned int *, unsigned int, unsigned int)
    #       vvvv remove "(*)"
    #   int (NBN_Stream *, unsigned int *, unsigned int, unsigned int)
    #       vvvv generate_type
    #   func(*NBN_Stream, *uint, uint, uint) sint
    return generate_type(s.replace("(*)", ""))

def generate_typedef(node):
    assert node["kind"] == "TypedefDecl"
    match = RE_TYPE_FUN.match(node["type"]["qualType"])
    if not match:
        raise Exception(f"failed to match function typedef with type `{node['type']['qualType']}`")
    type = generate_type_function_pointer(node["type"]["qualType"])
    return f"alias {node['name']} = {type};"

def generate_function(node):
    assert node["kind"] == "FunctionDecl"
    match = RE_TYPE_FUN.match(node["type"]["qualType"])
    if not match:
        raise Exception(f"failed to match function with type `{node['type']['qualType']}`")
    return_type = generate_type(match[1])
    param_types = [generate_type(t) for t in match[2].split(",")] if match[2] != "void" else []
    # XXX: Function prototypes in nbnet.h do not have parameter names.
    # The generic parameter names param1, param2, etc. are used instead.
    return f"extern func {node['name']}(" + ", ".join([f"param{idx+1}: {t}" for idx, t in enumerate(param_types)]) + f") {return_type};"

def generate_struct(node):
    assert node["kind"] == "RecordDecl"
    assert node["tagUsed"] == "struct"
    assert node["completeDefinition"]
    lines = [f"struct {node['name']} {{"]
    for field in node["inner"]:
        if field["kind"] != "FieldDecl":
            continue
        if RE_TYPE_FUN.match(field["type"]["qualType"]):
            type = generate_type_function_pointer(field["type"]["qualType"])
            lines.append(f"{INDENT}var {identifier(field['name'])}: {type};")
            continue
        lines.append(f"{INDENT}var {identifier(field['name'])}: {generate_type(field['type']['qualType'])};")
    lines.append("}")
    return "\n".join(lines)

def generate_union(node):
    assert node["kind"] == "RecordDecl"
    assert node["tagUsed"] == "union"
    assert node["completeDefinition"]
    lines = [f"union {node['name']} {{"]
    for field in node["inner"]:
        if field["kind"] != "FieldDecl":
            continue
        lines.append(f"{INDENT}var {identifier(field['name'])}: {generate_type(field['type']['qualType'])};")
    lines.append("}")
    return "\n".join(lines)

def generate_enum(node):
    assert node["kind"] == "EnumDecl"
    lines = [f"enum {node['name']} {{"]
    for constant in node["inner"]:
        if constant["kind"] != "EnumConstantDecl":
            continue
        if constant.get("inner") is not None and constant["inner"][0].get("value") is not None:
            lines.append(f"{INDENT}{constant['name']} = {constant['inner'][0]['value']};")
        else:
            lines.append(f"{INDENT}{constant['name']};")
    lines.append("}")
    return "\n".join(lines)

def generate_node(node):
    if node["name"] in EXPLICIT:
        return EXPLICIT[node["name"]]
    if node["kind"] == "TypedefDecl":
        return generate_typedef(node)
    if node["kind"] == "FunctionDecl":
        return generate_function(node)
    if node["kind"] == "RecordDecl" and node["tagUsed"] == "struct":
        return generate_struct(node)
    if node["kind"] == "RecordDecl" and node["tagUsed"] == "union":
        return generate_union(node)
    if node["kind"] == "EnumDecl":
        return generate_enum(node)
    raise Exception(f"unhandled node `{node['name']}` with kind `{node['kind']}`")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("path", metavar="FILE")
    args = parser.parse_args()

    clang_ast_dump = ['clang', '-Xclang', '-ast-dump=json', '-c', args.path]
    ast = json.loads(subprocess.check_output(clang_ast_dump))
    assert ast["kind"] == "TranslationUnitDecl"

    def ast_node_from_nbnet(node):
        return (
            node.get("name") is not None and
            (node["name"].startswith("NBN") or node["name"] == "Word")
        )

    # Ignore builtin and included declarations/definitions.
    ast = [node for node in ast["inner"] if ast_node_from_nbnet(node)]

    def ast_node_is_forward_record_decl(node):
        return node["kind"] == "RecordDecl" and node.get("completeDefinition") is None

    # Ignore forward struct declations.
    ast = [node for node in ast if not ast_node_is_forward_record_decl(node)]

    def ast_node_is_unknown_typedef_decl(node):
        return (
            node["kind"] == "TypedefDecl" and
            node["name"] not in EXPLICIT and
            node["name"] not in FUNCTION_PTR_TYPEDEFS
        )

    # ignore all unknown typedefs.
    ast = [node for node in ast if not ast_node_is_unknown_typedef_decl(node)]

    print("import \"c\";")
    print("\n", end="")
    for node in ast:
        print(generate_node(node))

    # TODO: Compile and run `compare.sunder` and `compare.c`, then diff their
    # output to make sure that all types have the same size and alignment.
    if False:
        with open("compare.sunder", "w") as f:
            f.write("import \"std\";\n")
            f.write("import \"nbnet.sunder\";\n")
            f.write("func main() void {\n")
            for node in ast:
                if node["kind"] == "FunctionDecl":
                    continue
                f.write(f"{INDENT}let {node['name']}_size = sizeof({node['name']});\n")
                f.write(f"{INDENT}let {node['name']}_align = alignof({node['name']});\n")
                f.write(f"{INDENT}std::print_format_line(std::out(), \"{node['name']} {{}} {{}}\", (:[]std::formatter)[std::formatter::init[[usize]](&{node['name']}_size), std::formatter::init[[usize]](&{node['name']}_align)]);\n")
            f.write("}")

        with open("compare.c", "w") as f:
            f.write("#include <stdalign.h>\n")
            f.write("#include <stdio.h>\n")
            f.write("#include <nbnet.h>\n")
            f.write("int main(void) {\n")
            for node in ast:
                if node["kind"] == "FunctionDecl":
                    continue
                f.write(f"printf(\"{INDENT}{node['name']} %zu %zu\\n\", sizeof({node['name']}), alignof({node['name']}));\n")
            f.write("}")

if __name__ == "__main__":
    main()
