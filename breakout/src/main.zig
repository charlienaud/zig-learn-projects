const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

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

        render(renderer);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1000 / FPS);
    }
}

fn update(delta: f32) void {
    if (pause) {
        return;
    }

    ballCollision(delta);
}

fn render(renderer: *c.SDL_Renderer) void {
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
