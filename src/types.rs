//! Deeper lightweight type checker for Sayanox

use crate::ast::{BinOp, Expr, Program, Stmt};
use crate::stdlib;
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq)]
pub enum Ty { Number, String, Bool, List, Struct(String), Func { params: Vec<Ty>, ret: Box<Ty> }, Unknown }

impl Ty {
    fn name(&self) -> String { match self { Ty::Number => "number".into(), Ty::String => "string".into(), Ty::Bool => "bool".into(), Ty::List => "list".into(), Ty::Struct(s) => format!("struct {}", s), Ty::Func { .. } => "function".into(), Ty::Unknown => "unknown".into() } }
    fn compatible(&self, other: &Ty) -> bool { self == other || self == &Ty::Unknown || other == &Ty::Unknown || matches!((self, other), (Ty::Struct(_), Ty::Struct(_))) }
    fn is_condition(&self) -> bool { matches!(self, Ty::Number | Ty::Bool | Ty::Unknown) }
}

pub fn check(program: &Program) -> Result<(), String> {
    let mut vars: HashMap<String, Ty> = HashMap::new();
    let mut structs: HashMap<String, Vec<String>> = HashMap::new();
    let mut funcs: HashMap<String, (Vec<Ty>, Ty)> = HashMap::new();
    for spec in stdlib::BUILTINS { let _ = spec; }
    for stmt in &program.statements { check_stmt(stmt, &mut vars, &mut structs, &mut funcs, false)?; }
    Ok(())
}

fn check_stmt(stmt: &Stmt, vars: &mut HashMap<String, Ty>, structs: &mut HashMap<String, Vec<String>>, funcs: &mut HashMap<String, (Vec<Ty>, Ty)>, in_fn: bool) -> Result<(), String> {
    match stmt {
        Stmt::Hold { name, value, .. } => { let ty = infer_expr(value, vars, structs, funcs)?; if let Some(prev) = vars.get(name) { if !prev.compatible(&ty) { return Err(format!("type error: cannot reassign `{}` from {} to {}", name, prev.name(), ty.name())); } } vars.insert(name.clone(), ty); Ok(()) }
        Stmt::Assign { name, value } => { let ty = infer_expr(value, vars, structs, funcs)?; match vars.get(name) { None => Err(format!("type error: assignment to undeclared `{}` (use hold first)", name)), Some(prev) if !prev.compatible(&ty) => Err(format!("type error: cannot assign {} to `{}` (was {})", ty.name(), name, prev.name())), _ => Ok(()) } }
        Stmt::StructDef { name, fields, .. } => { structs.insert(name.clone(), fields.clone()); Ok(()) }
        Stmt::Make { name, params, body, .. } => { let param_tys = vec![Ty::Number; params.len()]; funcs.insert(name.clone(), (param_tys.clone(), Ty::Number)); let mut local = vars.clone(); for p in params { local.insert(p.clone(), Ty::Number); } for s in body { check_stmt(s, &mut local, structs, funcs, true)?; } Ok(()) }
        Stmt::Show(e) | Stmt::Expr(e) => { infer_expr(e, vars, structs, funcs)?; Ok(()) }
        Stmt::Give(e) => { if !in_fn { return Err("type error: `give` is only valid inside a function".into()); } infer_expr(e, vars, structs, funcs)?; Ok(()) }
        Stmt::When { condition, then_body, otherwise_body } => { let ct = infer_expr(condition, vars, structs, funcs)?; if !ct.is_condition() { return Err(format!("type error: when condition must be bool or number, got {}", ct.name())); } for s in then_body { check_stmt(s, vars, structs, funcs, in_fn)?; } if let Some(body) = otherwise_body { for s in body { check_stmt(s, vars, structs, funcs, in_fn)?; } } Ok(()) }
        Stmt::While { condition, body } => { let ct = infer_expr(condition, vars, structs, funcs)?; if !ct.is_condition() { return Err(format!("type error: while condition must be bool or number, got {}", ct.name())); } for s in body { check_stmt(s, vars, structs, funcs, in_fn)?; } Ok(()) }
        Stmt::Use { .. } => Ok(()),
    }
}

