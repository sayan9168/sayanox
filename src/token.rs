//! Tokens for the Sayanox language.
//!
//! The token model is deliberately independent from the parser so the lexer
//! can be tested as a complete source-to-token boundary.

#[derive(Debug, Clone, PartialEq)]
pub enum TokenKind {
    Show,
    Hold,
    Make,
    Give,
    When,
    Otherwise,
    While,
    Struct,
    Use,
    Export,

    Ident(String),
    Number(f64),
    String(String),

    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Assign,
    EqEq,
    BangEq,
    Bang,
    AndAnd,
    OrOr,
    Gt,
    Lt,
    Gte,
    Lte,
    Dot,

    LParen,
    RParen,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Comma,
    Colon,
    Semicolon,

    Eof,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Token {
    pub kind: TokenKind,
    pub line: usize,
    pub column: usize,
}
