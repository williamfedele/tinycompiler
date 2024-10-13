pub const TokenType = enum {
    Integer,
    Plus,
    Minus,
    Star,
    Slash,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: u32,
};
