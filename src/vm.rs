//! First-party Sayanox runtime VM.
//!
//! The VM executes the parsed Sayanox AST directly. It deliberately stays on
//! the standard library so the normal `--run` path does not require C, Clang,
//! or a third-party runtime.

use crate::ast::{BinOp, Expr, Program, Stmt};
use std::collections::HashMap;
use std::fs;

#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Number(f64),
    String(String),
    Bool(bool),
    List(Vec<Value>),
    Struct { name: String, fields: HashMap<String, Value> },
    Null,
}

impl Value {
    fn truthy(&self) -> bool {
        match self {
            Self::Bool(v) => *v,
            Self::Number(v) => *v != 0.0,
            Self::String(v) => !v.is_empty(),
            Self::List(v) => !v.is_empty(),
            Self::Null => false,
            Self::Struct { .. } => true,
        }
    }

    pub fn display(&self) -> String {
        match self {
            Self::Number(v) if v.fract() == 0.0 => format!("{v:.0}"),
            Self::Number(v) => v.to_string(),
            Self::String(v) => v.clone(),
            Self::Bool(v) => v.to_string(),
            Self::List(v) => format!("[{}]", v.iter().map(Self::display).collect::<Vec<_>>().join(", ")),
            Self::Struct { name, fields } => {
                let mut parts = fields.iter().map(|(k, v)| format!("{k}: {}", v.display())).collect::<Vec<_>>();
                parts.sort();
                format!("{name} {{ {} }}", parts.join(", "))
            }
            Self::Null => "null".into(),
        }
    }
}

#[derive(Clone)]
struct Function {
    params: Vec<String>,
    body: Vec<Stmt>,
}

enum Flow {
    Normal(Value),
    Return(Value),
}

pub fn run(program: &Program) -> Result<Value, String> {
    let mut vm = Vm { scopes: vec![HashMap::new()], functions: HashMap::new() };
    vm.collect_functions(program);
    let mut last = Value::Null;
    for statement in &program.statements {
        match vm.exec(statement)? {
            Flow::Normal(value) => last = value,
            Flow::Return(value) => return Ok(value),
        }
    }
    Ok(last)
}

struct Vm {
    scopes: Vec<HashMap<String, Value>>,
    functions: HashMap<String, Function>,
}

impl Vm {
    fn collect_functions(&mut self, program: &Program) {
        for statement in &program.statements {
            if let Stmt::Make { name, params, body, .. } = statement {
                self.functions.insert(name.clone(), Function { params: params.clone(), body: body.clone() });
            }
        }
    }

    fn get(&self, name: &str) -> Option<Value> {
        self.scopes.iter().rev().find_map(|scope| scope.get(name).cloned())
    }

    fn set(&mut self, name: &str, value: Value) {
        for scope in self.scopes.iter_mut().rev() {
            if scope.contains_key(name) {
                scope.insert(name.into(), value);
                return;
            }
        }
        self.scopes.last_mut().unwrap().insert(name.into(), value);
    }

    fn exec(&mut self, statement: &Stmt) -> Result<Flow, String> {
        match statement {
            Stmt::Show(expr) => {
                println!("{}", self.eval(expr)?.display());
                Ok(Flow::Normal(Value::Null))
            }
            Stmt::Hold { name, value, .. } | Stmt::Assign { name, value } => {
                let value = self.eval(value)?;
                self.set(name, value.clone());
                Ok(Flow::Normal(value))
            }
            Stmt::Give(expr) => Ok(Flow::Return(self.eval(expr)?)),
            Stmt::Expr(expr) => Ok(Flow::Normal(self.eval(expr)?)),
            Stmt::When { condition, then_body, otherwise_body } => {
                let branch = if self.eval(condition)?.truthy() { Some(then_body) } else { otherwise_body.as_ref() };
                self.exec_block(branch)
            }
            Stmt::While { condition, body } => {
                let mut last = Value::Null;
                let mut guard = 0usize;
                while self.eval(condition)?.truthy() {
                    match self.exec_block(Some(body))? {
                        Flow::Normal(value) => last = value,
                        Flow::Return(value) => return Ok(Flow::Return(value)),
                    }
                    guard += 1;
                    if guard > 10_000_000 { return Err("runtime error: loop iteration limit exceeded".into()); }
                }
                Ok(Flow::Normal(last))
            }
            Stmt::Make { .. } | Stmt::StructDef { .. } | Stmt::Use { .. } => Ok(Flow::Normal(Value::Null)),
        }
    }

