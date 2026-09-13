//! Sayanox Compiler - Entry point

mod ast;
mod codegen;
mod diagnostic;
mod lexer;
mod module;
mod native;
mod parser;
mod stdlib;
mod token;
mod types;

use std::env;
use std::fs;
use std::path::PathBuf;
use std::process;

const VERSION: &str = "0.3.30";

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Sayanox Compiler v{}", VERSION);
        eprintln!("Usage: sayanox <input.sa> [-o output]");
        eprintln!("       sayanox <input.sa> --tokens");
        eprintln!("       sayanox <input.sa> --ast");
        eprintln!("       sayanox <input.sa> --check          (type check only)");
        eprintln!("       sayanox <input.sa> --jit");
        eprintln!("       sayanox <input.sa> --native -o bin");
        eprintln!("\nModules:  use \"other.sa\"");
        eprintln!("Packages: tools/sxpkg init | install | list");
        process::exit(1);
    }

    let input = PathBuf::from(&args[1]);
    let mut output: Option<PathBuf> = None;
    let mut show_tokens = false;
    let mut show_ast = false;
    let mut check_only = false;
    let mut use_jit = false;
    let mut use_native = false;
    let mut skip_types = false;

    let mut i = 2;
    while i < args.len() {
        match args[i].as_str() {
            "-o" => {
                if i + 1 < args.len() {
                    output = Some(PathBuf::from(&args[i + 1]));
                    i += 2;
                } else {
                    eprintln!("error: -o requires a filename");
                    process::exit(1);
                }
            }
            "--tokens" => {
                show_tokens = true;
                i += 1;
            }
            "--ast" => {
                show_ast = true;
                i += 1;
            }
            "--check" => {
                check_only = true;
                i += 1;
            }
            "--no-check" => {
                skip_types = true;
                i += 1;
            }
            "--jit" => {
                use_jit = true;
                i += 1;
            }
            "--native" => {
                use_native = true;
                i += 1;
            }
            _ => {
                eprintln!("error: unknown argument `{}`", args[i]);
                process::exit(1);
            }
        }
    }

    // Multi-file: resolve `use` imports
    let program = match module::load_program(&input) {
        Ok(p) => p,
        Err(e) => {
            // Fallback: single-file path if module loader fails on non-use programs
            let source = match fs::read_to_string(&input) {
                Ok(s) => s,
                Err(err) => {
                    eprintln!("error: {}", e);
                    eprintln!("also: {}", err);
                    process::exit(1);
                }
            };
            let mut lexer = lexer::Lexer::new(&source);
            let tokens = match lexer.tokenize() {
                Ok(t) => t,
                Err(err) => {
                    eprintln!("{}", diagnostic::render_error("lexer", &err, &source, &input));
                    process::exit(1);
                }
            };
            if show_tokens {
                for t in &tokens {
                    println!("{:?}", t);
                }
                return;
            }
            let mut parser = parser::Parser::new(tokens);
            match parser.parse() {
                Ok(p) => p,
                Err(err) => {
                    eprintln!("{}", diagnostic::render_error("parser", &err, &source, &input));
                    process::exit(1);
                }
            }
        }
    };

    if show_ast {
        println!("{:#?}", program);
        return;
    }

    if !skip_types {
        if let Err(e) = types::check(&program) {
            eprintln!("error[types]: {}", e);
            process::exit(1);
        }
    }

    if check_only {
        println!("OK type check passed ({})", input.display());
        return;
    }

    if use_jit {
        match native::jit_evaluate(&program) {
            Ok(v) => println!("JIT result: {}", v),
            Err(e) => {
                eprintln!("error[jit]: {}", e);
                process::exit(1);
            }
        }
        return;
    }

    if use_native {
        let out = output
            .unwrap_or_else(|| {
                let mut p = input.clone();
                p.set_extension("");
                p
            })
            .to_string_lossy()
            .to_string();
        let out = if out.is_empty() || out == "." {
            "a.out".to_string()
        } else {
            out
        };
        match native::compile_native(&program, &out) {
            Ok(()) => {
                println!("OK AOT native binary -> {}", out);
                println!("  Run: ./{}", out);
            }
            Err(e) => {
                eprintln!("error[aot]: {}", e);
                process::exit(1);
            }
        }
        return;
    }

    let mut codegen = codegen::Codegen::new();
    let c_code = codegen.generate(&program);
    let output_path = output.unwrap_or_else(|| {
        let mut p = input.clone();
        p.set_extension("c");
        p
    });

    if let Err(e) = fs::write(&output_path, &c_code) {
        eprintln!("error: failed to write {}: {}", output_path.display(), e);
        process::exit(1);
    }

    println!("OK compiled successfully -> {}", output_path.display());
    println!(
        "  Next: clang {} -o program && ./program",
        output_path.display()
    );
}
