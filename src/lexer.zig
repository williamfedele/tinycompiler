const ErrorContext = @import("errors.zig").ErrorContext;
const CompilerError = @import("errors.zig").CompilerError;
const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

const std = @import("std");

pub const Lexer = struct {
    source: []const u8,
    start: usize,
    current: usize,
    line: u32,
    column: u32,

    pub fn init(source: []const u8) Lexer {
        return Lexer{
            .source = source,
            .start = 0,
            .current = 0,
            .line = 1,
            .column = 0,
        };
    }

    pub fn nextToken(self: *Lexer) CompilerError!Token {
        self.skipWhitespace();
        self.start = self.current;

        if (self.isAtEnd()) {
            return Token{
                .type = .EOF,
                .lexeme = "",
                .line = self.line,
            };
        }

        const c = self.advance();
        return switch (c) {
            ':' => self.makeToken(.Colon),
            ';' => self.makeToken(.Semicolon),
            '+' => self.makeToken(.Plus),
            '-' => self.makeToken(.Minus),
            '*' => self.makeToken(.Star),
            '/' => self.makeToken(.Slash),
            '=' => if (self.peekNextChar('=')) self.makeToken(.EqualEqual) else self.makeToken(.Equal),
            '>' => if (self.peekNextChar('=')) self.makeToken(.GreaterThanEqual) else self.makeToken(.GreaterThan),
            '<' => if (self.peekNextChar('=')) self.makeToken(.LessThanEqual) else self.makeToken(.LessThan),
            '(' => self.makeToken(.LeftParen),
            ')' => self.makeToken(.RightParen),
            '0'...'9' => self.number(),
            'a'...'z', 'A'...'Z', '_' => self.identifier(),
            else => return self.reportError(CompilerError.UnexpectedCharacter, "Unexpected character found.", null),
        };
    }

    // Look ahead at the next char in the source file.
    // If it matches the expected char, advance.
    fn peekNextChar(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;
        if (self.source[self.current] != expected) return false;
        self.current += 1;
        self.column += 1;
        return true;
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        self.current += 1;
        self.column += 1;
        return self.source[self.current - 1];
    }

    fn makeToken(self: *Lexer, token_type: TokenType) Token {
        return Token{
            .type = token_type,
            .lexeme = self.source[self.start..self.current],
            .line = self.line,
        };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.source[self.current];
            switch (c) {
                ' ', '\r', '\t' => {
                    self.current += 1;
                    self.column += 1;
                },
                '\n' => {
                    self.line += 1;
                    self.current += 1;
                    self.column = 0;
                },
                else => return,
            }
        }
    }

    fn number(self: *Lexer) Token {
        while (!self.isAtEnd() and std.ascii.isDigit(self.source[self.current])) {
            self.current += 1;
            self.column += 1;
        }
        return self.makeToken(.Integer);
    }

    fn identifier(self: *Lexer) Token {
        while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.source[self.current]) or self.source[self.current] == '_')) {
            self.current += 1;
            self.column += 1;
        }
        const lexeme = self.source[self.start..self.current];

        // Extend with more types
        if (std.mem.eql(u8, lexeme, "int")) {
            return self.makeToken(.Type);
        }

        // TODO: organize this

        const token_type = if (std.mem.eql(u8, lexeme, "print"))
            TokenType.Print
        else if (std.mem.eql(u8, lexeme, "if"))
            TokenType.If
        else if (std.mem.eql(u8, lexeme, "else"))
            TokenType.Else
        else if (std.mem.eql(u8, lexeme, "while"))
            TokenType.While
        else if (std.mem.eql(u8, lexeme, "end"))
            TokenType.End
        else if (std.mem.eql(u8, lexeme, "var"))
            TokenType.Var
        else
            TokenType.Identifier;
        return self.makeToken(token_type);
    }

    pub fn reportError(self: *Lexer, err: CompilerError, comptime message: []const u8, expected: ?[]const u8) CompilerError {
        const error_ctx = ErrorContext.create(err, .{ .line = self.line, .column = self.column }, message, expected, self.source[self.start..self.current]);

        std.log.err("{}", .{error_ctx});
        return err;
    }
};
