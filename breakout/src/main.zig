const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

// Game
const WINDOW_DEFAULT_X = 0;
const WINDOW_DEFAULT_Y = 0;
const WINDOW_WIDTH = 800;
const WINDOW_HEIGHT = 600;
const FPS = 60;
const DELTA_TIME_SEC: f32 = 1.0 / @as(f32, @floatFromInt(FPS));

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
const BRICK_X_OFFSET: f32 = (WINDOW_WIDTH - BRICK_COLS * (BRICK_WIDTH + BRICK_GAP) - BRICK_GAP) / 2;
const BRICK_Y_OFFSET: f32 = 25;

// State
var run = true;
var pause = false;

var ball_x_pos: f32 = 0;
var ball_y_pos: f32 = 0;
var ball_d_x: f32 = 1;
var ball_d_y: f32 = 1;

var paddle_x_pos: f32 = WINDOW_WIDTH / 2 + PADDLE_WIDTH / 2;
const paddle_y_pos: f32 = WINDOW_HEIGHT - PADDLE_HEIGHT - 25;

const Brick = struct {
    x: f32,
    y: f32,
};

// Generate the bricks pool at compile time
const bricks: [BRICKS_TOTAL]Brick = bricks_pool: {
    var tmp_bricks: [BRICKS_TOTAL]Brick = undefined;
    for (0..BRICKS_TOTAL) |i| {
        const row = i / BRICK_COLS;
        const col = i % BRICK_COLS;

        tmp_bricks[i] = .{
            .x = BRICK_X_OFFSET + @as(f32, @floatFromInt(col)) * (BRICK_WIDTH + BRICK_GAP),
            .y = BRICK_Y_OFFSET + @as(f32, @floatFromInt(row)) * (BRICK_HEIGHT + BRICK_GAP),
        };
    }

    break :bricks_pool tmp_bricks;
};

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

            if (paddle_x_pos < 0) {
                paddle_x_pos = 0;
            }
        }

        if (is_right_pressed) {
            paddle_x_pos += PADDLE_SPEED * DELTA_TIME_SEC;

            if (paddle_x_pos > WINDOW_WIDTH - PADDLE_WIDTH) {
                paddle_x_pos = WINDOW_WIDTH - PADDLE_WIDTH;
            }
        }
        // END PADDLE MOVEMENT

        update(DELTA_TIME_SEC);

        _ = c.SDL_SetRenderDrawColor(renderer, 22, 27, 34, 255);
        _ = c.SDL_RenderClear(renderer);

        render(renderer);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1000 / FPS);
    }
}

fn update(delta: f32) void {
    if (pause) {
        return;
    }

    // Make the ball bounce on window limit
    var nextX = ball_x_pos + ball_d_x * BALL_SPEED * delta;
    var nextY = ball_y_pos + ball_d_y * BALL_SPEED * delta;

    if (nextX < 0 or nextX + BALL_SIZE > WINDOW_WIDTH) {
        ball_d_x *= -1;
        // direction change, recompute
        nextX = ball_x_pos + ball_d_x * BALL_SPEED * delta;
    }

    if (nextY < 0 or nextY + BALL_SIZE > WINDOW_HEIGHT) {
        ball_d_y *= -1;
        // direction change, recompute
        nextY = ball_y_pos + ball_d_y * BALL_SPEED * delta;
    }
    // End ball bounce

    // Collision with paddle
    if (c.SDL_HasIntersection(&ballRect(), &paddleRect()) != 0) {
        ball_d_y *= -1;
        // direction change, recompute
        nextY = ball_y_pos + ball_d_y * BALL_SPEED * delta;
    }
    // If the ball collision from the side of the paddle, the physics is kinda weird
    // Should not be an issue when we're going to setup ball lost if below the paddle

    // End paddle collision

    ball_x_pos = nextX;
    ball_y_pos = nextY;
}

fn render(renderer: *c.SDL_Renderer) void {
    // Draw the bricks
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 255, 255);
    for (bricks) |brick| {
        std.debug.print("BRICK: x: {d}, y: {d}\n", .{ brick.x, brick.y });
        const brick_rect: c.SDL_Rect = .{
            .x = @intFromFloat(brick.x),
            .y = @intFromFloat(brick.y),
            .w = BRICK_WIDTH,
            .h = BRICK_HEIGHT,
        };

        _ = c.SDL_RenderFillRect(renderer, &brick_rect);
    }

    // Draw the ball
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &ballRect());

    // Draw the paddle
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &paddleRect());
}

fn ballRect() c.SDL_Rect {
    const ball_rect: c.SDL_Rect = .{
        .x = @intFromFloat(ball_x_pos),
        .y = @intFromFloat(ball_y_pos),
        .w = BALL_SIZE,
        .h = BALL_SIZE,
    };

    return ball_rect;
}

fn paddleRect() c.SDL_Rect {
    const paddle_rect: c.SDL_Rect = .{
        .x = @intFromFloat(paddle_x_pos),
        .y = @intFromFloat(paddle_y_pos),
        .w = PADDLE_WIDTH,
        .h = PADDLE_HEIGHT,
    };

    return paddle_rect;
}
