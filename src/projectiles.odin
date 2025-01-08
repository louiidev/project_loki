package main
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
	projectile.distance_limit = game_data.bullet_range
	projectile.sprite_cell_start = {0, 1}
	projectile.rotation = rotation
	projectile.velocity = direction * game_data.bullet_velocity
	projectile.target = .ENEMY
	projectile.damage_to_deal = 1
	projectile.last_hit_ent_id = last_hit_id
	projectile.hits = hits
	projectile.bounce_count = bounce_count
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
		projectile.damage_to_deal = 1
		projectile.last_hit_ent_id = 0
		projectile.hits = 0
		projectile.bounce_count = 0
		append(&game_data.projectiles, projectile)
	}
}
