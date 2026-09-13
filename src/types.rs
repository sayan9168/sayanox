//! Lightweight type checker for Sayanox
//!
//! Tracks Number / String / List / Struct / Unknown.
//! Catches hold reassignment mismatches and bad binary ops.

use crate::ast::{BinOp, Expr, Program, Stmt};
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq)]
pub enum Ty {
    Number,
    String,
    List,
    Struct(String),
    Unknown,
}

impl Ty {
    fn name(&self) -> &str {
        match self {
            Ty::Number => "number",
            Ty::String => "string",
            Ty::List => "list",
            Ty::Struct(s) => s,
            Ty::Unknown => "unknown",
        }
    }
}

pub fn check(program: &Program) -> Result<(), String> {
    let mut vars: HashMap<String, Ty> = HashMap::new();
    let mut structs: HashMap<String, Vec<String>> = HashMap::new();
    for stmt in &program.statements {
        check_stmt(stmt, &mut vars, &mut structs)?;
    }
    Ok(())
}

fn check_stmt(
    stmt: &Stmt,
    vars: &mut HashMap<String, Ty>,
    structs: &mut HashMap<String, Vec<String>>,
) -> Result<(), String> {
    match stmt {
        Stmt::Hold { name, value } => {
            let ty = infer_expr(value, vars, structs)?;
            if let Some(prev) = vars.get(name) {
                if prev != &ty && ty != Ty::Unknown && prev != &Ty::Unknown {
                    return Err(format!(
                        "type error: cannot reassign `{}` from {} to {}",
                        name,
                        prev.name(),
                        ty.name()
                    ));
                }
            }
            vars.insert(name.clone(), ty);
            Ok(())
        }
        Stmt::Assign { name, value } => {
            let ty = infer_expr(value, vars, structs)?;
            match vars.get(name) {
                None => {
                    return Err(format!(
                        "type error: assignment to undeclared `{}` (use hold first)",
                        name
                    ))
                }
                Some(prev) if prev != &ty && ty != Ty::Unknown && prev != &Ty::Unknown => {
                    return Err(format!(
                        "type error: cannot assign {} to `{}` (was {})",
                        ty.name(),
                        name,
                        prev.name()
                    ))
                }
                _ => {}
            }
            Ok(())
        }
        Stmt::StructDef { name, fields } => {
            structs.insert(name.clone(), fields.clone());
            Ok(())
        }
        Stmt::Show(e) | Stmt::Give(e) | Stmt::Expr(e) => {
            infer_expr(e, vars, structs)?;
            Ok(())
        }
        Stmt::When {
            condition,
            then_body,
            otherwise_body,
        } => {
            infer_expr(condition, vars, structs)?;
            for s in then_body {
                check_stmt(s, vars, structs)?;
            }
            if let Some(body) = otherwise_body {
                for s in body {
                    check_stmt(s, vars, structs)?;
                }
            }
            Ok(())
        }
        Stmt::While { condition, body } => {
            infer_expr(condition, vars, structs)?;
            for s in body {
                check_stmt(s, vars, structs)?;
            }
            Ok(())
        }
        Stmt::Make { body, .. } => {
            for s in body {
                check_stmt(s, vars, structs)?;
            }
            Ok(())
        }
        Stmt::Use { .. } => Ok(()),
    }
}

fn infer_expr(
    expr: &Expr,
    vars: &HashMap<String, Ty>,
    structs: &HashMap<String, Vec<String>>,
) -> Result<Ty, String> {
    match expr {
        Expr::Number(_) => Ok(Ty::Number),
        Expr::String(_) => Ok(Ty::String),
        Expr::Ident(name) => Ok(vars.get(name).cloned().unwrap_or(Ty::Unknown)),
        Expr::Array(_) => Ok(Ty::List),
        Expr::StructLit { name, .. } => {
            if !structs.contains_key(name) && !name.is_empty() {
                // Allow even if not registered yet in same pass order
            }
            Ok(Ty::Struct(name.clone()))
        }
        Expr::Field { object, .. } => {
            infer_expr(object, vars, structs)?;
            Ok(Ty::Number)
        }
        Expr::Index { array, index } => {
            infer_expr(array, vars, structs)?;
            let it = infer_expr(index, vars, structs)?;
            if it != Ty::Number && it != Ty::Unknown {
                return Err("type error: index must be a number".into());
            }
            Ok(Ty::Number)
        }
        Expr::Call { name, args } => {
            for a in args {
                infer_expr(a, vars, structs)?;
            }
            Ok(match name.as_str() {
                "concat" | "str" | "read_file" | "upper" | "lower" | "trim" => Ty::String,
                "len" | "list_len" | "list_get" | "contains" | "starts_with" | "ends_with"
                | "write_file" | "push" => Ty::Number,
                _ => Ty::Unknown,
            })
        }
        Expr::Binary { left, op, right } => {
            let l = infer_expr(left, vars, structs)?;
            let r = infer_expr(right, vars, structs)?;
            match op {
                BinOp::Add
                | BinOp::Sub
                | BinOp::Mul
                | BinOp::Div
                | BinOp::Mod
                | BinOp::Gt
                | BinOp::Lt
                | BinOp::Gte
                | BinOp::Lte
                | BinOp::Eq
                | BinOp::Neq => {
                    if (l == Ty::String || r == Ty::String)
                        && matches!(op, BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod)
                    {
                        return Err(format!(
                            "type error: cannot use {:?} on string values",
                            op
                        ));
                    }
                    Ok(Ty::Number)
                }
            }
        }
    }
}
