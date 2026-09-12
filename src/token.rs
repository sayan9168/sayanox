//! Tokens for the Sayanox language

#[derive(Debug, Clone, PartialEq)]
pub enum TokenKind {
    // Keywords
    Show,
    Hold,
    Make,
    Give,
    When,
    Otherwise,
    While,
    Struct,
    Use,

    // Literals
    Ident(String),
    Number(f64),
    String(String),

    // Operators
    Plus,
    Minus,
    Star,
    Slash,
    Assign,
    EqEq,
    BangEq,
    Gt,
    Lt,
    Gte,
    Lte,
    Dot,

    // Delimiters
    LParen,
    RParen,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Comma,
    Colon,

    Eof,
}

#[derive(Debug, Clone)]
pub struct Token {
    pub kind: TokenKind,
    pub line: usize,
    pub column: usize,
}
