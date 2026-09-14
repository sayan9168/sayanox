//! Lexer for Sayanox.
//!
//! This lexer is the complete source-to-token boundary for the current
//! language grammar. It handles whitespace, line and block comments, Unicode
//! identifiers, numeric literals, escaped strings, operators, punctuation,
//! and precise source locations.

use crate::token::{Token, TokenKind};

pub struct Lexer {
    input: Vec<char>,
    position: usize,
    line: usize,
    column: usize,
}

impl Lexer {
    pub fn new(input: &str) -> Self {
        Self { input: input.chars().collect(), position: 0, line: 1, column: 1 }
    }

    pub fn tokenize(&mut self) -> Result<Vec<Token>, String> {
        let mut tokens = Vec::new();
        while !self.is_at_end() {
            self.skip_whitespace_and_comments()?;
            if self.is_at_end() { break; }
            let start_line = self.line;
            let start_column = self.column;
            let ch = self.advance();
            let kind = match ch {
                '(' => TokenKind::LParen, ')' => TokenKind::RParen,
                '{' => TokenKind::LBrace, '}' => TokenKind::RBrace,
                '[' => TokenKind::LBracket, ']' => TokenKind::RBracket,
                ',' => TokenKind::Comma, ':' => TokenKind::Colon,
                ';' => TokenKind::Semicolon, '.' => TokenKind::Dot,
                '+' => TokenKind::Plus, '-' => TokenKind::Minus,
                '*' => TokenKind::Star, '/' => TokenKind::Slash,
                '%' => TokenKind::Percent,
                '=' => if self.match_char('=') { TokenKind::EqEq } else { TokenKind::Assign },
                '!' => if self.match_char('=') { TokenKind::BangEq } else { TokenKind::Bang },
                '&' => {
                    if self.match_char('&') { TokenKind::AndAnd }
                    else { return Err(self.error_at(start_line, start_column, "expected '&' after '&'")); }
                }
                '|' => {
                    if self.match_char('|') { TokenKind::OrOr }
                    else { return Err(self.error_at(start_line, start_column, "expected '|' after '|'")); }
                }
                '>' => if self.match_char('=') { TokenKind::Gte } else { TokenKind::Gt },
                '<' => if self.match_char('=') { TokenKind::Lte } else { TokenKind::Lt },
                '"' => self.string(start_line, start_column)?,
                c if c.is_ascii_digit() => self.number(c, start_line, start_column)?,
                c if is_identifier_start(c) => self.identifier(c),
                _ => return Err(self.error_at(start_line, start_column, &format!("unexpected character '{}'", ch))),
            };
            tokens.push(Token { kind, line: start_line, column: start_column });
        }
        tokens.push(Token { kind: TokenKind::Eof, line: self.line, column: self.column });
        Ok(tokens)
    }

    fn string(&mut self, start_line: usize, start_column: usize) -> Result<TokenKind, String> {
        let mut value = String::new();
        while !self.is_at_end() && self.peek() != '"' {
            if self.peek() == '\\' {
                self.advance();
                if self.is_at_end() { return Err(self.error_at(start_line, start_column, "unterminated escape sequence")); }
                let escape_line = self.line;
                let escape_column = self.column.saturating_sub(1);
                let escaped = self.advance();
                let decoded = match escaped {
                    'n' => '\n', 'r' => '\r', 't' => '\t', '0' => '\0',
                    'b' => '\u{0008}', 'f' => '\u{000C}', 'v' => '\u{000B}',
                    'a' => '\u{0007}', '"' => '"', '\\' => '\\',
                    'x' => self.hex_escape(escape_line, escape_column)?,
                    other => return Err(self.error_at(escape_line, escape_column, &format!("unknown escape sequence '\\{}'", other))),
                };
                value.push(decoded);
                continue;
            }
            let ch = self.advance();
            if ch == '\n' { self.line += 1; self.column = 1; }
            value.push(ch);
        }
        if self.is_at_end() { return Err(self.error_at(start_line, start_column, "unterminated string")); }
        self.advance();
        Ok(TokenKind::String(value))
    }

