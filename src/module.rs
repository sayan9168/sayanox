//! Multi-file module resolution for Sayanox
//!
//! Syntax:
//!   use "math.sa"
//!
//! Paths are resolved relative to the file that contains the `use`.
//! Circular imports are rejected.

use crate::ast::{Program, Stmt};
use crate::lexer::Lexer;
use crate::parser::Parser;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

pub fn load_program(entry: &Path) -> Result<Program, String> {
    let mut visited = HashSet::new();
    load_recursive(entry, &mut visited)
}

fn load_recursive(path: &Path, visited: &mut HashSet<PathBuf>) -> Result<Program, String> {
    let canon = path
        .canonicalize()
        .map_err(|e| format!("cannot open {}: {}", path.display(), e))?;
    if !visited.insert(canon.clone()) {
        return Err(format!(
            "circular module import involving {}",
            path.display()
        ));
    }

    let source = fs::read_to_string(&canon)
        .map_err(|e| format!("failed to read {}: {}", canon.display(), e))?;
    let mut lexer = Lexer::new(&source);
    let tokens = lexer.tokenize().map_err(|e| format!("{}: {}", canon.display(), e))?;
    let mut parser = Parser::new(tokens);
    let program = parser
        .parse()
        .map_err(|e| format!("{}: {}", canon.display(), e))?;

    let parent = canon.parent().unwrap_or_else(|| Path::new("."));
    let mut statements = Vec::new();

    for stmt in program.statements {
        match stmt {
            Stmt::Use { path: rel } => {
                let child = parent.join(&rel);
                let nested = load_recursive(&child, visited)?;
                statements.extend(nested.statements);
            }
            other => statements.push(other),
        }
    }

    Ok(Program { statements })
}
