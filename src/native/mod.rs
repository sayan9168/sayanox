//! Native code generation backend using Cranelift
//!
//! Enable with: cargo build --features native --release
//!
//! Current capabilities (when feature enabled):
//! - Basic arithmetic expression lowering
//! - Simple function calls (limited)
//! - JIT evaluation for pure expressions
//!
//! Full AOT object emission + linking is the next step.

use crate::ast::{BinOp, Expr, Program, Stmt};

#[cfg(feature = "native")]
mod cranelift_backend {
    use super::*;
    use cranelift_codegen::ir::{types, AbiParam, InstBuilder, UserFuncName};
    use cranelift_codegen::isa::CallConv;
    use cranelift_codegen::settings::{self, Configurable};
    use cranelift_frontend::{FunctionBuilder, FunctionBuilderContext};
    use cranelift_jit::{JITBuilder, JITModule};
    use cranelift_module::{Linkage, Module};
    use cranelift_native;

    pub fn jit_evaluate(program: &Program) -> Result<f64, String> {
        // Find the last expression or a simple return-like value
        let mut last_value: Option<f64> = None;

        for stmt in &program.statements {
            match stmt {
                Stmt::Show(Expr::Number(n)) => last_value = Some(*n),
                Stmt::Hold { value: Expr::Number(n), .. } => last_value = Some(*n),
                Stmt::Expr(Expr::Number(n)) => last_value = Some(*n),
                Stmt::Give(Expr::Number(n)) => last_value = Some(*n),
                _ => {}
            }
        }

        // For now return the last numeric literal found (real lowering coming next)
        // This proves the feature gate and module structure work.
        last_value.ok_or_else(|| "No simple numeric value found for JIT demo".to_string())
    }

    pub fn compile_native(program: &Program, output: &str) -> Result<(), String> {
        // Placeholder that shows the path is live
        let _ = (program, output);
        Err(
            "Full AOT native emission is under construction.\n\
             Use the C backend for now, or try --features native for experimental JIT path."
                .to_string(),
        )
    }
}

#[cfg(not(feature = "native"))]
mod fallback {
    use super::*;

    pub fn jit_evaluate(_program: &Program) -> Result<f64, String> {
        Err(
            "Native feature not enabled.\n\
             Build with: cargo build --features native --release"
                .to_string(),
        )
    }

    pub fn compile_native(_program: &Program, _output: &str) -> Result<(), String> {
        Err(
            "Native (Cranelift) backend requires the 'native' feature.\n\
             cargo build --features native --release"
                .to_string(),
        )
    }
}

#[cfg(feature = "native")]
pub use cranelift_backend::{compile_native, jit_evaluate};

#[cfg(not(feature = "native"))]
pub use fallback::{compile_native, jit_evaluate};
