//------------------------------------------------------------------------------
//  texcube/main.odin
//  Texture creation, rendering with texture, packed vertex components.
//------------------------------------------------------------------------------
package main

import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import slog "../sokol/log"
import stime "../sokol/time"
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import t "core:time"


Entity :: struct {
	position: Vector2,
	speed:    f32,
}

Particle :: struct {
	position:               Vector2,
	active:                 bool,
	velocity:               Vector2,
	rotation:               f32,
	sprite_cell_start_x:    int,
	sprite_cell_start_y:    int,
	animation_count:        int,
	current_animation_time: f32,
	timer_per_frame:        f32,
}

Projectile :: struct {
	using particle:            Particle,
	player_owned:              bool,
	distance_limit:            f32,
	current_distance_traveled: f32,
	damage_to_deal:            f32,
}


GameRunState :: struct {
	projectiles: [dynamic]Projectile,
	particles:   [dynamic]Particle,
	player:      Entity,
}

game_run_state: GameRunState

init_time: t.Time
seconds_since_init :: proc() -> f64 {
	using t
	if init_time._nsec == 0 {
		fmt.println("invalid time")
		return 0
	}
	return duration_seconds(since(init_time))
}


init :: proc "c" () {
	context = runtime.default_context()
	init_time = t.now()
	sg.setup(
		{
			environment = sglue.environment(),
			logger = {func = slog.func},
			d3d11_shader_debugging = ODIN_DEBUG,
		},
	)
	stime.setup()
	gfx_init()
	init_images()


	game_run_state.player.speed = 50

}


fps_limit :: 144
min_frametime := 1.0 / fps_limit
paused := false
last_time: u64 = 0

frame :: proc "c" () {
	context = runtime.default_context()
	using sapp.Keycode


	dt: f32 = auto_cast stime.sec(stime.laptime(&last_time))


	{
		// PLAYER LOGIC
		using game_run_state
		x := f32(int(inputs.button_down[D]) - int(inputs.button_down[A]))
		y := f32(int(inputs.button_down[W]) - int(inputs.button_down[S]))
		player_input: Vector2 = {x, y}
		if x != 0 && y != 0 {
			player_input = linalg.normalize(player_input)
		}
		player.position += player_input * dt * player.speed


	}

	{
		// RENDER PLAYER
		xform :=
			linalg.matrix4_translate_f32({-8, -8, 0.0}) *
			linalg.matrix4_translate_f32(
				{game_run_state.player.position.x, game_run_state.player.position.y, 0.0},
			)

		uvs := get_frame_uvs(Image_Id.player, {0, 0}, {16, 16})
		draw_quad_xform(xform, {auto_cast 16, auto_cast 16}, .player, uvs)
	}


	gfx_update()
	inputs_end_frame()
}


cleanup :: proc "c" () {
	context = runtime.default_context()
	sg.shutdown()
}

main :: proc() {
	sapp.run(
		{
			init_cb = init,
			frame_cb = frame,
			cleanup_cb = cleanup,
			event_cb = event_cb,
			width = 1280,
			height = 720,
			window_title = "My Game",
			icon = {sokol_default = true},
			logger = {func = slog.func},
		},
	)
}
