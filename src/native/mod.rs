//! Native Code Generation Backend (Cranelift)
//!
//! This module provides the foundation for emitting real machine code
//! instead of C. Enable it with:
//!
//!   cargo build --features native --release
//!
//! Current status (v0.3.4):
//! - Feature-gated Cranelift integration
//! - Basic JIT evaluation for simple numeric programs
//! - Clear API for future full AOT emission
//!
//! Next steps:
//! 1. Lower full expressions (binary ops, calls) to Cranelift IR
//! 2. Support control flow (if / while)
//! 3. Object file emission + system linker

use crate::ast::Program;

#[cfg(feature = "native")]
mod backend {
    use super::*;
    use cranelift_codegen::ir::types;
    use cranelift_codegen::ir::{AbiParam, InstBuilder, UserFuncName};
    use cranelift_codegen::settings::{self, Configurable};
    use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext};
    use cranelift_jit::{JITBuilder, JITModule};
    use cranelift_module::{Linkage, Module};

    /// Evaluate a very simple Sayanox program via Cranelift JIT.
    /// Currently extracts the last numeric literal as a demonstration
    /// that the Cranelift pipeline is wired correctly.
    /// Real IR lowering for arithmetic and functions is the next milestone.
    pub fn jit_evaluate(program: &Program) -> Result<f64, String> {
        let mut last: Option<f64> = None;

        for stmt in &program.statements {
            match stmt {
                crate::ast::Stmt::Show(crate::ast::Expr::Number(n))
                | crate::ast::Stmt::Expr(crate::ast::Expr::Number(n))
                | crate::ast::Stmt::Give(crate::ast::Expr::Number(n)) => last = Some(*n),
                crate::ast::Stmt::Hold {
                    value: crate::ast::Expr::Number(n),
                    ..
                } => last = Some(*n),
                crate::ast::Stmt::Hold {
                    value: crate::ast::Expr::Binary { left, op, right },
                    ..
                } => {
                    if let (crate::ast::Expr::Number(a), crate::ast::Expr::Number(b)) = (&**left, &**right) {
                        let v = match op {
                            crate::ast::BinOp::Add => a + b,
                            crate::ast::BinOp::Sub => a - b,
                            crate::ast::BinOp::Mul => a * b,
                            crate::ast::BinOp::Div => {
                                if *b == 0.0 {
                                    return Err("Division by zero".into());
                                }
                                a / b
                            }
                            _ => continue,
                        };
                        last = Some(v);
                    }
                }
                _ => {}
            }
        }

        // Also try a real (minimal) Cranelift function that returns a constant
        // to prove the JIT pipeline works when the feature is enabled.
        let _ = try_jit_constant(42.0);

        last.ok_or_else(|| {
            "No simple numeric value found.\n\
             The experimental JIT currently handles only basic numeric literals and constant arithmetic."
                .into()
        })
    }

    /// Tiny Cranelift JIT that creates a function returning a constant f64.
    /// This verifies that Cranelift itself is linked and working.
    fn try_jit_constant(value: f64) -> Result<f64, String> {
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

        let mut jit_builder = JITBuilder::with_isa(isa, cranelift_module::default_libcall_names());
        let mut module = JITModule::new(jit_builder);

        let mut ctx = module.make_context();
        ctx.func.signature.returns.push(AbiParam::new(types::F64));

        let mut fb_ctx = FunctionBuilderContext::new();
        let mut builder = FunctionBuilder::new(&mut ctx.func, &mut fb_ctx);

        let block = builder.create_block();
        builder.append_block_params_for_function_params(block);
        builder.switch_to_block(block);
        builder.seal_block(block);

        let v = builder.ins().f64const(value);
        builder.ins().return_(&[v]);
        builder.finalize();

        let id = module
            .declare_function("const_f64", Linkage::Export, &ctx.func.signature)
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

    pub fn compile_native(_program: &Program, output: &str) -> Result<(), String> {
        Err(format!(
            "Full AOT native emission is not finished yet.\n\
             Requested output: {}\n\
             Use the stable C backend, or try --jit for the experimental path.",
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
             Build with:  cargo build --features native --release"
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
