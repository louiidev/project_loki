package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"


Enemy :: struct {
	using entity:          Entity,
	type:                  EnemyType,
	spawn_indicator_timer: f32,
	flip_x:                bool,


	// bull_attack_data
	attack_direction:      Vector2,
	charge_up_time:        f32,
	charge_distance:       f32,
}

EnemyType :: enum {
	BAT,
	CRAWLER,
	BULL,
	CACTUS,
}


create_bat :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity()
	enemy.position = position
	enemy.type = .BAT
	enemy.speed = 28
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
	enemy.speed = 18
	enemy.id = last_id
	return enemy
}

create_cactus :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity()
	enemy.position = position
	enemy.type = .CACTUS
	enemy.speed = 0
	enemy.id = last_id
	return enemy
}


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

	if distance_from_target <= BAT_FIRE_DIST {
		if run_every_seconds(3) {
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
		}
	} else {
		move_entity_towards_player(entity, dt)
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

get_min_wave_for_enemy_spawn :: proc(enemy_type: EnemyType) -> int {
	switch (enemy_type) {
	case .CRAWLER:
		return 1
	case .BAT:
		return 1
	case .BULL:
		return 4
	case .CACTUS:
		return 1
	}

	return 0
}

get_enemy_base_propability :: proc(enemy_type: EnemyType) -> f32 {
	switch (enemy_type) {
	case .CRAWLER:
		return 0.7
	case .BAT:
		return 0.4
	case .BULL:
		return 0.1
	case .CACTUS:
		return 0.1
	}

	return 0


}

decrease_rate: f32 : 0.05
increase_rate: f32 : 0.05
get_enemy_spawn_probabilities :: proc() -> [EnemyType]f32 {
	probabilities: [EnemyType]f32
	wave_number := game_data.current_wave
	for type in EnemyType {
		base_prob := get_enemy_base_propability(type)
		if type == .CACTUS {
			probabilities[type] = base_prob
			continue
		}
		if base_prob > 0.45 {
			probabilities[type] = math.max(
				base_prob - (auto_cast wave_number * decrease_rate),
				0.1,
			)
		} else {
			probabilities[type] = math.min(
				base_prob + (auto_cast wave_number * increase_rate),
				0.65,
			)
		}
	}

	return probabilities
}


spawn_enemy_group :: proc(amount_to_spawn: int) {

	spawn_bag: [dynamic]EnemyType
	defer delete(spawn_bag)

	probabilities := get_enemy_spawn_probabilities()

	for type in EnemyType {
		if game_data.current_wave < get_min_wave_for_enemy_spawn(type) {
			continue
		}

		prob := int(probabilities[type] * 1000)

		for i := 0; i < prob; i += 1 {
			append(&spawn_bag, type)
		}


	}


	for i := 0; i < amount_to_spawn; i += 1 {
		spawn_bag_index := rand.int_max(len(spawn_bag))
		enemy_type := spawn_bag[spawn_bag_index]
		position: Vector2 = {
			rand.float32_range(-LEVEL_BOUNDS.x * 0.5, LEVEL_BOUNDS.x * 0.5),
			rand.float32_range(-LEVEL_BOUNDS.y * 0.5, LEVEL_BOUNDS.y * 0.5),
		}
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

		game_data.enemies[len(game_data.enemies) - 1].spawn_indicator_timer = SPAWN_INDICATOR_TIME
		unordered_remove(&spawn_bag, spawn_bag_index)
	}
}
