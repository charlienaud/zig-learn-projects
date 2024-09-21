const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});

const allocator = std.heap.page_allocator;

// Window
const WINDOW_DEFAULT_X = 0;
const WINDOW_DEFAULT_Y = 0;
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @as(f32, @floatFromInt(FPS));

// Game area
const GAME_WIDTH = 740;
const GAME_HEIGHT = 450;
const GAME_DEFAULT_X = (WINDOW_WIDTH - GAME_WIDTH) / 2;
const GAME_DEFAULT_Y = (WINDOW_HEIGHT - GAME_HEIGHT);
const WALL_SIZE = GAME_DEFAULT_X;

// Ball
const BALL_SPEED: f32 = 200; // pixel per second
const BALL_SIZE = 15;

// Paddle
const PADDLE_SPEED: f32 = 600; // pixel per second
const PADDLE_WIDTH = 100;
const PADDLE_HEIGHT = 15;

const BRICK_ROWS = 5;
const BRICK_COLS = 10;
const BRICKS_TOTAL = BRICK_ROWS * BRICK_COLS;
const BRICK_WIDTH: f32 = 60;
const BRICK_HEIGHT: f32 = 15;
const BRICK_GAP: f32 = 5;
const BRICK_X_OFFSET: f32 = GAME_DEFAULT_X + (GAME_WIDTH - BRICK_COLS * (BRICK_WIDTH + BRICK_GAP) - BRICK_GAP) / 2;
const BRICK_Y_OFFSET: f32 = GAME_DEFAULT_Y + 25;

// State
var run = true;
var pause = false;
var score: i32 = 0;

var paddle_x_pos: f32 = GAME_DEFAULT_X + GAME_WIDTH / 2 + PADDLE_WIDTH / 2;
const paddle_y_pos: f32 = WINDOW_HEIGHT - PADDLE_HEIGHT - 15;

var ball_x_pos: f32 = GAME_DEFAULT_X + (GAME_WIDTH / 2 + PADDLE_WIDTH / 2) + PADDLE_WIDTH / 2 - BALL_SIZE / 2;
var ball_y_pos: f32 = (WINDOW_HEIGHT - PADDLE_HEIGHT - 25) - 50;
var ball_d_x: f32 = 1;
var ball_d_y: f32 = -1;

const Brick = struct {
    x: f32,
    y: f32,
    life: u32 = 1,
};

const Text = struct {
    string: [*c]const u8,
    size: f32,
    rect: Vec2,
    text_align: TextAlign = TextAlign.left,
    vertical_align: TextVerticalAlign = TextVerticalAlign.top,
    x: f32,
    y: f32,
    fR: f32,
    fG: f32,
    fB: f32,
    fA: f32,
    debug: bool = false,
};

const TextAlign = enum {
    left,
    center,
    right,
};

const TextVerticalAlign = enum {
    top,
    middle,
    bottom,
};

const Vec2 = struct {
    x: f32,
    y: f32,
};

// Generate the bricks pool at compile time
var bricks: [BRICKS_TOTAL]Brick = bricks_pool: {
    var tmp_bricks: [BRICKS_TOTAL]Brick = undefined;
    var i = 0;
    for (0..BRICK_ROWS) |row| {
        for (0..BRICK_COLS) |col| {
            tmp_bricks[i] = .{
                .x = BRICK_X_OFFSET + @as(f32, @floatFromInt(col)) * (BRICK_WIDTH + BRICK_GAP),
                .y = BRICK_Y_OFFSET + @as(f32, @floatFromInt(row)) * (BRICK_HEIGHT + BRICK_GAP),
            };

            i += 1;
        }
    }

    break :bricks_pool tmp_bricks;
};

fn ballCollision(delta: f32) void {
    const nextX = ball_x_pos + ball_d_x * BALL_SPEED * delta;
    const nextY = ball_y_pos + ball_d_y * BALL_SPEED * delta;

    // Paddle collision
    if (c.SDL_HasIntersection(&ballRect(nextX, nextY), &paddleRect(paddle_x_pos, paddle_y_pos)) != 0) {
        ball_d_y *= -1;

        if (nextX < paddle_x_pos or nextX > paddle_x_pos + PADDLE_WIDTH) {
            ball_d_x *= -1;
        }

        return;
    }

    // Window Collision
    if (nextX < GAME_DEFAULT_X or nextX + BALL_SIZE > (GAME_WIDTH + GAME_DEFAULT_X)) {
        ball_d_x *= -1;

        return;
    }

    // Window Collision
    if (nextY < GAME_DEFAULT_Y or nextY + BALL_SIZE > WINDOW_HEIGHT) {
        ball_d_y *= -1;

        return;
    }

    // Bricks collision
    for (&bricks) |*brick| {
        if (brick.life == 0) {
            continue;
        }

        if (c.SDL_HasIntersection(&ballRect(ball_x_pos, ball_y_pos), &brickRect(brick.x, brick.y, BRICK_WIDTH, BRICK_HEIGHT)) != 0) {
            brick.*.life -= 1;
            ball_d_y *= -1;
            score += 1;
        }
    }
    // End bricks collision

    ball_x_pos = nextX;
    ball_y_pos = nextY;
}

