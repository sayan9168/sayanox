//! Abstract Syntax Tree for Sayanox

#[derive(Debug, Clone)]
pub enum Stmt {
    Show(Expr),
    Hold {
        name: String,
        value: Expr,
        exported: bool,
    },
    Assign { name: String, value: Expr },
    Make {
        name: String,
        params: Vec<String>,
        body: Vec<Stmt>,
        exported: bool,
    },
    Give(Expr),
    When {
        condition: Expr,
        then_body: Vec<Stmt>,
        otherwise_body: Option<Vec<Stmt>>,
    },
    While { condition: Expr, body: Vec<Stmt> },
    StructDef {
        name: String,
        fields: Vec<String>,
        exported: bool,
    },
    /// Import another .sa file (resolved relative to the current file).
    Use { path: String },
    Expr(Expr),
}

#[derive(Debug, Clone)]
pub enum Expr {
    Number(f64),
    String(String),
    Ident(String),
    Binary {
        left: Box<Expr>,
        op: BinOp,
        right: Box<Expr>,
    },
    Call { name: String, args: Vec<Expr> },
    Array(Vec<Expr>),
    Index {
        array: Box<Expr>,
        index: Box<Expr>,
    },
    StructLit {
        name: String,
        fields: Vec<(String, Expr)>,
    },
    Field {
        object: Box<Expr>,
        field: String,
    },
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    Gt,
    Lt,
    Eq,
    Neq,
    Gte,
    Lte,
}

#[derive(Debug, Clone)]
pub struct Program {
    pub statements: Vec<Stmt>,
}
