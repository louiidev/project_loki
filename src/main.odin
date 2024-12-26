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
import "core:strconv"
import "core:strings"
import t "core:time"


EnemyType :: enum {
	BAT,
	CRAWLER,
	BULL,
	CACTUS,
}

AnimationState :: enum {
	IDLE,
	WALKING,
	ROLLING,
}

last_id: u32 = 0
Entity :: struct {
	id:                       u32,
	position:                 Vector2,
	speed:                    f32,
	speed_while_shooting:     f32,
	roll_speed:               f32,
	active:                   bool,
	health:                   int,
	max_health:               int,
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
	xp_pickup_radius:         f32,
	i_frame_timer:            f32,
	reload_timer:             f32,
	time_to_reload:           f32,
}


Upgrade :: enum {
	PIERCING_SHOT,
	FORK_SHOT,
	RELOAD_SPEED,
	ROLL_SPEED,
	ROLL_STAMINIA,
	HEALTH,
	AMMO_UPGRADE,
}


AppState :: enum {
	MainMenu,
	GamePlay,
}

Enemy :: struct {
	using entity: Entity,
	type:         EnemyType,
}


ShopUpgrade :: struct {
	upgrade:   Upgrade,
	purchased: bool,
	cost:      int,
}

Camera :: struct {
	position: Vector2,
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
PLAYER_INITIAL_PICKUP_RADIUS :: 8
PLAYER_I_FRAME_TIMEOUT_AMOUNT :: 0.5
PLAYER_INITIAL_BULLETS :: 6
PLAYER_INITIAL_RELOAD_TIME :: 1.0
UPGRADE_TIMER_SHOW_TIME :: 0.9
STUN_TIME :: 0.5
INITIAL_WAVE_TIME :: 10

DEFAULT_ENT :: Entity {
	active                   = true,
	speed                    = PLAYER_WALK_SPEED,
	speed_while_shooting     = PLAYER_WALK_SPEED * 0.25,
	roll_speed               = PLAYER_ROLL_SPEED,
	roll_stamina             = INITAL_ROLL_STAMINIA,
	max_roll_stamina         = INITAL_ROLL_STAMINIA,
	max_weapon_cooldown_time = PLAYER_INITIAL_FIRE_RATE,
	health                   = 2,
	max_health               = 2.,
	xp_pickup_radius         = PLAYER_INITIAL_PICKUP_RADIUS,
	time_to_reload           = PLAYER_INITIAL_RELOAD_TIME,
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
	hits:                      int,
	last_hit_ent_id:           u32,
}

XpPickup :: struct {
	position: Vector2,
	active:   bool,
}

GameRunState :: struct {
	enemies:               [dynamic]Enemy,
	projectiles:           [dynamic]Projectile,
	particles:             [dynamic]Particle,
	player:                Entity,
	xp_pickups:            [dynamic]XpPickup,
	enemy_spawn_timer:     f32,
	money:                 int,

	// waves
	current_wave:          int,
	time_left_in_wave:     f32,


	// upgrades
	slowdown_multiplier:   f32,
	timer_to_show_upgrade: f32,
	show_upgrade_shop:     bool,
	next_upgrades:         [3]ShopUpgrade,
	player_upgrade:        [Upgrade]int,
	max_bullets:           int,
	current_bullets_count: int,
}

game_data: GameRunState
app_state: AppState = .GamePlay

camera: Camera
draw_hitboxes := false


generate_new_shop_upgrades :: proc() {
	for i := 0; i < len(game_data.next_upgrades); i += 1 {
		game_data.next_upgrades[i] = {
			upgrade   = auto_cast rand.int31_max(len(Upgrade)),
			purchased = false,
			cost      = 2,
		}
	}
}

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

	game_data.player = create_entity()
	game_data.current_bullets_count = PLAYER_INITIAL_BULLETS
	game_data.max_bullets = PLAYER_INITIAL_BULLETS
	game_data.current_wave = 1
	game_data.time_left_in_wave = INITIAL_WAVE_TIME
}


paused := false
can_player_move := true
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
	case .BULL:
		enemy.attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME
	case .CACTUS:

	}
	if (enemy.type != .CACTUS) {
		knockback_ent(&enemy.entity, direction)
		fmt.println("knock back")
	}

}