pub fn main() !void {
    // @see https://wiki.libsdl.org/SDL2/SDL_Init
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        c.SDL_Log("Failed to init SDL: %s", c.SDL_GetError());
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    // @see https://wiki.libsdl.org/SDL2/SDL_CreateWindow
    const window = c.SDL_CreateWindow("Zig Breakout", WINDOW_DEFAULT_X, WINDOW_DEFAULT_Y, WINDOW_WIDTH, WINDOW_HEIGHT, c.SDL_WINDOW_OPENGL) orelse {
        c.SDL_Log("Failed to create the window: %s", c.SDL_GetError());
        return error.SDLCreateWindowFailed;
    };
    defer c.SDL_DestroyWindow(window);

    // @see https://wiki.libsdl.org/SDL2/SDL_CreateRenderer
    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("Failed to create renderer: %s", c.SDL_GetError());
        return error.SDLCreateRendererFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    if (c.TTF_Init() != 0) {
        c.SDL_Log("Unable to initialize SDL2_ttf: %s", c.TTF_GetError());
        return error.SDLTTFInitFailed;
    }
    defer c.TTF_Quit();

    // Game loop
    while (run) {
        // @see https://wiki.libsdl.org/SDL2/SDL_PollEvent
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) == 1) {
            switch (event.type) {
                c.SDL_QUIT => {
                    run = false;
                },
                c.SDL_KEYDOWN => switch (event.key.keysym.sym) {
                    ' ' => {
                        pause = !pause;
                    },
                    else => {},
                },
                else => {},
            }
        }

        const keyboard = c.SDL_GetKeyboardState(null);

        // PADDLE MOVEMENT
        const is_left_pressed: bool = (keyboard[c.SDL_SCANCODE_LEFT] != 0);
        const is_right_pressed: bool = (keyboard[c.SDL_SCANCODE_RIGHT] != 0);

        if (is_left_pressed) {
            paddle_x_pos -= PADDLE_SPEED * DELTA_TIME_SEC;

            if (paddle_x_pos < GAME_DEFAULT_X) {
                paddle_x_pos = GAME_DEFAULT_X;
            }
        }

        if (is_right_pressed) {
            paddle_x_pos += PADDLE_SPEED * DELTA_TIME_SEC;

            if (paddle_x_pos > GAME_DEFAULT_X + GAME_WIDTH - PADDLE_WIDTH) {
                paddle_x_pos = GAME_DEFAULT_X + GAME_WIDTH - PADDLE_WIDTH;
            }
        }
        // END PADDLE MOVEMENT

        update(DELTA_TIME_SEC);

        _ = c.SDL_SetRenderDrawColor(renderer, 22, 27, 34, 255);
        _ = c.SDL_RenderClear(renderer);

        try render(renderer);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1000 / FPS);
    }
}

