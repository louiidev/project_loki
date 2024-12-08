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
import "core:math/rand"
import t "core:time"


EnemyType :: enum {
	BAT,
	CRAWLER,
}

AnimationState :: enum {
	IDLE,
	WALKING,
	ROLLING,
}

Entity :: struct {
	position:                 Vector2,
	speed:                    f32,
	speed_while_shooting:     f32,
	roll_speed:               f32,
	active:                   bool,
	health:                   int,
	collision_radius:         f32,
	knockback_timer:          f32,
	knockback_direction:      Vector2,
	knockback_velocity:       Vector2,
	roll_stamina:             f32,
	max_roll_stamina:         f32,
	attack_timer:             f32,
	stun_timer:               f32,
	current_animation_timer:  f32,
	current_animation_frame:  int,
	animation_state:          AnimationState,
	weapon_cooldown_timer:    f32,
	max_weapon_cooldown_time: f32,
}


Enemy :: struct {
	using entity: Entity,
	type:         EnemyType,
}

SPRITE_PIXEL_SIZE :: 16
ENEMY_KNOCKBACK_VELOCITY :: 150
ENEMY_KNOCKBACK_TIME :: 0.1
CRAWLER_ATTACK_TIME :: 10
BAT_ATTACK_TIME :: 10
PLAYER_KNOCKBACK_VELOCITY :: 120
PLAYER_WALK_SPEED :: 50
PLAYER_ROLL_SPEED :: 120
INITAL_ROLL_STAMINIA :: 2
ROLL_STAMINIA_ADD_ON_SHOT :: 0.1
WALK_ANIMATION_TIME :: 0.08
WALK_ANIMATION_FRAMES :: 6
ROLLING_ANIMATION_TIME :: 0.08
ROLLING_ANIMATION_FRAMES :: 4
PLAYER_INITIAL_FIRE_RATE :: 0.2

DEFAULT_ENT :: Entity {
	active                   = true,
	speed                    = PLAYER_WALK_SPEED,
	speed_while_shooting     = PLAYER_WALK_SPEED * 0.25,
	roll_speed               = PLAYER_ROLL_SPEED,
	roll_stamina             = INITAL_ROLL_STAMINIA,
	max_roll_stamina         = INITAL_ROLL_STAMINIA,
	max_weapon_cooldown_time = PLAYER_INITIAL_FIRE_RATE,
	health                   = 2,
}

Particle :: struct {
	position:               Vector2,
	active:                 bool,
	velocity:               Vector2,
	rotation:               f32,
	sprite_cell_start:      Vector2Int,
	animation_count:        int,
	current_frame:          int,
	current_animation_time: f32,
	time_per_frame:         f32,
}

Projectile :: struct {
	using particle:            Particle,
	player_owned:              bool,
	distance_limit:            f32,
	current_distance_traveled: f32,
	damage_to_deal:            int,
}


GameRunState :: struct {
	enemies:     [dynamic]Enemy,
	projectiles: [dynamic]Projectile,
	particles:   [dynamic]Particle,
	player:      Entity,
}

game_run_state: GameRunState
draw_hitboxes := true

init :: proc "c" () {
	context = runtime.default_context()
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

	game_run_state.player = DEFAULT_ENT
	generate_level()
}


paused := false
last_time: u64 = 0
mouse_world_position: Vector2


set_ent_animation_state :: proc(ent: ^Entity, animation_state: AnimationState) {
	ent.animation_state = animation_state
	ent.current_animation_frame = 0
	ent.current_animation_timer = 0
}

calc_rotation_to_target :: proc(a, b: Vector2) -> f32 {
	delta_x := a.x - b.x
	delta_y := a.y - b.y
	angle := linalg.atan2(delta_y, delta_x)
	return angle
}

circles_overlap :: proc(
	a_pos_center: Vector2,
	a_radius: f32,
	b_pos_center: Vector2,
	b_radius: f32,
) -> bool {
	distance := linalg.distance(a_pos_center, b_pos_center)
	// Check if the distance is less than or equal to the sum of the radii
	if (distance <= (a_radius + b_radius)) {
		return true
	}

	return false
}


knockback_enemy :: proc(enemy: ^Enemy, direction: Vector2) {
	switch (enemy.type) {
	case .CRAWLER:
		enemy.attack_timer = CRAWLER_ATTACK_TIME + ENEMY_KNOCKBACK_TIME
	case .BAT:
		enemy.attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME
	}
	knockback_ent(&enemy.entity, direction)
}


