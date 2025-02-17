package main
import "core:math"
import "core:math/linalg"

Projectile :: struct {
	using base:                BaseEntity,
	velocity:                  Vector2,
	rotation:                  f32,
	sprite_cell_start:         Vector2Int,
	animation_count:           int,
	current_frame:             int,
	current_animation_time:    f32,
	time_per_frame:            f32,
	scale:                     f32,
	target:                    ProjectileTarget,
	distance_limit:            f32,
	current_distance_traveled: f32,
	damage_to_deal:            f32,
	hits:                      int,
	last_hit_ent_id:           u32,
	bounce_count:              int,
}

ProjectileTarget :: enum {
	PLAYER,
	ENEMY,
	ALL,
}


create_enemy_projectile :: proc(position: Vector2, rotation: f32, velocity: Vector2, damage: f32) {
	projectile: Projectile
	projectile.sprite_cell_start = {0, 0}
	projectile.animation_count = 1
	projectile.time_per_frame = 0.02
	projectile.position = position
	projectile.active = true
	projectile.distance_limit = 250
	projectile.rotation = rotation
	projectile.velocity = velocity
	projectile.target = .PLAYER
	projectile.damage_to_deal = damage
	projectile.scale = 1
	append(&game_data.projectiles, projectile)
}

create_player_projectile :: proc(
	position: Vector2,
	direction: Vector2,
	rotation: f32,
	last_hit_id: u32 = 0,
	hits: int = 0,
	bounce_count: int = 0,
) {
	projectile: Projectile
	projectile.animation_count = 2
	projectile.time_per_frame = 0.05
	projectile.position = position
	projectile.active = true
	projectile.distance_limit = (game_data.bullet_range + game_data.weapon_bullet_range)
	projectile.sprite_cell_start = {0, 1}
	projectile.rotation = rotation
	projectile.velocity =
		direction * (game_data.bullet_velocity + game_data.weapon_bullet_velocity)
	projectile.target = .ENEMY
	projectile.damage_to_deal = game_data.bullet_dmg + game_data.weapon_bullet_dmg
	projectile.last_hit_ent_id = last_hit_id
	projectile.hits = hits
	projectile.bounce_count = bounce_count
	projectile.scale = (game_data.bullet_scale + game_data.weapon_bullet_scale) + 1.0
	append(&game_data.projectiles, projectile)
}


quintuple_directions: [5]Vector2 : {{1, 1}, {1, -1}, {-1, -1}, {-1, 1}, {0, 1}}
create_quintuple_projectiles :: proc(position: Vector2, target: ProjectileTarget) {
	for direction in quintuple_directions {
		projectile: Projectile
		projectile.animation_count = 1
		projectile.time_per_frame = 0.05
		projectile.position = position
		projectile.active = true
		projectile.distance_limit = 50
		projectile.sprite_cell_start = {0, 0}
		projectile.rotation = 0.0
		projectile.velocity = linalg.normalize(direction) * 30
		projectile.target = target
		projectile.damage_to_deal = 10
		projectile.last_hit_ent_id = 0
		projectile.hits = 0
		projectile.bounce_count = 0
		projectile.scale = 1.0
		append(&game_data.projectiles, projectile)
	}
}


create_quintuple_projectiles_spikes :: proc(position: Vector2, target: ProjectileTarget) {
	for direction in quintuple_directions {
		projectile: Projectile
		projectile.animation_count = 1
		projectile.time_per_frame = 0.05
		projectile.position = position
		projectile.active = true
		projectile.distance_limit = 100
		projectile.sprite_cell_start = {0, 2}
		projectile.rotation = math.atan2(direction.y, direction.x)
		projectile.velocity = linalg.normalize(direction) * 100
		projectile.target = target
		projectile.damage_to_deal =
			target == .ENEMY ? game_data.bullet_dmg + game_data.weapon_bullet_dmg : 10
		projectile.last_hit_ent_id = 0
		projectile.hits = 0
		projectile.bounce_count = 0
		projectile.scale = 1.0

		append(&game_data.projectiles, projectile)
	}
}
