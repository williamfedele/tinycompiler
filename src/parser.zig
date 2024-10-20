const std = @import("std");
const CompilerError = @import("errors.zig").CompilerError;
const ErrorContext = @import("errors.zig").ErrorContext;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const ASTNode = @import("ast.zig").ASTNode;

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    allocator: std.mem.Allocator,

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) CompilerError!Parser {
        var parser = Parser{
            .lexer = lexer,
            .current_token = undefined,
            .allocator = allocator,
        };
        try parser.advance();
        return parser;
    }

    fn advance(self: *Parser) CompilerError!void {
        self.current_token = try self.lexer.nextToken();
    }

    pub fn parse(self: *Parser) CompilerError!ASTNode {
        var statements = std.ArrayList(ASTNode).init(self.allocator);
        defer statements.deinit();

        while (self.current_token.type != .EOF) {
            const stmt = try self.parseStatement();
            try statements.append(stmt);
        }

        return ASTNode{ .Program = try statements.toOwnedSlice() };
    }

    fn parseStatement(self: *Parser) CompilerError!ASTNode {
        return switch (self.current_token.type) {
            .Identifier => self.parseAssignment(),
            .Print => self.parsePrintStatement(),
            .If => self.parseIfStatement(),
            .While => self.parseWhileStatement(),
            else => self.reportError(CompilerError.UnexpectedToken, "Expected statement.", "Statement"),
        };
    }

    fn parseAssignment(self: *Parser) CompilerError!ASTNode {
        const identifier = self.current_token.lexeme;
        try self.advance();

        if (self.current_token.type != .Equal) {
            return self.reportError(CompilerError.UnexpectedToken, "Expected equals.", "Equal ('=')");
        }
        try self.advance();

        const value = try self.allocator.create(ASTNode);
        errdefer self.allocator.destroy(value);
        value.* = try self.parseExpression();

        return ASTNode{ .Assignment = .{ .identifier = identifier, .value = value } };
    }

    fn parsePrintStatement(self: *Parser) CompilerError!ASTNode {
        try self.advance();
        const expr = try self.allocator.create(ASTNode);
        errdefer self.allocator.destroy(expr);
        expr.* = try self.parseExpression();
        return ASTNode{ .PrintStmt = expr };
    }

    fn parseIfStatement(self: *Parser) CompilerError!ASTNode {
        // Consume 'if'
        try self.advance();

        const condition = try self.allocator.create(ASTNode);
        condition.* = try self.parseExpression();

        var then_body = std.ArrayList(ASTNode).init(self.allocator);
        errdefer {
            for (then_body.items) |*node| {
                self.freeASTNode(node);
            }
            then_body.deinit();
        }

        while (self.current_token.type != .Else and self.current_token.type != .End) {
            const stmt = try self.parseStatement();
            try then_body.append(stmt);
        }

        var else_body: ?[]ASTNode = null;
        if (self.current_token.type == .Else) {
            // Consume 'else'
            try self.advance();

            var else_statements = std.ArrayList(ASTNode).init(self.allocator);
            errdefer {
                for (else_statements.items) |*node| {
                    self.freeASTNode(node);
                }
                else_statements.deinit();
            }

            while (self.current_token.type != .End) {
                const stmt = try self.parseStatement();
                try else_statements.append(stmt);
            }
            else_body = try else_statements.toOwnedSlice();
        }

        if (self.current_token.type != .End) {
            return self.reportError(CompilerError.UnexpectedToken, "Expected 'end'", "End");
        }

        // Consume 'end'
        try self.advance();

        return ASTNode{ .IfStmt = .{
            .condition = condition,
            .then_body = try then_body.toOwnedSlice(),
            .else_body = else_body,
        } };
    }

    fn parseWhileStatement(self: *Parser) CompilerError!ASTNode {
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

    fn parseExpression(self: *Parser) CompilerError!ASTNode {
        var left = try self.parseTerm();

        while (self.current_token.type == .GreaterThan or
            self.current_token.type == .LessThan or
            self.current_token.type == .GreaterThanEqual or
            self.current_token.type == .LessThanEqual or
            self.current_token.type == .EqualEqual)
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

    fn parseTerm(self: *Parser) CompilerError!ASTNode {
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

    fn parseFactor(self: *Parser) CompilerError!ASTNode {
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
                    return self.reportError(CompilerError.UnexpectedToken, "Expected right parenthesis.", "RightParen");
                }
                try self.advance();
                return expr;
            },
            else => return self.reportError(CompilerError.UnexpectedToken, "Expected term.", "Term"),
        }
    }

    pub fn reportError(self: *Parser, err: CompilerError, comptime message: []const u8, expected: ?[]const u8) CompilerError {
        const error_ctx = ErrorContext.create(err, .{ .line = self.current_token.line, .column = self.lexer.column }, message, expected, @tagName(self.current_token.type));

        std.log.err("{}", .{error_ctx});
        return err;
    }

    pub fn getCurrentLine(self: *Parser) []const u8 {
        var line_start = self.lexer.current;
        while (line_start > 0 and self.lexer.source[line_start - 1] != '\n') {
            line_start -= 1;
        }
        var line_end = self.lexer.current;
        while (line_end < self.lexer.source.len and self.lexer.source[line_end] != '\n') {
            line_end += 1;
        }
        return self.lexer.source[line_start..line_end];
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

                for (if_stmt.then_body) |*stmt| {
                    self.freeASTNode(stmt);
                }
                self.allocator.free(if_stmt.then_body);

                if (if_stmt.else_body) |else_body| {
                    for (else_body) |*stmt| {
                        self.freeASTNode(stmt);
                    }
                    self.allocator.free(else_body);
                }
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
