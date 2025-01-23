//------------------------------------------------------------------------------
//  texcube/main.odin
//  Texture creation, rendering with texture, packed vertex components.
//------------------------------------------------------------------------------
package main

import sapp "../vendor/sokol/app"
import sg "../vendor/sokol/gfx"
import sglue "../vendor/sokol/glue"
import slog "../vendor/sokol/log"
// import stime "../sokol/time"

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:strings"

import "time"


DEBUG :: ODIN_DEBUG

RELEASE :: !DEBUG

// PLATFORM :: #config(PLATFORM, "undefined")

DEMO :: #config(DEMO, true)

WEB :: ODIN_ARCH == .wasm32

// :config
when DEBUG {
	DEV :: true
	TESTING :: false
	PROFILE :: false
} else {
	DEV :: false
	TESTING :: false
	PROFILE :: false
}


GameRunState :: struct {
	enemies:                              [dynamic]Enemy,
	projectiles:                          [dynamic]Projectile,
	particles:                            [dynamic]Particle,
	environment_prop:                     [dynamic]EnvironmentProp,
	sprite_particles:                     [dynamic]SpriteParticle,
	permanence:                           [dynamic]Permanence,
	popup_text:                           [dynamic]PopupText,
	bombs:                                [dynamic]Bomb,
	blood:                                [dynamic]Blood,
	player:                               Player,
	pickups:                              [dynamic]Pickup,
	enemy_spawn_timer:                    f32,
	money:                                int,
	ticks:                                u64,
	rolldown_cooldown_timer:              f32,

	// waves
	current_wave:                         int,
	time_left_in_wave:                    f32,
	timer_to_show_player_death_ui:        f32,
	timer_to_show_player_death_animation: f32,
	reroll_cost:                          int,

	// upgrades
	next_upgrades:                        [3]ShopUpgrade,
	player_upgrade:                       [Upgrade]int,
	max_bullets:                          int,
	current_bullets_count:                int,
	money_pickup_radius:                  f32,
	bullet_velocity:                      f32,
	bullet_spread:                        f32,
	bullet_range:                         f32,
	time_to_reload:                       f32,
	enemy_stun_time:                      f32,
	crit_chance:                          f32,
	orb_damage_per_hit:                   f32,
	bullet_dmg:                           f32,
	poison_dmg:                           f32,
	freeze_slowdown:                      f32,
	poison_slowdown:                      f32,
	bullet_freeze_chance:                 f32,
	bullet_poison_chance:                 f32,
	chance_enemy_explodes:                f32,
	chance_bomb_drop_reload:              f32,
	chance_for_piercing_shot:             f32,
	explosive_dmg:                        f32,
	bullet_scale:                         f32,
	fire_rate:                            f32,


	// weapons
	weapon_bullet_velocity:               f32,
	weapon_max_bullets:                   int,
	weapon_spread:                        f32,
	weapon_bullet_dmg:                    f32,
	weapon_time_to_reload:                f32,
	weapon_bullet_scale:                  f32,
	weapon_bullet_range:                  f32,
	weapon_bullet_spread:                 f32,
	weapon_fire_rate:                     f32,

	// timers
	in_transition_timer:                  f32,
	out_transition_timer:                 f32,
	knockback_radius_timer:               f32,
	knockback_hold_timer:                 f32,
	timer_to_show_upgrade:                f32,
	slowdown_multiplier:                  f32,
	shop_in_transition_time:              f32,
	shop_out_transition_time:             f32,


	// camera shake
	camera_zoom:                          f32,
	shake_amount:                         f32,
	ui_state:                             GameUIState,
	app_state:                            AppState,
	world_time_elapsed:                   f32,
	explosions:                           [dynamic]Explosion,
	knockback_position:                   Vector2,
	// STATS
	enemies_killed:                       u32,
	money_earned:                         u32,
	using ux_state:                       struct {
		ux_alpha:      f32,
		ux_anim_state: enum {
			fade_in,
			hold,
			fade_out,
		},
		hold_end_time: f64,
	},
}


AnimationState :: enum {
	IDLE,
	WALKING,
	ROLLING,
}


Player :: struct {
	using entity:       Entity,
	just_fired_timer:   f32,
	i_frame_timer:      f32,
	current_speed:      f32,
	roll_timer:         f32,
	last_weapon_pickup: Weapon,
}


last_id: u32 = 0
Entity :: struct {
	using _:                 BaseEntity,
	id:                      u32,
	velocity:                Vector2,
	dodge_roll_cooldown:     f32,
	speed:                   f32,
	roll_speed:              f32,
	health:                  f32,
	max_health:              f32,
	collision_radius:        f32,
	knockback_timer:         f32,
	knockback_direction:     Vector2,
	knockback_velocity:      Vector2,
	attack_timer:            f32,
	stun_timer:              f32,
	current_animation_timer: f32,
	current_animation_frame: int,
	animation_state:         AnimationState,
	weapon_cooldown_timer:   f32,
	reload_timer:            f32,
	scale_x:                 f32,
}


AppState :: enum {
	splash_logo,
	splash_fmod,
	main_menu,
	game,
}

GameUIState :: enum {
	nil,
	pause_menu,
	upgrade_menu,
	player_death,
}


ShopUpgrade :: struct {
	upgrade:   Upgrade,
	purchased: bool,
	cost:      int,
}

Camera :: struct {
	position: Vector2,
}


Bomb :: struct {
	using _:                 BaseEntity,
	current_animation_timer: f32,
	current_animation_frame: int,
	last_frame_timer:        f32,
}


MAX_POPUP_TEXT_LIFE_TIME: f32 : 1.0
PopupText :: struct {
	using _:   BaseEntity,
	alpha:     f32,
	text:      string,
	color:     Vector4,
	life_time: f32,
	scale:     f32,
}

DEFAULT_POPUP_TXT: PopupText : {active = true, color = COLOR_WHITE, scale = 1.0}

// UPGRADES INITIAL VALUES
// REVOLVER
PLAYER_INITIAL_BULLETS :: 6
PLAYER_INITIAL_BULLET_RANGE: f32 : 100
PLAYER_INITIAL_BULLET_SPREAD: f32 : 12.0
PLAYER_INITIAL_RELOAD_TIME :: 1.4
PLAYER_INITIAL_BULLET_DMG: f32 : 10
PLAYER_INITIAL_BULLET_VELOCITY :: 500.0
PLAYER_INITIAL_FIRE_RATE :: 0.2


PLAYER_MIN_POSSIBLE_RELOAD_TIME :: 0.1

PLAYER_INITIAL_PICKUP_RADIUS :: 30
PLAYER_INITIAL_CRIT_CHANCE: f32 : 7.5
PLAYER_MAX_CRIT_CHANCE: f32 : 75.5
PLAYER_WALK_SPEED :: 80
PLAYER_WALK_SHOOTING_SPEED :: 80 * 0.25
PLAYER_SPEED_REDUCATION_PER_FRAME: f32 : 70.0
PLAYER_SPEED_ADDITION_PER_FRAME: f32 : 120.0
PLAYER_ROLL_SPEED :: 100
PLAYER_ROLLDOWN_COOLDOWN :: 0.8
PLAYER_DODGE_ROLL_PWR :: 180
PLAYER_DODGE_ROLL_TIME :: 0.36
PLAYER_DEFAULT_ORB_DMG: f32 : 3

PLAYER_INITIAL_poison_DMG: f32 : 1.0
PLAYER_INITIAL_FREEZE_SLOWDOWN: f32 : 0.75
INITIAL_EXPLOSIVE_DMG: f32 : 15
INITIAL_FREEZE_SLOWDOWN: f32 : 0.75

PLAYER_GUN_MOVE_DIST: f32 : 8.0


MIN_ENEMIES_PER_SPAWN: int : 2
MAX_ENEMIES_PER_SPAWN: int : 5

MAX_EVER_ENEMIES_PER_SPAWN: int : 15

WAVE_ENEMY_PER_SPAWN_MODIFIER: int : 1
WAVE_ENEMY_HEALTH_MODIFIER: f32 : 2.5


SPRITE_PIXEL_SIZE :: 16

PLAYER_KNOCKBACK_VELOCITY :: 120


REROLL_COST_MODIFIER :: 2
INITIAL_REROLL_COST :: 1


IDLE_ANIMATION_TIME :: 0.6
IDLE_ANIMATION_FRAMES :: 2
WALK_ANIMATION_TIME :: 0.08
WALK_ANIMATION_FRAMES :: 6
ROLLING_ANIMATION_TIME :: 0.08
ROLLING_ANIMATION_FRAMES :: 4

PLAYER_I_FRAME_TIMEOUT_AMOUNT :: 0.5

UPGRADE_TIMER_SHOW_TIME :: 0.9
TIMER_TO_SHOW_DEATH_UI: f32 : 2.0
TIMER_TO_SHOW_DEATH_ANIMATION: f32 : 1.5
INITIAL_STUN_TIME :: 0.5
INITIAL_WAVE_TIME :: 30
WAVE_TIME_MODIFIER: f32 : 0.5
CAMERA_SHAKE_DECAY: f32 : 0.8
SHAKE_POWER: f32 : 2.0
SPAWN_INDICATOR_TIME: f32 : 0.90
LEVEL_BOUNDS: Vector2 : {465, 242}
FENCE_SIZE: Vector2 : {496, 270}
HALF_BOUNDS: Vector2 : {LEVEL_BOUNDS.x * 0.5, LEVEL_BOUNDS.y * 0.5}

