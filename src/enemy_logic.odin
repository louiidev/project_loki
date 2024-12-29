package main

import "core:math"
import "core:math/linalg"


move_entity_towards_player :: proc(entity: ^Entity, dt: f32) {
	if (entity.stun_timer > 0) {
		return
	}
	target_position := game_data.player.position
	distance_from_target := linalg.distance(target_position, entity.position)
	delta_x: f32 = target_position.x - entity.position.x
	delta_y: f32 = target_position.x - entity.position.y


	move_direction := linalg.normalize(target_position - entity.position)

	x := entity.position.x + move_direction.x * dt * entity.speed
	y := entity.position.y + move_direction.y * dt * entity.speed
	potential_pos: Vector2 = {x, y}

	can_move_x := true
	can_move_y := true


	for &enemy in game_data.enemies {
		if !enemy.active ||
		   enemy.health <= 0 ||
		   entity == &enemy ||
		   enemy.knockback_timer > 0 ||
		   enemy.stun_timer > 0 ||
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


	if circles_overlap(entity.position, entity.collision_radius, game_data.player.position, 4) {
		damage_player(1)
	}
}


BAT_FIRE_DIST :: 50

bat_update_logic :: proc(entity: ^Entity, dt: f32) {
	target_position := game_data.player.position
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
		append(&game_data.projectiles, projectile)
		entity.weapon_cooldown_timer = 5
	}
}

BULL_CHARGE_DIST :: 80
BULL_MAX_CHARGE_DIST: f32 : 130
BULL_CHARGE_SPEED: f32 : 140
// time to attack
// charge direction

bull_update_logic :: proc(entity: ^Enemy, dt: f32) {
	target_position := game_data.player.position
	distance_from_target := linalg.distance(target_position, entity.position)


	// If bull has charged attack already
	// don't reset attack
	// if bull isn't close to player
	// move close to player
	//

	if distance_from_target > BULL_CHARGE_DIST &&
	   entity.weapon_cooldown_timer <= 0 &&
	   entity.attack_direction == V2_ZERO {
		move_entity_towards_player(entity, dt)
		entity.charge_distance = 0
	} else if entity.attack_direction == V2_ZERO && entity.charge_distance == 0 {
		entity.attack_direction = linalg.normalize(target_position - entity.position)
		entity.weapon_cooldown_timer = 1.5
	}

	if entity.weapon_cooldown_timer <= 0 &&
	   entity.charge_distance == 0 &&
	   entity.attack_direction != V2_ZERO {
		entity.attack_direction = linalg.normalize(target_position - entity.position)
	}

	if entity.weapon_cooldown_timer <= 0 &&
	   entity.attack_direction != V2_ZERO &&
	   entity.charge_distance < BULL_MAX_CHARGE_DIST {
		x := entity.attack_direction.x * dt * BULL_CHARGE_SPEED
		y := entity.attack_direction.y * dt * BULL_CHARGE_SPEED
		dist_this_frame := linalg.length(Vector2{x, y})
		entity.charge_distance += dist_this_frame

		entity.position += {x, y}
	} else if entity.charge_distance >= BULL_MAX_CHARGE_DIST {
		entity.attack_direction = V2_ZERO
		entity.weapon_cooldown_timer = 0
		entity.charge_distance = 0
	}

	if circles_overlap(entity.position, entity.collision_radius, game_data.player.position, 4) {
		damage_player(1)
	}
}

cactus_update_logic :: proc(entity: ^Entity, dt: f32) {
	if circles_overlap(entity.position, entity.collision_radius, game_data.player.position, 4) {
		damage_player(1)
	}
}

create_bat :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity()
	enemy.position = position
	enemy.type = .BAT
	enemy.speed = 20
	enemy.weapon_cooldown_timer = 10
	enemy.id = last_id
	return enemy
}

create_crawler :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity()
	enemy.position = position
	enemy.type = .CRAWLER
	enemy.speed = 20
	enemy.id = last_id
	return enemy
}

create_bull :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity()
	enemy.position = position
	enemy.type = .BULL
	enemy.speed = 20
	enemy.id = last_id
	return enemy
}

create_cactus :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity()
	enemy.position = position
	enemy.type = .CACTUS
	enemy.speed = 20
	enemy.id = last_id
	return enemy
}
