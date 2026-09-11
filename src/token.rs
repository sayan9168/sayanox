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

    // Delimiters
    LParen,
    RParen,
    LBrace,
    RBrace,
    Comma,

    Eof,
}

#[derive(Debug, Clone)]
pub struct Token {
    pub kind: TokenKind,
    pub line: usize,
    pub column: usize,
}
