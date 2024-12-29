package main


Projectile :: struct {
	using particle:            Particle,
	player_owned:              bool,
	distance_limit:            f32,
	current_distance_traveled: f32,
	damage_to_deal:            int,
	hits:                      int,
	last_hit_ent_id:           u32,
	can_bounce:                bool,
}


create_player_projectile :: proc(position: Vector2, direction: Vector2, rotation: f32, last_hit_id:u32 = 0, hits:int = 0, can_bounce: bool = true)  {
    projectile: Projectile
	projectile.animation_count = 2
	projectile.time_per_frame = 0.05
	projectile.position = position
	projectile.active = true
	projectile.distance_limit = 250
	projectile.sprite_cell_start = {0, 1}
	projectile.rotation = -rotation
	projectile.velocity = direction * 160
	projectile.player_owned = true
	projectile.damage_to_deal = 1
	projectile.last_hit_ent_id = last_hit_id
	projectile.hits = hits
	projectile.can_bounce = can_bounce
	append(&game_data.projectiles, projectile)
}
