package main

import "core:math"
import "core:math/linalg"


move_entity_towards_player :: proc(entity: ^Entity, dt: f32) {
	target_position := game_run_state.player.position
	distance_from_target := linalg.distance(target_position, entity.position)
	delta_x: f32 = target_position.x - entity.position.x
	delta_y: f32 = target_position.x - entity.position.y


	move_direction := linalg.normalize(target_position - entity.position)

	x := entity.position.x + move_direction.x * dt * entity.speed
	y := entity.position.y + move_direction.y * dt * entity.speed
	potential_pos: Vector2 = {x, y}

	can_move_x := true
	can_move_y := true


	for &enemy in game_run_state.enemies {
		if !enemy.active ||
		   enemy.health <= 0 ||
		   entity == &enemy ||
		   enemy.knockback_timer > 0 ||
		   entity.speed > enemy.speed {
			continue
		}

		if circles_overlap({x, entity.position.y}, 5, {enemy.position.x, enemy.position.y}, 5) {
			entity_distance_to_target := linalg.distance(target_position, enemy.position)
			// give presidence to closest entity
			if (entity_distance_to_target >= distance_from_target) {
				continue
			}

			can_move_x = false
		}

		if circles_overlap({entity.position.x, y}, 5, {enemy.position.x, enemy.position.y}, 5) {
			entity_distance_to_target := linalg.distance(target_position, enemy.position)
			// give presidence to closest entity
			if (entity_distance_to_target >= distance_from_target) {
				continue
			}

			can_move_y = false
		}
	}

	if can_move_x {
		entity.position.x = x
	}

	if can_move_y {

		entity.position.y = y
	}
}

crawler_update_logic :: proc(entity: ^Entity, dt: f32) {
	move_entity_towards_player(entity, dt)
}


BAT_FIRE_DIST :: 50

bat_update_logic :: proc(entity: ^Entity, dt: f32) {
	target_position := game_run_state.player.position
	distance_from_target := linalg.distance(target_position, entity.position)

	if distance_from_target > BAT_FIRE_DIST {
		// move closer
		move_entity_towards_player(entity, dt)
	} else if entity.weapon_cooldown_timer <= 0 {
		// fire projectile
		rotation_z := calc_rotation_to_target(target_position, entity.position)
		attack_direction: Vector2 = {math.cos(rotation_z), math.sin(rotation_z)}
		projectile: Projectile
		projectile.sprite_cell_start = {0, 0}
		projectile.animation_count = 1
		projectile.time_per_frame = 0.02
		projectile.position = entity.position
		projectile.active = true
		projectile.distance_limit = 250
		projectile.rotation = rotation_z
		projectile.velocity = attack_direction * 50
		projectile.player_owned = false
		projectile.damage_to_deal = 1
		append(&game_run_state.projectiles, projectile)
		entity.weapon_cooldown_timer = 5
	}
}
