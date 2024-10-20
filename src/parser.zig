const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const LexerError = @import("lexer.zig").LexerError;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const ASTNode = @import("ast.zig").ASTNode;

pub const ParserError = struct {
    message: []const u8,
    line: usize,
    column: usize,
    source_line: []const u8,

    pub fn format(self: ParserError, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("Parser error at line {d}:{d}: {s}\n\n{s}\n", .{
            self.line,
            self.column,
            self.message,
            self.source_line,
        });

        var i: usize = 0;
        while (i < self.column - 1) : (i += 1) {
            try writer.writeByte('~');
        }
        try writer.writeByte('^');
        try writer.writeByte('\n');
    }
};

pub const ParseError = error{ UnexpectedToken, SyntaxError, OutOfMemory } || std.fmt.ParseIntError || LexerError;

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
            else => self.reportError("Unexpected token: expected statement."),
        };
    }

    fn parseAssignment(self: *Parser) ParseError!ASTNode {
        const identifier = self.current_token.lexeme;
        try self.advance();

        if (self.current_token.type != .Equal) {
            return self.reportError("Unexpected token: expected '='.");
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
                    return self.reportError("Unexpected token: expected ')'.");
                }
                try self.advance();
                return expr;
            },
            else => return self.reportError("Unexpected token: expected term."),
        }
    }

    pub fn reportError(self: *Parser, comptime message: []const u8) ParseError {
        const error_msg = ParserError{
            .message = message,
            .line = self.current_token.line,
            .column = self.lexer.column,
            .source_line = self.getCurrentLine(),
        };

        std.log.err("{}", .{error_msg});
        return error.UnexpectedToken;
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
