const std = @import("std");
const Allocator = std.mem.Allocator;
const ASTNode = @import("ast.zig").ASTNode;

const SymbolType = enum {
    Variable,
};

const Symbol = struct {
    identifier: []const u8,
    symbol_type: SymbolType,
};

const Scope = struct {
    symbols: std.StringHashMap(Symbol),
    parent: ?*Scope,

    pub fn init(allocator: Allocator, parent: ?*Scope) Scope {
        return .{
            .symbols = std.StringHashMap(Symbol).init(allocator),
            .parent = parent,
        };
    }

    pub fn deinit(self: *Scope) void {
        self.symbols.deinit();
    }
};

pub const SymbolTable = struct {
    allocator: Allocator,
    current_scope: *Scope,

    pub fn init(allocator: Allocator) !SymbolTable {
        const global_scope = try allocator.create(Scope);
        global_scope.* = Scope.init(allocator, null);
        return .{
            .allocator = allocator,
            .current_scope = global_scope,
        };
    }

    pub fn deinit(self: *SymbolTable) void {
        var current: ?*Scope = self.current_scope;
        while (current) |scope| {
            const parent = scope.parent;
            scope.deinit();
            self.allocator.destroy(scope);
            current = parent;
        }
    }

    pub fn enterScope(self: *SymbolTable) !void {
        const new_scope = try self.allocator.create(Scope);
        new_scope.* = Scope.init(self.allocator, self.current_scope);
        self.current_scope = new_scope;
    }

    pub fn exitScope(self: *SymbolTable) void {
        if (self.current_scope.parent) |parent| {
            const old_scope = self.current_scope;
            self.current_scope = parent;
            old_scope.deinit();
            self.allocator.destroy(old_scope);
        }
    }

    pub fn addSymbol(self: *SymbolTable, identifier: []const u8, symbol_type: SymbolType) !void {
        if (self.current_scope.symbols.contains(identifier)) {
            std.log.err("Identifier already exists", .{});
            return;
        }
        try self.current_scope.symbols.put(identifier, .{
            .identifier = identifier,
            .symbol_type = symbol_type,
        });
    }

    // Search for a symbol in valid scopes.
    pub fn lookupSymbol(self: *SymbolTable, identifier: []const u8) ?Symbol {
        var current = self.current_scope;
        while (current) |scope| {
            if (scope.symbols.get(identifier)) |symbol| {
                return symbol;
            }
            current = scope.parent;
        }
    }

    // TODO: make sure variable usage in RHS of statements are valid (declared, in scope)
    pub fn build(self: *SymbolTable, node: *const ASTNode) !void {
        switch (node.*) {
            .Program => |statements| {
                for (statements) |*stmt| {
                    try self.build(stmt);
                }
            },
            .VarDecl => {
                // TODO
            },
            .Assignment => {},
            .PrintStmt => {},
            .IfStmt => |if_stmt| {
                try self.enterScope();

                for (if_stmt.then_body) |*stmt| {
                    try self.build(stmt);
                }

                self.exitScope();

                if (if_stmt.else_body) |else_body| {
                    try self.enterScope();
                    defer self.exitScope();

                    for (else_body) |*stmt| {
                        try self.build(stmt);
                    }
                }
            },
            .WhileStmt => |while_stmt| {
                try self.enterScope();
                defer self.exitScope();

                for (while_stmt.body) |*stmt| {
                    try self.build(stmt);
                }
            },
            .BinaryExpr => {},
            .Integer => {},
            .Identifier => {},
        }
    }
};
