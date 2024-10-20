const std = @import("std");

pub const Location = struct {
    line: usize,
    column: usize,
};

pub const CompilerError = error{
    // Lexer
    Overflow,
    UnexpectedCharacter,
    InvalidCharacter,

    // Parser
    UnexpectedToken,
    ExpectedIdentifier,
    InvalidExpression,

    // Type checking
    UndefinedVariable,

    // General
    OutOfMemory,
    FileNotFound,
};

pub const ErrorContext = struct {
    err: CompilerError,
    message: []const u8,
    loc: Location,
    expected: ?[]const u8,
    got: ?[]const u8,

    pub fn create(
        err: CompilerError,
        loc: Location,
        message: []const u8,
        expected: ?[]const u8,
        got: ?[]const u8,
    ) ErrorContext {
        return .{
            .err = err,
            .loc = loc,
            .message = message,
            .expected = expected,
            .got = got,
        };
    }

    pub fn format(self: ErrorContext, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("Error at line {d}:{d}: error: {s}\n", .{
            self.loc.line,
            self.loc.column,
            self.message,
        });

        if (self.expected != null and self.got != null) {
            try writer.print(" expected: {s}\n got: {s}\n", .{
                self.expected.?,
                self.got.?,
            });
        }
    }
};
