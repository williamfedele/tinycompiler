const TokenType = @import("token.zig").TokenType;

pub const ASTNode = union(enum) {
    Program: []ASTNode,
    VarDecl: struct { identifier: []const u8, var_type: []const u8, initial_value: ?*ASTNode },
    Assignment: struct { identifier: []const u8, value: *ASTNode },
    PrintStmt: *ASTNode,
    IfStmt: struct { condition: *ASTNode, then_body: []ASTNode, else_body: ?[]ASTNode },
    WhileStmt: struct { condition: *ASTNode, body: []ASTNode },
    BinaryExpr: struct { left: *ASTNode, operator: TokenType, right: *ASTNode },
    Integer: i64,
    Identifier: []const u8,
};
