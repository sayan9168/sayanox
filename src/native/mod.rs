//! Native code generation backend using Cranelift
//!
//! Goal: Emit real machine code instead of C.
//!
//! Current status:
//! - Module layout ready
//! - Basic API defined
//! - Full Cranelift IR lowering for arithmetic + functions is the next implementation step
//!
//! When ready, add to Cargo.toml:
//!   cranelift-codegen = "0.108"
//!   cranelift-frontend = "0.108"
//!   cranelift-module = "0.108"
//!   cranelift-object = "0.108"
//!   target-lexicon = "0.12"
//!
//! Then implement:
//! 1. Type mapping (Sayanox values → Cranelift types)
//! 2. Expression lowering
//! 3. Function & control-flow lowering
//! 4. Object file emission + linking

use crate::ast::Program;

/// Compile a Sayanox program to a native object / executable.
/// Currently returns a clear message until the full backend is finished.
pub fn compile_native(_program: &Program, output: &str) -> Result<(), String> {
    Err(format!(
        "Native (Cranelift) backend is under active development.\n\
         Requested output: {}\n\
         The stable C backend is currently used.\n\
         See src/native/mod.rs and README.md for the implementation plan.",
        output
    ))
}

/// Future JIT entry point for quick evaluation of simple expressions.
pub fn jit_evaluate(_program: &Program) -> Result<f64, String> {
    Err("JIT evaluation not yet implemented — coming with the Cranelift backend.".to_string())
}
