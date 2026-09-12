//! User-facing compiler diagnostics for Sayanox.

use std::path::Path;

pub fn render_error(phase: &str, message: &str, source: &str, path: &Path) -> String {
    let line = extract_number_after(message, "line ").unwrap_or(1).max(1);
    let column = extract_number_after(message, "column ").unwrap_or(1).max(1);
    let lines: Vec<&str> = source.lines().collect();
    let source_line = lines.get(line.saturating_sub(1)).copied().unwrap_or("");
    let start = line.saturating_sub(1).max(1);
    let end = (line + 1).min(lines.len().max(1));

    let mut out = String::new();
    out.push_str(&format!("error[{}]: {}\n", phase, message));
    out.push_str(&format!(" --> {}:{}:{}\n", path.display(), line, column));
    out.push_str("  |\n");

    for number in start..=end {
        if let Some(text) = lines.get(number - 1) {
            out.push_str(&format!("{:>3} | {}\n", number, text));
            if number == line {
                let caret_column = column.saturating_sub(1).min(text.chars().count());
                out.push_str(&format!("    | {}^\n", " ".repeat(caret_column)));
            }
        }
    }

    if let Some(hint) = hint_for(message) {
        out.push_str(&format!("  = hint: {}\n", hint));
    }
    out.push_str("  = help: check the highlighted line and the token immediately before it\n");
    if source_line.trim().is_empty() {
        out.push_str("  = note: the reported line is empty or outside the available source\n");
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
    if digits.is_empty() { None } else { digits.parse().ok() }
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
    } else {
        None
    }
}
