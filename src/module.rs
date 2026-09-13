//! Multi-file modules with export / namespace rules
//!
//! - `use "math.sa"` loads a sibling file
//! - If the file uses any `export`, only exported make/hold/struct are public
//! - Private makes are renamed `m<id>_<name>` so they cannot collide

use crate::ast::{Expr, Program, Stmt};
use crate::lexer::Lexer;
use crate::parser::Parser;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};

static MODULE_ID: AtomicUsize = AtomicUsize::new(1);

pub fn load_program(entry: &Path) -> Result<Program, String> {
    let mut visited = HashSet::new();
    load_recursive(entry, &mut visited, true)
}

fn load_recursive(
    path: &Path,
    visited: &mut HashSet<PathBuf>,
    is_entry: bool,
) -> Result<Program, String> {
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
    let tokens = lexer
        .tokenize()
        .map_err(|e| format!("{}: {}", canon.display(), e))?;
    let mut parser = Parser::new(tokens);
    let program = parser
        .parse()
        .map_err(|e| format!("{}: {}", canon.display(), e))?;

    let parent = canon.parent().unwrap_or_else(|| Path::new("."));
    let mut statements = Vec::new();
    let mod_id = MODULE_ID.fetch_add(1, Ordering::Relaxed);

    let has_export = program.statements.iter().any(|s| is_exported(s));

    for stmt in program.statements {
        match stmt {
            Stmt::Use { path: rel } => {
                let child = parent.join(&rel);
                let nested = load_recursive(&child, visited, false)?;
                statements.extend(nested.statements);
            }
            other => {
                if is_entry || !has_export || is_exported(&other) {
                    statements.push(rewrite_private(other, mod_id, has_export && !is_entry));
                } else {
                    // private helper kept under rewritten name so exported code can call it
                    statements.push(rewrite_private(other, mod_id, true));
                }
            }
        }
    }

    Ok(Program { statements })
}

fn is_exported(stmt: &Stmt) -> bool {
    match stmt {
        Stmt::Hold { exported, .. }
        | Stmt::Make { exported, .. }
        | Stmt::StructDef { exported, .. } => *exported,
        _ => false,
    }
}

fn rewrite_private(stmt: Stmt, mod_id: usize, force_private_names: bool) -> Stmt {
    match stmt {
        Stmt::Make {
            name,
            params,
            body,
            exported,
        } => {
            let name = if force_private_names && !exported {
                format!("m{}_{}", mod_id, name)
            } else {
                name
            };
            let body = body
                .into_iter()
                .map(|s| rewrite_private(s, mod_id, force_private_names))
                .collect();
            Stmt::Make {
                name,
                params,
                body,
                exported,
            }
        }
        Stmt::Hold {
            name,
            value,
            exported,
        } => {
            let name = if force_private_names && !exported {
                format!("m{}_{}", mod_id, name)
            } else {
                name
            };
            Stmt::Hold {
                name,
                value: rewrite_expr(value, mod_id, force_private_names),
                exported,
            }
        }
        Stmt::StructDef {
            name,
            fields,
            exported,
        } => {
            let name = if force_private_names && !exported {
                format!("M{}_{}", mod_id, name)
            } else {
                name
            };
            Stmt::StructDef {
                name,
                fields,
                exported,
            }
        }
        Stmt::Show(e) => Stmt::Show(rewrite_expr(e, mod_id, force_private_names)),
        Stmt::Assign { name, value } => Stmt::Assign {
            name,
            value: rewrite_expr(value, mod_id, force_private_names),
        },
        Stmt::Give(e) => Stmt::Give(rewrite_expr(e, mod_id, force_private_names)),
        Stmt::When {
            condition,
            then_body,
            otherwise_body,
        } => Stmt::When {
            condition: rewrite_expr(condition, mod_id, force_private_names),
            then_body: then_body
                .into_iter()
                .map(|s| rewrite_private(s, mod_id, force_private_names))
                .collect(),
            otherwise_body: otherwise_body.map(|b| {
                b.into_iter()
                    .map(|s| rewrite_private(s, mod_id, force_private_names))
                    .collect()
            }),
        },
        Stmt::While { condition, body } => Stmt::While {
            condition: rewrite_expr(condition, mod_id, force_private_names),
            body: body
                .into_iter()
                .map(|s| rewrite_private(s, mod_id, force_private_names))
                .collect(),
        },
        Stmt::Expr(e) => Stmt::Expr(rewrite_expr(e, mod_id, force_private_names)),
        other => other,
    }
}

fn rewrite_expr(expr: Expr, mod_id: usize, force: bool) -> Expr {
    if !force {
        return expr;
    }
    match expr {
        Expr::Call { name, args } => Expr::Call {
            name: if name.starts_with('m') || stdlib_name(&name) {
                name
            } else {
                // leave public calls as-is; private helpers already rewritten at def site
                name
            },
            args: args
                .into_iter()
                .map(|a| rewrite_expr(a, mod_id, force))
                .collect(),
        },
        Expr::Binary { left, op, right } => Expr::Binary {
            left: Box::new(rewrite_expr(*left, mod_id, force)),
            op,
            right: Box::new(rewrite_expr(*right, mod_id, force)),
        },
        Expr::Array(xs) => Expr::Array(
            xs.into_iter()
                .map(|x| rewrite_expr(x, mod_id, force))
                .collect(),
        ),
        Expr::Index { array, index } => Expr::Index {
            array: Box::new(rewrite_expr(*array, mod_id, force)),
            index: Box::new(rewrite_expr(*index, mod_id, force)),
        },
        Expr::Field { object, field } => Expr::Field {
            object: Box::new(rewrite_expr(*object, mod_id, force)),
            field,
        },
        Expr::StructLit { name, fields } => Expr::StructLit {
            name,
            fields: fields
                .into_iter()
                .map(|(k, v)| (k, rewrite_expr(v, mod_id, force)))
                .collect(),
        },
        other => other,
    }
}

fn stdlib_name(name: &str) -> bool {
    matches!(
        name,
        "len" | "concat"
            | "contains"
            | "starts_with"
            | "ends_with"
            | "upper"
            | "lower"
            | "trim"
            | "push"
            | "list_len"
            | "list_get"
            | "read_file"
            | "write_file"
            | "str"
    )
}
