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
const BALL_SIZE = 20;

// Paddle
const PADDLE_SPEED: f32 = 600; // pixel per second
const PADDLE_WIDTH = 200;
const PADDLE_HEIGHT = 20;

// State
var run = true;
var pause = false;

var ballXPos: f32 = 0;
var ballYPos: f32 = 0;
var ballDx: f32 = 1;
var ballDy: f32 = 1;

var paddleXPos: f32 = WINDOW_WIDTH / 2 + PADDLE_WIDTH / 2;
const paddleYPos: f32 = WINDOW_HEIGHT - PADDLE_HEIGHT;

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
        const isLeftPressed: bool = (keyboard[c.SDL_SCANCODE_LEFT] != 0);
        const isRightPressed: bool = (keyboard[c.SDL_SCANCODE_RIGHT] != 0);

        if (isLeftPressed) {
            paddleXPos -= PADDLE_SPEED * DELTA_TIME_SEC;

            if (paddleXPos < 0) {
                paddleXPos = 0;
            }
        }

        if (isRightPressed) {
            paddleXPos += PADDLE_SPEED * DELTA_TIME_SEC;

            if (paddleXPos > WINDOW_WIDTH - PADDLE_WIDTH) {
                paddleXPos = WINDOW_WIDTH - PADDLE_WIDTH;
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
    var nextX = ballXPos + ballDx * BALL_SPEED * delta;
    var nextY = ballYPos + ballDy * BALL_SPEED * delta;

    if (nextX < 0 or nextX + BALL_SIZE > WINDOW_WIDTH) {
        ballDx *= -1;
        // direction change, recompute
        nextX = ballXPos + ballDx * BALL_SPEED * delta;
    }

    if (nextY < 0 or nextY + BALL_SIZE > WINDOW_HEIGHT) {
        ballDy *= -1;
        // direction change, recompute
        nextY = ballYPos + ballDy * BALL_SPEED * delta;
    }
    // End ball bounce

    ballXPos = nextX;
    ballYPos = nextY;
}

fn render(renderer: *c.SDL_Renderer) void {
    const ball: c.SDL_Rect = .{
        .x = @intFromFloat(ballXPos),
        .y = @intFromFloat(ballYPos),
        .w = BALL_SIZE,
        .h = BALL_SIZE,
    };
    const paddle: c.SDL_Rect = .{
        .x = @intFromFloat(paddleXPos),
        .y = @intFromFloat(paddleYPos),
        .w = PADDLE_WIDTH,
        .h = PADDLE_HEIGHT,
    };

    // Draw the ball
    _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &ball);

    // Draw the paddle
    _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
    _ = c.SDL_RenderFillRect(renderer, &paddle);
}