knockback_ent :: proc(ent: ^Entity, direction: Vector2) {
	if (ent.knockback_timer > 0) {
		return
	}

	ent.knockback_timer = ENEMY_KNOCKBACK_TIME
	ent.knockback_direction = direction
}


knockback_logic_update :: proc(
	ent: ^Entity,
	delta_t: f32,
	velocity: f32,
	potential_position: ^Vector2,
) {
	if (ent.knockback_timer > 0) {
		t := 1.0 - (ent.knockback_timer / ENEMY_KNOCKBACK_TIME)
		ent.knockback_velocity.x = math.lerp(ent.knockback_direction.x * velocity, 0.0, delta_t)
		ent.knockback_velocity.y = math.lerp(ent.knockback_direction.y * velocity, 0, delta_t)
		potential_position.x += ent.knockback_velocity.x * delta_t
		potential_position.y += ent.knockback_velocity.y * delta_t
	}

}

update_player_animations :: proc(ent: ^Entity, dt: f32) {

	switch (ent.animation_state) {
	case .IDLE:
		ent.current_animation_timer = 0
		ent.current_animation_frame = 0
	case .ROLLING:
		if ent.current_animation_timer > ROLLING_ANIMATION_TIME {
			ent.current_animation_timer = 0
			if ent.current_animation_frame >= ROLLING_ANIMATION_FRAMES - 1 {
				ent.current_animation_frame = 0
			} else {
				ent.current_animation_frame += 1
			}
		}
	case .WALKING:
		if ent.current_animation_timer > WALK_ANIMATION_TIME {
			ent.current_animation_timer = 0
			if ent.current_animation_frame >= WALK_ANIMATION_FRAMES - 1 {

				ent.current_animation_frame = 0
			} else {

				ent.current_animation_frame += 1
			}
		}
	}
}

update_entity_timers :: proc(ent: ^Entity, dt: f32) {
	ent.attack_timer = math.max(0.0, ent.attack_timer - dt)
	ent.knockback_timer = math.max(0.0, ent.knockback_timer - dt)
	ent.stun_timer = math.max(0.0, ent.stun_timer - dt)
	ent.weapon_cooldown_timer = math.max(0.0, ent.weapon_cooldown_timer - dt)
	ent.current_animation_timer += dt
}


create_bat :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = DEFAULT_ENT
	enemy.position = position
	enemy.type = .BAT
	enemy.speed = 20
	enemy.weapon_cooldown_timer = 10

	return enemy
}

create_crawler :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = DEFAULT_ENT
	enemy.position = position
	enemy.type = .CRAWLER
	enemy.speed = 20

	return enemy
}

room_size: Vector2 : {80, 60}
generate_level :: proc() {
	number_of_enemies: int = auto_cast rand.float32_range(10, 20)
	for i := 0; i < number_of_enemies; i += 1 {
		enemy_type: EnemyType = auto_cast rand.int31_max(len(EnemyType))
		position: Vector2 = {
			rand.float32_range(-room_size.x, room_size.x),
			rand.float32_range(-room_size.y, room_size.y),
		}
		switch (enemy_type) {
		case .BAT:
			append(&game_run_state.enemies, create_bat(position))
		case .CRAWLER:
			append(&game_run_state.enemies, create_crawler(position))
		}
	}
}

spawn_projectile_particle :: proc(p: Projectile, sprite_cell_start_y: int) {
	particle: Particle

	particle.position = p.position
	particle.sprite_cell_start = {0, sprite_cell_start_y}
	particle.animation_count = 4
	particle.time_per_frame = 0.025
	particle.rotation = p.rotation
	append(&game_run_state.particles, particle)
}


