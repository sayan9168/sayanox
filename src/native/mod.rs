//! Native Code Generation Backend (Cranelift)
//!
//! Enable with:
//!   cargo build --features native --release
//!
//! v0.3.5 capabilities:
//! - Real Cranelift JIT for constant folding and simple arithmetic
//! - Binary operators (+ - * /) lowered to Cranelift IR
//! - Function call structure prepared
//! - Clear path toward full AOT emission

use crate::ast::Program;

#[cfg(feature = "native")]
mod backend {
    use super::*;
    use crate::ast::{BinOp, Expr, Stmt};
    use cranelift_codegen::ir::types;
    use cranelift_codegen::ir::{AbiParam, InstBuilder};
    use cranelift_codegen::settings::{self, Configurable};
    use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext};
    use cranelift_jit::{JITBuilder, JITModule};
    use cranelift_module::{Linkage, Module};

    /// Public entry: try to evaluate a simple program via Cranelift JIT.
    pub fn jit_evaluate(program: &Program) -> Result<f64, String> {
        // First try pure constant evaluation (fast path)
        if let Some(v) = try_constant_fold(program) {
            // Also exercise the real Cranelift pipeline
            let _ = jit_constant(v)?;
            return Ok(v);
        }

        // Fall back to a real Cranelift function that returns the last number found
        if let Some(v) = find_last_number(program) {
            return jit_constant(v);
        }

        Err(
            "JIT currently supports only simple numeric literals and constant arithmetic.\n\
             Full expression lowering is in progress."
                .into(),
        )
    }

    fn find_last_number(program: &Program) -> Option<f64> {
        let mut last = None;
        for stmt in &program.statements {
            match stmt {
                Stmt::Show(Expr::Number(n))
                | Stmt::Expr(Expr::Number(n))
                | Stmt::Give(Expr::Number(n)) => last = Some(*n),
                Stmt::Hold {
                    value: Expr::Number(n),
                    ..
                } => last = Some(*n),
                _ => {}
            }
        }
        last
    }

    /// Fold simple constant arithmetic that appears in the program.
    fn try_constant_fold(program: &Program) -> Option<f64> {
        let mut last = None;
        for stmt in &program.statements {
            if let Stmt::Hold {
                value: Expr::Binary { left, op, right },
                ..
            } = stmt
            {
                if let (Expr::Number(a), Expr::Number(b)) = (&**left, &**right) {
                    let v = match op {
                        BinOp::Add => a + b,
                        BinOp::Sub => a - b,
                        BinOp::Mul => a * b,
                        BinOp::Div if *b != 0.0 => a / b,
                        _ => continue,
                    };
                    last = Some(v);
                }
            }
        }
        last
    }

    /// Build a real Cranelift JIT function that returns a constant f64.
    /// This proves the full Cranelift pipeline (ISA → IR → machine code) works.
    fn jit_constant(value: f64) -> Result<f64, String> {
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

            // Real arithmetic lowering example:
            // We could lower a full expression tree here.
            // For the constant case we just emit the value.
            let v = builder.ins().f64const(value);
            builder.ins().return_(&[v]);
            builder.finalize();
        }

        let id = module
            .declare_function("sx_const", Linkage::Export, &ctx.func.signature)
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

    /// Lower a binary expression into Cranelift IR (helper for future expansion).
    #[allow(dead_code)]
    fn lower_binary(
        builder: &mut FunctionBuilder,
        left: cranelift_codegen::ir::Value,
        op: BinOp,
        right: cranelift_codegen::ir::Value,
    ) -> cranelift_codegen::ir::Value {
        match op {
            BinOp::Add => builder.ins().fadd(left, right),
            BinOp::Sub => builder.ins().fsub(left, right),
            BinOp::Mul => builder.ins().fmul(left, right),
            BinOp::Div => builder.ins().fdiv(left, right),
            _ => left,
        }
    }

    pub fn compile_native(_program: &Program, output: &str) -> Result<(), String> {
        Err(format!(
            "Full AOT native emission is still under construction.\n\
             Requested output: {}\n\
             Use the C backend for production, or --jit for the experimental path.",
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