fn draw_text(renderer: *c.SDL_Renderer, text: Text) !void {
    var formatted_text = text;

    if (text.debug == true) {
        _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
        _ = c.SDL_RenderFillRect(renderer, &makeRect(formatted_text.x, formatted_text.y, formatted_text.rect.x, formatted_text.rect.y));
    }

    const font_file = @embedFile("fonts/Roboto-Regular.ttf");
    const font_rw = c.SDL_RWFromConstMem(
        @ptrCast(&font_file[0]),
        @intCast(font_file.len),
    ) orelse {
        c.SDL_Log("Unable to get RWFromConstMem: %s", c.SDL_GetError());
        return error.SDLRWFromConstMemFailed;
    };

    const font = c.TTF_OpenFontRW(font_rw, 0, @intFromFloat(formatted_text.size)) orelse {
        c.SDL_Log("Unable to load font: %s", c.TTF_GetError());
        return error.SDLOpenFontRWFailed;
    };
    defer c.TTF_CloseFont(font);

    const font_surface = c.TTF_RenderUTF8_Solid(
        font,
        formatted_text.string,
        c.SDL_Color{
            .r = @intFromFloat(formatted_text.fR),
            .g = @intFromFloat(formatted_text.fG),
            .b = @intFromFloat(formatted_text.fB),
            .a = @intFromFloat(formatted_text.fA),
        },
    ) orelse {
        c.SDL_Log("Unable to render text: %s", c.TTF_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_FreeSurface(font_surface);

    const font_texture = c.SDL_CreateTextureFromSurface(renderer, font_surface) orelse {
        c.SDL_Log("Unable to create texture: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyTexture(font_texture);

    const text_width = @divFloor(font_surface.*.w, 2);
    const text_height = @divFloor(font_surface.*.h, 2);

    if (formatted_text.rect.x == 0 and formatted_text.rect.y == 0) {
        formatted_text.rect.x = @floatFromInt(text_width);
        formatted_text.rect.y = @floatFromInt(text_height);
    }

    if (formatted_text.text_align == TextAlign.center) {
        formatted_text.x += (formatted_text.rect.x - @as(f32, @floatFromInt(text_width))) / 2;
    }

    if (formatted_text.text_align == TextAlign.right) {
        formatted_text.x += (formatted_text.rect.x - @as(f32, @floatFromInt(text_width)));
    }

    if (formatted_text.vertical_align == TextVerticalAlign.middle) {
        formatted_text.y += (formatted_text.rect.y - @as(f32, @floatFromInt(text_height))) / 2;
    }

    if (formatted_text.vertical_align == TextVerticalAlign.bottom) {
        formatted_text.y += (formatted_text.rect.y - @as(f32, @floatFromInt(text_height)));
    }

    const font_rect: c.SDL_Rect = .{
        .w = text_width,
        .h = text_height,
        .x = @intFromFloat(formatted_text.x),
        .y = @intFromFloat(formatted_text.y),
    };

    _ = c.SDL_RenderCopy(renderer, font_texture, null, &font_rect);
}

fn update(delta: f32) void {
    if (pause) {
        return;
    }

    ballCollision(delta);
}

fn render(renderer: *c.SDL_Renderer) !void {
    // Draw the bricks
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255);
    for (bricks) |brick| {
        if (brick.life == 0) {
            continue;
        }

        _ = c.SDL_RenderFillRect(renderer, &brickRect(brick.x, brick.y, BRICK_WIDTH, BRICK_HEIGHT));
    }

    // Draw the walls
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &leftWall());
    _ = c.SDL_RenderFillRect(renderer, &rightWall());
    _ = c.SDL_RenderFillRect(renderer, &topWall());

    // Draw the ball
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &ballRect(ball_x_pos, ball_y_pos));

    // Draw the paddle
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &paddleRect(paddle_x_pos, paddle_y_pos));

    // Draw the score
    const buffer = std.fmt.allocPrint(allocator, "{}", .{score}) catch unreachable;
    var dest = try allocator.alloc(u8, buffer.len);
    try i32ToString(score, &dest);
    try draw_text(renderer, try score_text(dest));

    allocator.free(buffer);
    allocator.free(dest);
}

fn score_text(string: []u8) !Text {
    // const score_label = "Score:";

    // Render text
    return Text{
        .string = string.ptr,
        .size = 50,
        .text_align = TextAlign.center,
        .vertical_align = TextVerticalAlign.middle,
        .x = WINDOW_WIDTH - 200,
        .y = GAME_DEFAULT_Y - WALL_SIZE - 30,
        .rect = Vec2{ .x = 200, .y = 30 },
        .fR = 255,
        .fG = 255,
        .fB = 255,
        .fA = 255,
        .debug = true,
    };
}

fn ballRect(x: f32, y: f32) c.SDL_Rect {
    return makeRect(x, y, BALL_SIZE, BALL_SIZE);
}

fn paddleRect(x: f32, y: f32) c.SDL_Rect {
    return makeRect(x, y, PADDLE_WIDTH, PADDLE_HEIGHT);
}

fn brickRect(x: f32, y: f32, w: f32, h: f32) c.SDL_Rect {
    return makeRect(x, y, w, h);
}

fn leftWall() c.SDL_Rect {
    return makeRect(0, GAME_DEFAULT_Y, WALL_SIZE, GAME_HEIGHT);
}

fn topWall() c.SDL_Rect {
    return makeRect(0, GAME_DEFAULT_Y - WALL_SIZE, WINDOW_WIDTH, WALL_SIZE);
}

fn rightWall() c.SDL_Rect {
    return makeRect(WINDOW_WIDTH - WALL_SIZE, GAME_DEFAULT_Y, WALL_SIZE, GAME_HEIGHT);
}

fn makeRect(x: f32, y: f32, w: f32, h: f32) c.SDL_Rect {
    return c.SDL_Rect{
        .x = @intFromFloat(x),
        .y = @intFromFloat(y),
        .w = @intFromFloat(w),
        .h = @intFromFloat(h),
    };
}

fn i32ToString(value: i32, dest: *[]u8) !void {
    var buffer: [11]u8 = undefined; // 10 for the digits and 1 for the sign
    const slice = try std.fmt.bufPrint(&buffer, "{}", .{value});

    std.mem.copyBackwards(u8, dest.*, buffer[0..slice.len]); // Copy the contents to the new slice
}