    fn exec_block(&mut self, body: Option<&Vec<Stmt>>) -> Result<Flow, String> {
        let Some(body) = body else { return Ok(Flow::Normal(Value::Null)); };
        let mut last = Value::Null;
        for statement in body {
            match self.exec(statement)? {
                Flow::Normal(value) => last = value,
                Flow::Return(value) => return Ok(Flow::Return(value)),
            }
        }
        Ok(Flow::Normal(last))
    }

    fn eval(&mut self, expr: &Expr) -> Result<Value, String> {
        match expr {
            Expr::Number(value) => Ok(Value::Number(*value)),
            Expr::String(value) => Ok(Value::String(value.clone())),
            Expr::Ident(name) => self.get(name).ok_or_else(|| format!("undefined variable `{name}`")),
            Expr::Array(items) => Ok(Value::List(items.iter().map(|item| self.eval(item)).collect::<Result<Vec<_>, _>>()?)),
            Expr::Index { array, index } => {
                let array = self.eval(array)?;
                let index = number_index(&self.eval(index)?)?;
                match array {
                    Value::List(values) => values.get(index).cloned().ok_or_else(|| "index out of bounds".into()),
                    Value::String(value) => value.chars().nth(index).map(|c| Value::String(c.to_string())).ok_or_else(|| "index out of bounds".into()),
                    _ => Err("value is not indexable".into()),
                }
            }
            Expr::Field { object, field } => match self.eval(object)? {
                Value::Struct { fields, .. } => fields.get(field).cloned().ok_or_else(|| format!("unknown field `{field}`")),
                _ => Err("field access requires a struct value".into()),
            },
            Expr::StructLit { name, fields } => {
                let mut object = HashMap::new();
                for (field, value) in fields { object.insert(field.clone(), self.eval(value)?); }
                Ok(Value::Struct { name: name.clone(), fields: object })
            }
            Expr::Binary { left, op, right } => {
                let left_value = self.eval(left)?;
                let right_value = self.eval(right)?;
                self.binary(left_value, *op, right_value)
            }
            Expr::Call { name, args } => self.call(name, args),
        }
    }

    fn binary(&self, left: Value, op: BinOp, right: Value) -> Result<Value, String> {
        match op {
            BinOp::Add => match (left, right) {
                (Value::Number(a), Value::Number(b)) => Ok(Value::Number(a + b)),
                (Value::String(a), Value::String(b)) => Ok(Value::String(a + &b)),
                _ => Err("`+` requires two numbers or two strings".into()),
            },
            BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod => {
                let (a, b) = numbers(left, right)?;
                if matches!(op, BinOp::Div | BinOp::Mod) && b == 0.0 { return Err("runtime error: division by zero".into()); }
                Ok(Value::Number(match op {
                    BinOp::Sub => a - b, BinOp::Mul => a * b, BinOp::Div => a / b, BinOp::Mod => a % b,
                    _ => unreachable!(),
                }))
            }
            BinOp::Gt | BinOp::Lt | BinOp::Eq | BinOp::Neq | BinOp::Gte | BinOp::Lte => {
                let result = match (&left, &right) {
                    (Value::Number(a), Value::Number(b)) => cmp(*a, *b, op),
                    (Value::String(a), Value::String(b)) => cmp_str(a, b, op),
                    _ => match op {
                        BinOp::Eq => left == right,
                        BinOp::Neq => left != right,
                        _ => return Err("ordered comparison requires matching numbers or strings".into()),
                    },
                };
                Ok(Value::Bool(result))
            }
        }
    }

