const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const Parser = @import("parser.zig").Parser;
const ASTNode = @import("parser.zig").ASTNode;
const SymbolTable = @import("symtab.zig").SymbolTable;
const CodeGen = @import("codegen.zig").CodeGen;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // TODO: take this as argument
    const fileName = "test.tc";

    const file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const source = try allocator.alloc(u8, file_size);
    defer allocator.free(source);

    const bytes_read = try file.readAll(source);
    if (bytes_read != file_size) {
        return error.IncompleteRead;
    }

    var lexer = Lexer.init(source);
    var parser = try Parser.init(&lexer, allocator);
    const ast = parser.parse() catch {
        std.debug.print("Compilation failed while parsing. Aborting.\n", .{});
        return;
    };

    var symbol_table = try SymbolTable.init(allocator);
    defer symbol_table.deinit();

    symbol_table.build(&ast) catch {
        std.debug.print("Semantic errors founds. Aborting.\n", .{});
        return;
    };

    // TODO: give this the same name as the input file
    const outfile = try std.fs.cwd().createFile("test.py", .{});
    var codegen = CodeGen.init(outfile);
    codegen.generate(&ast) catch |err| {
        std.debug.print("Error generating code: {}\n", .{err});
        return;
    };
}

pub fn printAST(node: ASTNode, indent: usize) void {
    const stdout = std.io.getStdOut().writer();

    for (0..indent) |_| {
        stdout.print(" ", .{}) catch unreachable;
    }

    switch (node) {
        .Program => |statements| {
            stdout.print("Program\n", .{}) catch unreachable;
            for (statements) |stmt| {
                printAST(stmt, indent + 1);
            }
        },
        .Assignment => |assign| {
            stdout.print("Assignment: {s} =\n", .{assign.identifier}) catch unreachable;
            printAST(assign.value.*, indent + 1);
        },
        .PrintStmt => |expr| {
            stdout.print("Print:\n", .{}) catch unreachable;
            printAST(expr.*, indent + 1);
        },
        .IfStmt => |if_stmt| {
            stdout.print("If:\n", .{}) catch unreachable;
            stdout.print("  Condition:\n", .{}) catch unreachable;
            printAST(if_stmt.condition.*, indent + 2);
            stdout.print("  Body:\n", .{}) catch unreachable;
            for (if_stmt.then_body) |stmt| {
                printAST(stmt, indent + 2);
            }
        },
        .WhileStmt => |while_stmt| {
            stdout.print("While:\n", .{}) catch unreachable;
            stdout.print(" Condition:\n", .{}) catch unreachable;
            printAST(while_stmt.condition.*, indent + 2);
            stdout.print(" Body:\n", .{}) catch unreachable;
            for (while_stmt.body) |stmt| {
                printAST(stmt, indent + 2);
            }
        },
        .BinaryExpr => |bin_expr| {
            stdout.print("BinaryExpr: {s}\n", .{@tagName(bin_expr.operator)}) catch unreachable;
            printAST(bin_expr.left.*, indent + 1);
            printAST(bin_expr.right.*, indent + 1);
        },
        .Integer => |value| {
            stdout.print("Integer: {d}\n", .{value}) catch unreachable;
        },
        .Identifier => |name| {
            stdout.print("Identifier: {s}\n", .{name}) catch unreachable;
        },
    }
}
