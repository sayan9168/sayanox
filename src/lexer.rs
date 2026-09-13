//! Lexer for Sayanox

use crate::token::{Token, TokenKind};

pub struct Lexer {
    input: Vec<char>,
    position: usize,
    line: usize,
    column: usize,
}

impl Lexer {
    pub fn new(input: &str) -> Self {
        Self {
            input: input.chars().collect(),
            position: 0,
            line: 1,
            column: 1,
        }
    }

    pub fn tokenize(&mut self) -> Result<Vec<Token>, String> {
        let mut tokens = Vec::new();
        while !self.is_at_end() {
            self.skip_whitespace_and_comments();
            if self.is_at_end() {
                break;
            }
            let start_col = self.column;
            let ch = self.advance();
            let kind = match ch {
                '(' => TokenKind::LParen,
                ')' => TokenKind::RParen,
                '{' => TokenKind::LBrace,
                '}' => TokenKind::RBrace,
                '[' => TokenKind::LBracket,
                ']' => TokenKind::RBracket,
                ',' => TokenKind::Comma,
                ':' => TokenKind::Colon,
                '.' => TokenKind::Dot,
                '+' => TokenKind::Plus,
                '-' => TokenKind::Minus,
                '*' => TokenKind::Star,
                '/' => TokenKind::Slash,
                '%' => TokenKind::Percent,
                '=' => {
                    if self.match_char('=') {
                        TokenKind::EqEq
                    } else {
                        TokenKind::Assign
                    }
                }
                '!' => {
                    if self.match_char('=') {
                        TokenKind::BangEq
                    } else {
                        return Err(format!("Unexpected character '!' at line {}", self.line));
                    }
                }
                '>' => {
                    if self.match_char('=') {
                        TokenKind::Gte
                    } else {
                        TokenKind::Gt
                    }
                }
                '<' => {
                    if self.match_char('=') {
                        TokenKind::Lte
                    } else {
                        TokenKind::Lt
                    }
                }
                '"' => self.string()?,
                c if c.is_ascii_digit() => self.number(c)?,
                c if c.is_alphabetic() || c == '_' => self.identifier(c),
                _ => {
                    return Err(format!(
                        "Unexpected character '{}' at line {}, column {}",
                        ch, self.line, start_col
                    ));
                }
            };
            tokens.push(Token {
                kind,
                line: self.line,
                column: start_col,
            });
        }
        tokens.push(Token {
            kind: TokenKind::Eof,
            line: self.line,
            column: self.column,
        });
        Ok(tokens)
    }

    fn string(&mut self) -> Result<TokenKind, String> {
        let mut value = String::new();
        while !self.is_at_end() && self.peek() != '"' {
            if self.peek() == '\\' {
                self.advance();
                if self.is_at_end() {
                    break;
                }
                let e = self.advance();
                value.push(match e {
                    'n' => '\n',
                    't' => '\t',
                    'r' => '\r',
                    '"' => '"',
                    '\\' => '\\',
                    other => other,
                });
                continue;
            }
            if self.peek() == '\n' {
                self.line += 1;
                self.column = 0;
            }
            value.push(self.advance());
        }
        if self.is_at_end() {
            return Err(format!("Unterminated string at line {}", self.line));
        }
        self.advance();
        Ok(TokenKind::String(value))
    }

    fn number(&mut self, first: char) -> Result<TokenKind, String> {
        let mut num = first.to_string();
        while !self.is_at_end() && (self.peek().is_ascii_digit() || self.peek() == '.') {
            num.push(self.advance());
        }
        num.parse::<f64>()
            .map(TokenKind::Number)
            .map_err(|_| format!("Invalid number '{}' at line {}", num, self.line))
    }

    fn identifier(&mut self, first: char) -> TokenKind {
        let mut ident = first.to_string();
        while !self.is_at_end() && (self.peek().is_alphanumeric() || self.peek() == '_') {
            ident.push(self.advance());
        }
        match ident.as_str() {
            "show" => TokenKind::Show,
            "hold" => TokenKind::Hold,
            "make" => TokenKind::Make,
            "give" => TokenKind::Give,
            "when" => TokenKind::When,
            "otherwise" => TokenKind::Otherwise,
            "while" => TokenKind::While,
            "struct" => TokenKind::Struct,
            "use" => TokenKind::Use,
            _ => TokenKind::Ident(ident),
        }
    }

    fn skip_whitespace_and_comments(&mut self) {
        loop {
            if self.is_at_end() {
                break;
            }
            match self.peek() {
                ' ' | '\t' | '\r' => {
                    self.advance();
                }
                '\n' => {
                    self.advance();
                    self.line += 1;
                    self.column = 1;
                }
                '/' if self.peek_next() == Some('/') => {
                    while !self.is_at_end() && self.peek() != '\n' {
                        self.advance();
                    }
                }
                _ => break,
            }
        }
    }

    fn advance(&mut self) -> char {
        let ch = self.input[self.position];
        self.position += 1;
        self.column += 1;
        ch
    }

    fn peek(&self) -> char {
        if self.is_at_end() {
            '\0'
        } else {
            self.input[self.position]
        }
    }

    fn peek_next(&self) -> Option<char> {
        if self.position + 1 >= self.input.len() {
            None
        } else {
            Some(self.input[self.position + 1])
        }
    }

    fn match_char(&mut self, expected: char) -> bool {
        if self.peek() == expected {
            self.advance();
            true
        } else {
            false
        }
    }

    fn is_at_end(&self) -> bool {
        self.position >= self.input.len()
    }
}