    fn hex_escape(&mut self, line: usize, column: usize) -> Result<char, String> {
        let mut digits = String::new();
        for _ in 0..2 {
            if self.is_at_end() || !self.peek().is_ascii_hexdigit() {
                return Err(self.error_at(line, column, "expected two hexadecimal digits after '\\x'"));
            }
            digits.push(self.advance());
        }
        let value = u8::from_str_radix(&digits, 16)
            .map_err(|_| self.error_at(line, column, "invalid hexadecimal escape"))?;
        Ok(value as char)
    }

    fn number(&mut self, first: char, start_line: usize, start_column: usize) -> Result<TokenKind, String> {
        let mut number = first.to_string();
        while self.peek().is_ascii_digit() { number.push(self.advance()); }
        if self.peek() == '.' && self.peek_next().is_some_and(|c| c.is_ascii_digit()) {
            number.push(self.advance());
            while self.peek().is_ascii_digit() { number.push(self.advance()); }
        }
        if matches!(self.peek(), 'e' | 'E') {
            number.push(self.advance());
            if matches!(self.peek(), '+' | '-') { number.push(self.advance()); }
            if !self.peek().is_ascii_digit() {
                return Err(self.error_at(start_line, start_column, &format!("invalid exponent in number '{}'", number)));
            }
            while self.peek().is_ascii_digit() { number.push(self.advance()); }
        }
        if self.peek() == '.' {
            return Err(self.error_at(start_line, start_column, &format!("invalid number '{}': multiple decimal points", number)));
        }
        let value = number.parse::<f64>().map_err(|_| self.error_at(start_line, start_column, &format!("invalid number '{}'", number)))?;
        if !value.is_finite() {
            return Err(self.error_at(start_line, start_column, &format!("number '{}' is outside the supported range", number)));
        }
        Ok(TokenKind::Number(value))
    }

    fn identifier(&mut self, first: char) -> TokenKind {
        let mut ident = first.to_string();
        while is_identifier_continue(self.peek()) { ident.push(self.advance()); }
        match ident.as_str() {
            "show" => TokenKind::Show, "hold" => TokenKind::Hold, "make" => TokenKind::Make,
            "give" => TokenKind::Give, "when" => TokenKind::When, "otherwise" => TokenKind::Otherwise,
            "while" => TokenKind::While, "struct" => TokenKind::Struct, "use" => TokenKind::Use,
            "export" => TokenKind::Export, _ => TokenKind::Ident(ident),
        }
    }

    fn skip_whitespace_and_comments(&mut self) -> Result<(), String> {
        loop {
            if self.is_at_end() { return Ok(()); }
            match self.peek() {
                ' ' | '\t' | '\r' => { self.advance(); }
                '\n' => { self.advance(); self.line += 1; self.column = 1; }
                '/' if self.peek_next() == Some('/') => {
                    self.advance(); self.advance();
                    while !self.is_at_end() && self.peek() != '\n' { self.advance(); }
                }
                '/' if self.peek_next() == Some('*') => self.skip_block_comment()?,
                _ => return Ok(()),
            }
        }
    }

    fn skip_block_comment(&mut self) -> Result<(), String> {
        let start_line = self.line;
        let start_column = self.column;
        self.advance(); self.advance();
        while !self.is_at_end() {
            if self.peek() == '*' && self.peek_next() == Some('/') {
                self.advance(); self.advance(); return Ok(());
            }
            let ch = self.advance();
            if ch == '\n' { self.line += 1; self.column = 1; }
        }
        Err(self.error_at(start_line, start_column, "unterminated block comment"))
    }

