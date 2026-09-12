//! Sayanox Compiler - Entry point
//! An original easy programming language with its own compiler.

mod ast;
mod codegen;
mod diagnostic;
mod lexer;
mod native;
mod parser;
mod stdlib;
mod token;

use std::env;
use std::fs;
use std::path::PathBuf;
use std::process;

const VERSION: &str = "0.3.28";

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Sayanox Compiler v{}", VERSION);
        eprintln!("Usage: sayanox <input.sa> [-o output]");
        eprintln!("       sayanox <input.sa> --tokens");
        eprintln!("       sayanox <input.sa> --ast");
        eprintln!("       sayanox <input.sa> --jit");
        eprintln!("       sayanox <input.sa> --native -o bin");
        eprintln!("\nBuilt-in library: {} helpers", stdlib::BUILTINS.len());
        process::exit(1);
    }

    let input = PathBuf::from(&args[1]);
    let mut output: Option<PathBuf> = None;
    let mut show_tokens = false;
    let mut show_ast = false;
    let mut use_jit = false;
    let mut use_native = false;

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
            "--tokens" => { show_tokens = true; i += 1; }
            "--ast" => { show_ast = true; i += 1; }
            "--jit" => { use_jit = true; i += 1; }
            "--native" => { use_native = true; i += 1; }
            _ => {
                eprintln!("error: unknown argument `{}`", args[i]);
                eprintln!("hint: run `sayanox` without arguments to see usage");
                process::exit(1);
            }
        }
    }

    let source = match fs::read_to_string(&input) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("error: failed to read {}: {}", input.display(), e);
            process::exit(1);
        }
    };

    let mut lexer = lexer::Lexer::new(&source);
    let tokens = match lexer.tokenize() {
        Ok(t) => t,
        Err(e) => {
            eprintln!("{}", diagnostic::render_error("lexer", &e, &source, &input));
            process::exit(1);
        }
    };

    if show_tokens {
        for t in &tokens { println!("{:?}", t); }
        return;
    }

    let mut parser = parser::Parser::new(tokens);
    let program = match parser.parse() {
        Ok(p) => p,
        Err(e) => {
            eprintln!("{}", diagnostic::render_error("parser", &e, &source, &input));
            process::exit(1);
        }
    };

    if show_ast {
        println!("{:#?}", program);
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
        let out = output.unwrap_or_else(|| {
            let mut p = input.clone();
            p.set_extension("");
            p
        }).to_string_lossy().to_string();
        let out = if out.is_empty() || out == "." { "a.out".to_string() } else { out };
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
    println!("  Next: clang {} -o program && ./program", output_path.display());
}
