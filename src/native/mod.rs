//! Native Code Generation Backend (Cranelift)
//!
//! Enable with:
//!   cargo build --features native --release
//!
//! v0.3.6:
//! - Full expression tree lowering for arithmetic (+ - * /)
//! - Real Cranelift IR generation for binary expressions
//! - Constant folding + JIT execution path
//! - Prepared for function calls and control flow

use crate::ast::Program;

#[cfg(feature = "native")]
mod backend {
    use super::*;
    use crate::ast::{BinOp, Expr, Stmt};
    use cranelift_codegen::ir::types;
    use cranelift_codegen::ir::{AbiParam, InstBuilder, Value};
    use cranelift_codegen::settings::{self, Configurable};
    use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext};
    use cranelift_jit::{JITBuilder, JITModule};
    use cranelift_module::{Linkage, Module};

    pub fn jit_evaluate(program: &Program) -> Result<f64, String> {
        if let Some(expr) = find_evaluable_expr(program) {
            return jit_expression(&expr);
        }
        Err(
            "No evaluable numeric expression found for JIT.\n\
             Currently supports numeric literals and constant arithmetic expressions."
                .into(),
        )
    }

    fn find_evaluable_expr(program: &Program) -> Option<Expr> {
        let mut last = None;
        for stmt in &program.statements {
            match stmt {
                Stmt::Show(e) | Stmt::Expr(e) | Stmt::Give(e) => {
                    if is_numeric_expr(e) {
                        last = Some(e.clone());
                    }
                }
                Stmt::Hold { value, .. } => {
                    if is_numeric_expr(value) {
                        last = Some(value.clone());
                    }
                }
                _ => {}
            }
        }
        last
    }

    fn is_numeric_expr(expr: &Expr) -> bool {
        match expr {
            Expr::Number(_) => true,
            Expr::Binary { left, right, .. } => {
                is_numeric_expr(left) && is_numeric_expr(right)
            }
            _ => false,
        }
    }

    fn jit_expression(expr: &Expr) -> Result<f64, String> {
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

        let mut module = JITModule::new(JITBuilder::with_isa(
            isa,
            cranelift_module::default_libcall_names(),
        ));

        let mut ctx = module.make_context();
        ctx.func.signature.returns.push(AbiParam::new(types::F64));

        let mut fb_ctx = FunctionBuilderContext::new();
        {
            let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fb_ctx);
            let block = builder.create_block();
            builder.append_block_params_for_function_params(block);
            builder.switch_to_block(block);
            builder.seal_block(block);

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

    /// Recursively lower an expression tree into Cranelift IR values.
    fn lower_expr(builder: &mut FunctionBuilder, expr: &Expr) -> Result<Value, String> {
        match expr {
            Expr::Number(n) => Ok(builder.ins().f64const(*n)),
            Expr::Binary { left, op, right } => {
                let l = lower_expr(builder, left)?;
                let r = lower_expr(builder, right)?;
                let v = match op {
                    BinOp::Add => builder.ins().fadd(l, r),
                    BinOp::Sub => builder.ins().fsub(l, r),
                    BinOp::Mul => builder.ins().fmul(l, r),
                    BinOp::Div => builder.ins().fdiv(l, r),
                    BinOp::Gt => {
                        let c = builder.ins().fcmp(
                            cranelift_codegen::ir::condcodes::FloatCC::GreaterThan,
                            l,
                            r,
                        );
                        builder.ins().fcvt_from_uint(types::F64, c)
                    }
                    BinOp::Lt => {
                        let c = builder.ins().fcmp(
                            cranelift_codegen::ir::condcodes::FloatCC::LessThan,
                            l,
                            r,
                        );
                        builder.ins().fcvt_from_uint(types::F64, c)
                    }
                    BinOp::Eq => {
                        let c = builder.ins().fcmp(
                            cranelift_codegen::ir::condcodes::FloatCC::Equal,
                            l,
                            r,
                        );
                        builder.ins().fcvt_from_uint(types::F64, c)
                    }
                    _ => {
                        return Err(format!("Operator {:?} not yet lowered in Cranelift", op));
                    }
                };
                Ok(v)
            }
            _ => Err(
                "Only numeric literals and binary arithmetic expressions are supported in JIT for now"
                    .into(),
            ),
        }
    }

    pub fn compile_native(_program: &Program, output: &str) -> Result<(), String> {
        Err(format!(
            "Full AOT native emission is still under construction.\n\
             Requested output: {}\n\
             Use the C backend for production builds, or --jit for experimental expression evaluation.",
            output
        ))
    }
}

#[cfg(not(feature = "native"))]
mod backend {
    use super::*;

    pub fn jit_evaluate(_program: &Program) -> Result<f64, String> {
        Err(
            "Native feature is not enabled.\n\
             Build with: cargo build --features native --release"
                .into(),
        )
    }

    pub fn compile_native(_program: &Program, _output: &str) -> Result<(), String> {
        Err(
            "Native (Cranelift) backend requires the 'native' feature.\n\
             cargo build --features native --release"
                .into(),
        )
    }
}

pub use backend::{compile_native, jit_evaluate};
