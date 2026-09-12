//! Parser for Sayanox (recursive descent)

use crate::ast::*;
use crate::token::{Token, TokenKind};

pub struct Parser {
    tokens: Vec<Token>,
    current: usize,
}

impl Parser {
    pub fn new(tokens: Vec<Token>) -> Self { Self { tokens, current: 0 } }

    pub fn parse(&mut self) -> Result<Program, String> {
        let mut statements = Vec::new();
        while !self.is_at_end() { statements.push(self.statement()?); }
        Ok(Program { statements })
    }

    fn statement(&mut self) -> Result<Stmt, String> {
        match &self.peek().kind {
            TokenKind::Show => self.show_stmt(),
            TokenKind::Hold => self.hold_stmt(),
            TokenKind::Make => self.make_or_struct(),
            TokenKind::Give => self.give_stmt(),
            TokenKind::When => self.when_stmt(),
            TokenKind::While => self.while_stmt(),
            TokenKind::Ident(_) if self.peek_next_is(&TokenKind::Assign) => self.assign_stmt(),
            _ => Ok(Stmt::Expr(self.expression()?)),
        }
    }

    fn show_stmt(&mut self) -> Result<Stmt, String> { self.advance(); Ok(Stmt::Show(self.expression()?)) }

    fn hold_stmt(&mut self) -> Result<Stmt, String> {
        self.advance();
        let name = self.consume_ident("Expected variable name after 'hold'")?;
        self.consume(&TokenKind::Assign, "Expected '=' after variable name")?;
        let value = self.expression()?;
        Ok(Stmt::Hold { name, value })
    }

    fn assign_stmt(&mut self) -> Result<Stmt, String> {
        let name = self.consume_ident("Expected variable name")?;
        self.consume(&TokenKind::Assign, "Expected '=' after variable name")?;
        let value = self.expression()?;
        Ok(Stmt::Assign { name, value })
    }

    fn make_or_struct(&mut self) -> Result<Stmt, String> {
        self.advance();
        if self.match_token(&TokenKind::Struct) { return self.struct_def(); }
        self.make_stmt()
    }

    fn struct_def(&mut self) -> Result<Stmt, String> {
        let name = self.consume_ident("Expected struct name")?;
        self.consume(&TokenKind::LBrace, "Expected '{' after struct name")?;
        let mut fields = Vec::new();
        if !self.check(&TokenKind::RBrace) {
            loop {
                fields.push(self.consume_ident("Expected field name")?);
                if !self.match_token(&TokenKind::Comma) { break; }
            }
        }
        self.consume(&TokenKind::RBrace, "Expected '}' after struct fields")?;
        Ok(Stmt::StructDef { name, fields })
    }

    fn make_stmt(&mut self) -> Result<Stmt, String> {
        let name = self.consume_ident("Expected function name after 'make'")?;
        self.consume(&TokenKind::LParen, "Expected '(' after function name")?;
        let mut params = Vec::new();
        if !self.check(&TokenKind::RParen) {
            loop {
                params.push(self.consume_ident("Expected parameter name")?);
                if !self.match_token(&TokenKind::Comma) { break; }
            }
        }
        self.consume(&TokenKind::RParen, "Expected ')' after parameters")?;
        self.consume(&TokenKind::LBrace, "Expected '{' after function signature")?;
        let mut body = Vec::new();
        while !self.check(&TokenKind::RBrace) && !self.is_at_end() { body.push(self.statement()?); }
        self.consume(&TokenKind::RBrace, "Expected '}' after function body")?;
        Ok(Stmt::Make { name, params, body })
    }

    fn give_stmt(&mut self) -> Result<Stmt, String> { self.advance(); Ok(Stmt::Give(self.expression()?)) }

