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
    Number(f64), String(String), Bool(bool), List(Vec<Value>),
    Struct { name: String, fields: HashMap<String, Value> }, Null,
}
impl Value {
    fn truthy(&self) -> bool { match self { Self::Bool(v)=>*v, Self::Number(v)=>*v!=0.0, Self::String(v)=>!v.is_empty(), Self::List(v)=>!v.is_empty(), Self::Null=>false, Self::Struct{..}=>true } }
    pub fn display(&self) -> String { match self { Self::Number(v) if v.fract()==0.0=>format!("{v:.0}"), Self::Number(v)=>v.to_string(), Self::String(v)=>v.clone(), Self::Bool(v)=>v.to_string(), Self::List(v)=>format!("[{}]",v.iter().map(Self::display).collect::<Vec<_>>().join(", ")), Self::Struct{name,fields}=>{let mut p=fields.iter().map(|(k,v)|format!("{k}: {}",v.display())).collect::<Vec<_>>();p.sort();format!("{name} {{ {} }}",p.join(", "))}, Self::Null=>"null".into() } }
}
#[derive(Clone)] struct Function { params: Vec<String>, body: Vec<Stmt> }
enum Flow { Normal(Value), Return(Value) }
pub fn run(program:&Program)->Result<Value,String>{let mut vm=Vm{scopes:vec![HashMap::new()],functions:HashMap::new()};vm.collect_functions(program);let mut last=Value::Null;for s in &program.statements{match vm.exec(s)?{Flow::Normal(v)=>last=v,Flow::Return(v)=>return Ok(v)}}Ok(last)}
struct Vm { scopes:Vec<HashMap<String,Value>>, functions:HashMap<String,Function> }
impl Vm {
 fn collect_functions(&mut self,p:&Program){for s in &p.statements{if let Stmt::Make{name,params,body,..}=s{self.functions.insert(name.clone(),Function{params:params.clone(),body:body.clone()});}}}
 fn get(&self,n:&str)->Option<Value>{self.scopes.iter().rev().find_map(|s|s.get(n).cloned())}
 fn set(&mut self,n:&str,v:Value){for s in self.scopes.iter_mut().rev(){if s.contains_key(n){s.insert(n.into(),v);return}}self.scopes.last_mut().unwrap().insert(n.into(),v);}
 fn exec(&mut self,s:&Stmt)->Result<Flow,String>{match s{
  Stmt::Show(e)=>{println!("{}",self.eval(e)?.display());Ok(Flow::Normal(Value::Null))}
  Stmt::Hold{name,value,..}|Stmt::Assign{name,value}=>{let v=self.eval(value)?;self.set(name,v.clone());Ok(Flow::Normal(v))}
  Stmt::Give(e)=>Ok(Flow::Return(self.eval(e)?)),Stmt::Expr(e)=>Ok(Flow::Normal(self.eval(e)?)),
  Stmt::When{condition,then_body,otherwise_body}=>{let b=if self.eval(condition)?.truthy(){Some(then_body)}else{otherwise_body.as_ref()};self.exec_block(b)}
  Stmt::While{condition,body}=>{let mut last=Value::Null;let mut guard=0usize;while self.eval(condition)?.truthy(){match self.exec_block(Some(body))?{Flow::Normal(v)=>last=v,Flow::Return(v)=>return Ok(Flow::Return(v))}guard+=1;if guard>10_000_000{return Err("runtime error: loop iteration limit exceeded".into())}}Ok(Flow::Normal(last))}
  Stmt::Make{..}|Stmt::StructDef{..}|Stmt::Use{..}=>Ok(Flow::Normal(Value::Null)),
 }}
 fn exec_block(&mut self,b:Option<&Vec<Stmt>>)->Result<Flow,String>{let Some(b)=b else{return Ok(Flow::Normal(Value::Null))};let mut last=Value::Null;for s in b{match self.exec(s)?{Flow::Normal(v)=>last=v,Flow::Return(v)=>return Ok(Flow::Return(v))}}Ok(Flow::Normal(last))}
 fn eval(&mut self,e:&Expr)->Result<Value,String>{match e{
  Expr::Number(v)=>Ok(Value::Number(*v)),Expr::String(v)=>Ok(Value::String(v.clone())),Expr::Ident(n)=>self.get(n).ok_or_else(||format!("undefined variable `{n}`")),
  Expr::Array(xs)=>Ok(Value::List(xs.iter().map(|x|self.eval(x)).collect::<Result<Vec<_>,_>>()?)),
  Expr::Index{array,index}=>{let a=self.eval(array)?;let i=self.eval(index)?;let n=number_index(&i)?;match a{Value::List(v)=>v.get(n).cloned().ok_or_else(||"index out of bounds".into()),Value::String(v)=>v.chars().nth(n).map(|c|Value::String(c.to_string())).ok_or_else(||"index out of bounds".into()),_=>Err("value is not indexable".into())}},
  Expr::Field{object,field}=>match self.eval(object)?{Value::Struct{fields,..}=>fields.get(field).cloned().ok_or_else(||format!("unknown field `{field}`")),_=>Err("field access requires a struct value".into())},
  Expr::StructLit{name,fields}=>{let mut o=HashMap::new();for(k,v)in fields{o.insert(k.clone(),self.eval(v)?);}Ok(Value::Struct{name:name.clone(),fields:o})},
  Expr::Binary{left,op,right}=>{let l=self.eval(left)?;let r=self.eval(right)?;self.binary(l,*op,r)},Expr::Call{name,args}=>self.call(name,args),
 }}
 fn binary(&self,l:Value,op:BinOp,r:Value)->Result<Value,String>{match op{
  BinOp::Add=>match(l,r){(Value::Number(a),Value::Number(b))=>Ok(Value::Number(a+b)),(Value::String(a),Value::String(b))=>Ok(Value::String(a+&b)),_=>Err("`+` requires two numbers or two strings".into())},
  BinOp::Sub|BinOp::Mul|BinOp::Div|BinOp::Mod=>{let(a,b)=numbers(l,r)?;if matches!(op,BinOp::Div|BinOp::Mod)&&b==0.0{return Err("runtime error: division by zero".into())}Ok(Value::Number(match op{BinOp::Sub=>a-b,BinOp::Mul=>a*b,BinOp::Div=>a/b,BinOp::Mod=>a%b,_=>unreachable!()}))},
  BinOp::Gt|BinOp::Lt|BinOp::Eq|BinOp::Neq|BinOp::Gte|BinOp::Lte=>{let x=match(&l,&r){(Value::Number(a),Value::Number(b))=>cmp(*a,*b,op),(Value::String(a),Value::String(b))=>cmp_str(a,b,op),_=>match op{BinOp::Eq=>l==r,BinOp::Neq=>l!=r,_=>return Err("ordered comparison requires matching numbers or strings".into())}};Ok(Value::Bool(x))}
 }}
 fn call(&mut self,n:&str,args:&[Expr])->Result<Value,String>{if let Some(v)=self.builtin(n,args)?{return Ok(v)}let f=self.functions.get(n).cloned().ok_or_else(||format!("unknown function `{n}`"))?;if args.len()!=f.params.len(){return Err(format!("function `{n}` expects {} argument(s), got {}",f.params.len(),args.len()))}let vals=args.iter().map(|e|self.eval(e)).collect::<Result<Vec<_>,_>>()?;self.scopes.push(f.params.iter().cloned().zip(vals).collect());let r=self.exec_block(Some(&f.body));self.scopes.pop();match r?{Flow::Normal(v)|Flow::Return(v)=>Ok(v)}}
 fn builtin(&mut self,n:&str,args:&[Expr])->Result<Option<Value>,String>{let mut values=||args.iter().map(|e|self.eval(e)).collect::<Result<Vec<_>,_>>();let v=match n{
  "len"|"list_len"=>{let a=values()?;require_arity(n,&a,1)?;Some(Value::Number(match &a[0]{Value::String(s)=>s.chars().count()as f64,Value::List(v)=>v.len()as f64,_=>return Err("len expects a string or list".into())}))},
  "concat"=>{let a=values()?;require_arity(n,&a,2)?;Some(Value::String(format!("{}{}",a[0].display(),a[1].display())))},
  "contains"|"starts_with"|"ends_with"=>{let a=values()?;require_arity(n,&a,2)?;let(x,y)=match(&a[0],&a[1]){(Value::String(x),Value::String(y))=>(x,y),_=>return Err(format!("{n} expects two strings"))};Some(Value::Bool(match n{"contains"=>x.contains(y),"starts_with"=>x.starts_with(y),_=>x.ends_with(y)}))},
  "upper"|"lower"|"trim"=>{let a=values()?;require_arity(n,&a,1)?;let x=match&a[0]{Value::String(s)=>s,_=>return Err(format!("{n} expects a string"))};Some(Value::String(match n{"upper"=>x.to_uppercase(),"lower"=>x.to_lowercase(),_=>x.trim().to_string()}))},
  "str"=>{let a=values()?;require_arity(n,&a,1)?;Some(Value::String(a[0].display()))},
  "list_get"=>{let a=values()?;require_arity(n,&a,2)?;let i=number_index(&a[1])?;match&a[0]{Value::List(v)=>Some(v.get(i).cloned().ok_or("index out of bounds")?),_=>return Err("list_get expects a list".into())}},
  "push"=>{let a=values()?;require_arity(n,&a,2)?;match&a[0]{Value::List(v)=>{let mut x=v.clone();x.push(a[1].clone());Some(Value::List(x))},_=>return Err("push expects a list".into())}},
  "read_file"=>{let a=values()?;require_arity(n,&a,1)?;let p=match&a[0]{Value::String(s)=>s,_=>return Err("read_file expects a path string".into())};Some(Value::String(fs::read_to_string(p).map_err(|e|format!("read_file: {e}"))?))},
  "write_file"=>{let a=values()?;require_arity(n,&a,2)?;let p=match&a[0]{Value::String(s)=>s,_=>return Err("write_file expects a path string".into())};fs::write(p,a[1].display()).map_err(|e|format!("write_file: {e}"))?;Some(Value::Null)},_=>None};Ok(v)}
}
fn require_arity(n:&str,a:&[Value],x:usize)->Result<(),String>{if a.len()==x{Ok(())}else{Err(format!("{n} expects {x} argument(s), got {}",a.len()))}}
fn numbers(a:Value,b:Value)->Result<(f64,f64),String>{match(a,b){(Value::Number(x),Value::Number(y))=>Ok((x,y)),_=>Err("arithmetic requires numbers".into())}}
fn number_index(v:&Value)->Result<usize,String>{match v{Value::Number(n)if n.is_finite()&&n.fract()==0.0&&*n>=0.0=>Ok(*n as usize),_=>Err("index must be a non-negative integer".into())}}
fn cmp(a:f64,b:f64,o:BinOp)->bool{match o{BinOp::Gt=>a>b,BinOp::Lt=>a<b,BinOp::Eq=>a==b,BinOp::Neq=>a!=b,BinOp::Gte=>a>=b,BinOp::Lte=>a<=b,_=>false}}
fn cmp_str(a:&str,b:&str,o:BinOp)->bool{match o{BinOp::Gt=>a>b,BinOp::Lt=>a<b,BinOp::Eq=>a==b,BinOp::Neq=>a!=b,BinOp::Gte=>a>=b,BinOp::Lte=>a<=b,_=>false}}
#[cfg(test)]mod tests{use super::*;use crate::ast::{Expr,Program,Stmt};fn p(s:Vec<Stmt>)->Program{Program{statements:s}}fn n(x:f64)->Expr{Expr::Number(x)}#[test]fn arithmetic(){let p=p(vec![Stmt::Expr(Expr::Binary{left:Box::new(n(6.0)),op:BinOp::Mul,right:Box::new(n(7.0))})]);assert_eq!(run(&p).unwrap(),Value::Number(42.0))}#[test]fn div_zero(){let p=p(vec![Stmt::Expr(Expr::Binary{left:Box::new(n(1.0)),op:BinOp::Div,right:Box::new(n(0.0))})]);assert!(run(&p).is_err())}}
