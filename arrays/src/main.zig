const std = @import("std");
const Allocator = std.mem.Allocator;

pub const User = struct {
    name: []const u8,

    pub fn deinit(self: User, allocator: Allocator) void {
		allocator.free(self.name);
	}
};

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
	const stdout = std.io.getStdOut().writer();

    // const array = [_]i32{1, 2, 3, 4, 5, 6};
    // const array: [6]u8 = .{1, 2, 3, 4, 5, 6};
    const array: [6]u8 = undefined;
    std.log.info("{d}", .{array});

    const name = "Azertyu";
    std.log.info("{d}", .{name.len});
    for (name) |ch| {
        std.debug.print("{c}", .{ch});
    }
    std.debug.print("\n", .{});

    var numbers: [10]u8 = undefined;
    for (&numbers, 0..) |*number, i| {
        number.* = @intCast(i);
    }

    std.log.info("Numbers: {d}", .{numbers});

    const numbers1 = [_]u8{1, 2, 3, 4, 5, 6};
    const numbers2 = [_]u8{7, 8, 9, 10, 11, 12};
    const numbers1And2 = numbers1 ++ numbers2;
    std.log.info("Numbers: {d} (len: {d})", .{numbers1And2, numbers1And2.len});

    const firstName = "John";
    const lastName = "Doe";
    const fullName = firstName ++ " " ++ lastName;
    std.log.info("Full name: {s}", .{fullName});

    const repeated3Timaes = firstName ** 3;
    std.log.info("Repeated 3 times: {s}", .{repeated3Timaes});
    const numbers3: [10]u8 = .{3} ** 10;
    std.log.info("Numbers: {d} (len: {d})", .{numbers3, numbers3.len});

    // All is computed at compile time
    const numbers4: [10]u8 = blk: {
        var tmpNumbers: [10]u8 = undefined;
        for (&tmpNumbers, 0..) |*number, i| {
            number.* = @intCast(i * i);
        }

        break :blk tmpNumbers;
    };
    std.log.info("Numbers: {d} (len: {d})", .{numbers4, numbers4.len});

    // ArrayList
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();
    var arr = std.ArrayList(User).init(allocator);
	defer {
		for (arr.items) |user| {
			user.deinit(allocator);
		}
		arr.deinit();
	}

    	var i: i32 = 0;
	while (true) : (i += 1) {
		var buf: [30]u8 = undefined;
		try stdout.print("Please enter a name: ", .{});
		if (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
			const newName = line;

			if (newName.len == 0) {
				break;
			}
			const owned_name = try allocator.dupe(u8, newName);
			try arr.append(.{.name = owned_name});
		}

        try stdout.print("arr.length: {d}\n", .{arr.items.len});

        for (arr.items, 0..) |user, index| {
            try stdout.print("- [{d}] {s}\n", .{index, user.name});
        }
	}

}