damage_player :: proc(damage_amount: int) {
	using game_data
	if player.i_frame_timer <= 0 && player.animation_state != .ROLLING {
		player.health -= damage_amount
		player.i_frame_timer = PLAYER_I_FRAME_TIMEOUT_AMOUNT

		if player.health <= 0 {
			player.active = false
		}
	}
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


purchase_shop_upgrade :: proc(shop_upgrade: ^ShopUpgrade) {
	shop_upgrade.purchased = true
	game_data.money -= shop_upgrade.cost
	assert(game_data.money >= 0)


	game_data.player_upgrade[shop_upgrade.upgrade] += 1

	#partial switch (shop_upgrade.upgrade) {
	case .AMMO_UPGRADE:
		game_data.max_bullets += 2
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
	ent.i_frame_timer = math.max(0.0, ent.i_frame_timer - dt)
	ent.reload_timer = math.max(0.0, ent.reload_timer - dt)
	ent.current_animation_timer += dt
}

create_entity :: proc(position: Vector2 = V2_ZERO, speed: f32 = 20) -> Entity {
	entity := DEFAULT_ENT
	last_id += 1
	entity.id = last_id

	return entity
}

spawn_projectile_particle :: proc(p: Projectile, sprite_cell_start_y: int) {
	particle: Particle

	particle.position = p.position
	particle.sprite_cell_start = {0, sprite_cell_start_y}
	particle.animation_count = 4
	particle.time_per_frame = 0.025
	particle.rotation = p.rotation
	append(&game_data.particles, particle)
}

mouse_to_matrix :: proc() -> Vector2 {
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
	world_pos = linalg.inverse(proj * view) * world_pos
	// world_pos = view * world_pos
	return world_pos.xy
}


draw_status_bar :: proc(
	position: Vector2,
	color: Vector4,
	value: f32,
	max_value: f32,
	width: f32 = 15,
	height: f32 = 1.5,
	border_width: f32 = 0.5,
) {
	xform := translate_mat4(extend(position + {-width * 0.5, 0.0}))

	draw_quad_xform(xform, {width, height}, .nil, DEFAULT_UV, {1, 1, 1, 1})
	xform = xform * linalg.matrix4_translate_f32({border_width * 0.5, border_width * 0.5, 0.0})
	width_percentage := value / max_value
	draw_quad_xform(
		xform,
		{(width - border_width), height - border_width},
		.nil,
		DEFAULT_UV,
		{0.0, 0.0, 0.0, 0.3},
	)
	draw_quad_xform(
		xform,
		{(width - border_width) * width_percentage, height - border_width},
		.nil,
		DEFAULT_UV,
		color,
	)
}
round_to_half :: proc(value: f32) -> f32 {
	return math.round(value * 2) / 2
}

ENEMY_SPAWN_TIMER_MIN :: 2
ENEMY_SPAWN_TIMER_MAX :: 6


GAMEPLAY_CLEAR_COLOR: sg.Color : {0.89, 0.7, 0.3, 1.0}
game_play :: proc() {
	clear_color = GAMEPLAY_CLEAR_COLOR
	dt: f32 = auto_cast stime.sec(stime.laptime(&last_time))
	ui_dt: f32 = dt


	if game_data.show_upgrade_shop {
		dt = 0.0
	}


	game_data.time_left_in_wave = math.max(0, game_data.time_left_in_wave - dt)
	game_data.enemy_spawn_timer -= dt


	if game_data.time_left_in_wave <= 0 && !game_data.show_upgrade_shop {
		for &e in game_data.enemies {
			e.active = false
		}
		for &xp in game_data.xp_pickups {
			xp.active = false
		}
		for &p in game_data.projectiles {
			p.active = false
		}


		dt = math.lerp(dt, 0.0, 1 - game_data.timer_to_show_upgrade / UPGRADE_TIMER_SHOW_TIME)

		if game_data.timer_to_show_upgrade <= 0 && game_data.show_upgrade_shop == true {
			game_data.timer_to_show_upgrade = UPGRADE_TIMER_SHOW_TIME
		} else {
			game_data.timer_to_show_upgrade = math.max(game_data.timer_to_show_upgrade - dt, 0.0)
			if game_data.timer_to_show_upgrade == 0 {
				game_data.show_upgrade_shop = true
				generate_new_shop_upgrades()
			}
		}

	}

	if game_data.enemy_spawn_timer <= 0 {
		game_data.enemy_spawn_timer = rand.float32_range(
			ENEMY_SPAWN_TIMER_MIN,
			ENEMY_SPAWN_TIMER_MAX,
		)

		amount_to_spawn: int = rand.int_max(10) + 1


		for i := 0; i < amount_to_spawn; i += 1 {
			enemy_type: EnemyType = auto_cast rand.int31_max(len(EnemyType))
			spawn_x: f32 = 330 * 0.5
			spawn_y: f32 = 200 * 0.5

			position: Vector2 =
				{
					math.sign(rand.float32_range(-1, 1)) * spawn_x,
					math.sign(rand.float32_range(-1, 1)) * spawn_y,
				} +
				game_data.player.position
			switch (enemy_type) {
			case .BAT:
				append(&game_data.enemies, create_bat(position))
			case .CRAWLER:
				append(&game_data.enemies, create_crawler(position))
			case .BULL:
				append(&game_data.enemies, create_bull(position))
			case .CACTUS:
				append(&game_data.enemies, create_cactus(position))
			}
		}
	}

	if game_data.player.active && can_player_move {


		dist := linalg.distance(mouse_world_position, game_data.player.position)

		direction := mouse_world_position - game_data.player.position

		max_distance: f32 = 25
		clamped_dist := math.min(dist, max_distance)


		if direction.x != 0 && direction.y != 0 {
			// we will make the camera better later on
			camera.position = linalg.lerp(
				camera.position,
				game_data.player.position + linalg.normalize(direction) * clamped_dist,
				dt * 4,
			)

			// camera.position = {round_to_half(camera.position.x), round_to_half(camera.position.y)}

		}


	}

	draw_frame.camera_xform = translate_mat4(Vector3{-camera.position.x, -camera.position.y, 0})


	mouse_world_position = mouse_to_matrix()


	{
		tiles_x: f32 = 22
		tiles_y: f32 = 15

		// Calculate the camera's current offset
		camera_offset_x := math.floor(camera.position.x / 16)
		camera_offset_y := math.floor(camera.position.y / 16)
		offset := tiles_x * 8.0 + tiles_y * 8.0
		// render tiles
		for x: int = auto_cast camera_offset_x; x < auto_cast (tiles_x + camera_offset_x); x += 1 {
			for y: int = auto_cast camera_offset_y;
			    y < auto_cast (tiles_y + camera_offset_y);
			    y += 1 {
				// Calculate tile world position
				tile_pos := Vector3 {
					auto_cast x * 16.0 - tiles_x * 8.0,
					auto_cast y * 16.0 - tiles_y * 8.0,
					0.0,
				}

				// Offset tile position by camera movement (player position)
				world_pos := tile_pos
				xform := translate_mat4(world_pos)

				color := Vector4{0.89, 0.7, 0.3, 1.0}
				if (x + y) % 2 == 0 {
					color = Vector4{0.88, 0.67, 0.32, 1.0}
				}
				draw_quad_xform(xform, {16, 16}, .nil, DEFAULT_UV, color)
			}
		}
	}

	if game_data.timer_to_show_upgrade <= 0 && !game_data.show_upgrade_shop {
		// XP pickups
		for &xp in &game_data.xp_pickups {
			if circles_overlap(
				xp.position,
				4,
				game_data.player.position,
				game_data.player.xp_pickup_radius,
			) {
				xp.active = false
				game_data.money += 1
			}

			xform := translate_mat4({xp.position.x, xp.position.y, 0.0})
			draw_quad_center_xform(xform, {4, 4}, .nil, DEFAULT_UV, {0.0, 0.0, 1.0, 1.0})
		}

		// clean up enemies
		for i := len(game_data.xp_pickups) - 1; i >= 0; i -= 1 {
			xp := &game_data.xp_pickups[i]
			if !xp.active {
				ordered_remove(&game_data.xp_pickups, i)
			}
		}

	}

	{
		using sapp.Keycode
		using sapp
		// PLAYER LOGIC
		using game_data


		if can_player_move {
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

			if inputs.mouse_down[Mousebutton.LEFT] || player.weapon_cooldown_timer > 0 {
				speed = player.speed_while_shooting
			}

			if game_data.current_bullets_count == 0 {
				if player.reload_timer <= 0 {
					game_data.current_bullets_count = game_data.max_bullets
				}
			}

			if inputs.mouse_down[Mousebutton.LEFT] &&
			   player.weapon_cooldown_timer <= 0 &&
			   game_data.current_bullets_count > 0 &&
			   player.reload_timer <= 0 {

				game_data.current_bullets_count -= 1

				if game_data.current_bullets_count <= 0 {
					player.reload_timer = player.time_to_reload
				}


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
				append(&game_data.projectiles, projectile)
				if player.animation_state == .ROLLING {
					set_ent_animation_state(&player, .WALKING)
				}

				player.weapon_cooldown_timer = player.max_weapon_cooldown_time
			}
			player.position += player_input * dt * speed
		}

		// RENDER PLAYER
		xform := linalg.matrix4_translate_f32(
			{game_data.player.position.x, game_data.player.position.y, 0.0},
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
				{game_data.player.position.x, game_data.player.position.y, 0.0},
			) *
			linalg.matrix4_rotate(weapon_rotation_angle, Vector3{0, 0, 1}) *
			linalg.matrix4_translate_f32({-5, -12, 0.0})
		weapon_uvs := get_frame_uvs(.weapons, {1, 0}, {24, 24})
		draw_quad_xform(xform, {auto_cast 24, auto_cast 24}, .weapons, weapon_uvs)
		draw_status_bar(
			game_data.player.position + {0.0, -12},
			{1, 0, 0, 1},
			auto_cast game_data.player.health,
			auto_cast game_data.player.max_health,
		)

		draw_status_bar(
			game_data.player.position + {0.0, -14},
			{0, 0, 1, 1},
			player.roll_stamina,
			player.max_roll_stamina,
		)

		// line
		draw_rect_bordered_center_xform(
			translate_mat4(extend(game_data.player.position + {0.0, 14})),
			{12, 0.5},
			1,
			COLOR_WHITE,
			{0.1, 0.1, 0.1, 1},
		)

		// left
		draw_rect_bordered_center_xform(
			translate_mat4(extend(game_data.player.position + {-6.3, 14})),
			{0.5, 2.5},
			1,
			COLOR_WHITE,
			{0.1, 0.1, 0.1, 1},
		)

		// right
		draw_rect_bordered_center_xform(
			translate_mat4(extend(game_data.player.position + {6.3, 14})),
			{0.5, 2.5},
			1,
			COLOR_WHITE,
			{0.1, 0.1, 0.1, 1},
		)

		if game_data.current_bullets_count == 0 && player.reload_timer > 0 {
			t_normalized := 1.0 - (player.reload_timer / player.time_to_reload)
			min: f32 = -6.3
			max: f32 = 6.3
			x: f32 = math.lerp(min, max, t_normalized)

			draw_rect_bordered_center_xform(
				translate_mat4(extend(game_data.player.position + {x, 14})),
				{0.5, 2.5},
				1,
				COLOR_WHITE,
				{0.1, 0.1, 0.1, 1},
			)
		}
	}


	{
		// @enemies
		for &enemy in game_data.enemies {
			if enemy.health <= 0 {
				append(&game_data.xp_pickups, XpPickup{enemy.position, true})
				enemy.active = false
				continue
			}

			flip_x := enemy.position.x > game_data.player.position.x

			switch (enemy.type) {
			case .CRAWLER:
				crawler_update_logic(&enemy, dt)
			case .BAT:
				bat_update_logic(&enemy, dt)
			case .BULL:
				bull_update_logic(&enemy, dt)
			case .CACTUS:
				cactus_update_logic(&enemy, dt)
			}


			// RENDER ENEMIES
			xform := linalg.matrix4_translate_f32({enemy.position.x, enemy.position.y, 0.0})
			if flip_x {
				xform *= linalg.matrix4_scale_f32({-1, 1, 1})
			}
			sprite_y_index: int = auto_cast enemy.type
			update_entity_timers(&enemy, dt)

			knockback_flash: f32 = 0
			if enemy.knockback_timer > 0 || enemy.stun_timer > 0.2 {
				knockback_flash = 1
			}

			knockback_logic_update(&enemy, dt, ENEMY_KNOCKBACK_VELOCITY, &enemy.position)


			uvs := get_frame_uvs(.enemies, {0, sprite_y_index}, {16, 16})

			draw_quad_center_xform(xform, {16, 16}, .enemies, uvs, COLOR_WHITE, knockback_flash)

			if enemy.health != enemy.max_health {
				draw_status_bar(
					enemy.position + {0.0, 12},
					{1, 0, 0, 1},
					auto_cast enemy.health,
					auto_cast enemy.max_health,
				)
			}

		}


		// clean up enemies
		for i := len(game_data.enemies) - 1; i >= 0; i -= 1 {
			enemy := &game_data.enemies[i]
			if !enemy.active {
				ordered_remove(&game_data.enemies, i)
			}
		}


	}


	{
		// PROJECTILES
		for &p in game_data.projectiles {
			distance_this_frame := p.velocity * dt
			p.position += distance_this_frame
			p.current_distance_traveled += linalg.length(distance_this_frame)

			if p.current_distance_traveled > p.distance_limit || !p.active {
				p.active = false
				continue
			}

			p.current_animation_time += dt

			if p.current_frame < p.animation_count - 1 &&
			   p.current_animation_time > p.time_per_frame {
				p.current_frame += 1
				p.current_animation_time = 0
			}


			if p.player_owned {
				for &e in game_data.enemies {
					if (!e.active) {
						continue
					}

					if (p.last_hit_ent_id != e.id &&
						   circles_overlap(p.position, 6, e.position, 6)) {
						knockback_enemy(&e, linalg.normalize(p.velocity))
						e.stun_timer = STUN_TIME
						if p.hits >= game_data.player_upgrade[Upgrade.PIERCING_SHOT] {
							p.active = false
							fmt.println(game_data.player_upgrade[Upgrade.PIERCING_SHOT])
						} else {
							p.hits += 1
							p.last_hit_ent_id = e.id
						}
						e.health -= p.damage_to_deal
						spawn_projectile_particle(p, 1)
						game_data.player.roll_stamina = math.min(
							game_data.player.roll_stamina + ROLL_STAMINIA_ADD_ON_SHOT,
							game_data.player.max_roll_stamina,
						)
						break
					}
				}
			} else if (circles_overlap(
					   p.position,
					   game_data.player.collision_radius,
					   game_data.player.position,
					   4,
				   )) &&
			   game_data.player.animation_state != .ROLLING {
				// PLAYER dmg

				p.active = false
				damage_player(1)
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


		for p_i := len(game_data.projectiles) - 1; p_i >= 0; p_i -= 1 {
			if (!game_data.projectiles[p_i].active) {
				ordered_remove(&game_data.projectiles, p_i)
			}
		}


	}


	{
		// DEBUGGER TOOLS
		alpha: f32 = 0.2
		if draw_hitboxes {

			for e in game_data.enemies {
				xform := linalg.matrix4_translate(Vector3{e.position.x, e.position.y, 0.0})
				draw_quad_center_xform(xform, {12, 12}, .nil, DEFAULT_UV, {1, 0, 0, alpha})
			}

			for p in game_data.projectiles {
				xform :=
					linalg.matrix4_translate(Vector3{p.position.x, p.position.y, 0.0}) *
					linalg.matrix4_rotate(p.rotation, Vector3{0, 0, 1})

				draw_quad_center_xform(xform, {12, 12}, .nil, DEFAULT_UV, {0, 1, 0, alpha})
			}


			xform := linalg.matrix4_translate_f32(
				{game_data.player.position.x, game_data.player.position.y, alpha},
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


	draw_frame.camera_xform = identity()

	mouse_ui_pos := mouse_to_matrix()

	// {
	// 	// XP bar
	// 	half_height := pixel_height / 2.0

	// 	draw_status_bar(
	// 		{0.0, half_height - 10},
	// 		Vector4{0.0, 0.0, 1.0, 1.0},
	// 		auto_cast game_data.current_xp,
	// 		auto_cast game_data.to_next_level_xp,
	// 		100,
	// 		5,
	// 		1,
	// 	)
	// }


	{
		set_ui_projection_alignment(.bottom_center)
		using sapp

		draw_text_center(
			{0, f32(sapp.height()) - 100},
			fmt.tprintf("Wave %d", game_data.current_wave),
			30,
		)
		draw_text_center(
			{0, f32(sapp.height()) - 135},
			fmt.tprintf("Time left %.0f", game_data.time_left_in_wave),
			30,
		)

		set_ui_projection_alignment(.center_center)
		mouse_world_position = mouse_to_matrix()
		// UPGRADE MENU
		if game_data.show_upgrade_shop {

			box_width: f32 = 180
			box_height: f32 = 250
			padding: f32 = 20
			xform := transform_2d({-box_width - padding, 0.0})
			position: Vector2 = {-box_width - padding, 0.0}

			if bordered_button({-75, -box_height - 25}, {100, 50}, "Reroll shop", 20, 1) {
				generate_new_shop_upgrades()
			}
			if bordered_button({75, -box_height - 25}, {100, 50}, "Next Wave", 20, 2) {
				game_data.current_wave += 1
				game_data.time_left_in_wave = INITIAL_WAVE_TIME + 10
				game_data.show_upgrade_shop = false
			}

			for i := 0; i < len(game_data.next_upgrades); i += 1 {
				color := COLOR_WHITE

				draw_rect_center_xform(xform, {box_width, box_height}, color)
				heading := get_upgrade_heading(game_data.next_upgrades[i].upgrade)
				description := get_upgrade_description(game_data.next_upgrades[i].upgrade)

				draw_text_center(
					position - {0.0, -box_height * 0.5 + 40 + 10},
					heading,
					36,
					{0, 0, 0, 1},
				)

				draw_text_center(
					position - {0.0, -box_height * 0.5 + 100},
					description,
					24,
					{0, 0, 0, 1},
				)

				if bordered_button(
					position - {0.0, box_height * 0.5 - 30},
					{100, 50},
					"Buy",
					30,
					100 + auto_cast game_data.next_upgrades[i].upgrade,
					game_data.next_upgrades[i].purchased ||
					game_data.money < game_data.next_upgrades[i].cost,
				) {
					purchase_shop_upgrade(&game_data.next_upgrades[i])
				}

				position += {box_width + padding, 0}
				xform = xform * transform_2d({box_width + padding, 0.0})
			}

		}


	}


	{
		// Base UI
		set_ui_projection_alignment(.bottom_left)
		using game_data

		draw_text(
			Vector2{10, 10},
			fmt.tprintf("Ammo: %d/%d", game_data.current_bullets_count, game_data.max_bullets),
			32,
		)
		size := measure_text("Ammo", 32)
		padding: f32 = 10
		draw_text(
			Vector2{10, 10 + size.y + padding},
			fmt.tprintf("Health: %d/%d", player.health, player.max_health),
			32,
		)
		size = measure_text("Health", 32) + size + padding
		draw_text(
			Vector2{10, 10 + size.y + padding},
			fmt.tprintf("Stamina: %.1f/%.1f", player.roll_stamina, player.max_roll_stamina),
			32,
		)
		size = measure_text("Stamina", 32) + size + padding
		draw_text(
			Vector2{10, 10 + size.y + padding},
			fmt.tprintf("Money: %d/%d", game_data.money),
			32,
		)
	}

}

MAIN_MENU_CLEAR_COLOR: sg.Color : {1, 1, 1, 1}


UiID :: u32

UiState :: struct {
	hover_id:        UiID,
	click_captured:  bool,
	down_clicked_id: u32,
}

reset_ui_state :: proc() {
	ui_state.click_captured = false


	if inputs.button_just_pressed[sapp.Mousebutton.LEFT] {
		ui_state.down_clicked_id = 0
	}
}

ui_state: UiState

main_menu :: proc() {
	clear_color = MAIN_MENU_CLEAR_COLOR
	set_ui_projection_alignment(.center_center)
	mouse_world_position = mouse_to_matrix()
	start_btn_pos := V2_ZERO
	button_height: f32 = 120
	button_width: f32 = 450
	padding: f32 = 20


	if bordered_button(start_btn_pos, {button_width, button_height}, "Start Game", 48, 1) {
		app_state = .GamePlay
	}
	start_btn_pos.y -= button_height + padding
	if bordered_button(start_btn_pos, {button_width, button_height}, "Options", 48, 2) {
	}
	start_btn_pos.y -= button_height + padding
	if bordered_button(start_btn_pos, {button_width, button_height}, "Exit", 48, 3) {
	}
}


frame :: proc "c" () {
	context = runtime.default_context()


	switch app_state {
	case .MainMenu:
		main_menu()
	case .GamePlay:
		game_play()
	}
	reset_ui_state()

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
