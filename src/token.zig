pub const TokenType = enum { Integer, Plus, Minus, Star, Slash, GreaterThan, LessThan, Assign, LeftParen, RightParen, Print, If, While, End, Identifier, EOF };

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: u32,
};
