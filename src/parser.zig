const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const LexerError = @import("lexer.zig").LexerError;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

pub const ParseError = error{ UnexpectedToken, InvalidExpression, OutOfMemory } || std.fmt.ParseIntError || LexerError;

pub const ASTNode = union(enum) {
    Program: []ASTNode,
    Assignment: struct { identifier: []const u8, value: *ASTNode },
    PrintStmt: *ASTNode,
    IfStmt: struct { condition: *ASTNode, body: []ASTNode },
    WhileStmt: struct { condition: *ASTNode, body: []ASTNode },
    BinaryExpr: struct { left: *ASTNode, operator: TokenType, right: *ASTNode },
    Integer: i64,
    Identifier: []const u8,
};

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    allocator: std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) ParseError!Parser {
        var parser = Parser{
            .lexer = lexer,
            .current_token = undefined,
            .allocator = allocator,
        };
        try parser.advance();
        return parser;
    }

    fn advance(self: *Parser) ParseError!void {
        self.current_token = try self.lexer.nextToken();
    }

    pub fn parse(self: *Parser) ParseError!ASTNode {
        var statements = std.ArrayList(ASTNode).init(self.allocator);
        defer statements.deinit();

        while (self.current_token.type != .EOF) {
            const stmt = try self.parseStatement();
            try statements.append(stmt);
        }

        return ASTNode{ .Program = try statements.toOwnedSlice() };
    }

    fn parseStatement(self: *Parser) ParseError!ASTNode {
        return switch (self.current_token.type) {
            .Identifier => self.parseAssignment(),
            .Print => self.parsePrintStatement(),
            .If => self.parseIfStatement(),
            .While => self.parseWhileStatement(),
            else => ParseError.UnexpectedToken,
        };
    }

    fn parseAssignment(self: *Parser) ParseError!ASTNode {
        const identifier = self.current_token.lexeme;
        try self.advance();

        if (self.current_token.type != .Assign) {
            return ParseError.UnexpectedToken;
        }
        try self.advance();

        const value = try self.allocator.create(ASTNode);
        errdefer self.allocator.destroy(value);
        value.* = try self.parseExpression();

        return ASTNode{ .Assignment = .{ .identifier = identifier, .value = value } };
    }

    fn parsePrintStatement(self: *Parser) ParseError!ASTNode {
        try self.advance();
        const expr = try self.allocator.create(ASTNode);
        errdefer self.allocator.destroy(expr);
        expr.* = try self.parseExpression();
        return ASTNode{ .PrintStmt = expr };
    }

    fn parseIfStatement(self: *Parser) ParseError!ASTNode {
        try self.advance();
        const condition = try self.allocator.create(ASTNode);
        condition.* = try self.parseExpression();

        var body = std.ArrayList(ASTNode).init(self.allocator);
        errdefer {
            for (body.items) |*node| {
                self.freeASTNode(node);
            }
            body.deinit();
        }

        while (self.current_token.type != .End) {
            const stmt = try self.parseStatement();
            try body.append(stmt);
        }
        try self.advance();

        return ASTNode{ .IfStmt = .{
            .condition = condition,
            .body = try body.toOwnedSlice(),
        } };
    }

    fn parseWhileStatement(self: *Parser) ParseError!ASTNode {
        try self.advance();
        const condition = try self.allocator.create(ASTNode);
        condition.* = try self.parseExpression();

        var body = std.ArrayList(ASTNode).init(self.allocator);
        errdefer {
            for (body.items) |*node| {
                self.freeASTNode(node);
            }
            body.deinit();
        }

        while (self.current_token.type != .End) {
            const stmt = try self.parseStatement();
            try body.append(stmt);
        }
        try self.advance();

        return ASTNode{ .WhileStmt = .{
            .condition = condition,
            .body = try body.toOwnedSlice(),
        } };
    }

    fn parseExpression(self: *Parser) ParseError!ASTNode {
        var left = try self.parseTerm();

        while (self.current_token.type == .GreaterThan or
            self.current_token.type == .LessThan)
        {
            const op = self.current_token.type;
            try self.advance();
            const right = try self.parseTerm();

            const new_left = try self.allocator.create(ASTNode);
            errdefer self.allocator.destroy(new_left);
            const new_right = try self.allocator.create(ASTNode);
            errdefer self.allocator.destroy(new_right);
            new_left.* = left;
            new_right.* = right;

            left = ASTNode{ .BinaryExpr = .{
                .left = new_left,
                .operator = op,
                .right = new_right,
            } };
        }

        return left;
    }

    fn parseTerm(self: *Parser) ParseError!ASTNode {
        var left = try self.parseFactor();

        while (self.current_token.type == .Plus or
            self.current_token.type == .Minus or
            self.current_token.type == .Star or
            self.current_token.type == .Slash)
        {
            const op = self.current_token.type;
            try self.advance();
            const right = try self.parseFactor();

            const new_left = try self.allocator.create(ASTNode);
            errdefer self.allocator.destroy(new_left);
            const new_right = try self.allocator.create(ASTNode);
            errdefer self.allocator.destroy(new_right);
            new_left.* = left;
            new_right.* = right;

            left = ASTNode{ .BinaryExpr = .{
                .left = new_left,
                .operator = op,
                .right = new_right,
            } };
        }

        return left;
    }

    fn parseFactor(self: *Parser) ParseError!ASTNode {
        switch (self.current_token.type) {
            .Integer => {
                const value = try std.fmt.parseInt(i64, self.current_token.lexeme, 10);
                try self.advance();
                return ASTNode{ .Integer = value };
            },
            .Identifier => {
                const identifier = self.current_token.lexeme;
                try self.advance();
                return ASTNode{ .Identifier = identifier };
            },
            .LeftParen => {
                try self.advance();
                const expr = try self.parseExpression();
                if (self.current_token.type != .RightParen) {
                    std.log.info("TOKEN_TYPE: {s}\n", .{@tagName(self.current_token.type)});
                    return ParseError.UnexpectedToken;
                }
                try self.advance();
                return expr;
            },
            else => return ParseError.InvalidExpression,
        }
    }

    fn freeASTNode(self: *Parser, node: *ASTNode) void {
        switch (node.*) {
            .Program => |statements| {
                for (statements) |*stmt| {
                    self.freeASTNode(stmt);
                }
                self.allocator.free(statements);
            },
            .Assignment => |assign| {
                self.freeASTNode(assign.value);
                self.allocator.destroy(assign.value);
            },
            .PrintStmt => |expr| {
                self.freeASTNode(expr);
                self.allocator.destroy(expr);
            },
            .IfStmt => |if_stmt| {
                self.freeASTNode(if_stmt.condition);
                self.allocator.destroy(if_stmt.condition);
                for (if_stmt.body) |*stmt| {
                    self.freeASTNode(stmt);
                }
                self.allocator.free(if_stmt.body);
            },
            .WhileStmt => |while_stmt| {
                self.freeASTNode(while_stmt.condition);
                self.allocator.destroy(while_stmt.condition);
                for (while_stmt.body) |*stmt| {
                    self.freeASTNode(stmt);
                }
                self.allocator.free(while_stmt.body);
            },
            .BinaryExpr => |bin_expr| {
                self.freeASTNode(bin_expr.left);
                self.freeASTNode(bin_expr.right);
                self.allocator.destroy(bin_expr.left);
                self.allocator.destroy(bin_expr.right);
            },
            .Integer, .Identifier => {},
        }
    }
};
