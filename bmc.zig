const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;
const fmt = std.fmt;
const io = std.io;
const fs = std.fs;
const heap = std.heap;

const CompilerError = error{
    WordNotFound,
    IntegerNotFound,
    ToNotFound,
    FromNotFound,
    ThenNotFound,
    DoNotFound,
    QuoteNotFound,
    SingleQuoteNotFound,
    UnknownCommand,
    UnknownVariable,
    UnknownConditionType,
    OverflowingIntegerLiteral,
    OverflowingAddress,
    OverflowingCharacter,
    UnexpectedEOF,
    UnexpectedEnd,
    UnexpectedLoop,
    UnclosedBlock,
};

const Compiler = struct {
    const Self = @This();

    source: []const u8,
    index: usize,
    line: usize,
    data: [1999]usize,
    var_ptr: usize,
    labels: [100]usize,
    label_addr: usize,
    labels_len: usize,
    whiles: [100]usize,
    while_addr: usize,
    whiles_len: usize,

    fn init(source: []const u8) Self {
        return Self{
            .source = source,
            .index = 0,
            .line = 1,
            .data = [_]usize{0} ** 1999,
            .var_ptr = 1,
            .labels = [_]usize{0} ** 100,
            .label_addr = 1,
            .labels_len = 0,
            .whiles = [_]usize{0} ** 100,
            .while_addr = 1,
            .whiles_len = 0,
        };
    }

    fn compile(self: *Self) CompilerError!void {
        while (self.getChar(self.index) != 0) {
            const cmd = try self.getWord();

            if (mem.eql(u8, cmd, "set")) {
                try self.setCmd();
            } else if (mem.eql(u8, cmd, "add")) {
                try self.addCmd();
            } else if (mem.eql(u8, cmd, "sub")) {
                try self.subCmd();
            } else if (mem.eql(u8, cmd, "asm")) {
                Self.emit("{s}", .{try self.getString()});
            } else if (mem.eql(u8, cmd, "if")) {
                try self.ifCmd();
            } else if (mem.eql(u8, cmd, "else")) {
                try self.elseCmd();
            } else if (mem.eql(u8, cmd, "end")) {
                try self.endCmd();
            } else if (mem.eql(u8, cmd, "while")) {
                try self.whileCmd();
            } else if (mem.eql(u8, cmd, "loop")) {
                try self.loopCmd();
            } else if (mem.eql(u8, cmd, "halt")) {
                Self.emit("\tHLT", .{});
            } else if (mem.eql(u8, cmd, "input")) {
                try self.inputCmd();
            } else if (mem.eql(u8, cmd, "outn")) {
                try self.outnCmd();
            } else if (mem.eql(u8, cmd, "outc")) {
                try self.outcCmd();
            } else {
                return CompilerError.UnknownCommand;
            }

            self.skipWhitespace();
        }

        if (self.labels_len != 0) {
            return CompilerError.UnclosedBlock;
        }

        Self.emit("\tHLT", .{});

        for (self.data) |v, i| {
            if (v != 0) {
                const value = @intCast(isize, i) - 999;
                Self.emit("v{}\tDAT\t{}", .{ v, value });
            }
        }
    }

    fn setCmd(self: *Self) CompilerError!void {
        const variable = try self.getAddr();
        const to = try self.getWord();

        if (!mem.eql(u8, to, "to")) {
            return CompilerError.ToNotFound;
        }

        if (self.getInteger()) |int| {
            var vaddr = self.data[@intCast(usize, int + 999)];
            if (vaddr == 0) {
                self.data[@intCast(usize, int + 999)] = self.var_ptr;
                vaddr = self.var_ptr;
                self.var_ptr += 1;
            }

            Self.emit("\tLDA\tv{}", .{vaddr});
            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 300});
        } else |e| {
            if (e == CompilerError.SingleQuoteNotFound) {
                return e;
            }

            const src_var = try self.getAddr();

            Self.emit("\tDAT\t{}", .{@as(u16, src_var) + 500});
            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 300});
        }
    }

    fn addCmd(self: *Self) CompilerError!void {
        if (self.getInteger()) |int| {
            var vaddr = self.data[@intCast(usize, int + 999)];
            if (vaddr == 0) {
                self.data[@intCast(usize, int + 999)] = self.var_ptr;
                vaddr = self.var_ptr;
                self.var_ptr += 1;
            }

            const to = try self.getWord();
            const variable = try self.getAddr();

            if (!mem.eql(u8, to, "to")) {
                return CompilerError.ToNotFound;
            }

            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 500});
            Self.emit("\tADD\tv{}", .{vaddr});
            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 300});
        } else |_| {
            const src_var = try self.getAddr();
            const to = try self.getWord();
            const variable = try self.getAddr();

            if (!mem.eql(u8, to, "to")) {
                return CompilerError.ToNotFound;
            }

            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 500});
            Self.emit("\tDAT\t{}", .{src_var + 100});
            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 300});
        }
    }

    fn subCmd(self: *Self) CompilerError!void {
        if (self.getInteger()) |int| {
            var vaddr = self.data[@intCast(usize, int + 999)];
            if (vaddr == 0) {
                self.data[@intCast(usize, int + 999)] = self.var_ptr;
                vaddr = self.var_ptr;
                self.var_ptr += 1;
            }

            const from = try self.getWord();
            const variable = try self.getAddr();

            if (!mem.eql(u8, from, "from")) {
                return CompilerError.FromNotFound;
            }

            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 500});
            Self.emit("\tSUB\tv{}", .{vaddr});
            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 300});
        } else |_| {
            const src_var = try self.getAddr();
            const from = try self.getWord();
            const variable = try self.getAddr();

            if (!mem.eql(u8, from, "from")) {
                return CompilerError.FromNotFound;
            }

            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 500});
            Self.emit("\tDAT\t{}", .{src_var + 200});
            Self.emit("\tDAT\t{}", .{@as(u16, variable) + 300});
        }
    }

    fn ifCmd(self: *Self) CompilerError!void {
        const ctype = try self.getWord();

        if (!mem.eql(u8, ctype, "true") and !mem.eql(u8, ctype, "negative")) {
            return CompilerError.UnknownConditionType;
        }

        const condition = try self.getAddr();
        const then = try self.getWord();

        if (!mem.eql(u8, then, "then")) {
            return CompilerError.ThenNotFound;
        }

        self.labels[self.labels_len] = self.label_addr;

        Self.emit("\tDAT\t{}", .{@as(u16, condition) + 500});
        if (mem.eql(u8, ctype, "true")) {
            Self.emit("\tBRZ\tl{}", .{self.label_addr});
        } else if (mem.eql(u8, ctype, "negative")) {
            Self.emit("\tBRP\tl{}", .{self.label_addr});
        }

        self.labels_len += 1;
        self.label_addr += 1;
    }

    fn elseCmd(self: *Self) CompilerError!void {
        const ifLabel = self.labels[self.labels_len - 1];
        self.labels[self.labels_len - 1] = self.label_addr;

        Self.emit("\tBRA\tl{}", .{self.label_addr});
        Self.emit("l{}\tLDA\t0", .{ifLabel});

        self.label_addr += 1;
    }

    fn endCmd(self: *Self) CompilerError!void {
        if (self.labels_len < 1) {
            return CompilerError.UnexpectedEnd;
        }

        self.labels_len -= 1;
        Self.emit("l{}\tLDA\t0", .{self.labels[self.labels_len]});
    }

    fn whileCmd(self: *Self) CompilerError!void {
        const ctype = try self.getWord();

        if (!mem.eql(u8, ctype, "true") and !mem.eql(u8, ctype, "negative")) {
            return CompilerError.UnknownConditionType;
        }

        const condition = try self.getAddr();
        const do = try self.getWord();

        if (!mem.eql(u8, do, "do")) {
            return CompilerError.DoNotFound;
        }

        self.whiles[self.whiles_len] = self.while_addr;

        Self.emit("p{}\tDAT\t{}", .{ self.while_addr, @as(u16, condition) + 500 });
        if (mem.eql(u8, ctype, "true")) {
            Self.emit("\tBRZ\te{}", .{self.while_addr});
        } else if (mem.eql(u8, ctype, "negative")) {
            Self.emit("\tBRP\te{}", .{self.while_addr});
        }

        self.whiles_len += 1;
        self.while_addr += 1;
    }

    fn loopCmd(self: *Self) CompilerError!void {
        if (self.whiles_len < 1) {
            return CompilerError.UnexpectedLoop;
        }

        self.whiles_len -= 1;

        Self.emit("\tBRA\tp{}", .{self.whiles[self.whiles_len]});
        Self.emit("e{}\tLDA\t0", .{self.whiles[self.whiles_len]});
    }

    fn inputCmd(self: *Self) CompilerError!void {
        const to = try self.getWord();
        const variable = try self.getAddr();

        if (!mem.eql(u8, to, "to")) {
            return CompilerError.ToNotFound;
        }

        Self.emit("\tINP", .{});
        Self.emit("\tDAT\t{}", .{@as(u16, variable) + 300});
    }

    fn outnCmd(self: *Self) CompilerError!void {
        const from = try self.getWord();
        const variable = try self.getAddr();

        if (!mem.eql(u8, from, "from")) {
            return CompilerError.FromNotFound;
        }

        Self.emit("\tDAT\t{}", .{@as(u16, variable) + 500});
        Self.emit("\tOUT\t", .{});
    }

    fn outcCmd(self: *Self) CompilerError!void {
        const from = try self.getWord();
        const variable = try self.getAddr();

        if (!mem.eql(u8, from, "from")) {
            return CompilerError.FromNotFound;
        }

        Self.emit("\tDAT\t{}", .{@as(u16, variable) + 500});
        Self.emit("\tOTC\t", .{});
    }

    fn getAddr(self: *Self) CompilerError!u8 {
        if (self.getInteger()) |addr| {
            if (addr < 0 or addr > 99) {
                return CompilerError.OverflowingAddress;
            }

            return @intCast(u8, addr);
        } else |_| {
            const var_name = try self.getWord();

            if (var_name.len > 1) {
                return CompilerError.UnknownVariable;
            }

            switch (var_name[0]) {
                'a'...'z' => return @intCast(u8, 99 - @as(i16, var_name[0]) + @as(i16, 'a')),
                else => return CompilerError.UnknownVariable,
            }
        }
    }

    fn getString(self: *Self) CompilerError![]const u8 {
        self.skipWhitespace();

        if (self.getChar(self.index) != '"') {
            return CompilerError.QuoteNotFound;
        }

        self.index += 1;

        var end_index = self.index;
        var c = self.getChar(end_index);

        while (c != '"') {
            end_index += 1;
            c = self.getChar(end_index);

            if (c == 0) {
                return CompilerError.UnexpectedEOF;
            }
        }

        defer self.index = end_index + 1;
        return self.source[self.index..end_index];
    }

    fn getWord(self: *Self) CompilerError![]const u8 {
        self.skipWhitespace();

        var end_index = self.index;

        while (ascii.isAlpha(self.getChar(end_index))) {
            end_index += 1;
        }

        if (end_index == self.index) {
            return CompilerError.WordNotFound;
        }

        defer self.index = end_index;
        return self.source[self.index..end_index];
    }

    fn getInteger(self: *Self) CompilerError!i16 {
        self.skipWhitespace();

        var sign: i16 = 1;
        var value: i16 = 0;

        if (self.getChar(self.index) == '\'') {
            self.index += 1;
            const c = self.getChar(self.index);
            self.index += 1;
            if (self.getChar(self.index) != '\'') {
                return CompilerError.SingleQuoteNotFound;
            }
            self.index += 1;

            if (c < 100) {
                return @as(i16, c);
            } else {
                return CompilerError.OverflowingCharacter;
            }
        }

        if (self.getChar(self.index) == '-') {
            self.index += 1;
            sign = -1;
        }

        if (!ascii.isDigit(self.getChar(self.index))) {
            return CompilerError.IntegerNotFound;
        }

        while (ascii.isDigit(self.getChar(self.index))) {
            value *= 10;
            value += @as(i16, self.getChar(self.index) - '0');
            self.index += 1;

            if (value > 999) {
                return CompilerError.OverflowingIntegerLiteral;
            }
        }

        return value * sign;
    }

    fn skipWhitespace(self: *Self) void {
        while (ascii.isSpace(self.getChar(self.index))) {
            if (self.getChar(self.index) == '\n') {
                self.line += 1;
            }

            self.index += 1;
        }
    }

    fn getChar(self: *Self, index: usize) u8 {
        if (index < self.source.len) {
            return self.source[index];
        }

        return 0;
    }

    fn emit(comptime frmt: []const u8, args: anytype) void {
        const writer = io.getStdOut().writer();
        fmt.format(writer, frmt, args) catch unreachable;
        _ = writer.write("\n") catch unreachable;
    }
};

pub fn main() anyerror!void {
    var file = try fs.cwd().openFile("main.bmc", .{});
    var source = try file.readToEndAlloc(heap.page_allocator, 0x10000);
    var compiler = Compiler.init(source);

    try compiler.compile();
}
