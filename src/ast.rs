//! Abstract Syntax Tree for Sayanox

#[derive(Debug, Clone)]
pub enum Stmt {
    Show(Expr),
    Hold {
        name: String,
        value: Expr,
    },
    Make {
        name: String,
        params: Vec<String>,
        body: Vec<Stmt>,
    },
    Give(Expr),
    When {
        condition: Expr,
        then_body: Vec<Stmt>,
        otherwise_body: Option<Vec<Stmt>>,
    },
    While {
        condition: Expr,
        body: Vec<Stmt>,
    },
    /// Struct definition: make struct Name { field1, field2 }
    StructDef {
        name: String,
        fields: Vec<String>,
    },
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
    Call {
        name: String,
        args: Vec<Expr>,
    },
    /// Array literal: [1, 2, 3]
    Array(Vec<Expr>),
    /// Indexing: arr[0]
    Index {
        array: Box<Expr>,
        index: Box<Expr>,
    },
    /// Struct literal: Point { x: 10, y: 20 }
    StructLit {
        name: String,
        fields: Vec<(String, Expr)>,
    },
    /// Field access: p.x
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