fn infer_expr(expr: &Expr, vars: &HashMap<String, Ty>, structs: &HashMap<String, Vec<String>>, funcs: &HashMap<String, (Vec<Ty>, Ty)>) -> Result<Ty, String> {
    match expr {
        Expr::Number(_) => Ok(Ty::Number), Expr::String(_) => Ok(Ty::String), Expr::Ident(name) => Ok(vars.get(name).cloned().unwrap_or(Ty::Unknown)), Expr::Array(_) => Ok(Ty::List),
        Expr::StructLit { name, fields } => { if let Some(expected) = structs.get(name) { for (fname, _) in fields { if !expected.iter().any(|f| f == fname) { return Err(format!("type error: struct `{}` has no field `{}`", name, fname)); } } } for (_, v) in fields { infer_expr(v, vars, structs, funcs)?; } Ok(Ty::Struct(name.clone())) }
        Expr::Field { object, field } => { let ot = infer_expr(object, vars, structs, funcs)?; if let Ty::Struct(sname) = &ot { if let Some(fields) = structs.get(sname) { if !fields.iter().any(|f| f == field) { return Err(format!("type error: struct `{}` has no field `{}`", sname, field)); } } } Ok(Ty::Number) }
        Expr::Index { array, index } => { let at = infer_expr(array, vars, structs, funcs)?; let it = infer_expr(index, vars, structs, funcs)?; if !it.compatible(&Ty::Number) { return Err("type error: index must be a number".into()); } match at { Ty::List => Ok(Ty::Number), Ty::String => Ok(Ty::String), Ty::Unknown => Ok(Ty::Unknown), other => Err(format!("type error: cannot index {}", other.name())) } }
        Expr::Call { name, args } => {
            for a in args { infer_expr(a, vars, structs, funcs)?; }
            if let Some(spec) = stdlib::builtin(name) { if args.len() < spec.min_args || args.len() > spec.max_args { let expected = if spec.min_args == spec.max_args { spec.min_args.to_string() } else { format!("{}..{}", spec.min_args, spec.max_args) }; return Err(format!("type error: wrong number of arguments for `{}`: expected {}, got {}", name, expected, args.len())); } }
            if let Some((params, ret)) = funcs.get(name) { if params.len() != args.len() { return Err(format!("type error: wrong number of arguments for `{}`: expected {}, got {}", name, params.len(), args.len())); } return Ok(ret.clone()); }
            Ok(match name.as_str() { "concat" | "str" | "read_file" | "upper" | "lower" | "trim" | "char_at" => Ty::String, "char_code" | "len" | "list_len" | "list_get" | "write_file" | "push" => Ty::Number, "contains" | "starts_with" | "ends_with" => Ty::Bool, _ => Ty::Unknown })
        }
        Expr::Binary { left, op, right } => {
            let l = infer_expr(left, vars, structs, funcs)?; let r = infer_expr(right, vars, structs, funcs)?;
            if matches!(op, BinOp::Eq | BinOp::Neq | BinOp::Gt | BinOp::Lt | BinOp::Gte | BinOp::Lte) { if !l.compatible(&r) { return Err(format!("type error: cannot compare {} with {}", l.name(), r.name())); } return Ok(Ty::Bool); }
            if matches!(op, BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod) && (l == Ty::String || r == Ty::String) { return Err(format!("type error: cannot use arithmetic on string values ({:?})", op)); }
            if matches!(op, BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod) && !l.compatible(&Ty::Number) && l != Ty::Unknown { return Err(format!("type error: left operand of {:?} must be number, got {}", op, l.name())); }
            if matches!(op, BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod) && !r.compatible(&Ty::Number) && r != Ty::Unknown { return Err(format!("type error: right operand of {:?} must be number, got {}", op, r.name())); }
            Ok(Ty::Number)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*; use crate::ast::{Expr, Program, Stmt};
    #[test] fn rejects_string_math() { let program = Program { statements: vec![Stmt::Show(Expr::Binary { left: Box::new(Expr::String("a".into())), op: BinOp::Add, right: Box::new(Expr::Number(1.0)) })]}; assert!(check(&program).is_err()); }
    #[test] fn accepts_number_math() { let program = Program { statements: vec![Stmt::Show(Expr::Binary { left: Box::new(Expr::Number(1.0)), op: BinOp::Add, right: Box::new(Expr::Number(2.0)) })]}; assert!(check(&program).is_ok()); }
    #[test] fn checks_builtin_arity_from_registry() { let program = Program { statements: vec![Stmt::Show(Expr::Call { name: "concat".into(), args: vec![Expr::String("a".into())] })]}; assert!(check(&program).is_err()); }
    #[test] fn comparisons_produce_bool() { let program = Program { statements: vec![Stmt::Show(Expr::Binary { left: Box::new(Expr::Number(1.0)), op: BinOp::Eq, right: Box::new(Expr::Number(1.0)) })]}; assert!(check(&program).is_ok()); }
}