    fn call(&mut self, name: &str, args: &[Expr]) -> Result<Value, String> {
        if name == "push" {
            if args.len() != 2 { return Err("push expects 2 argument(s)".into()); }
            let value = self.eval(&args[1])?;
            let variable = match &args[0] {
                Expr::Ident(name) => name,
                _ => return Err("push expects a list variable as its first argument".into()),
            };
            let list = self.get(variable).ok_or_else(|| format!("undefined variable `{variable}`"))?;
            match list {
                Value::List(mut values) => {
                    values.push(value);
                    self.set(variable, Value::List(values));
                    Ok(Value::Null)
                }
                _ => Err("push expects a list variable as its first argument".into()),
            }
        } else {
            if let Some(value) = self.builtin(name, args)? { return Ok(value); }
            let function = self.functions.get(name).cloned().ok_or_else(|| format!("unknown function `{name}`"))?;
            if args.len() != function.params.len() { return Err(format!("function `{name}` expects {} argument(s), got {}", function.params.len(), args.len())); }
            let values = args.iter().map(|expr| self.eval(expr)).collect::<Result<Vec<_>, _>>()?;
            self.scopes.push(function.params.iter().cloned().zip(values).collect());
            let result = self.exec_block(Some(&function.body));
            self.scopes.pop();
            match result? { Flow::Normal(value) | Flow::Return(value) => Ok(value) }
        }
    }

    fn builtin(&mut self, name: &str, args: &[Expr]) -> Result<Option<Value>, String> {
        let mut values = || args.iter().map(|expr| self.eval(expr)).collect::<Result<Vec<_>, _>>();
        let value = match name {
            "len" | "list_len" => {
                let args = values()?; require_arity(name, &args, 1)?;
                Some(Value::Number(match &args[0] {
                    Value::String(value) => value.chars().count() as f64,
                    Value::List(value) => value.len() as f64,
                    _ => return Err("len expects a string or list".into()),
                }))
            }
            "string_len" => {
                let args = values()?; require_arity(name, &args, 1)?;
                match &args[0] { Value::String(value) => Some(Value::Number(value.chars().count() as f64)), _ => return Err("string_len expects a string".into()) }
            }
            "concat" => {
                let args = values()?; require_arity(name, &args, 2)?;
                let a = match &args[0] { Value::String(v) => v, _ => return Err("concat expects two strings".into()) };
                let b = match &args[1] { Value::String(v) => v, _ => return Err("concat expects two strings".into()) };
                Some(Value::String(format!("{}{}", a, b)))
            }
            "char_at" => {
                let args = values()?; require_arity(name, &args, 2)?;
                let value = match &args[0] { Value::String(v) => v, _ => return Err("char_at expects a string".into()) };
                let index = number_index(&args[1])?;
                Some(Value::String(value.chars().nth(index).map(|c| c.to_string()).ok_or("index out of bounds")?))
            }
            "char_code" => {
                let args = values()?; require_arity(name, &args, 2)?;
                let value = match &args[0] { Value::String(v) => v, _ => return Err("char_code expects a string".into()) };
                let index = number_index(&args[1])?;
                Some(Value::Number(value.chars().nth(index).map(|c| c as u32 as f64).ok_or("index out of bounds")?))
            }
            "contains" | "starts_with" | "ends_with" => {
                let args = values()?; require_arity(name, &args, 2)?;
                let (x, y) = match (&args[0], &args[1]) { (Value::String(x), Value::String(y)) => (x, y), _ => return Err(format!("{name} expects two strings")) };
                Some(Value::Bool(match name { "contains" => x.contains(y), "starts_with" => x.starts_with(y), _ => x.ends_with(y) }))
            }
            "upper" | "lower" | "trim" => {
                let args = values()?; require_arity(name, &args, 1)?;
                let value = match &args[0] { Value::String(value) => value, _ => return Err(format!("{name} expects a string")) };
                Some(Value::String(match name { "upper" => value.to_uppercase(), "lower" => value.to_lowercase(), _ => value.trim().to_string() }))
            }
            "str" => { let args = values()?; require_arity(name, &args, 1)?; Some(Value::String(args[0].display())) }
            "list_get" => {
                let args = values()?; require_arity(name, &args, 2)?; let index = number_index(&args[1])?;
                match &args[0] { Value::List(values) => Some(values.get(index).cloned().ok_or("index out of bounds")?), _ => return Err("list_get expects a list".into()) }
            }
            "read_file" => {
                let args = values()?; require_arity(name, &args, 1)?;
                let path = match &args[0] { Value::String(path) => path, _ => return Err("read_file expects a path string".into()) };
                Some(Value::String(fs::read_to_string(path).map_err(|e| format!("read_file: {e}"))?))
            }
            "write_file" => {
                let args = values()?; require_arity(name, &args, 2)?;
                let path = match &args[0] { Value::String(path) => path, _ => return Err("write_file expects a path string".into()) };
                fs::write(path, args[1].display()).map_err(|e| format!("write_file: {e}"))?;
                Some(Value::Null)
            }
            _ => None,
        };
        Ok(value)
    }
}

