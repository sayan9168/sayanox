//! Small built-in standard library registry.
//!
//! These names are implemented by the compiler runtime and are intentionally
//! kept small. The registry gives tooling and documentation one canonical list.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BuiltinKind {
    String,
    List,
    Io,
    Conversion,
}

pub const BUILTINS: &[(&str, BuiltinKind, &str)] = &[
    ("len", BuiltinKind::String, "Return the length of a string or list."),
    ("concat", BuiltinKind::String, "Concatenate two strings."),
    ("contains", BuiltinKind::String, "Check whether a string contains another string."),
    ("starts_with", BuiltinKind::String, "Check whether a string starts with a prefix."),
    ("ends_with", BuiltinKind::String, "Check whether a string ends with a suffix."),
    ("upper", BuiltinKind::String, "Return an uppercase copy of a string."),
    ("lower", BuiltinKind::String, "Return a lowercase copy of a string."),
    ("trim", BuiltinKind::String, "Return a trimmed copy of a string."),
    ("push", BuiltinKind::List, "Append a number to a list."),
    ("list_len", BuiltinKind::List, "Return a list length."),
    ("list_get", BuiltinKind::List, "Read a list element by index."),
    ("read_file", BuiltinKind::Io, "Read a UTF-8 file into a string."),
    ("write_file", BuiltinKind::Io, "Write a string to a file."),
    ("str", BuiltinKind::Conversion, "Convert a number to a string."),
];

pub fn is_builtin(name: &str) -> bool {
    BUILTINS.iter().any(|(builtin, _, _)| *builtin == name)
}
