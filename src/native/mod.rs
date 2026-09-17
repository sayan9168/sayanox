//! Native backend placeholder.
//!
//! Cranelift was removed to keep the optional Rust host dependency-free
//! (std only). Prefer Stage-2 / `./selfhost/sx` for native binaries via C.

use crate::ast::Program;

pub fn jit_evaluate(_program: &Program) -> Result<f64, String> {
    Err(
        "JIT native backend removed (zero-crate Rust host). \
         Use: ./selfhost/sx file.sa --run"
            .into(),
    )
}

pub fn compile_native(_program: &Program, _output: &str) -> Result<(), String> {
    Err(
        "AOT native backend removed (zero-crate Rust host). \
         Use: ./selfhost/sx file.sa -o prog --run"
            .into(),
    )
}
