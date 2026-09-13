//! Tokens for the Sayanox language

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

    Eof,
}

#[derive(Debug, Clone)]
pub struct Token {
    pub kind: TokenKind,
    pub line: usize,
    pub column: usize,
}
