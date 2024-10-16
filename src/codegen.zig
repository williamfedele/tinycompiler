const std = @import("std");
const ASTNode = @import("parser.zig").ASTNode; // TODO: should probably extract this type

pub const CodeGen = struct {
    // TODO: pre-codegen phase to create a symbol table for semantic error handling
    // symbol_table: SymbolTable
    buf_writer: std.io.BufferedWriter(4096, std.fs.File.Writer),

    pub fn init(file: std.fs.File) CodeGen {
        return .{
            .buf_writer = std.io.bufferedWriter(file.writer()),
        };
    }

    pub fn generate(self: *CodeGen, node: *const ASTNode) !void {
        try self.traverse(node, 0);
        try self.buf_writer.flush();
    }

    pub fn traverse(self: *CodeGen, node: *const ASTNode, indentLevel: usize) !void {
        switch (node.*) {
            .Program => |statements| {
                for (statements) |*stmt| {
                    try self.traverse(stmt, indentLevel);
                }
            },
            .Assignment => |assign| {
                const writer = self.buf_writer.writer();
                for (0..indentLevel) |_| {
                    try writer.writeAll("\t");
                }
                try writer.print("{s} = ", .{assign.identifier});
                try self.traverse(assign.value, indentLevel);
                try writer.writeAll("\n");
            },
            .PrintStmt => |expr| {
                const writer = self.buf_writer.writer();
                for (0..indentLevel) |_| {
                    try writer.writeAll("\t");
                }
                try writer.writeAll("print(");
                try self.traverse(expr, indentLevel);
                try writer.writeAll(")\n");
            },
            .IfStmt => |if_stmt| {
                const writer = self.buf_writer.writer();
                for (0..indentLevel) |_| {
                    try writer.writeAll("\t");
                }
                try writer.writeAll("if ");
                try self.traverse(if_stmt.condition, indentLevel);
                try writer.writeAll(":\n");
                for (if_stmt.body) |*stmt| {
                    try self.traverse(stmt, indentLevel + 1);
                }
            },
            .WhileStmt => |while_stmt| {
                const writer = self.buf_writer.writer();
                for (0..indentLevel) |_| {
                    try writer.writeAll("\t");
                }
                try writer.writeAll("while ");
                try self.traverse(while_stmt.condition, indentLevel);
                try writer.writeAll(":\n");
                for (while_stmt.body) |*stmt| {
                    try self.traverse(stmt, indentLevel + 1);
                }
            },
            .BinaryExpr => |bin_expr| {
                const writer = self.buf_writer.writer();
                try self.traverse(bin_expr.left, indentLevel);
                switch (bin_expr.operator) {
                    .GreaterThan => try writer.writeAll(" > "),
                    .LessThan => try writer.writeAll(" < "),
                    .Plus => try writer.writeAll(" + "),
                    .Minus => try writer.writeAll(" - "),
                    else => return,
                }
                try self.traverse(bin_expr.right, indentLevel);
            },
            .Integer => |data| {
                const writer = self.buf_writer.writer();
                try writer.print("{d}", .{data});
            },
            .Identifier => |data| {
                const writer = self.buf_writer.writer();
                try writer.writeAll(data);
            },
        }
    }
};