    fn when_stmt(&mut self) -> Result<Stmt, String> {
        self.advance();
        let condition = self.expression()?;
        self.consume(&TokenKind::LBrace, "Expected '{' after condition")?;
        let mut then_body = Vec::new();
        while !self.check(&TokenKind::RBrace) && !self.is_at_end() { then_body.push(self.statement()?); }
        self.consume(&TokenKind::RBrace, "Expected '}' after when body")?;
        let otherwise_body = if self.match_token(&TokenKind::Otherwise) {
            self.consume(&TokenKind::LBrace, "Expected '{' after otherwise")?;
            let mut body = Vec::new();
            while !self.check(&TokenKind::RBrace) && !self.is_at_end() { body.push(self.statement()?); }
            self.consume(&TokenKind::RBrace, "Expected '}' after otherwise body")?;
            Some(body)
        } else { None };
        Ok(Stmt::When { condition, then_body, otherwise_body })
    }

    fn while_stmt(&mut self) -> Result<Stmt, String> {
        self.advance();
        let condition = self.expression()?;
        self.consume(&TokenKind::LBrace, "Expected '{' after while condition")?;
        let mut body = Vec::new();
        while !self.check(&TokenKind::RBrace) && !self.is_at_end() { body.push(self.statement()?); }
        self.consume(&TokenKind::RBrace, "Expected '}' after while body")?;
        Ok(Stmt::While { condition, body })
    }

    fn expression(&mut self) -> Result<Expr, String> { self.equality() }

    fn equality(&mut self) -> Result<Expr, String> {
        let mut expr = self.comparison()?;
        loop {
            let op = if self.match_token(&TokenKind::EqEq) { Some(BinOp::Eq) }
                else if self.match_token(&TokenKind::BangEq) { Some(BinOp::Neq) }
                else { None };
            let Some(op) = op else { break };
            let right = self.comparison()?;
            expr = Expr::Binary { left: Box::new(expr), op, right: Box::new(right) };
        }
        Ok(expr)
    }

    fn comparison(&mut self) -> Result<Expr, String> {
        let mut expr = self.term()?;
        while matches!(self.peek().kind, TokenKind::Gt | TokenKind::Lt | TokenKind::Gte | TokenKind::Lte) {
            let op = match self.advance().kind {
                TokenKind::Gt => BinOp::Gt, TokenKind::Lt => BinOp::Lt,
                TokenKind::Gte => BinOp::Gte, TokenKind::Lte => BinOp::Lte,
                _ => unreachable!(),
            };
            let right = self.term()?;
            expr = Expr::Binary { left: Box::new(expr), op, right: Box::new(right) };
        }
        Ok(expr)
    }

    fn term(&mut self) -> Result<Expr, String> {
        let mut expr = self.factor()?;
        loop {
            let op = if self.match_token(&TokenKind::Plus) { Some(BinOp::Add) }
                else if self.match_token(&TokenKind::Minus) { Some(BinOp::Sub) }
                else { None };
            let Some(op) = op else { break };
            let right = self.factor()?;
            expr = Expr::Binary { left: Box::new(expr), op, right: Box::new(right) };
        }
        Ok(expr)
    }

    fn factor(&mut self) -> Result<Expr, String> {
        let mut expr = self.unary()?;
        loop {
            let op = if self.match_token(&TokenKind::Star) { Some(BinOp::Mul) }
                else if self.match_token(&TokenKind::Slash) { Some(BinOp::Div) }
                else { None };
            let Some(op) = op else { break };
            let right = self.unary()?;
            expr = Expr::Binary { left: Box::new(expr), op, right: Box::new(right) };
        }
        Ok(expr)
    }

    fn unary(&mut self) -> Result<Expr, String> {
        if self.match_token(&TokenKind::Minus) {
            let right = self.unary()?;
            return Ok(Expr::Binary { left: Box::new(Expr::Number(0.0)), op: BinOp::Sub, right: Box::new(right) });
        }
        self.call()
    }

