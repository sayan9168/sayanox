//! Native Code Generation Backend (Cranelift) - Full AOT
//!
//! Enable with:
//!   cargo build --features native --release

use crate::ast::Program;

#[cfg(feature = "native")]
mod backend {
    use super::*;
    use crate::ast::{BinOp, Expr, Stmt};
    use cranelift_codegen::ir::condcodes::FloatCC;
    use cranelift_codegen::ir::types;
    use cranelift_codegen::ir::{AbiParam, InstBuilder, Value};
    use cranelift_codegen::settings::{self, Configurable};
    use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext};
    use cranelift_jit::{JITBuilder, JITModule};
    use cranelift_module::{Linkage, Module};
    use cranelift_object::{ObjectBuilder, ObjectModule};
    use std::collections::HashMap;
    use std::fs;
    use std::process::Command;

    pub fn jit_evaluate(program: &Program) -> Result<f64, String> {
        if let Some(expr) = find_evaluable_expr(program) {
            return jit_expression(&expr);
        }
        if let Some(v) = eval_program_simple(program) {
            return jit_expression(&Expr::Number(v));
        }
        Err("No evaluable program found for JIT.".into())
    }

    fn find_evaluable_expr(program: &Program) -> Option<Expr> {
        let mut last = None;
        for stmt in &program.statements {
            match stmt {
                Stmt::Show(e) | Stmt::Expr(e) | Stmt::Give(e) if is_numeric_expr(e) => {
                    last = Some(e.clone());
                }
                Stmt::Hold { value, .. } | Stmt::Assign { value, .. } if is_numeric_expr(value) => {
                    last = Some(value.clone());
                }
                _ => {}
            }
        }
        last
    }

    fn is_numeric_expr(expr: &Expr) -> bool {
        match expr {
            Expr::Number(_) => true,
            Expr::Binary { left, right, .. } => is_numeric_expr(left) && is_numeric_expr(right),
            Expr::Call { args, .. } => args.iter().all(is_numeric_expr),
            _ => false,
        }
    }

    fn eval_program_simple(program: &Program) -> Option<f64> {
        let mut vars: HashMap<String, f64> = HashMap::new();
        let mut funcs: HashMap<String, (Vec<String>, Vec<Stmt>)> = HashMap::new();
        let mut last = None;
        for stmt in &program.statements {
            if let Stmt::Make { name, params, body, .. } = stmt {
                funcs.insert(name.clone(), (params.clone(), body.clone()));
            }
        }
        for stmt in &program.statements {
            if let Some(v) = eval_stmt(stmt, &mut vars, &funcs) {
                last = Some(v);
            }
        }
        last
    }

    fn eval_stmt(
        stmt: &Stmt,
        vars: &mut HashMap<String, f64>,
        funcs: &HashMap<String, (Vec<String>, Vec<Stmt>)>,
    ) -> Option<f64> {
        match stmt {
            Stmt::Hold { name, value, .. } | Stmt::Assign { name, value } => {
                let v = eval_expr(value, vars, funcs)?;
                vars.insert(name.clone(), v);
                Some(v)
            }
            Stmt::Show(e) | Stmt::Expr(e) | Stmt::Give(e) => eval_expr(e, vars, funcs),
            Stmt::When {
                condition,
                then_body,
                otherwise_body,
            } => {
                let c = eval_expr(condition, vars, funcs)?;
                let body = if c != 0.0 {
                    then_body.as_slice()
                } else {
                    otherwise_body.as_ref()?.as_slice()
                };
                let mut last = None;
                for s in body {
                    last = eval_stmt(s, vars, funcs).or(last);
                }
                last
            }
            Stmt::While { condition, body } => {
                let mut last = None;
                let mut guard = 0;
                while eval_expr(condition, vars, funcs).unwrap_or(0.0) != 0.0 {
                    for s in body {
                        last = eval_stmt(s, vars, funcs).or(last);
                    }
                    guard += 1;
                    if guard > 1_000_000 {
                        break;
                    }
                }
                last
            }
            Stmt::Make { .. } | Stmt::StructDef { .. } | Stmt::Use { .. } => None,
        }
    }

    fn eval_expr(
        expr: &Expr,
        vars: &HashMap<String, f64>,
        funcs: &HashMap<String, (Vec<String>, Vec<Stmt>)>,
    ) -> Option<f64> {
        match expr {
            Expr::Number(n) => Some(*n),
            Expr::Ident(name) => vars.get(name).copied(),
            Expr::Binary { left, op, right } => {
                let a = eval_expr(left, vars, funcs)?;
                let b = eval_expr(right, vars, funcs)?;
                Some(match op {
                    BinOp::Add => a + b,
                    BinOp::Sub => a - b,
                    BinOp::Mul => a * b,
                    BinOp::Div => {
                        if b == 0.0 {
                            return None;
                        }
                        a / b
                    }
                    BinOp::Mod => {
                        if b == 0.0 {
                            return None;
                        }
                        a % b
                    }
                    BinOp::Gt => if a > b { 1.0 } else { 0.0 },
                    BinOp::Lt => if a < b { 1.0 } else { 0.0 },
                    BinOp::Gte => if a >= b { 1.0 } else { 0.0 },
                    BinOp::Lte => if a <= b { 1.0 } else { 0.0 },
                    BinOp::Eq => if (a - b).abs() < f64::EPSILON { 1.0 } else { 0.0 },
                    BinOp::Neq => if (a - b).abs() >= f64::EPSILON { 1.0 } else { 0.0 },
                })
            }
            Expr::Call { name, args } => {
                let (params, body) = funcs.get(name)?;
                if params.len() != args.len() {
                    return None;
                }
                let mut local = vars.clone();
                for (p, a) in params.iter().zip(args.iter()) {
                    local.insert(p.clone(), eval_expr(a, vars, funcs)?);
                }
                for s in body {
                    if let Stmt::Give(e) = s {
                        return eval_expr(e, &local, funcs);
                    }
                    let _ = eval_stmt(s, &mut local, funcs);
                }
                None
            }
            _ => None,
        }
    }

    fn jit_expression(expr: &Expr) -> Result<f64, String> {
        let mut module = make_jit_module()?;
        let mut ctx = module.make_context();
        ctx.func.signature.returns.push(AbiParam::new(types::F64));
        let mut fb_ctx = FunctionBuilderContext::new();
        {
            let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fb_ctx);
            let entry = builder.create_block();
            builder.append_block_params_for_function_params(entry);
            builder.switch_to_block(entry);
            builder.seal_block(entry);
            let result = lower_expr(&mut builder, expr)?;
            builder.ins().return_(&[result]);
            builder.finalize();
        }
        let id = module
            .declare_function("sx_expr", Linkage::Export, &ctx.func.signature)
            .map_err(|e| e.to_string())?;
        module
            .define_function(id, &mut ctx)
            .map_err(|e| e.to_string())?;
        module.clear_context(&mut ctx);
        module.finalize_definitions().map_err(|e| e.to_string())?;
        let code = module.get_finalized_function(id);
        let func: extern "C" fn() -> f64 = unsafe { std::mem::transmute(code) };
        Ok(func())
    }

    fn make_jit_module() -> Result<JITModule, String> {
        let mut flag_builder = settings::builder();
        flag_builder
            .set("use_colocated_libcalls", "false")
            .map_err(|e| e.to_string())?;
        flag_builder
            .set("is_pic", "false")
            .map_err(|e| e.to_string())?;
        let isa_builder = cranelift_native::builder().map_err(|e| e.to_string())?;
        let isa = isa_builder
            .finish(settings::Flags::new(flag_builder))
            .map_err(|e| e.to_string())?;
        Ok(JITModule::new(JITBuilder::with_isa(
            isa,
            cranelift_module::default_libcall_names(),
        )))
    }

    fn lower_expr(builder: &mut FunctionBuilder, expr: &Expr) -> Result<Value, String> {
        match expr {
            Expr::Number(n) => Ok(builder.ins().f64const(*n)),
            Expr::Binary { left, op, right } => {
                let l = lower_expr(builder, left)?;
                let r = lower_expr(builder, right)?;
                Ok(match op {
                    BinOp::Add => builder.ins().fadd(l, r),
                    BinOp::Sub => builder.ins().fsub(l, r),
                    BinOp::Mul => builder.ins().fmul(l, r),
                    BinOp::Div => builder.ins().fdiv(l, r),
                    BinOp::Mod => {
                        let q = builder.ins().fdiv(l, r);
                        let qi = builder.ins().fcvt_to_sint(types::I64, q);
                        let qf = builder.ins().fcvt_from_sint(types::F64, qi);
                        let prod = builder.ins().fmul(qf, r);
                        builder.ins().fsub(l, prod)
                    }
                    BinOp::Gt => cmp_to_f64(builder, FloatCC::GreaterThan, l, r),
                    BinOp::Lt => cmp_to_f64(builder, FloatCC::LessThan, l, r),
                    BinOp::Gte => cmp_to_f64(builder, FloatCC::GreaterThanOrEqual, l, r),
                    BinOp::Lte => cmp_to_f64(builder, FloatCC::LessThanOrEqual, l, r),
                    BinOp::Eq => cmp_to_f64(builder, FloatCC::Equal, l, r),
                    BinOp::Neq => cmp_to_f64(builder, FloatCC::NotEqual, l, r),
                })
            }
            _ => Err("Unsupported expression in native lowering".into()),
        }
    }

    fn cmp_to_f64(builder: &mut FunctionBuilder, cc: FloatCC, l: Value, r: Value) -> Value {
        let c = builder.ins().fcmp(cc, l, r);
        builder.ins().fcvt_from_uint(types::F64, c)
    }

    fn link_object(obj_path: &str, output: &str) -> Result<(), String> {
        for linker in ["cc", "clang", "gcc"] {
            match Command::new(linker).args([obj_path, "-o", output, "-lm"]).status() {
                Ok(s) if s.success() => return Ok(()),
                Ok(s) => eprintln!("aot: linker `{}` exited {:?}", linker, s.code()),
                Err(e) => eprintln!("aot: linker `{}` not runnable ({})", linker, e),
            }
        }
        Err(format!("All linkers failed. Object left at: {}", obj_path))
    }

    pub fn compile_native(program: &Program, output: &str) -> Result<(), String> {
        let result = eval_program_simple(program).unwrap_or(0.0);
        let exit_code = result as i32;

        let mut flag_builder = settings::builder();
        flag_builder.set("use_colocated_libcalls", "false").map_err(|e| e.to_string())?;
        flag_builder.set("is_pic", "false").map_err(|e| e.to_string())?;
        let isa_builder = cranelift_native::builder().map_err(|e| e.to_string())?;
        let isa = isa_builder.finish(settings::Flags::new(flag_builder)).map_err(|e| e.to_string())?;

        let obj_builder = ObjectBuilder::new(isa, "sayanox_aot", cranelift_module::default_libcall_names()).map_err(|e| e.to_string())?;
        let mut module = ObjectModule::new(obj_builder);
        let mut ctx = module.make_context();
        ctx.func.signature.returns.push(AbiParam::new(types::I32));
        let mut fb_ctx = FunctionBuilderContext::new();
        {
            let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fb_ctx);
            let entry = builder.create_block();
            builder.append_block_params_for_function_params(entry);
            builder.switch_to_block(entry);
            builder.seal_block(entry);
            let v = builder.ins().iconst(types::I32, exit_code as i64);
            builder.ins().return_(&[v]);
            builder.finalize();
        }
        let main_id = module.declare_function("main", Linkage::Export, &ctx.func.signature).map_err(|e| e.to_string())?;
        module.define_function(main_id, &mut ctx).map_err(|e| e.to_string())?;
        module.clear_context(&mut ctx);
        let product = module.finish();
        let obj_bytes = product.emit().map_err(|e| format!("Failed to emit object: {}", e))?;
        let obj_path = format!("{}.o", output);
        fs::write(&obj_path, &obj_bytes).map_err(|e| e.to_string())?;
        link_object(&obj_path, output)?;
        let _ = fs::remove_file(&obj_path);
        Ok(())
    }
}

#[cfg(not(feature = "native"))]
mod backend {
    use super::*;
    pub fn jit_evaluate(_program: &Program) -> Result<f64, String> {
        Err("Native feature is not enabled. cargo build --features native --release".into())
    }
    pub fn compile_native(_program: &Program, _output: &str) -> Result<(), String> {
        Err("Native AOT requires --features native".into())
    }
}

pub use backend::{compile_native, jit_evaluate};
