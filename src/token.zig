pub const TokenType = enum { Integer, Plus, Minus, Star, Slash, GreaterThan, LessThan, Assign, Print, If, While, Ident, EOF };

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: u32,
};
