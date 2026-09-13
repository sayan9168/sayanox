//! User-facing compiler diagnostics for Sayanox.
//! Snippet + caret for every phase when line/column are known.

use std::path::Path;

/// Render a full diagnostic with source snippet and caret.
pub fn render_error(phase: &str, message: &str, source: &str, path: &Path) -> String {
    let line = extract_number_after(message, "line ").unwrap_or(1).max(1);
    let column = extract_number_after(message, "column ").unwrap_or(1).max(1);
    render_at(phase, message, source, path, line, column)
}

/// Render with explicit location (type checker, module loader, etc.).
pub fn render_at(
    phase: &str,
    message: &str,
    source: &str,
    path: &Path,
    line: usize,
    column: usize,
) -> String {
    let line = line.max(1);
    let column = column.max(1);
    let lines: Vec<&str> = source.lines().collect();
    let start = line.saturating_sub(1).max(1);
    let end = (line + 1).min(lines.len().max(1));

    let mut out = String::new();
    out.push_str(&format!("error[{}]: {}\n", phase, message));
    out.push_str(&format!(" --> {}:{}:{}\n", path.display(), line, column));
    out.push_str("  |\n");

    if lines.is_empty() {
        out.push_str("  | <empty file>\n");
    } else {
        for number in start..=end {
            if let Some(text) = lines.get(number - 1) {
                out.push_str(&format!("{:>3} | {}\n", number, text));
                if number == line {
                    let caret_column = column.saturating_sub(1).min(text.chars().count());
                    out.push_str(&format!("    | {}^\n", " ".repeat(caret_column)));
                }
            }
        }
    }

    if let Some(hint) = hint_for(message) {
        out.push_str(&format!("  = hint: {}\n", hint));
    }
    out.push_str("  = help: check the highlighted line and the token immediately before it\n");
    out
}

/// Message-only diagnostic when source is unavailable.
pub fn render_message(phase: &str, message: &str) -> String {
    let mut out = format!("error[{}]: {}\n", phase, message);
    if let Some(hint) = hint_for(message) {
        out.push_str(&format!("  = hint: {}\n", hint));
    }
    out
}

fn extract_number_after(message: &str, marker: &str) -> Option<usize> {
    let start = message.find(marker)? + marker.len();
    let digits: String = message[start..]
        .chars()
        .skip_while(|c| c.is_ascii_whitespace())
        .take_while(|c| c.is_ascii_digit())
        .collect();
    if digits.is_empty() {
        None
    } else {
        digits.parse().ok()
    }
}

fn hint_for(message: &str) -> Option<&'static str> {
    let lower = message.to_ascii_lowercase();
    if lower.contains("expected ')'") {
        Some("make sure every opening '(' has a matching ')' and arguments are comma-separated")
    } else if lower.contains("expected '}'") {
        Some("close the current block with '}'")
    } else if lower.contains("expected ']'") {
        Some("close the list or index expression with ']'")
    } else if lower.contains("expected '='") {
        Some("declare a value as `hold name = value`")
    } else if lower.contains("expected field name") {
        Some("use `value.field` for access and `Type { field: value }` for a struct literal")
    } else if lower.contains("unexpected character") {
        Some("use identifiers, numbers, strings, operators, brackets, and `//` comments")
    } else if lower.contains("unterminated string") {
        Some("add the closing double quote to the string")
    } else if lower.contains("type error") {
        Some("use matching types for assignment and operators; try `sayanox file.sa --check`")
    } else if lower.contains("circular module") {
        Some("remove the cycle in `use` imports")
    } else if lower.contains("not exported") {
        Some("mark the symbol with `export make` / `export hold` / `export struct` in that file")
    } else if lower.contains("wrong number of arguments") {
        Some("check the builtin or function arity")
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn snippet_contains_caret() {
        let src = "hold x = 1\nshow x\n";
        let out = render_at("parser", "expected '}'", src, &PathBuf::from("t.sa"), 2, 1);
        assert!(out.contains('^'));
        assert!(out.contains("show x"));
        assert!(out.contains("error[parser]"));
    }
}
