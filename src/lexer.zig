const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;

const std = @import("std");

pub const Lexer = struct {
    source: []const u8,
    start: usize,
    current: usize,
    line: u32,

    pub fn init(source: []const u8) Lexer {
        return Lexer{
            .source = source,
            .start = 0,
            .current = 0,
            .line = 1,
        };
    }

    pub fn nextToken(self: *Lexer) !Token {
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
            '+' => self.makeToken(.Plus),
            '-' => self.makeToken(.Minus),
            '*' => self.makeToken(.Star),
            '/' => self.makeToken(.Slash),
            '=' => self.makeToken(.Assign),
            '>' => self.makeToken(.GreaterThan),
            '<' => self.makeToken(.LessThan),
            '0'...'9' => self.number(),
            'a'...'z', 'A'...'Z', '_' => self.identifier(),
            else => error.UnexpectedCharacter,
        };
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        self.current += 1;
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
                ' ', '\r', '\t' => self.current += 1,
                '\n' => {
                    self.line += 1;
                    self.current += 1;
                },
                else => return,
            }
        }
    }

    fn number(self: *Lexer) Token {
        while (!self.isAtEnd() and std.ascii.isDigit(self.source[self.current])) {
            self.current += 1;
        }
        return self.makeToken(.Integer);
    }

    fn identifier(self: *Lexer) Token {
        while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.source[self.current]) or self.source[self.current] == '_')) {
            self.current += 1;
        }
        const lexeme = self.source[self.start..self.current];
        const token_type = if (std.mem.eql(u8, lexeme, "print"))
            TokenType.Print
        else if (std.mem.eql(u8, lexeme, "if"))
            TokenType.If
        else if (std.mem.eql(u8, lexeme, "while"))
            TokenType.While
        else
            TokenType.Ident;
        return self.makeToken(token_type);
    }
};
