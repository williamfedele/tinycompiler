const std = @import("std");

pub const TokenType = enum {
    Integer,
    Plus,
    Minus,
    Star,
    Slash,
    GreaterThan,
    LessThan,
    GreaterThanEqual,
    LessThanEqual,
    Equal,
    EqualEqual,
    LeftParen,
    RightParen,
    Print,
    Var,
    Colon,
    Semicolon,
    Type,
    If,
    Else,
    While,
    End,
    Identifier,
    EOF,

    pub fn toString(self: TokenType) []const u8 {
        const tokenStrs = comptime blk: {
            const Type = @This();
            var result: [std.enums.values(Type).len][]const u8 = undefined;
            for (std.enums.values(Type), 0..) |tag, i| {
                result[i] = switch (tag) {
                    .Plus => "+",
                    .Minus => "-",
                    .Star => "*",
                    .Slash => "/",
                    .GreaterThan => ">",
                    .LessThan => "<",
                    .GreaterThanEqual => ">=",
                    .LessThanEqual => "<=",
                    .Equal => "=",
                    .EqualEqual => "==",
                    .LeftParen => "(",
                    .RightParen => ")",
                    else => @tagName(tag),
                };
            }
            break :blk result;
        };
        return tokenStrs[@intFromEnum(self)];
    }
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: u32,
};