    fn advance(&mut self) -> char {
        let ch = self.input[self.position]; self.position += 1; self.column += 1; ch
    }
    fn peek(&self) -> char { self.input.get(self.position).copied().unwrap_or('\0') }
    fn peek_next(&self) -> Option<char> { self.input.get(self.position + 1).copied() }
    fn match_char(&mut self, expected: char) -> bool {
        if self.peek() == expected { self.advance(); true } else { false }
    }
    fn is_at_end(&self) -> bool { self.position >= self.input.len() }
    fn error_at(&self, line: usize, column: usize, message: &str) -> String {
        format!("Sayanox lexer error at line {}, column {}: {}", line, column, message)
    }
}

fn is_identifier_start(ch: char) -> bool { ch == '_' || ch.is_alphabetic() }
fn is_identifier_continue(ch: char) -> bool { ch == '_' || ch.is_alphanumeric() }

#[cfg(test)]
mod tests {
    use super::*;

    fn kinds(source: &str) -> Vec<TokenKind> {
        Lexer::new(source).tokenize().unwrap().into_iter().map(|t| t.kind).collect()
    }

    #[test]
    fn lexes_all_current_keywords() {
        let tokens = kinds("show hold make give when otherwise while struct use export");
        assert_eq!(tokens.len(), 11);
        assert_eq!(tokens[0], TokenKind::Show);
        assert_eq!(tokens[8], TokenKind::Use);
        assert_eq!(tokens[9], TokenKind::Export);
        assert_eq!(tokens[10], TokenKind::Eof);
    }

    #[test]
    fn lexes_operators_and_punctuation() {
        let tokens = kinds("(){}[],:;. + - * / % = == ! != && || > < >= <=");
        assert!(tokens.contains(&TokenKind::AndAnd));
        assert!(tokens.contains(&TokenKind::OrOr));
        assert!(tokens.contains(&TokenKind::Bang));
        assert!(tokens.contains(&TokenKind::Semicolon));
        assert_eq!(tokens.last(), Some(&TokenKind::Eof));
    }

    #[test]
    fn lexes_escaped_and_multiline_strings() {
        let tokens = kinds("show \"hello\\nworld\\x21\"");
        assert_eq!(tokens[1], TokenKind::String("hello\nworld!".to_string()));
    }

    #[test]
    fn skips_line_and_block_comments() {
        let tokens = kinds("// line\n/* block\ncomment */ show 42");
        assert_eq!(tokens[0], TokenKind::Show);
        assert_eq!(tokens[1], TokenKind::Number(42.0));
    }

    #[test]
    fn supports_unicode_identifiers() {
        let tokens = kinds("hold café_变量 = 1");
        assert_eq!(tokens[1], TokenKind::Ident("café_变量".to_string()));
    }

    #[test]
    fn supports_decimal_and_exponent_numbers() {
        let tokens = kinds("1 3.14 6.02e23 4E-2");
        assert_eq!(tokens[0], TokenKind::Number(1.0));
        assert_eq!(tokens[1], TokenKind::Number(3.14));
        assert_eq!(tokens[2], TokenKind::Number(6.02e23));
        assert_eq!(tokens[3], TokenKind::Number(4E-2));
    }

    #[test]
    fn rejects_unterminated_comment() {
        let error = Lexer::new("/* missing").tokenize().unwrap_err();
        assert!(error.contains("unterminated block comment"));
    }

    #[test]
    fn rejects_invalid_single_ampersand() {
        let error = Lexer::new("&").tokenize().unwrap_err();
        assert!(error.contains("expected '&' after '&'"));
    }

    #[test]
    fn preserves_multiline_token_location() {
        let tokens = Lexer::new("show \"a\nb\"\nshow 42").tokenize().unwrap();
        assert_eq!(tokens[0].line, 1);
        assert_eq!(tokens[0].column, 1);
        assert_eq!(tokens[2].line, 3);
        assert_eq!(tokens[2].column, 1);
    }
}