WALLS: [4]Vector4 : {
	{-HALF_BOUNDS.x - 10, -HALF_BOUNDS.y, 10, LEVEL_BOUNDS.y}, // left
	{-HALF_BOUNDS.x, -HALF_BOUNDS.y - 10, LEVEL_BOUNDS.x, 10}, // bottom
	{HALF_BOUNDS.x, -HALF_BOUNDS.y, 10, LEVEL_BOUNDS.y}, // right
	{-HALF_BOUNDS.x, HALF_BOUNDS.y, LEVEL_BOUNDS.x, 10}, // up
}
DEBUG_HITBOXES :: false
DEBUG_NO_ENEMIES :: false


DEFAULT_ENT :: Entity {
	active           = true,
	speed            = PLAYER_WALK_SPEED,
	roll_speed       = PLAYER_ROLL_SPEED,
	collision_radius = 4,
}


PLAYER :: Player {
	current_speed = PLAYER_WALK_SPEED,
}

Blood :: struct {
	using _:          BaseEntity,
	size:             f32,
	current_lifetime: f32,
	max_lifetime:     f32,
	velocity:         Vector2,
	ground_y:         f32,
	color:            Vector4,
}

Explosion :: struct {
	using _:          BaseEntity,
	current_lifetime: f32,
	max_lifetime:     f32,
	size:             f32,
}


PickupType :: enum {
	Money,
	Health,
	Ammo,
	Shotgun,
	SMG,
	Sniper,
	MachineGun,
}

MONEY_ANIM_FRAMES :: 8
MONEY_ANIM_TIME_PER_FRAME: f32 : 0.1
Pickup :: struct {
	using _:                 BaseEntity,
	picked_up:               bool,
	current_animation_frame: int,
	current_animation_timer: f32,
	start_pos:               Vector2,
	current_pickup_time:     f32,
	type:                    PickupType,
	amount:                  int,
}


game_data: GameRunState


camera: Camera


restart_run :: proc() {
	// eventually Ill put in a fade out
	reset_scene()


	setup_run()
}


setup_run :: proc() {
	game_data = {}
	game_data.app_state = .game
	game_data.player = create_default_player(20)
	game_data.current_bullets_count = PLAYER_INITIAL_BULLETS
	game_data.crit_chance = PLAYER_INITIAL_CRIT_CHANCE
	game_data.orb_damage_per_hit = PLAYER_DEFAULT_ORB_DMG

	game_data.current_wave = 1
	game_data.reroll_cost = INITIAL_REROLL_COST
	game_data.time_left_in_wave = INITIAL_WAVE_TIME
	game_data.timer_to_show_upgrade = UPGRADE_TIMER_SHOW_TIME
	game_data.money_pickup_radius = PLAYER_INITIAL_PICKUP_RADIUS
	// weapon stuff
	game_data.weapon_bullet_velocity = PLAYER_INITIAL_BULLET_VELOCITY
	game_data.weapon_bullet_spread = PLAYER_INITIAL_BULLET_SPREAD
	game_data.weapon_time_to_reload = PLAYER_INITIAL_RELOAD_TIME
	game_data.weapon_max_bullets = PLAYER_INITIAL_BULLETS
	game_data.weapon_bullet_range = PLAYER_INITIAL_BULLET_RANGE
	game_data.weapon_bullet_dmg = PLAYER_INITIAL_BULLET_DMG
	game_data.weapon_fire_rate = PLAYER_INITIAL_FIRE_RATE

	game_data.camera_zoom = 1.0
	game_data.enemy_stun_time = INITIAL_STUN_TIME
	game_data.poison_dmg = PLAYER_INITIAL_poison_DMG
	game_data.explosive_dmg = INITIAL_EXPLOSIVE_DMG
	game_data.freeze_slowdown = INITIAL_FREEZE_SLOWDOWN


	setup_scene_props()
}


generate_new_shop_upgrades :: proc(last_upgrades: []ShopUpgrade) {

	upgrades_bag: [dynamic]Upgrade
	defer delete(upgrades_bag)

	probabilities := get_upgrade_shop_probabilities()

	for upgrade in Upgrade {
		skip := false
		for l_upgrade in last_upgrades {
			if l_upgrade.upgrade == upgrade {
				skip = true
				break
			}

		}
		if skip {
			continue
		}
		prob := int(probabilities[upgrade] * 1000)
		for i := 0; i < prob; i += 1 {
			append(&upgrades_bag, upgrade)
		}

	}


	for i := 0; i < len(game_data.next_upgrades); i += 1 {
		upgrade: Upgrade = upgrades_bag[rand.int_max(len(upgrades_bag))]
		game_data.next_upgrades[i] = {
			upgrade   = upgrade,
			purchased = false,
			cost      = get_upgrade_cost(upgrade) + get_upgrade_cost_additional(upgrade),
		}


		for length := len(upgrades_bag) - 1; length >= 0; length -= 1 {
			upgrade := upgrades_bag[length]
			if upgrade == game_data.next_upgrades[i].upgrade {
				ordered_remove(&upgrades_bag, length)
			}

		}


	}
}


primary_color: Vector4
secondary_color: Vector4
background_color: Vector4
clear_color: sg.Color

