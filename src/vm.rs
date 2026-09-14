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
            Self::Null => "null".to_string(),
        }
    }
}

#[derive(Clone)]
struct Function { params: Vec<String>, body: Vec<Stmt> }

enum Flow { Normal(Value), Return(Value) }

pub fn run(program: &Program) -> Result<Value, String> {
    let mut vm = Vm { scopes: vec![HashMap::new()], functions: HashMap::new() };
    vm.collect_functions(program);
    let mut last = Value::Null;
    for stmt in &program.statements {
        match vm.exec(stmt)? {
            Flow::Normal(v) => last = v,
            Flow::Return(v) => return Ok(v),
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
        for stmt in &program.statements {
            if let Stmt::Make { name, params, body, .. } = stmt {
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
                scope.insert(name.to_string(), value);
                return;
            }
        }
        self.scopes.last_mut().unwrap().insert(name.to_string(), value);
    }

    fn exec(&mut self, stmt: &Stmt) -> Result<Flow, String> {
        match stmt {
            Stmt::Show(expr) => { println!("{}", self.eval(expr)?.display()); Ok(Flow::Normal(Value::Null)) }
            Stmt::Hold { name, value, .. } | Stmt::Assign { name, value } => {
                let v = self.eval(value)?;
                self.set(name, v.clone());
                Ok(Flow::Normal(v))
            }
            Stmt::Give(expr) => Ok(Flow::Return(self.eval(expr)?)),
            Stmt::Expr(expr) => Ok(Flow::Normal(self.eval(expr)?)),
            Stmt::When { condition, then_body, otherwise_body } => {
                let body = if self.eval(condition)?.truthy() { Some(then_body) } else { otherwise_body.as_ref() };
                self.exec_block(body)
            }
            Stmt::While { condition, body } => {
                let mut last = Value::Null;
                let mut guard = 0usize;
                while self.eval(condition)?.truthy() {
                    match self.exec_block(Some(body))? {
                        Flow::Normal(v) => last = v,
                        Flow::Return(v) => return Ok(Flow::Return(v)),
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
        for stmt in body {
            match self.exec(stmt)? {
                Flow::Normal(v) => last = v,
                Flow::Return(v) => return Ok(Flow::Return(v)),
            }
        }
        Ok(Flow::Normal(last))
    }

    fn eval(&mut self, expr: &Expr) -> Result<Value, String> {
        match expr {
            Expr::Number(v) => Ok(Value::Number(*v)),
            Expr::String(v) => Ok(Value::String(v.clone())),
            Expr::Ident(name) => self.get(name).ok_or_else(|| format!("undefined variable `{name}`")),
            Expr::Array(items) => Ok(Value::List(items.iter().map(|e| self.eval(e)).collect::<Result<Vec<_>, _>>()?)),
            Expr::Index { array, index } => {
                let a = self.eval(array)?;
                let i = self.eval(index)?;
                let idx = number_index(&i)?;
                match a {
                    Value::List(v) => v.get(idx).cloned().ok_or_else(|| "index out of bounds".into()),
                    Value::String(v) => v.chars().nth(idx).map(|c| Value::String(c.to_string())).ok_or_else(|| "index out of bounds".into()),
                    _ => Err("value is not indexable".into()),
                }
            }
            Expr::Field { object, field } => match self.eval(object)? {
                Value::Struct { fields, .. } => fields.get(field).cloned().ok_or_else(|| format!("unknown field `{field}`")),
                _ => Err("field access requires a struct value".into()),
            },
            Expr::StructLit { name, fields } => {
                let mut out = HashMap::new();
                for (k, v) in fields { out.insert(k.clone(), self.eval(v)?); }
                Ok(Value::Struct { name: name.clone(), fields: out })
            }
            Expr::Binary { left, op, right } => {
                let l = self.eval(left)?;
                let r = self.eval(right)?;
                self.binary(l, *op, r)
            }
            Expr::Call { name, args } => self.call(name, args),
        }
    }

    fn binary(&self, l: Value, op: BinOp, r: Value) -> Result<Value, String> {
        match op {
            BinOp::Add => match (l, r) {
                (Value::Number(a), Value::Number(b)) => Ok(Value::Number(a + b)),
                (Value::String(a), Value::String(b)) => Ok(Value::String(a + &b)),
                _ => Err("`+` requires two numbers or two strings".into()),
            },
            BinOp::Sub | BinOp::Mul | BinOp::Div | BinOp::Mod => {
                let (a, b) = numbers(l, r)?;
                if matches!(op, BinOp::Div | BinOp::Mod) && b == 0.0 { return Err("runtime error: division by zero".into()); }
                Ok(Value::Number(match op {
                    BinOp::Sub => a - b,
                    BinOp::Mul => a * b,
                    BinOp::Div => a / b,
                    BinOp::Mod => a % b,
                    _ => unreachable!(),
                }))
            }
            BinOp::Gt | BinOp::Lt | BinOp::Eq | BinOp::Neq | BinOp::Gte | BinOp::Lte => {
                let result = match (&l, &r) {
                    (Value::Number(a), Value::Number(b)) => cmp(*a, *b, op),
                    (Value::String(a), Value::String(b)) => cmp_str(a, b, op),
                    _ => match op { BinOp::Eq => l == r, BinOp::Neq => l != r, _ => return Err("ordered comparison requires matching numbers or strings".into()) },
                };
                Ok(Value::Bool(result))
            }
        }
    }

    fn call(&mut self, name: &str, args: &[Expr]) -> Result<Value, String> {
        if let Some(v) = self.builtin(name, args)? { return Ok(v); }
        let f = self.functions.get(name).cloned().ok_or_else(|| format!("unknown function `{name}`"))?;
        if args.len() != f.params.len() { return Err(format!("function `{name}` expects {} argument(s), got {}", f.params.len(), args.len())); }
        let values = args.iter().map(|e| self.eval(e)).collect::<Result<Vec<_>, _>>()?;
        let scope = f.params.iter().cloned().zip(values).collect::<HashMap<_, _>>();
        self.scopes.push(scope);
        let result = self.exec_block(Some(&f.body));
        self.scopes.pop();
        match result? { Flow::Normal(v) | Flow::Return(v) => Ok(v) }
    }

    fn builtin(&mut self, name: &str, args: &[Expr]) -> Result<Option<Value>, String> {
        let values = args.iter().map(|e| self.eval(e)).collect::<Result<Vec<_>, _>>()?;
        let v = match name {
            "len" | "list_len" => {
                require_arity(name, &values, 1)?;
                Some(Value::Number(match &values[0] { Value::String(s) => s.chars().count() as f64, Value::List(v) => v.len() as f64, _ => return Err("len expects a string or list".into()) }))
            }
            "concat" => { require_arity(name, &values, 2)?; Some(Value::String(format!("{}{}", values[0].display(), values[1].display()))) }
            "contains" | "starts_with" | "ends_with" => {
                require_arity(name, &values, 2)?;
                let (x, y) = match (&values[0], &values[1]) { (Value::String(x), Value::String(y)) => (x, y), _ => return Err(format!("{name} expects two strings")) };
                Some(Value::Bool(match name { "contains" => x.contains(y), "starts_with" => x.starts_with(y), _ => x.ends_with(y) }))
            }
            "upper" | "lower" | "trim" => {
                require_arity(name, &values, 1)?;
                let x = match &values[0] { Value::String(s) => s, _ => return Err(format!("{name} expects a string")) };
                Some(Value::String(match name { "upper" => x.to_uppercase(), "lower" => x.to_lowercase(), _ => x.trim().to_string() }))
            }
            "str" => { require_arity(name, &values, 1)?; Some(Value::String(values[0].display())) }
            "list_get" => {
                require_arity(name, &values, 2)?;
                let i = number_index(&values[1])?;
                match &values[0] { Value::List(v) => Some(v.get(i).cloned().ok_or("index out of bounds")?), _ => return Err("list_get expects a list".into()) }
            }
            "push" => {
                require_arity(name, &values, 2)?;
                match &values[0] { Value::List(v) => { let mut n = v.clone(); n.push(values[1].clone()); Some(Value::List(n)) }, _ => return Err("push expects a list".into()) }
            }
            "read_file" => {
                require_arity(name, &values, 1)?;
                let p = match &values[0] { Value::String(s) => s, _ => return Err("read_file expects a path string".into()) };
                Some(Value::String(fs::read_to_string(p).map_err(|e| format!("read_file: {e}"))?))
            }
            "write_file" => {
                require_arity(name, &values, 2)?;
                let p = match &values[0] { Value::String(s) => s, _ => return Err("write_file expects a path string".into()) };
                fs::write(p, values[1].display()).map_err(|e| format!("write_file: {e}"))?;
                Some(Value::Null)
            }
            _ => None,
        };
        Ok(v)
    }
}

fn require_arity(name: &str, args: &[Value], n: usize) -> Result<(), String> {
    if args.len() == n { Ok(()) } else { Err(format!("{name} expects {n} argument(s), got {}", args.len())) }
}

fn numbers(a: Value, b: Value) -> Result<(f64, f64), String> {
    match (a, b) { (Value::Number(x), Value::Number(y)) => Ok((x, y)), _ => Err("arithmetic requires numbers".into()) }
}

fn number_index(v: &Value) -> Result<usize, String> {
    match v { Value::Number(n) if n.is_finite() && n.fract() == 0.0 && *n >= 0.0 => Ok(*n as usize), _ => Err("index must be a non-negative integer".into()) }
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
    fn num(n: f64) -> Expr { Expr::Number(n) }

    #[test]
    fn evaluates_arithmetic_without_c() {
        let p = program(vec![Stmt::Expr(Expr::Binary { left: Box::new(num(6.0)), op: BinOp::Mul, right: Box::new(num(7.0)) })]);
        assert_eq!(run(&p).unwrap(), Value::Number(42.0));
    }

    #[test]
    fn rejects_division_by_zero() {
        let p = program(vec![Stmt::Expr(Expr::Binary { left: Box::new(num(1.0)), op: BinOp::Div, right: Box::new(num(0.0)) })]);
        assert!(run(&p).is_err());
    }
}
