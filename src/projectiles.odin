package main


Projectile :: struct {
	position:                  Vector2,
	active:                    bool,
	velocity:                  Vector2,
	rotation:                  f32,
	sprite_cell_start:         Vector2Int,
	animation_count:           int,
	current_frame:             int,
	current_animation_time:    f32,
	time_per_frame:            f32,
	scale:                     f32,
	player_owned:              bool,
	distance_limit:            f32,
	current_distance_traveled: f32,
	damage_to_deal:            int,
	hits:                      int,
	last_hit_ent_id:           u32,
	bounce_count:              int,
}


create_player_projectile :: proc(position: Vector2, direction: Vector2, rotation: f32, last_hit_id:u32 = 0, hits:int = 0, bounce_count: int = 0)  {
    projectile: Projectile
	projectile.animation_count = 2
	projectile.time_per_frame = 0.05
	projectile.position = position
	projectile.active = true
	projectile.distance_limit = 250
	projectile.sprite_cell_start = {0, 1}
	projectile.rotation = rotation
	projectile.velocity = direction * game_data.bullet_velocity
	projectile.player_owned = true
	projectile.damage_to_deal = 1
	projectile.last_hit_ent_id = last_hit_id
	projectile.hits = hits
	projectile.bounce_count = bounce_count
	append(&game_data.projectiles, projectile)
}
