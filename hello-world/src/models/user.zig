const std = @import("std");


pub const MAX_POWER = 100_000;

pub const User = struct {
    firstName: []const u8,
    lastName: []const u8,

    // The use of init is merely a convention and in some cases open or some other name might make more sense
    pub fn init(firstName: []const u8, lastName: []const u8) User {
        return .{
            .firstName = firstName,
            .lastName = lastName,
        };
    }

    pub fn isJohn(user: User) void {
        if (std.mem.eql(u8, user.firstName, "John")) { 
            std.debug.print("Oh! it's John !!!\n", .{});
        }
    }
};