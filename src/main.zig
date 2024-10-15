const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var lexer = Lexer.init("x = 10\nif x > 9 print x");

    while (true) {
        const token = lexer.nextToken() catch |err| {
            try stdout.print("Error: {}\n", .{err});
            return;
        };

        if (token.type == .EOF) break;
        try stdout.print("Token: {s}, Type: {s}, Line: {d}\n", .{ token.lexeme, @tagName(token.type), token.line });
    }
}