vec_to_color :: proc(color: Vector4) -> sg.Color {
	return sg.Color{color.r, color.g, color.b, color.a}
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
	primary_color = hex_to_rgb(0xfff3f3)
	secondary_color = hex_to_rgb(0xa07cff)
	background_color = hex_to_rgb(0xbf704d)
	clear_color = vec_to_color(background_color)
	// stime.setup()
	gfx_init()
	init_images()
	init_sound()
	setup_run()
	init_time = time.now()
	sapp.toggle_fullscreen()

	when (!DEBUG || !TESTING) && !DEV {
		game_data.app_state = .splash_logo
	} else {
		game_data.app_state = .game
		// ux_mode = .splash_logo
	}


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


EXPLOSION_LIFETIME: f32 : 0.25
create_explosion :: proc(position: Vector2) {

	camera_shake(0.85)
	explosion: Explosion

	size := rand.float32_range(32, 64)

	explosion.size = size
	explosion.position = position
	explosion.max_lifetime = EXPLOSION_LIFETIME
	explosion.active = true
	append(&game_data.explosions, explosion)
	play_sound("event:/explosion", position)

	for &enemy in game_data.enemies {
		if circles_overlap(
			enemy.position,
			enemy.collision_radius,
			explosion.position,
			explosion.size * 0.5,
		) {
			damage_enemy(
				&enemy,
				game_data.explosive_dmg,
				linalg.normalize(enemy.position - explosion.position) * 40,
			)
		}
	}

	if circles_overlap(
		game_data.player.position,
		game_data.player.collision_radius,
		explosion.position,
		explosion.size * 0.5,
	) {
		damage_player(game_data.explosive_dmg, .projectile)
	}

	create_explosion_permanence(&explosion)
	spawn_explosion_particles(position, size, hex_to_rgb(0x25131a))
}


DamageType :: enum {
	physical,
	projectile,
}

damage_player :: proc(damage_amount: f32, dmg_type: DamageType) {
	using game_data
	if player.i_frame_timer <= 0 && player.animation_state != .ROLLING {
		player.health -= damage_amount
		player.i_frame_timer = PLAYER_I_FRAME_TIMEOUT_AMOUNT
		play_sound("event:/hit")
		if player.health <= 0 {
			game_data.timer_to_show_player_death_animation = TIMER_TO_SHOW_DEATH_ANIMATION
			game_data.timer_to_show_player_death_ui = TIMER_TO_SHOW_DEATH_UI
		}
		if dmg_type == .physical {
			knockback_enemies_in_radius(&player, 30)
		}

	}


}


KNOCKBACK_RADIUS_TIME: f32 : 0.5
knockback_enemies_in_radius :: proc(player: ^Entity, radius: f32) {
	game_data.knockback_radius_timer = KNOCKBACK_RADIUS_TIME
	game_data.knockback_position = player.position
	for &enemy in game_data.enemies {
		if circles_overlap(player.position, radius, enemy.position, enemy.collision_radius) {
			knockback_enemy(&enemy, linalg.normalize(enemy.position - player.position))
			enemy.stun_timer = game_data.enemy_stun_time
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


wrap_animations :: proc(ent: ^Entity, dt: f32, animation_time: f32, frames: int) {

	if ent.current_animation_timer > animation_time {
		ent.current_animation_timer = 0
		if ent.current_animation_frame >= frames - 1 {
			ent.current_animation_frame = 0
		} else {
			ent.current_animation_frame += 1
		}
	}
}


update_player_animations :: proc(ent: ^Entity, dt: f32) {

	switch (ent.animation_state) {
	case .IDLE:
		wrap_animations(ent, dt, IDLE_ANIMATION_TIME, IDLE_ANIMATION_FRAMES)
	case .ROLLING:
		wrap_animations(ent, dt, ROLLING_ANIMATION_TIME, ROLLING_ANIMATION_FRAMES)
	case .WALKING:
		wrap_animations(ent, dt, WALK_ANIMATION_TIME, WALK_ANIMATION_FRAMES)
	}
}


update_player_timers :: proc(ent: ^Player, dt: f32) {
	update_entity_timers(ent, dt)
	ent.i_frame_timer = math.max(0.0, ent.i_frame_timer - dt)
}

update_entity_timers :: proc(ent: ^Entity, dt: f32) {
	ent.attack_timer = math.max(0.0, ent.attack_timer - dt)
	ent.knockback_timer = math.max(0.0, ent.knockback_timer - dt)
	ent.stun_timer = math.max(0.0, ent.stun_timer - dt)
	ent.weapon_cooldown_timer = math.max(0.0, ent.weapon_cooldown_timer - dt)
	ent.reload_timer = math.max(0.0, ent.reload_timer - dt)
	ent.current_animation_timer += dt
	ent.dodge_roll_cooldown = math.max(0.0, ent.dodge_roll_cooldown - dt)
}

create_default_player :: proc(
	health: f32,
	position: Vector2 = V2_ZERO,
	speed: f32 = 20,
) -> Player {
	entity: Player = PLAYER
	entity.entity = DEFAULT_ENT
	entity.health = health
	entity.max_health = health
	entity.position = position
	return entity
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


is_within_bounds :: proc(position: Vector2) -> bool {
	if HALF_BOUNDS.x <= position.x ||
	   HALF_BOUNDS.y <= position.y ||
	   -HALF_BOUNDS.x > position.x ||
	   -HALF_BOUNDS.y > position.y {
		return false
	}

	return true
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


check_wall_collision :: proc(player_pos: Vector2, player_radius: f32, wall: Vector4) -> bool {
	// Create player AABB centered on player position
	player_half_size := player_radius / 2
	player_box := Vector4 {
		player_pos.x - player_half_size, // min x
		player_pos.y - player_half_size, // min y
		player_pos.x + player_half_size, // max x
		player_pos.y + player_half_size, // max y
	}
	// Wall is already in min/max format
	return rect_circle_collision(wall, player_pos, player_radius)
}

ENEMY_SPAWN_TIMER_MIN :: 2
ENEMY_SPAWN_TIMER_MAX :: 6


cleanup_scene :: proc() {
	for &e in game_data.enemies {
		e.active = false
		spawn_particles(e.position)
	}
	for &pickup in game_data.pickups {
		pickup.active = false
	}
	for &p in game_data.projectiles {
		p.active = false

		spawn_particles(p.position)
	}

	for &b in game_data.bombs {
		b.active = false
	}
}


reset_scene :: proc() {
	for &e in game_data.enemies {
		e.active = false

	}
	for &pickup in game_data.pickups {
		pickup.active = false
	}
	for &p in game_data.projectiles {
		p.active = false

	}

	for &p in game_data.environment_prop {
		p.active = false
		spawn_particles(p.position)
	}

	for &popup in game_data.popup_text {
		popup.active = false
	}
}


game_play :: proc() {


	dt: f32 = get_delta_time()
	app_dt: f32 = get_delta_time()
	ticks_per_second = u64(1.0 / dt)
	ticks_per_second = clamp(ticks_per_second, 60, 240)
	defer game_data.ticks += 1

	defer game_data.world_time_elapsed += app_dt

	particle_dt: f32 = get_delta_time()

	if inputs.button_just_pressed[sapp.Keycode.ESCAPE] {
		if game_data.ui_state == .pause_menu {
			game_data.ui_state = nil
		} else if game_data.ui_state == nil {
			game_data.ui_state = .pause_menu
		}
	}


	game_play_paused :=
		game_data.ui_state != nil ||
		game_data.in_transition_timer > 0 ||
		game_data.out_transition_timer > 0

	if game_play_paused {
		dt = 0.0
	}


	game_data.time_left_in_wave = math.max(0, game_data.time_left_in_wave - dt)
	game_data.enemy_spawn_timer -= dt

	if game_data.timer_to_show_player_death_ui > 0 {
		game_data.timer_to_show_player_death_ui -= app_dt
		game_data.timer_to_show_player_death_animation -= app_dt


		progress := math.min(
			game_data.timer_to_show_player_death_animation / TIMER_TO_SHOW_DEATH_ANIMATION,
			1,
		) // Clamp progress to 1
		dt = dt * (1 - math.pow(progress, 2))


		game_data.camera_zoom = math.lerp(game_data.camera_zoom, 1.3, app_dt)

		if game_data.timer_to_show_player_death_ui <= 0 {
			game_data.ui_state = .player_death
		}

		if game_data.timer_to_show_player_death_animation <= 0 {
			log.info(game_data.timer_to_show_player_death_ui)
			if game_data.player.active {
				game_data.player.active = false
				spawn_particles(game_data.player.position)
			}
		}
	}

	if game_data.time_left_in_wave <= 0 && game_data.ui_state == nil {
		dt = math.lerp(dt, 0.0, 1 - game_data.timer_to_show_upgrade / UPGRADE_TIMER_SHOW_TIME)

		game_data.timer_to_show_upgrade = math.max(game_data.timer_to_show_upgrade - app_dt, 0.0)
		if game_data.timer_to_show_upgrade <= 0 {
			game_data.timer_to_show_upgrade = UPGRADE_TIMER_SHOW_TIME
			game_data.ui_state = .upgrade_menu
			game_data.shop_in_transition_time = 0
			generate_new_shop_upgrades(nil)
			cleanup_scene()
		}


	}

	if game_data.enemy_spawn_timer <= 0 && !DEBUG_NO_ENEMIES {
		game_data.enemy_spawn_timer = rand.float32_range(
			ENEMY_SPAWN_TIMER_MIN,
			ENEMY_SPAWN_TIMER_MAX,
		)

		min := MIN_ENEMIES_PER_SPAWN
		max := math.min(
			(MAX_ENEMIES_PER_SPAWN - min) + WAVE_ENEMY_PER_SPAWN_MODIFIER * game_data.current_wave,
			MAX_EVER_ENEMIES_PER_SPAWN,
		)


		if game_data.time_left_in_wave > SPAWN_INDICATOR_TIME + 0.5 {
			amount_to_spawn: int = rand.int_max(max) + MIN_ENEMIES_PER_SPAWN
			spawn_enemy_group(amount_to_spawn)
		}


	}

	if game_data.player.active && !game_play_paused {

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

		if game_data.ui_state == nil {
			game_data.shake_amount = math.max(game_data.shake_amount - CAMERA_SHAKE_DECAY * dt, 0)
			amount := math.pow(game_data.shake_amount, SHAKE_POWER)
			// rotation = max_roll * amount * rand_range(-1, 1)

			camera.position.x += amount * rand.float32_range(-1, 1)
			camera.position.y += amount * rand.float32_range(-1, 1)
		} else {
			game_data.shake_amount = 0
		}

	}

	draw_frame.camera_xform = translate_mat4(Vector3{-camera.position.x, -camera.position.y, 0})
	set_ortho_projection(game_data.camera_zoom)

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

				// color := Vector4{0.89, 0.7, 0.3, 1.0}
				// if (x + y) % 2 == 0 {
				// 	color = Vector4{0.88, 0.67, 0.32, 1.0}
				// }

				color := COLOR_WHITE
				if !is_within_bounds(tile_pos.xy) {
					color.a = 0.3
					// color.rgb -= 0.5
					// draw_quad_xform(xform, {18, 16}, .tiles, DEFAULT_UV, color)
				}


			}
		}
	}

	{
		// LEVEL BOUNDS
		draw_quad_center_xform(Matrix4(1), FENCE_SIZE, .level_bounds)
	}

	{
		// update_render_blood(dt)
	}

	{
		update_render_props()
	}

	{
		// PERMANENCE
		render_update_permanence(dt)
	}


	{

		if game_data.knockback_radius_timer > 0 {
			game_data.knockback_radius_timer -= dt
			if game_data.knockback_radius_timer <= 0 {
				game_data.knockback_hold_timer = KNOCKBACK_RADIUS_TIME
				game_data.knockback_radius_timer = 0
			}
		}

		if game_data.knockback_radius_timer > 0 || game_data.knockback_hold_timer > 0 {
			alpha: f32 = 0
			if game_data.knockback_hold_timer > 0 {
				game_data.knockback_hold_timer -= dt

				alpha = ease_over_time(
					game_data.knockback_hold_timer,
					KNOCKBACK_RADIUS_TIME,
					.Bounce_In,
					1.0,
					0.0,
				)
			}
			current := ease_over_time(
				game_data.knockback_radius_timer,
				KNOCKBACK_RADIUS_TIME,
				.Bounce_In,
				60,
				1,
			)
			draw_quad_center_xform(
				transform_2d(game_data.knockback_position),
				{current, current},
				.circle,
				get_frame_uvs(.circle, {1, 0}, {64, 64}),
				COLOR_WHITE - {0, 0, 0, alpha},
			)
		}
	}

	if !game_play_paused {
		// XP pickups
		for &pickup in &game_data.pickups {
			if !pickup.picked_up &&
			   circles_overlap(
				   pickup.position,
				   game_data.money_pickup_radius,
				   game_data.player.position,
				   game_data.player.collision_radius,
			   ) {

				#partial switch (pickup.type) {
				case .Money:
					game_data.money += pickup.amount
					game_data.money_earned += auto_cast pickup.amount
				case .Ammo:
					game_data.current_bullets_count += pickup.amount
				case .Health:
					game_data.player.health = math.min(
						f32(pickup.amount) + game_data.player.health,
						game_data.player.max_health,
					)

				}

				pickup.picked_up = true
				pickup.start_pos = pickup.position

			}
			pickup.current_animation_timer += dt
			if pickup.current_animation_timer > MONEY_ANIM_TIME_PER_FRAME {
				pickup.current_animation_timer = 0
				if pickup.current_animation_frame >= MONEY_ANIM_FRAMES - 1 {
					pickup.current_animation_frame = 0
				} else {
					pickup.current_animation_frame += 1
				}
			}

			if pickup.picked_up {

				time_to_pickup: f32 = 0.75
				pickup.current_pickup_time += dt
				using ease
				pickup.position = {
					ease_over_time(
						pickup.current_pickup_time,
						time_to_pickup,
						.Exponential_In,
						pickup.start_pos.x,
						game_data.player.position.x,
					),
					ease_over_time(
						pickup.current_pickup_time,
						time_to_pickup,
						.Exponential_In,
						pickup.start_pos.y,
						game_data.player.position.y,
					),
				}

				if linalg.distance(pickup.position, game_data.player.position) <= 4 {
					pickup.active = false
					popup_txt: PopupText = DEFAULT_POPUP_TXT
					switch (pickup.type) {
					case .Money:
						popup_txt.text = fmt.tprintf("$%d", pickup.amount)
						popup_txt.color = hex_to_rgb(0xffd569)
					case .Ammo:
						popup_txt.text = fmt.tprintf("Ammo +%d", pickup.amount)
						popup_txt.color = hex_to_rgb(0xffd569)
					case .Health:
						popup_txt.text = fmt.tprintf("Health +%d", pickup.amount)
						popup_txt.color = hex_to_rgb(0xe84444)
					case .Shotgun:
						popup_txt.text = "+Shotgun"
						popup_txt.color = COLOR_WHITE
						add_shotgun_to_player()
					case .SMG:
						popup_txt.text = "+SMG"
						popup_txt.color = COLOR_WHITE
						add_smg_to_player()
					case .MachineGun:
						popup_txt.text = "+Machine Gun"
						popup_txt.color = COLOR_WHITE
						add_machine_gun_to_player()
					case .Sniper:
						popup_txt.text = "+Sniper"
						popup_txt.color = COLOR_WHITE
						add_sniper_to_player()
					}


					popup_txt.position = pickup.position
					append(&game_data.popup_text, popup_txt)
				}
			}

			draw_pos := pickup.position
			draw_pos.y += sine_breathe_alpha(game_data.world_time_elapsed * 0.5) * 6
			xform := translate_mat4({draw_pos.x, draw_pos.y, 0.0})

			switch (pickup.type) {
			case .Money, .Ammo, .Health:
				uvs := get_frame_uvs(
					.money,
					{pickup.current_animation_frame, auto_cast pickup.type},
					{16, 16},
				)
				draw_quad_center_xform(xform, {12, 12}, .money, uvs, COLOR_WHITE)
			case .Shotgun, .SMG, .MachineGun, .Sniper:
				uvs := get_frame_uvs(
					.weapons,
					{auto_cast pickup_to_weapon_enum(pickup.type), 0},
					{24, 24},
				)
				draw_quad_center_xform(xform, {24, 24}, .money, uvs, COLOR_WHITE)
			}


		}
	}


	{
		using sapp.Keycode
		using sapp
		// PLAYER LOGIC
		using game_data


		// if can_player_move {
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
		} else if player.animation_state != .IDLE {
			set_ent_animation_state(&player, .IDLE)
		}

		update_player_timers(&player, dt)
		update_player_animations(&player, dt)


		speed := player.speed

		if !game_play_paused && inputs.button_just_pressed[Keycode.SPACE] {
			if player.dodge_roll_cooldown <= 0 && player.animation_state != .ROLLING {
				direction: Vector2 = player_input != V2_ZERO ? player_input : {1, 0}
				player.velocity = direction * PLAYER_DODGE_ROLL_PWR
				set_ent_animation_state(&player, .ROLLING)
				player.dodge_roll_cooldown = PLAYER_ROLLDOWN_COOLDOWN
				player.roll_timer = PLAYER_DODGE_ROLL_TIME
			}

		}

		if player.roll_timer > 0 {

			player.roll_timer -= dt

			x_normalized := math.sign(x)
			if run_every_seconds(0.075) {
				spawn_walking_particles(
					player.position + {-x_normalized * 2, -5},
					COLOR_WHITE,
					{-x, -y},
				)
			}

			if player.roll_timer <= 0 {
				player.roll_timer = 0
				set_ent_animation_state(&player, .WALKING)
			}
		}


		rotation_z := calc_rotation_to_target(mouse_world_position, player.position)
		delta_x := PLAYER_GUN_MOVE_DIST * math.cos(-rotation_z)
		delta_y := PLAYER_GUN_MOVE_DIST * math.sin(-rotation_z)
		attack_position: Vector2 = player.position + {delta_x, -delta_y}


		if game_data.current_bullets_count == 0 {
			if player.reload_timer <= 0 {
				game_data.current_bullets_count =
					game_data.max_bullets + game_data.weapon_max_bullets
			}
		}
		JUST_FIRED_TIME: f32 : 0.15
		game_data.player.just_fired_timer -= dt
		if !game_play_paused &&
		   inputs.mouse_down[Mousebutton.LEFT] &&
		   player.weapon_cooldown_timer <= 0 &&
		   game_data.current_bullets_count > 0 &&
		   player.reload_timer <= 0 {
			game_data.player.just_fired_timer = JUST_FIRED_TIME

			if game_data.player_upgrade[.BULLETS] == 0 {
				game_data.player_upgrade[.BULLETS] = 1
			}

			points, angles := generate_points_rotation_around_circle(
				3,
				game_data.player_upgrade[.BULLETS],
				(game_data.bullet_spread + game_data.bullet_spread) *
				auto_cast game_data.player_upgrade[.BULLETS],
			)

			spread :=
				(game_data.bullet_spread + game_data.bullet_spread) +
				auto_cast game_data.player_upgrade[.BULLETS]
			camera_shake(0.45)
			play_sound("event:/gunshot")
			for i := 0; i < game_data.player_upgrade[.BULLETS]; i += 1 {
				if game_data.current_bullets_count > 0 {
					game_data.current_bullets_count -= 1
					rotation_with_randomness :=
						rotation_z + math.to_radians(rand.float32_range(-spread, spread))
					attack_direction: Vector2 = {
						math.cos(rotation_with_randomness),
						math.sin(rotation_with_randomness),
					}
					create_player_projectile(
						points[i] + attack_position,
						attack_direction,
						rotation_with_randomness,
					)
					create_bullet_shell_permanence(&game_data.player, attack_direction * 700)
				}

			}

			if game_data.current_bullets_count <= 0 {
				play_sound("event:/reload")
				player.reload_timer = (game_data.time_to_reload + game_data.weapon_time_to_reload)

				if should_spawn_upgrade(.BOMB_DROP_RELOAD) {
					bomb: Bomb
					bomb.active = true
					bomb.position = game_data.player.position
					append(&game_data.bombs, bomb)
				}
				if game_data.player_upgrade[.PIERCING_SPIKE_RELOAD] >= 1 {
					create_quintuple_projectiles_spikes(game_data.player.position, .ENEMY)
				}
			}

			if player.animation_state == .ROLLING {
				set_ent_animation_state(&player, .WALKING)
			}

			player.weapon_cooldown_timer = game_data.weapon_fire_rate + game_data.fire_rate
			delete(points)
			delete(angles)
		}


		potential_pos := player.position + player_input * dt * player.current_speed

		if player.roll_timer > 0 {
			potential_pos = player.position + player.velocity * dt
		}

		// left wall
		if check_wall_collision(potential_pos, game_data.player.collision_radius, WALLS[0]) {
			player_input.x = math.max(0, player_input.x)
			player.velocity = V2_ZERO
		}

		// bottom wall
		if check_wall_collision(potential_pos, game_data.player.collision_radius, WALLS[1]) {
			player_input.y = math.max(0, player_input.y)
			player.velocity = V2_ZERO
		}


		// right wall
		if check_wall_collision(potential_pos, game_data.player.collision_radius, WALLS[2]) {
			player_input.x = math.min(0, player_input.x)
			player.velocity = V2_ZERO
		}

		// top wall
		if check_wall_collision(potential_pos, game_data.player.collision_radius, WALLS[3]) {
			player_input.y = math.min(0, player_input.y)
			player.velocity = V2_ZERO
		}

		if player.roll_timer > 0 {
			player.position = player.position + player.velocity * dt
		} else {
			player.position = player.position + player_input * dt * player.current_speed
		}


		frame_x := player.current_animation_frame
		frame_y: int = auto_cast player.animation_state

		uvs := get_frame_uvs(.player, {frame_x, frame_y}, {18, 18})
		flash_amount: f32 = 0
		if player.i_frame_timer > 0 {
			flash_amount = 1
		}

		if player.health <= 0 {
			uvs = get_frame_uvs(.player, {0, 3}, {18, 18})
		}


		if player.active || player.health <= 0 {

			flip_x := mouse_world_position.x < game_data.player.position.x

			xform := transform_2d(game_data.player.position, 0, {flip_x ? -1 : 1, 1})
			draw_quad_center_xform(
				xform,
				{auto_cast 18, auto_cast 18},
				.player,
				uvs,
				COLOR_WHITE,
				flash_amount,
			)

			weapon_rotation_angle := calc_rotation_to_target(mouse_world_position, player.position)


			xform = transform_2d(player.position)


			if flip_x {
				xform *= linalg.matrix4_scale_f32({-1, 1, 1})
				weapon_rotation_angle = -calc_rotation_to_target(
					player.position,
					mouse_world_position,
				)
			}

			xform *=
				linalg.matrix4_rotate(weapon_rotation_angle, Vector3{0, 0, 1}) *
				linalg.matrix4_translate_f32({-5, -12, 0.0})

			if player.just_fired_timer > 0 {
				v := ease_over_time(player.just_fired_timer, JUST_FIRED_TIME, .Cubic_Out, 0, -5)
				scale_x := ease_over_time(
					player.just_fired_timer,
					JUST_FIRED_TIME,
					.Cubic_Out,
					1,
					0.85,
				)

				scale_y := ease_over_time(
					player.just_fired_timer,
					JUST_FIRED_TIME,
					.Cubic_Out,
					1,
					1.3,
				)

				xform *= transform_2d({v, 0}, 0, {scale_x, scale_y})
			}


			weapon_uvs := get_frame_uvs(
				.weapons,
				{auto_cast player.last_weapon_pickup, 0},
				{24, 24},
			)

			if player.health > 0 {
				draw_quad_xform(xform, {auto_cast 24, auto_cast 24}, .weapons, weapon_uvs)
			}

			if game_data.current_bullets_count == 0 && player.reload_timer > 0 {
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


				t_normalized :=
					1.0 -
					(player.reload_timer /
							(game_data.time_to_reload + game_data.weapon_time_to_reload))
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
	}

	{
		// ORBS
		if game_data.player_upgrade[.ROTATING_ORB] > 0 && game_data.player.active {
			radius: f32 = 20
			speed: f32 = 25
			points, angles := generate_points_rotation_around_circle(
				radius,
				game_data.player_upgrade[.ROTATING_ORB],
				360,
			)
			uvs := get_frame_uvs(.circle, {0, 0}, {64, 64})


			for i := 0; i < len(points); i += 1 {
				starting_angle: f32 = angles[i]
				angle: f32 = math.to_radians(f32(game_data.ticks) * speed * dt) + starting_angle
				orb_position := Vector2{radius * math.cos(angle), radius * math.sin(angle)}
				circle_radius: f32 = 6
				if run_every_seconds(1.0) {
					particle_color := hex_to_rgb(0x9bf0fd)
					particle_color.a = 0.5
					spawn_orb_particles(
						game_data.player.position + orb_position,
						particle_color,
						{},
					)
				}


				for &e in game_data.enemies {
					if e.active && e.stun_timer <= 0 {
						if circles_overlap(
							game_data.player.position + orb_position,
							circle_radius,
							e.position,
							e.collision_radius,
						) {
							create_blood_particle(
								&e,
								linalg.normalize(
									e.position - game_data.player.position + orb_position,
								),
							)
							damage_enemy(
								&e,
								game_data.orb_damage_per_hit,
								linalg.normalize(
									e.position - game_data.player.position + orb_position,
								),
							)

						}
					}
				}

				draw_quad_xform(
					transform_2d(game_data.player.position + orb_position),
					{circle_radius, circle_radius},
					.orb,
					uvs,
					hex_to_rgb(0x9bf0fd),
				)
			}


			delete(points)
			delete(angles)
		}

	}


	{

		BOMB_ANIMATION_TIME: f32 : 0.25
		BOMB_ANIMATION_FRAMES: int : 6
		BOMB_LAST_FRAME_HOLD_TIME: f32 : 0.35
		// @bombs
		for &bomb in game_data.bombs {
			bomb.current_animation_timer += dt
			if bomb.current_animation_timer > BOMB_ANIMATION_TIME {
				bomb.current_animation_timer = 0
				if bomb.current_animation_frame < BOMB_ANIMATION_FRAMES - 1 {
					bomb.current_animation_frame += 1
				}
			}

			if bomb.current_animation_frame >= BOMB_ANIMATION_FRAMES - 1 {
				bomb.last_frame_timer += dt

				if bomb.last_frame_timer > BOMB_LAST_FRAME_HOLD_TIME {
					bomb.active = false
					create_explosion(bomb.position)
				}

			}


			draw_quad_center_xform(
				transform_2d(bomb.position),
				{16, 16},
				.bomb,
				get_frame_uvs(.bomb, {bomb.current_animation_frame, 0}, {18, 18}),
				COLOR_WHITE,
				bomb.current_animation_frame >= BOMB_ANIMATION_FRAMES - 1 ? 1 : 0,
			)
		}
	}

	{
		// @enemies
		for &enemy in game_data.enemies {
			if enemy.health <= 0 {
				r_n := rand.int_max(20)


				if r_n <= 13 {
					amount := 1
					type: PickupType = .Health
					if r_n <= 11 {
						amount = rand.int_max(5) + 1
						type = .Money
					} else if r_n <= 12 {
						amount = rand.int_max(6) + 1
						type = .Ammo
					} else {
						amount = rand.int_max(1) + 1
					}

					mp: Pickup
					mp.position = enemy.position
					mp.active = true
					mp.picked_up = false
					mp.type = type
					mp.amount = amount
					append(&game_data.pickups, mp)
				} else if r_n <= 14 {
					type: PickupType = weapon_to_pickup_enum(
						auto_cast (1 + rand.int_max(len(Weapon) - 1)),
					)


					mp: Pickup
					mp.position = enemy.position
					mp.active = true
					mp.picked_up = false
					mp.amount = 0
					mp.type = type
					append(&game_data.pickups, mp)
				}


				enemy.active = false
				game_data.enemies_killed += 1
				if enemy.type == .EXPLOSIVE_CHASER {
					create_explosion(enemy.position)
				} else if should_spawn_upgrade(.EXPLODING_ENEMIES) {
					create_explosion(enemy.position)
				}


				if enemy.type == .SLUG {
					create_bby_slugs(enemy.position)
				}

				continue
			}

			if !enemy.active {
				continue
			}

			if enemy.spawn_indicator_timer > 0 {
				enemy.spawn_indicator_timer -= dt
				pos := enemy.position
				pos.y += sine_breathe_alpha(game_data.world_time_elapsed * 1.3) * 3
				color := COLOR_WHITE
				color.a -= sine_breathe_alpha(game_data.world_time_elapsed * 0.45)
				color.a = math.max(0.3, color.a)
				draw_quad_center_xform(
					transform_2d(pos),
					{16, 16},
					.spawn_indicator,
					DEFAULT_UV,
					color,
				)

				continue
			}
			if game_data.player.active &&
			   game_data.timer_to_show_player_death_animation <= 0 &&
			   enemy.attack_direction == V2_ZERO &&
			   linalg.distance(enemy.position, game_data.player.position) > 8 {
				enemy.flip_x = enemy.position.x < game_data.player.position.x
			}

			if !game_play_paused && game_data.player.active {
				enemy_update(&enemy, dt)
			}


			flash_amount: f32 = 0
			if enemy.knockback_timer > 0 || enemy.stun_timer > 0.2 {
				flash_amount = 1
			}


			position := enemy.position
			scale := V2_ONE
			if enemy.state == .WALKING {
				scale.x -= sine_breathe_alpha(game_data.world_time_elapsed) * 0.05
				scale.x += cos_breathe_alpha(game_data.world_time_elapsed) * 0.05

				scale.y += sine_breathe_alpha(game_data.world_time_elapsed) * 0.05
				scale.y -= cos_breathe_alpha(game_data.world_time_elapsed) * 0.05
			}

			if enemy.state == .JUMPING {
				scale.x -= 0.35
			}

			if enemy.state == .WALKING {
				position.y += sine_breathe_alpha(game_data.world_time_elapsed) * enemy.speed * 0.1
				position.y -= cos_breathe_alpha(game_data.world_time_elapsed) * enemy.speed * 0.1
			}


			rotation :=
				cos_breathe_alpha(game_data.world_time_elapsed * 0.5) * 0.05 -
				sine_breathe_alpha(game_data.world_time_elapsed * 0.5) * 0.05


			// RENDER ENEMIES
			xform := transform_2d(position, 0, {scale.x, scale.y})


			shadows_xform := transform_2d(enemy.position + {-1, -3})
			if enemy.state == .JUMPING {
				shadows_xform = transform_2d({enemy.position.x, enemy.ground_y} + {0, -3})
			}

			if enemy.state == .WALKING {
				xform *= transform_2d({-5, -5}, rotation)
				xform *= transform_2d({5, 5})
			}


			if enemy.flip_x {
				xform *= linalg.matrix4_scale_f32({-1, 1, 1})
			}


			if enemy.type == .TANK {
				xform *= linalg.matrix4_scale_f32({1.5, 1.5, 1})
				shadows_xform *= linalg.matrix4_scale_f32({1.5, 1.5, 1})
			}

			sprite_y_index: int = auto_cast enemy.type
			update_entity_timers(&enemy, dt)

			knockback_logic_update(&enemy, dt, ENEMY_KNOCKBACK_VELOCITY, &enemy.position)

			uvs := get_frame_uvs(.enemies, {0, sprite_y_index}, {18, 18})
			shadow_uvs := get_frame_uvs(.shadows, {0, sprite_y_index}, {18, 18})

			draw_quad_center_xform(shadows_xform, {18, 18}, .shadows, shadow_uvs, COLOR_WHITE)


			if enemy.type == .BULL && enemy.state == .PREP_ATTACK {
				attack_indicator_size := Vector2{150, 28}
				circle_center: f32 = 16.0
				attack_indicator_half_width := attack_indicator_size.x * 0.5
				target_rotation := math.atan2(enemy.attack_direction.y, enemy.attack_direction.x)
				target_xform := transform_2d(
					enemy.position + {attack_indicator_half_width, -18 * 0.5} - {circle_center, 0},
				)

				draw_quad_center_xform(
					target_xform *
					transform_2d({-attack_indicator_half_width + circle_center, 0}) *
					transform_2d({}, target_rotation) *
					transform_2d({attack_indicator_half_width - circle_center, 0}),
					attack_indicator_size,
					.bull_attack_indicator,
					DEFAULT_UV,
					COLOR_WHITE - {0, 0, 0, 0.3},
				)
			}


			color := COLOR_WHITE

			if enemy.statuses[.Poison] {
				color = hex_to_rgb(0xccf61f)
			} else if enemy.statuses[.Frozen] {
				color = hex_to_rgb(0x9bf0fd)
			}
			if enemy.type == .DISK {
				xform = transform_2d(enemy.position, enemy.rotation)
			}
			draw_quad_center_xform(xform, {18, 18}, .enemies, uvs, color, flash_amount)


			if enemy.type == .GUNNER {
				weapon_rotation_angle := calc_rotation_to_target(
					game_data.player.position,
					enemy.position,
				)


				xform = transform_2d(enemy.position)

				if enemy.flip_x {
					xform *= linalg.matrix4_scale_f32({-1, 1, 1})
					weapon_rotation_angle = -calc_rotation_to_target(
						enemy.position,
						game_data.player.position,
					)
				}

				xform *=
					linalg.matrix4_rotate(weapon_rotation_angle, Vector3{0, 0, 1}) *
					linalg.matrix4_scale_f32({1, -1, 1}) *
					linalg.matrix4_translate_f32({-5, -12, 0.0})


				weapon_uvs := get_frame_uvs(.weapons, {1, 0}, {24, 24})
				draw_quad_xform(xform, {auto_cast 24, auto_cast 24}, .weapons, weapon_uvs)
			}

			if enemy.health != enemy.max_health {
				draw_status_bar(
					enemy.position + {0.0, 12},
					{1, 0, 0, 1},
					auto_cast enemy.health,
					auto_cast enemy.max_health,
				)
			}

			if enemy.statuses[.Frozen] {
				xform := transform_2d(enemy.position + {0.0, 25})
				uv := get_frame_uvs(.statues, {0, 0}, {16, 16})
				draw_quad_center_xform(xform, {16, 16}, .statues, uv)
			}

			if enemy.statuses[.Poison] {
				uv := get_frame_uvs(.statues, {0, 1}, {16, 16})
				xform := transform_2d(enemy.position + {0.0, 25})
				if enemy.flip_x {
					xform *= linalg.matrix4_scale_f32({-1, 1, 1})
				}
				draw_quad_center_xform(xform, {16, 16}, .statues, uv)
			}

		}


	}


	{
		// PROJECTILES
		for &p in &game_data.projectiles {
			distance_this_frame := p.velocity * dt
			p.position += distance_this_frame
			p.current_distance_traveled += linalg.length(distance_this_frame)


			if p.current_distance_traveled > p.distance_limit {
				p.active = false
				create_bullet_death(&p)
				continue
			}

			if !p.active {
				continue
			}

			p.current_animation_time += dt

			if p.current_frame < p.animation_count - 1 &&
			   p.current_animation_time > p.time_per_frame {
				p.current_frame += 1
				p.current_animation_time = 0
			}

			if p.target == .ENEMY {
				// spawn_bullet_partciles(p.position, hex_to_rgb(0xffed73), p.velocity)
			}


			if p.target != .PLAYER {
				for &e in game_data.enemies {
					if (!e.active || e.spawn_indicator_timer > 0) {
						continue
					}

					if (p.last_hit_ent_id != e.id &&
						   circles_overlap(p.position, 6, e.position, 6)) {

						e.stun_timer = game_data.enemy_stun_time
						if !should_spawn_upgrade(.PIERCING_SHOT) {
							p.active = false

							if game_data.player_upgrade[Upgrade.BOUNCE_SHOT] > p.bounce_count {

								reflection := linalg.normalize(
									linalg.reflect(
										linalg.normalize(p.velocity),
										calculate_collision_point_circle_overlap(
											e.position,
											p.position,
											6,
										),
									),
								)
								create_player_projectile(
									p.position,
									reflection,
									calc_rotation_to_target(p.position, reflection),
									e.id,
									p.hits,
									p.bounce_count + 1,
								)
							}
						} else {
							p.hits += 1
							p.last_hit_ent_id = e.id
						}

						// create_blood_particle(&e, linalg.normalize(p.velocity))


						damage_enemy(&e, p.damage_to_deal, p.velocity)

						if should_spawn_upgrade(.BULLETS_CAUSE_FREEZE) {
							e.statuses[.Frozen] = true
						}

						if should_spawn_upgrade(.BULLETS_CAUSE_POISON) {
							e.statuses[.Poison] = true
						}
						if p.target == .ENEMY {
							create_bullet_death(&p)
						} else {
							spawn_particles(p.position, hex_to_rgb(0xf85a5a))
						}


						if e.health <= 0 {
							spawn_particles(e.position, COLOR_WHITE)

						}

						break
					}
				}
			}

			if p.target != .ENEMY &&
			   circles_overlap(
				   p.position,
				   4,
				   game_data.player.position,
				   game_data.player.collision_radius,
			   ) &&
			   game_data.player.animation_state != .ROLLING {
				// PLAYER dmg

				p.active = false
				damage_player(p.damage_to_deal, .projectile)
			}

			for &prop in game_data.environment_prop {

				if !prop.active || !prop.destructible {
					continue
				}

				if prop.active && circles_overlap(p.position, 5, prop.position, 5) {
					if p.target == .ENEMY {
						create_bullet_death(&p)
					}
					if prop.type == .cactus {
						create_quintuple_projectiles(prop.position, .ALL)

					}

					if prop.type == .tnt {
						create_explosion(prop.position)
					}
					create_prop_permanence(prop)
					prop.active = false
					p.active = false
				}

			}

			xform := transform_2d(p.position, p.rotation, p.scale)


			uvs := get_frame_uvs(
				.projectiles,
				{p.sprite_cell_start.x + p.current_frame, p.sprite_cell_start.y},
				{16, 16},
			)
			draw_quad_center_xform(xform, {auto_cast 18, auto_cast 18}, .projectiles, uvs)
		}


		update_render_particles(particle_dt)
	}


	{
		//explosions
		for &explosion in &game_data.explosions {
			color := COLOR_WHITE
			if explosion.current_lifetime <= (EXPLOSION_LIFETIME * 0.1) {
				color = COLOR_BLACK
			}
			explosion.current_lifetime += dt

			if explosion.current_lifetime >= explosion.max_lifetime {
				explosion.active = false
			}
			draw_quad_center_xform(
				transform_2d(explosion.position),
				{explosion.size, explosion.size},
				.circle,
				get_frame_uvs(.circle, {0, 0}, {64, 64}),
				color,
			)
		}
	}

	{
		// DEBUGGER TOOLS
		alpha: f32 = 0.2
		if DEBUG_HITBOXES {

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


			for wall in WALLS {
				draw_rect_xform(transform_2d(wall.xy), wall.zw, {0, 0, 0, 0.1})
			}


			xform := linalg.matrix4_translate_f32(
				{game_data.player.position.x, game_data.player.position.y, alpha},
			)


			draw_quad_center_xform(
				xform,
				{game_data.player.collision_radius, game_data.player.collision_radius},
				.nil,
				DEFAULT_UV,
				{0, 0, 1, alpha},
			)
		}
	}

	{
		for &popup_txt in game_data.popup_text {
			popup_txt.life_time += dt


			t := popup_txt.life_time / MAX_POPUP_TEXT_LIFE_TIME
			eased_t := ease.cubic_in(t)

			start_value: f32 = 0.0
			end_value: f32 = 10.0
			current_value := start_value + eased_t * (end_value - start_value)
			start_alpha_value: f32 = 1.0
			end_alpha_value: f32 = 0.0
			current_alpha_value :=
				start_alpha_value + eased_t * (end_alpha_value - start_alpha_value)
			color := popup_txt.color
			border_color := COLOR_BLACK
			color.a = current_alpha_value
			border_color.a = current_alpha_value

			if popup_txt.life_time >= MAX_POPUP_TEXT_LIFE_TIME {
				popup_txt.active = false
			}
			draw_text_outlined_center(
				transform_2d(popup_txt.position + {0, current_value}),
				popup_txt.text,
				8 * popup_txt.scale,
				0.5 * popup_txt.scale,
				0.5 * popup_txt.scale,
				color,
				border_color,
			)
		}
	}


	draw_frame.camera_xform = identity()

	mouse_ui_pos := mouse_to_matrix()

	{
		// Base UI
		set_ui_projection_alignment(.bottom_left)
		_, height := get_ui_dimensions()
		using game_data
		base_pos_y := 0.9 * height
		padding: f32 = 8
		draw_quad_xform(
			transform_2d({10, base_pos_y}),
			{64, 64},
			.ui,
			get_frame_uvs(.ui, {0, 0}, {16, 16}),
		)
		draw_text_outlined(
			transform_2d({50, base_pos_y}),
			fmt.tprintf("Money: $%d", game_data.money),
			32,
		)

		draw_quad_xform(
			transform_2d({10, base_pos_y - (64 + padding)}),
			{64, 64},
			.ui,
			get_frame_uvs(.ui, {0, 1}, {16, 16}),
		)

		draw_text_outlined(
			transform_2d({50, base_pos_y - (64 + padding)}),
			fmt.tprintf("Health: %.0f/%.0f", player.health, player.max_health),
			32,
		)

		draw_quad_xform(
			transform_2d({10, base_pos_y - (64 + padding) * 2}),
			{64, 64},
			.ui,
			get_frame_uvs(.ui, {0, 2}, {16, 16}),
		)

		draw_text_outlined(
			transform_2d({50, base_pos_y - (64 + padding) * 2}),
			fmt.tprintf(
				"Ammo: %d/%d",
				game_data.current_bullets_count,
				game_data.max_bullets + game_data.weapon_max_bullets,
			),
			32,
		)

	}


	{
		{
			set_ui_projection_alignment(.bottom_center)
			using sapp
			_, w_height := get_ui_dimensions()

			draw_text_outlined_center(
				transform_2d({0, w_height - 100}),
				fmt.tprintf("Wave %d", game_data.current_wave),
				30,
				4.0,
			)
			draw_text_outlined_center(
				transform_2d({0, w_height - 145}),
				fmt.tprintf("Time left %.0f", game_data.time_left_in_wave),
				30,
				4.0,
			)
		}


		set_ui_projection_alignment(.center_center)
		w_width, w_height := get_ui_dimensions()
		mouse_world_position = mouse_to_matrix()
		// UPGRADE MENU
		SHOP_TRANS_TIME: f32 : 1.0

		if game_data.ui_state == .upgrade_menu {
			game_data.shop_in_transition_time += app_dt

			offset_y := ease_over_time(
				game_data.shop_in_transition_time,
				SHOP_TRANS_TIME,
				.Bounce_Out,
				auto_cast -w_height,
				0,
			)

			if game_data.shop_in_transition_time >= SHOP_TRANS_TIME {
				offset_y = 0

				if game_data.shop_out_transition_time > 0 {
					game_data.shop_out_transition_time -= app_dt
					if game_data.shop_out_transition_time <= 0 {
						game_data.ui_state = nil
					}
					offset_y = ease_over_time(
						game_data.shop_out_transition_time,
						SHOP_TRANS_TIME,
						.Quartic_Out,
						auto_cast -w_height,
						0,
					)
				}
			}

			draw_frame.camera_xform = translate_mat4(Vector3{0, -offset_y, 0})

			draw_rect_center_xform(transform_2d({0, 0}), {w_width, w_height}, {0, 0, 0, 0.3})

			upgrade_sign_size := Vector2{184, 84} * 2.5
			draw_quad_xform(
				transform_2d({-upgrade_sign_size.x * 0.5, (w_height * 0.5) - upgrade_sign_size.y}),
				upgrade_sign_size,
				.upgrade_sign,
			)

			box_width: f32 = 250
			box_height: f32 = 350
			padding: f32 = 10
			xform := transform_2d({-box_width - padding, 0.0})
			position: Vector2 = {-box_width - padding, 0.0}

			button_height: f32 = 20 * 4
			button_width: f32 = 64 * 4

			card_size: Vector2 = {40, 52} * 5
			card_uv := get_frame_uvs(.card, {0, 0}, card_size / 5)
			card_disalbed_uv := get_frame_uvs(.card, {1, 0}, card_size / 5)
			card_shadow_uv := get_frame_uvs(.card, {2, 0}, card_size / 5)


			allow_inputs := offset_y == 0

			for i := 0; i < len(game_data.next_upgrades); i += 1 {
				shadow_size := card_size
				hover := false
				id: UiID = auto_cast i + 1


				disabled :=
					game_data.next_upgrades[i].purchased ||
					game_data.next_upgrades[i].cost > game_data.money ||
					!allow_inputs

				if !disabled && aabb_contains(position, card_size, mouse_world_position) {
					ui_state.hover_id = id
					hover = true
				}


				if !disabled &&
				   inputs.mouse_down[sapp.Mousebutton.LEFT] &&
				   ui_state.hover_id == id {
					ui_state.down_clicked_id = id
				}

				if !disabled &&
				   ui_state.hover_id == id &&
				   !ui_state.click_captured &&
				   inputs.mouse_just_pressed[sapp.Mousebutton.LEFT] &&
				   ui_state.down_clicked_id == id {
					ui_state.click_captured = true
					purchase_shop_upgrade(&game_data.next_upgrades[i])
				}


				offset: f32 = (auto_cast i * math.PI * 300) + math.PI * 200
				card_xform := xform
				shadow_xform := card_xform
				if !hover {
					card_xform =
						xform *
						transform_2d(
							{
								0,
								sine_breathe_alpha(
									(game_data.world_time_elapsed + offset) * 0.35,
								) *
								25,
							},
							(cos_breathe_alpha(game_data.world_time_elapsed * 0.5 + offset) *
									0.05 -
								sine_breathe_alpha(game_data.world_time_elapsed * 0.5 + offset) *
									0.05),
						)

					shadow_xform = card_xform
				} else {
					t := ui_state.hover_time / HOVER_TIME
					eased_t := ease.elastic_out(t)
					start_value: f32 = 0.0
					end_value: f32 = 40.0
					current_value := start_value + eased_t * (end_value - start_value)

					start_scale_value: f32 = 1.0
					end_scale_value: f32 = 1.15
					current_scale_value :=
						start_scale_value + eased_t * (end_scale_value - start_scale_value)
					shadow_size += current_value * 0.15
					scale := current_scale_value
					card_xform =
						xform *
						transform_2d(
							{current_value * 0.1, current_value},
							(cos_breathe_alpha(game_data.world_time_elapsed * 0.5 + offset) *
									0.05 -
								sine_breathe_alpha(game_data.world_time_elapsed * 0.5 + offset) *
									0.05),
							scale,
						)

					shadow_xform =
						xform *
						transform_2d(
							{},
							(cos_breathe_alpha(game_data.world_time_elapsed * 0.5 + offset) *
									0.05 -
								sine_breathe_alpha(game_data.world_time_elapsed * 0.5 + offset) *
									0.05),
							scale,
						)
				}

				draw_quad_center_xform(
					shadow_xform * transform_2d({-15, -25}),
					shadow_size,
					.card,
					card_shadow_uv,
				)
				draw_quad_center_xform(
					card_xform,
					card_size,
					.card,
					disabled ? card_disalbed_uv : card_uv,
				)
				heading := get_upgrade_heading(game_data.next_upgrades[i].upgrade)
				description := get_upgrade_description(game_data.next_upgrades[i].upgrade)
				draw_text_constrainted_center_outlined(
					card_xform * transform_2d({0, 80}),
					heading,
					card_size.x * 0.75,
					30,
					4,
				)
				draw_text_constrainted_center_outlined(
					card_xform,
					description,
					card_size.x * 0.75,
					18,
					2,
					2,
				)
				draw_text_outlined_center(
					card_xform * transform_2d({0, -100}),
					fmt.tprintf("$%d", game_data.next_upgrades[i].cost),
					40,
					4,
				)


				position += {box_width + padding, 0}
				xform = xform * transform_2d({box_width + padding, 0.0})
			}

			if image_button(
				{
					-button_width * 0.5 - padding * 0.5,
					-box_height * 0.5 - padding * 1.5 - button_height * 0.5,
				},
				fmt.tprintf("Reroll shop: $%d", game_data.reroll_cost),
				28,
				10,
				{button_width, button_height},
				game_data.reroll_cost > game_data.money,
			) {
				game_data.money -= game_data.reroll_cost
				generate_new_shop_upgrades(game_data.next_upgrades[:])
				game_data.reroll_cost += REROLL_COST_MODIFIER
			}
			if image_button(
				{
					button_width * 0.5 + padding * 0.5,
					-box_height * 0.5 - padding * 1.5 - button_height * 0.5,
				},
				"Next Wave",
				28,
				20,
				{button_width, button_height},
			) {
				game_data.shop_out_transition_time = SHOP_TRANS_TIME
				game_data.current_wave += 1
				game_data.time_left_in_wave =
					INITIAL_WAVE_TIME + WAVE_TIME_MODIFIER * auto_cast game_data.current_wave
				game_data.reroll_cost = INITIAL_REROLL_COST
				game_data.current_bullets_count =
					game_data.max_bullets + game_data.weapon_max_bullets

				reset_scene()
				setup_scene_props()
			}

		}

		if game_data.ui_state == .pause_menu {
			w, h := get_ui_dimensions()


			draw_rect_center_xform(transform_2d({0, 0}), {w, h}, COLOR_BLACK - {0, 0, 0, 0.55})
			left_align_padding: f32 = 50

			left_pos: f32 = -auto_cast w * f32(0.5) + left_align_padding
			button_spacing_y: f32 = 65


			draw_text_outlined_center(transform_2d({0, 150}), "Paused..", 50, 4.0)

			if text_button({left_pos, button_spacing_y}, "Resume", 40, 1) {
				game_data.ui_state = nil
			}
			if text_button({left_pos, 0}, "Options", 40, 2) {

			}
			if text_button({left_pos, -button_spacing_y}, "Restart", 40, 3) {
				restart_run()

			}
			if text_button({left_pos, -button_spacing_y * 2}, "Exit", 40, 4) {
				log.info("EXIT PRESSED")
				sapp.quit()
			}


		}

		if game_data.ui_state == .player_death {
			w, h := get_ui_dimensions()
			draw_rect_center_xform(transform_2d({0, 0}), {w, h}, COLOR_BLACK - {0, 0, 0, 0.65})
			button_pos_y: f32 = 0
			button_font_size: f32 : 30
			button_margin: f32 : 15
			button_size := Vector2{60, 24} * 4

			draw_text_outlined_center(transform_2d({0, 120}), "PLAYER DEAD", 48)
			draw_text_outlined_center(transform_2d({0, 70}), "GAME OVER", 48)

			stat_img_x: f32 = 60
			stat_img_y: f32 = -200
			draw_quad_center_xform(transform_2d({-stat_img_x, stat_img_y}), {80, 80}, .skull)
			draw_quad_center_xform(
				transform_2d({stat_img_x, stat_img_y}),
				{80, 80},
				.money,
				get_frame_uvs(.money, {0, 0}, {16, 16}),
			)
			draw_text_center_center(
				transform_2d({-stat_img_x + 3, stat_img_y - 50}),
				fmt.tprintf("%d", game_data.enemies_killed),
				30,
			)
			draw_text_center_center(
				transform_2d({stat_img_x + 3, stat_img_y - 50}),
				fmt.tprintf("%d", game_data.money_earned),
				30,
			)

			if image_button({0, button_pos_y}, "Restart Run", button_font_size, 1, button_size) {
				restart_run()
			}
			button_pos_y -= button_margin + button_size.y

			if image_button({0, button_pos_y}, "Exit", button_font_size, 2, button_size) {
				log.info("GAME QUIT PRESSED")
				sapp.quit()
			}
		}

	}


	if ui_state.hover_id != 0 {
		ui_state.hover_time += app_dt
	}


	{
		scale: f32 = 16
		sapp.show_mouse(false)
		set_ortho_projection(scale)
		mouse_world_position = mouse_to_matrix()
		draw_quad_center_xform(
			transform_2d(mouse_world_position, auto_cast game_data.world_time_elapsed * 0.1),
			{14 / scale, 14 / scale},
			.cursor,
		)
	}

	transition(app_dt)


	{
		// CLEANUP frame
		cleanup_base_entity(&game_data.enemies)
		cleanup_base_entity(&game_data.projectiles)
		cleanup_base_entity(&game_data.particles)
		cleanup_base_entity(&game_data.sprite_particles)
		cleanup_base_entity(&game_data.pickups)
		cleanup_base_entity(&game_data.explosions)
		cleanup_base_entity(&game_data.permanence)
		cleanup_base_entity(&game_data.environment_prop)
		cleanup_base_entity(&game_data.popup_text)
		cleanup_base_entity(&game_data.bombs)
		cleanup_base_entity(&game_data.blood)
	}
}

MAIN_MENU_CLEAR_COLOR: sg.Color : {1, 1, 1, 1}


UiID :: u32

HOVER_TIME: f32 = 0.3

UiState :: struct {
	hover_id:        UiID,
	hover_time:      f32,
	click_captured:  bool,
	down_clicked_id: u32,
}

reset_ui_state :: proc() {
	ui_state.click_captured = false
	if ui_state.hover_id == 0 {
		ui_state.hover_time = 0
	}
	ui_state.hover_id = 0

	if inputs.button_just_pressed[sapp.Mousebutton.LEFT] {
		ui_state.down_clicked_id = 0
	}
}

ui_state: UiState

import fstudio "../vendor/fmod/studio"
has_played_song := false
main_menu_song_instance: ^fstudio.EVENTINSTANCE
main_menu :: proc() {
	using game_data
	dt: f32 = get_delta_time()
	switch game_data.ux_anim_state {

	case .fade_in:
		reached := animate_to_target_f32(&ux_alpha, 1.0, dt, rate = 5.0, good_enough = 0.05)
		if reached {
			ux_anim_state = .hold
			hold_end_time = app_now() + 1.5
		}

	case .hold:
		if app_now() >= hold_end_time {
			ux_anim_state = .fade_out
		}

	case .fade_out:

	}
	col := COLOR_WHITE
	border_col := COLOR_BLACK
	col.a = ux_alpha
	border_col.a = ux_alpha

	w, h := get_ui_dimensions()
	if !has_played_song {
		has_played_song = true
		main_menu_song_instance = play_sound("event:/main_menu")
	}

	// clear_color = MAIN_MENU_CLEAR_COLOR
	set_ui_projection_alignment(.center_center)
	mouse_world_position = mouse_to_matrix()
	start_btn_pos: Vector2 = {0, -40}
	button_size: Vector2 = {60, 24} * 4.5
	padding: f32 = 5

	draw_quad_center_xform(
		transform_2d({0, 0}),
		{w, h},
		.background,
		DEFAULT_UV,
		col - {0, 0, 0, 0.7},
	)

	draw_quad_center_xform(transform_2d({0, 180}), {320, 180} * 1.8, .logo, DEFAULT_UV, col)


	if image_button(start_btn_pos, "Start Game", 38, 1, button_size, false, col, border_col) {
		game_data.in_transition_timer = IN_TRANSITION_TIME
	}
	start_btn_pos.y -= button_size.y + padding
	if image_button(start_btn_pos, "Options", 38, 2, button_size, false, col, border_col) {
	}
	start_btn_pos.y -= button_size.y + padding
	if image_button(start_btn_pos, "Exit", 38, 3, button_size, false, col, border_col) {
		log.info("Exit pressed")
		sapp.quit()
	}


	transition(dt)
}

init_time: time.Time
seconds_since_init :: proc() -> f64 {
	using time
	if init_time._nsec == 0 {
		log.error("invalid time")
		return 0
	}
	return duration_seconds(since(init_time))
}

app_now :: seconds_since_init


last_frame_time: f64
actual_dt: f64

get_delta_time :: proc() -> f32 {
	return f32(actual_dt)
}

frame :: proc "c" () {
	context = runtime.default_context()
	start_frame_time := seconds_since_init()
	actual_dt = start_frame_time - last_frame_time
	defer last_frame_time = start_frame_time
	if inputs.button_just_pressed[sapp.Keycode.F11] {
		sapp.toggle_fullscreen()
	}


	update_sound()
	switch game_data.app_state {
	case .splash_logo:
		set_ui_projection_alignment(.center_center)
		using game_data
		dt: f32 = get_delta_time()
		switch game_data.ux_anim_state {

		case .fade_in:
			reached := animate_to_target_f32(&ux_alpha, 1.0, dt, rate = 5.0, good_enough = 0.05)
			if reached {
				ux_anim_state = .hold
				hold_end_time = app_now() + 1.5
			}

		case .hold:
			if app_now() >= hold_end_time {
				ux_anim_state = .fade_out
			}

		case .fade_out:
			reached := animate_to_target_f32(&ux_alpha, 0.0, dt, rate = 15.0, good_enough = 0.05)
			if reached {
				ux_state = {}
				app_state = .splash_fmod
			}
		}
		col := COLOR_WHITE
		col.a = ux_alpha

		draw_text_center_center(Matrix4(1), "A game by louidev..", 40, col)
		draw_text_center_center(transform_2d({0, -60}), "Early demo v0.1", 30, col)

	case .splash_fmod:
		set_ui_projection_alignment(.center_center)
		using game_data
		dt: f32 = get_delta_time()
		switch ux_anim_state {
		case .fade_in:
			reached := animate_to_target_f32(&ux_alpha, 1.0, dt, rate = 5.0, good_enough = 0.05)
			if reached {
				ux_anim_state = .hold
				hold_end_time = app_now() + 1.5
			}

		case .hold:
			if app_now() >= hold_end_time {
				ux_anim_state = .fade_out
			}

		case .fade_out:
			reached := animate_to_target_f32(&ux_alpha, 0.0, dt, rate = 15.0, good_enough = 0.05)
			if reached {
				ux_state = {}
				app_state = .main_menu
			}
		}
		col := COLOR_WHITE
		col.a = ux_alpha
		draw_quad_center_xform(Matrix4(1), get_image_size(.fmod_logo), .fmod_logo, DEFAULT_UV, col)
	case .main_menu:
		main_menu()
	case .game:
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

base_width: f32 : 1280
base_height: f32 : 720


main :: proc() {
	_main()
}

@(export)
_main :: proc "c" () {
	context = runtime.default_context()
	when ODIN_ARCH == .wasm32 {
		context.allocator = emscripten_allocator()
		context.logger = create_emscripten_logger()
		context.assertion_failure_proc = web_assertion_failure_proc
	} else {
		context.logger = logger()
	}

	sapp.run(
		{
			init_cb = init,
			frame_cb = frame,
			cleanup_cb = cleanup,
			event_cb = event_cb,
			width = auto_cast base_width,
			height = auto_cast base_height,
			window_title = "My Game",
			icon = {sokol_default = true},
			logger = {func = slog.func},
			html5_use_emsc_set_main_loop = true,
			html5_emsc_set_main_loop_simulate_infinite_loop = true,
			html5_ask_leave_site = RELEASE,
		},
	)

}


IN_TRANSITION_TIME: f32 = 2.0
OUT_TRANSITION_TIME: f32 = 2.0

transition :: proc(dt: f32) {
	set_ui_projection_alignment(.center_center)
	width, height := get_ui_dimensions()

	if game_data.in_transition_timer <= 0 {
		if game_data.out_transition_timer > 0 {
			current_value_out := ease_over_time(
				game_data.out_transition_timer,
				OUT_TRANSITION_TIME,
				.Cubic_Out,
				width + width,
				width,
			)
			game_data.out_transition_timer -= dt
			draw_transition(false, current_value_out)
		}
		return
	}


	game_data.in_transition_timer -= dt

	if game_data.in_transition_timer <= 0 && game_data.app_state == .main_menu {
		game_data.out_transition_timer = OUT_TRANSITION_TIME
		game_data.app_state = .game
		play_sound("event:/game_music")
		stop_sound(main_menu_song_instance)
	}

	current_value_in := ease_over_time(
		game_data.in_transition_timer,
		IN_TRANSITION_TIME,
		.Cubic_In,
		width,
		0,
	)


	draw_transition(true, current_value_in)

}

transition_size: Vector2 : {64, 128}
draw_transition :: proc(inwards: bool, current_value: f32) {

	width, height := get_ui_dimensions()

	amount_to_draw: f32 = height / transition_size.y
	draw_rect_xform(
		transform_2d({-width + current_value - 1, -height * 0.5} - {width * 0.5, 0}),
		{width + 2, height},
		hex_to_rgb(0x25131a),
	)
	for i := 0; i <= auto_cast amount_to_draw; i += 1 {
		if inwards {
			draw_quad_xform(
				transform_2d(
					{
						-width * 0.5 + current_value,
						0.5 * -height + transition_size.y * auto_cast i,
					},
				),
				transition_size,
				.transition,
			)
		} else {
			draw_quad_xform(
				transform_2d(
					{
						-width * 0.5 + current_value - width,
						0.5 * -height + transition_size.y + transition_size.y * auto_cast i,
					},
					math.to_radians_f32(180),
				),
				transition_size,
				.transition,
			)


		}
	}
}