    fn call(&mut self) -> Result<Expr, String> {
        let mut expr = self.primary()?;
        loop {
            if self.match_token(&TokenKind::LParen) {
                let mut args = Vec::new();
                if !self.check(&TokenKind::RParen) {
                    loop {
                        args.push(self.expression()?);
                        if !self.match_token(&TokenKind::Comma) { break; }
                    }
                }
                self.consume(&TokenKind::RParen, "Expected ')' after arguments")?;
                if let Expr::Ident(name) = expr {
                    expr = Expr::Call { name, args };
                } else {
                    return Err(format!("Can only call identifiers at line {} column {}", self.previous().line, self.previous().column));
                }
            } else if self.match_token(&TokenKind::LBracket) {
                let index = self.expression()?;
                self.consume(&TokenKind::RBracket, "Expected ']' after index")?;
                expr = Expr::Index { array: Box::new(expr), index: Box::new(index) };
            } else if self.match_token(&TokenKind::Dot) {
                let field = self.consume_ident("Expected field name after '.'")?;
                expr = Expr::Field { object: Box::new(expr), field };
            } else { break; }
        }
        Ok(expr)
    }

    fn primary(&mut self) -> Result<Expr, String> {
        let token = self.advance();
        match token.kind {
            TokenKind::Number(n) => Ok(Expr::Number(n)),
            TokenKind::String(s) => Ok(Expr::String(s)),
            TokenKind::Ident(name) => {
                if self.check(&TokenKind::LBrace) {
                    self.advance();
                    let mut fields = Vec::new();
                    if !self.check(&TokenKind::RBrace) {
                        loop {
                            let fname = self.consume_ident("Expected field name")?;
                            self.consume(&TokenKind::Colon, "Expected ':' after field name")?;
                            let fval = self.expression()?;
                            fields.push((fname, fval));
                            if !self.match_token(&TokenKind::Comma) { break; }
                        }
                    }
                    self.consume(&TokenKind::RBrace, "Expected '}' after struct fields")?;
                    Ok(Expr::StructLit { name, fields })
                } else { Ok(Expr::Ident(name)) }
            }
            TokenKind::LParen => {
                let expr = self.expression()?;
                self.consume(&TokenKind::RParen, "Expected ')' after expression")?;
                Ok(expr)
            }
            TokenKind::LBracket => {
                let mut elements = Vec::new();
                if !self.check(&TokenKind::RBracket) {
                    loop {
                        elements.push(self.expression()?);
                        if !self.match_token(&TokenKind::Comma) { break; }
                    }
                }
                self.consume(&TokenKind::RBracket, "Expected ']' after array elements")?;
                Ok(Expr::Array(elements))
            }
            _ => Err(format!("Unexpected token {:?} at line {} column {}", token.kind, token.line, token.column)),
        }
    }

    fn match_token(&mut self, kind: &TokenKind) -> bool {
        if self.check(kind) { self.advance(); true } else { false }
    }

    fn check(&self, kind: &TokenKind) -> bool {
        if self.is_at_end() { return false; }
        std::mem::discriminant(&self.peek().kind) == std::mem::discriminant(kind)
    }

    fn peek_next_is(&self, kind: &TokenKind) -> bool {
        let next = self.current + 1;
        if next >= self.tokens.len() { return false; }
        std::mem::discriminant(&self.tokens[next].kind) == std::mem::discriminant(kind)
    }

    fn advance(&mut self) -> Token {
        if !self.is_at_end() { self.current += 1; }
        self.previous()
    }

    fn is_at_end(&self) -> bool { matches!(self.peek().kind, TokenKind::Eof) }
    fn peek(&self) -> &Token { &self.tokens[self.current] }
    fn previous(&self) -> Token { self.tokens[self.current.saturating_sub(1)].clone() }

    fn consume(&mut self, kind: &TokenKind, message: &str) -> Result<(), String> {
        if self.check(kind) { self.advance(); Ok(()) }
        else { Err(format!("{} at line {} column {}", message, self.peek().line, self.peek().column)) }
    }

    fn consume_ident(&mut self, message: &str) -> Result<String, String> {
        if let TokenKind::Ident(name) = &self.peek().kind {
            let name = name.clone(); self.advance(); Ok(name)
        } else {
            Err(format!("{} at line {} column {}", message, self.peek().line, self.peek().column))
        }
    }
}