frame :: proc "c" () {
	context = runtime.default_context()

	dt: f32 = auto_cast stime.sec(stime.laptime(&last_time))


	{
		// MOUSE TO WORLD
		mouse_x := inputs.screen_mouse_pos.x
		mouse_y := inputs.screen_mouse_pos.y
		proj := draw_frame.projection
		view := draw_frame.camera_xform

		// Normalize the mouse coordinates
		ndc_x := (mouse_x / (auto_cast sapp.width() * 0.5)) - 1.0
		ndc_y := (mouse_y / (auto_cast sapp.height() * 0.5)) - 1.0

		// Transform to world coordinates
		world_pos: Vector4 = {ndc_x, ndc_y, 0, 1}
		world_pos = m4_transform(m4_inverse(proj), world_pos)
		world_pos = m4_transform(view, world_pos)

		mouse_world_position = world_pos.xy
	}


	{
		using sapp.Keycode
		using sapp
		// PLAYER LOGIC
		using game_run_state
		x := f32(int(inputs.button_down[D]) - int(inputs.button_down[A]))
		y := f32(int(inputs.button_down[W]) - int(inputs.button_down[S]))
		player_input: Vector2 = {x, y}
		if x != 0 && y != 0 {
			player_input = linalg.normalize(player_input)
		}

		if x != 0 || y != 0 {
			if player.animation_state != .ROLLING {
				player.animation_state = .WALKING
			}
		} else {
			set_ent_animation_state(&player, .IDLE)
		}

		update_entity_timers(&player, dt)
		update_player_animations(&player, dt)


		speed := player.speed

		if inputs.button_just_pressed[Keycode.SPACE] {
			if player.roll_stamina > 0 && player.animation_state != .ROLLING {
				set_ent_animation_state(&player, .ROLLING)
			} else {
				set_ent_animation_state(&player, .WALKING)
			}
		}

		if player.animation_state == .ROLLING {
			player.roll_stamina -= dt
			speed = player.roll_speed

			if player.roll_stamina <= 0 {
				player.roll_stamina = 0
				set_ent_animation_state(&player, .WALKING)
			}
		} else {
			player.roll_stamina = math.min(player.roll_stamina + dt, player.max_roll_stamina)
		}


		rotation_z := -calc_rotation_to_target(mouse_world_position, player.position)
		attack_direction: Vector2 = {math.cos(-rotation_z), math.sin(-rotation_z)}
		gun_move_distance: f32 = 8.0
		delta_x := gun_move_distance * math.cos(rotation_z)
		delta_y := gun_move_distance * math.sin(rotation_z)
		attack_position: Vector2 = player.position + {delta_x, -delta_y}
		player_center_position := player.position + {-8, -8}

		if inputs.mouse_down[Mousebutton.LEFT] {
			speed = player.speed_while_shooting

		}

		if inputs.mouse_down[Mousebutton.LEFT] && player.weapon_cooldown_timer <= 0 {


			projectile: Projectile
			projectile.animation_count = 2
			projectile.time_per_frame = 0.02
			projectile.position = attack_position
			projectile.active = true
			projectile.distance_limit = 250
			projectile.sprite_cell_start = {0, 1}
			projectile.rotation = -rotation_z
			projectile.velocity = attack_direction * 100
			projectile.player_owned = true
			projectile.damage_to_deal = 1
			append(&game_run_state.projectiles, projectile)
			if player.animation_state == .ROLLING {
				set_ent_animation_state(&player, .WALKING)
			}

			player.weapon_cooldown_timer = player.max_weapon_cooldown_time
		}
		player.position += player_input * dt * speed

		// RENDER PLAYER
		xform := linalg.matrix4_translate_f32(
			{game_run_state.player.position.x, game_run_state.player.position.y, 0.0},
		)

		frame_x := 0
		frame_y := 0

		if player.animation_state == .WALKING {
			frame_x = player.current_animation_frame + 1
		} else if player.animation_state == .ROLLING {
			frame_y = 1
			frame_x = player.current_animation_frame
		}

		uvs := get_frame_uvs(.player, {frame_x, frame_y}, {16, 16})
		draw_quad_center_xform(xform, {auto_cast 16, auto_cast 16}, .player, uvs)


		weapon_rotation_angle := calc_rotation_to_target(mouse_world_position, player.position)


		xform =
			linalg.matrix4_translate_f32(
				{game_run_state.player.position.x, game_run_state.player.position.y, 0.0},
			) *
			linalg.matrix4_rotate(weapon_rotation_angle, Vector3{0, 0, 1}) *
			linalg.matrix4_translate_f32({-5, -12, 0.0})
		weapon_uvs := get_frame_uvs(.weapons, {1, 0}, {24, 24})
		draw_quad_xform(xform, {auto_cast 24, auto_cast 24}, .weapons, weapon_uvs)

		xform =
			linalg.matrix4_translate_f32(
				{game_run_state.player.position.x, game_run_state.player.position.y, 0.0},
			) *
			linalg.matrix4_translate_f32({-15 * 0.5, -12, 0.0})

		draw_quad_xform(xform, {15, 1.5}, .nil, DEFAULT_UV, {1, 1, 1, 1})
		xform = xform * linalg.matrix4_translate_f32({0.25, 0.25, 0.0})
		width_percentage := player.roll_stamina / player.max_roll_stamina
		draw_quad_xform(xform, {14.5 * width_percentage, 1}, .nil, DEFAULT_UV, {0, 0, 1, 1})
	}


	{
		// @enemies
		for &enemy in game_run_state.enemies {
			if enemy.health <= 0 {
				continue
			}

			switch (enemy.type) {
			case .CRAWLER:
				crawler_update_logic(&enemy, dt)
			case .BAT:
				bat_update_logic(&enemy, dt)
			}


			// RENDER ENEMIES
			xform := linalg.matrix4_translate_f32({enemy.position.x, enemy.position.y, 0.0})
			sprite_y_index := 0
			switch (enemy.type) {
			case .BAT:
				sprite_y_index = 0
			case .CRAWLER:
				sprite_y_index = 1
			}
			update_entity_timers(&enemy, dt)
			knockback_logic_update(&enemy, dt, ENEMY_KNOCKBACK_VELOCITY, &enemy.position)


			uvs := get_frame_uvs(.enemies, {0, sprite_y_index}, {16, 16})
			draw_quad_center_xform(xform, {16, 16}, .enemies, uvs)
		}


		// clean up enemies
		for i := len(game_run_state.enemies) - 1; i >= 0; i -= 1 {
			enemy := &game_run_state.enemies[i]
			if enemy.health <= 0 {
				ordered_remove(&game_run_state.enemies, i)
			}
		}


	}


	{
		// PROJECTILES
		for &p in game_run_state.projectiles {
			distance_this_frame := p.velocity * dt
			p.position += distance_this_frame
			p.current_distance_traveled += linalg.length(distance_this_frame)

			if p.current_distance_traveled > p.distance_limit {
				p.active = false
				continue
			}

			p.current_animation_time += dt

			if p.current_frame < p.animation_count - 1 &&
			   p.current_animation_time > p.time_per_frame {
				p.current_frame += 1
				p.current_animation_time = 0
			}

			center_pos :=
				game_run_state.player.position + {SPRITE_PIXEL_SIZE * 0.5, SPRITE_PIXEL_SIZE * 0.5}

			if p.player_owned {
				for &e in game_run_state.enemies {
					if (!e.active) {
						continue
					}

					center_position := e.position
					if (circles_overlap(p.position, 6, center_position, 6)) {
						knockback_ent(&e, linalg.normalize(p.velocity))
						p.active = false
						e.health -= p.damage_to_deal
						spawn_projectile_particle(p, 1)
						game_run_state.player.roll_stamina = math.min(
							game_run_state.player.roll_stamina + ROLL_STAMINIA_ADD_ON_SHOT,
							game_run_state.player.max_roll_stamina,
						)
						break
					}
				}
			} else if (circles_overlap(
					   center_pos,
					   game_run_state.player.collision_radius,
					   p.position,
					   4,
				   )) {
				// PLAYER dmg
			}

			xform :=
				linalg.matrix4_translate(Vector3{p.position.x, p.position.y, 0.0}) *
				linalg.matrix4_rotate(p.rotation, Vector3{0, 0, 1})

			uvs := get_frame_uvs(
				.projectiles,
				{p.sprite_cell_start.x + p.current_frame, p.sprite_cell_start.y},
				{16, 16},
			)
			draw_quad_center_xform(xform, {auto_cast 16, auto_cast 16}, .projectiles, uvs)
		}


		for p_i := len(game_run_state.projectiles) - 1; p_i >= 0; p_i -= 1 {
			if (!game_run_state.projectiles[p_i].active) {
				ordered_remove(&game_run_state.projectiles, p_i)
			}
		}


	}


	{
		// DEBUGGER TOOLS
		alpha: f32 = 0.2
		if draw_hitboxes {

			for e in game_run_state.enemies {
				xform := linalg.matrix4_translate(Vector3{e.position.x, e.position.y, 0.0})
				draw_quad_center_xform(xform, {12, 12}, .nil, DEFAULT_UV, {1, 0, 0, alpha})
			}

			for p in game_run_state.projectiles {
				xform :=
					linalg.matrix4_translate(Vector3{p.position.x, p.position.y, 0.0}) *
					linalg.matrix4_rotate(p.rotation, Vector3{0, 0, 1})

				draw_quad_center_xform(xform, {12, 12}, .nil, DEFAULT_UV, {0, 1, 0, alpha})
			}


			xform := linalg.matrix4_translate_f32(
				{game_run_state.player.position.x, game_run_state.player.position.y, alpha},
			)


			draw_quad_center_xform(
				xform,
				{auto_cast 8, auto_cast 8},
				.nil,
				DEFAULT_UV,
				{0, 0, 1, alpha},
			)
		}
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
