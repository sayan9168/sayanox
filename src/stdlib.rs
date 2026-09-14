//! Small built-in standard library registry.
//!
//! The registry is the canonical compiler-facing description of the first
//! standard library surface. Runtime implementations live in the VM and
//! generated C runtime, while this module provides stable names, categories,
//! arity, and documentation for compiler tooling.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BuiltinKind { String, List, Io, Conversion }

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct BuiltinSpec {
    pub name: &'static str,
    pub kind: BuiltinKind,
    pub min_args: usize,
    pub max_args: usize,
    pub description: &'static str,
}

pub const BUILTINS: &[BuiltinSpec] = &[
    BuiltinSpec { name: "len", kind: BuiltinKind::String, min_args: 1, max_args: 1, description: "Return the length of a string or list." },
    BuiltinSpec { name: "string_len", kind: BuiltinKind::String, min_args: 1, max_args: 1, description: "Return the Unicode character length of a string." },
    BuiltinSpec { name: "concat", kind: BuiltinKind::String, min_args: 2, max_args: 2, description: "Concatenate two strings." },
    BuiltinSpec { name: "char_at", kind: BuiltinKind::String, min_args: 2, max_args: 2, description: "Return the Unicode character at an index." },
    BuiltinSpec { name: "char_code", kind: BuiltinKind::String, min_args: 2, max_args: 2, description: "Return the Unicode scalar value at an index." },
    BuiltinSpec { name: "contains", kind: BuiltinKind::String, min_args: 2, max_args: 2, description: "Check whether a string contains another string." },
    BuiltinSpec { name: "starts_with", kind: BuiltinKind::String, min_args: 2, max_args: 2, description: "Check whether a string starts with a prefix." },
    BuiltinSpec { name: "ends_with", kind: BuiltinKind::String, min_args: 2, max_args: 2, description: "Check whether a string ends with a suffix." },
    BuiltinSpec { name: "upper", kind: BuiltinKind::String, min_args: 1, max_args: 1, description: "Return an uppercase copy of a string." },
    BuiltinSpec { name: "lower", kind: BuiltinKind::String, min_args: 1, max_args: 1, description: "Return a lowercase copy of a string." },
    BuiltinSpec { name: "trim", kind: BuiltinKind::String, min_args: 1, max_args: 1, description: "Return a trimmed copy of a string." },
    BuiltinSpec { name: "push", kind: BuiltinKind::List, min_args: 2, max_args: 2, description: "Append a value to a list variable." },
    BuiltinSpec { name: "list_len", kind: BuiltinKind::List, min_args: 1, max_args: 1, description: "Return a list length." },
    BuiltinSpec { name: "list_get", kind: BuiltinKind::List, min_args: 2, max_args: 2, description: "Read a list element by index." },
    BuiltinSpec { name: "read_file", kind: BuiltinKind::Io, min_args: 1, max_args: 1, description: "Read a UTF-8 file into a string." },
    BuiltinSpec { name: "write_file", kind: BuiltinKind::Io, min_args: 2, max_args: 2, description: "Write a string to a file." },
    BuiltinSpec { name: "str", kind: BuiltinKind::Conversion, min_args: 1, max_args: 1, description: "Convert a value to a string." },
];

pub fn builtin(name: &str) -> Option<&'static BuiltinSpec> { BUILTINS.iter().find(|spec| spec.name == name) }
pub fn is_builtin(name: &str) -> bool { builtin(name).is_some() }
pub fn accepts_arity(name: &str, argc: usize) -> bool { builtin(name).is_some_and(|spec| argc >= spec.min_args && argc <= spec.max_args) }

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn registry_contains_runtime_builtins() { assert!(is_builtin("len")); assert!(is_builtin("string_len")); assert!(is_builtin("char_at")); assert!(is_builtin("char_code")); assert!(is_builtin("push")); assert!(is_builtin("read_file")); assert!(!is_builtin("missing_builtin")); }
    #[test] fn builtin_arity_is_available_to_compiler_layers() { assert!(accepts_arity("concat", 2)); assert!(!accepts_arity("concat", 1)); assert!(accepts_arity("string_len", 1)); assert!(accepts_arity("char_at", 2)); assert!(accepts_arity("char_code", 2)); assert!(!accepts_arity("len", 2)); }
}
