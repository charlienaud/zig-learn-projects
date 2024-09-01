const std = @import("std");
const Todo = @import("models/todo.zig").Todo;

const print = std.debug.print;
const stdin = std.io.getStdIn().reader();

var buffer: [128]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const fbAllocator = fba.allocator();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpAllocator = gpa.allocator();

pub fn main() !void {
    var todos = std.ArrayList(Todo).init(gpAllocator);

    try todos.append(.{ .title = "aaa" });
    try todos.append(.{ .title = "Lorem" });
    try todos.append(.{ .title = "Loof" });

    while (true) {
        menu();
        print("> ", .{});
        const input = (try stdin.readUntilDelimiterOrEofAlloc(fbAllocator, '\n', 128)).?;
        defer fbAllocator.free(input);

        if (std.mem.eql(u8, input, "exit")) {
            break;
        }

        if (std.mem.eql(u8, input, "add")) {
            try add(&todos);
            continue;
        }

        if (std.mem.eql(u8, input, "list")) {
            list(todos);
            continue;
        }

        if (std.mem.eql(u8, input, "select")) {
            print("Enter the ID\n> ", .{});
            const todoId = (try stdin.readUntilDelimiterOrEofAlloc(fbAllocator, '\n', 128)).?;
            defer fbAllocator.free(todoId);
            const id: u32 = try std.fmt.parseInt(u32, todoId, 10);

            try todoActions(&todos, id);

            continue;
        }

        print("Unknown command\n", .{});
    }

    print("Exiting...\n", .{});
}

fn menu() void {
    print("------------------------------\n", .{});
    print("| Possible commands:\n", .{});
    print("| - exit\n", .{});
    print("| - add\n", .{});
    print("| - list\n", .{});
    print("| - select\n", .{});
    print("------------------------------\n", .{});
}

fn add(todos: *std.ArrayList(Todo)) !void {
    var buf: [30]u8 = undefined;
    print("What is the todo's title?\n> ", .{});
    if (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const title = line;

        if (title.len == 0) {
            return;
        }
        const owned_title = try gpAllocator.dupe(u8, title);
        try todos.append(.{ .title = owned_title });
    }

    print("todos.length: {d}\n", .{todos.items.len});
}

fn list(todos: std.ArrayList(Todo)) void {
    for (todos.items, 0..) |todo, i| {
        const status = if (todo.status == true) "DONE" else "NOT DONE";
        print("- [{d}] {s} | {s}\n", .{ i, todo.title, status });
    }
}

fn todoActions(todos: *std.ArrayList(Todo), selectedIndex: u32) !void {
    const todo = todos.items[selectedIndex];

    const status = if (todo.status == true) "DONE" else "NOT DONE";
    print("- {s} | {s}\n", .{ todo.title, status });

    while (true) {
        print("------------------------------\n", .{});
        print("| What do you xant to do?\n", .{});
        print("| - back\n", .{});
        print("| - do\n", .{});
        print("| - undo\n", .{});
        print("| - edit\n", .{});
        print("| - remove\n", .{});
        print("------------------------------\n", .{});

        print("> ", .{});
        const input = (try stdin.readUntilDelimiterOrEofAlloc(fbAllocator, '\n', 128)).?;
        defer fbAllocator.free(input);

        if (std.mem.eql(u8, input, "back")) {
            break;
        }

        if (std.mem.eql(u8, input, "remove")) {
            try remove(todos, selectedIndex);
            break;
        }

        if (std.mem.eql(u8, input, "do")) {
            try changeStatus(todos, selectedIndex, true);
            break;
        }

        if (std.mem.eql(u8, input, "undo")) {
            try changeStatus(todos, selectedIndex, false);
            break;
        }

        if (std.mem.eql(u8, input, "edit")) {
            print("New title?\n> ", .{});
            const newTitle = (try stdin.readUntilDelimiterOrEofAlloc(fbAllocator, '\n', 128)).?;
            defer fbAllocator.free(newTitle);

            try changeTitle(todos, selectedIndex, try gpAllocator.dupe(u8, newTitle));
            break;
        }

        print("Unknown command\n", .{});
    }
}

fn remove(todos: *std.ArrayList(Todo), index: u32) !void {
    _ = todos.orderedRemove(index);
}

fn changeStatus(todos: *std.ArrayList(Todo), index: u32, status: bool) !void {
    todos.items[index].status = status;
}

fn changeTitle(todos: *std.ArrayList(Todo), index: u32, title: []u8) !void {
    todos.items[index].title = title;
}
