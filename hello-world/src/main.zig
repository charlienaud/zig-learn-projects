const std = @import("std");
const user = @import("models/user.zig");
const User = user.User;
const MAX_POWER = user.MAX_POWER;

pub fn main() void {
    // const user1: User = .{
    //     .firstName = "John",
    //     .lastName = "Doe",
    // };

    const user1 = User.init("John", "Doe");

    std.debug.print("Hello {s} {s}!\n", .{user1.firstName, user1.lastName});
    user1.isJohn(); // Same as User.isJohn(user1)

    const sum = add(12, 4);
    std.debug.print("12 + 4 = {d}\n", .{sum});

    // Arrays and slices
    // const a = [3]i32{1, 2, 3};
    // const b: [3]i32 = .{1, 2, 3};
    // use _ to let the compiler infer the length
    // const c = [_]i32{1, 2, 3};

    // const d = a[1..2];
}

fn add(a: i64, b: i64) i64 {
    return a + b;
}