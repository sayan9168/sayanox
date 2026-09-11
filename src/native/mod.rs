//! Native code generation backend using Cranelift
//!
//! This module provides the foundation for emitting native machine code
//! instead of C. Full AOT compilation with linking is the long-term goal.
//!
//! Current status (v0.3):
//! - Module structure ready
//! - Planned: Cranelift IR lowering for expressions, functions, control flow
//! - Planned: Object file emission + system linker integration
//!
//! To enable later:
//!   cargo build --features native
//!
//! Dependencies that will be added:
//!   cranelift-codegen, cranelift-frontend, cranelift-module,
//!   cranelift-object, target-lexicon, etc.

use crate::ast::Program;

/// Placeholder for the native backend.
/// Returns an error until Cranelift integration is completed.
pub fn compile_native(_program: &Program, _output: &str) -> Result<(), String> {
    Err(
        "Native (Cranelift) backend is under active development.\n\
         Current version uses the stable C backend.\n\
         See README.md for the roadmap."
            .to_string(),
    )
}

/// Future entry point for JIT execution of simple expressions.
pub fn jit_evaluate(_program: &Program) -> Result<f64, String> {
    Err("JIT evaluation not yet implemented".to_string())
}