fn require_arity(name: &str, args: &[Value], expected: usize) -> Result<(), String> {
    if args.len() == expected { Ok(()) } else { Err(format!("{name} expects {expected} argument(s), got {}", args.len())) }
}

fn numbers(a: Value, b: Value) -> Result<(f64, f64), String> {
    match (a, b) { (Value::Number(x), Value::Number(y)) => Ok((x, y)), _ => Err("arithmetic requires numbers".into()) }
}

fn number_index(value: &Value) -> Result<usize, String> {
    match value { Value::Number(number) if number.is_finite() && number.fract() == 0.0 && *number >= 0.0 => Ok(*number as usize), _ => Err("index must be a non-negative integer".into()) }
}

fn cmp(a: f64, b: f64, op: BinOp) -> bool {
    match op { BinOp::Gt => a > b, BinOp::Lt => a < b, BinOp::Eq => a == b, BinOp::Neq => a != b, BinOp::Gte => a >= b, BinOp::Lte => a <= b, _ => false }
}

fn cmp_str(a: &str, b: &str, op: BinOp) -> bool {
    match op { BinOp::Gt => a > b, BinOp::Lt => a < b, BinOp::Eq => a == b, BinOp::Neq => a != b, BinOp::Gte => a >= b, BinOp::Lte => a <= b, _ => false }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ast::{Expr, Program, Stmt};

    fn program(statements: Vec<Stmt>) -> Program { Program { statements } }
    fn number(value: f64) -> Expr { Expr::Number(value) }

    #[test]
    fn arithmetic() {
        let program = program(vec![Stmt::Expr(Expr::Binary { left: Box::new(number(6.0)), op: BinOp::Mul, right: Box::new(number(7.0)) })]);
        assert_eq!(run(&program).unwrap(), Value::Number(42.0));
    }

    #[test]
    fn div_zero() {
        let program = program(vec![Stmt::Expr(Expr::Binary { left: Box::new(number(1.0)), op: BinOp::Div, right: Box::new(number(0.0)) })]);
        assert!(run(&program).is_err());
    }

    #[test]
    fn char_at_returns_unicode_character() {
        let program = program(vec![Stmt::Expr(Expr::Call { name: "char_at".into(), args: vec![Expr::String("Aβ".into()), Expr::Number(1.0)] })]);
        assert_eq!(run(&program).unwrap(), Value::String("β".into()));
    }

    #[test]
    fn char_code_returns_unicode_scalar() {
        let program = program(vec![Stmt::Expr(Expr::Call { name: "char_code".into(), args: vec![Expr::String("A😀".into()), Expr::Number(1.0)] })]);
        assert_eq!(run(&program).unwrap(), Value::Number('😀' as u32 as f64));
    }

    #[test]
    fn push_mutates_a_list_variable() {
        let program = program(vec![
            Stmt::Hold { name: "items".into(), value: Expr::Array(vec![number(1.0)]), exported: false },
            Stmt::Expr(Expr::Call { name: "push".into(), args: vec![Expr::Ident("items".into()), number(2.0)] }),
            Stmt::Expr(Expr::Call { name: "list_len".into(), args: vec![Expr::Ident("items".into())] }),
        ]);
        assert_eq!(run(&program).unwrap(), Value::Number(2.0));
    }
}
