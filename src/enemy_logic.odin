package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"


ENEMY_KNOCKBACK_VELOCITY :: 150
ENEMY_KNOCKBACK_TIME: f32 : 0.1
BAT_ATTACK_TIME: f32 : 5
JUMPER_ATTACK_TIME: f32 : 5
GUNNER_ATTACK_TIME: f32 : 5


Enemy :: struct {
	using entity:          Entity,
	type:                  EnemyType,
	spawn_indicator_timer: f32,
	flip_x:                bool,


	// bull_attack_data
	attack_direction:      Vector2,
	charge_up_time:        f32,
	charge_distance:       f32,
	state:                 EnemyState,
	// for jumping enemy
	ground_y:              f32,
	jump_velocity:         f32,
	scale:                 Vector2,
	// gunner enemy
	bullets_fired:         int,
}

EnemyState :: enum {
	IDLE,
	WALKING,
	PREP_ATTACK,
	ATTACKING,
	JUMPING,
}

EnemyType :: enum {
	BAT,
	CRAWLER,
	BULL,
	SLUG,
	BBY_SLUG,
	BARREL_CRAWLER,
	JUMPER,
	GUNNER,
}

create_bat :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity(20, position)
	enemy.type = .BAT
	enemy.speed = 28
	enemy.weapon_cooldown_timer = 10
	enemy.id = last_id
	enemy.attack_timer = BAT_ATTACK_TIME
	return enemy
}

create_crawler :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity(20, position)
	enemy.type = .CRAWLER
	enemy.speed = 20
	enemy.id = last_id
	return enemy
}

create_bull :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity(50, position)
	enemy.type = .BULL
	enemy.speed = 18

	enemy.id = last_id
	return enemy
}


create_slug :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity(50, position)
	enemy.type = .SLUG
	enemy.speed = 15
	enemy.id = last_id
	return enemy
}

create_bby_slug :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity(10, position)
	enemy.type = .BBY_SLUG
	enemy.speed = 20
	enemy.id = last_id
	return enemy
}

create_barrel_crawler :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity(10, position)
	enemy.type = .BARREL_CRAWLER
	enemy.speed = 15
	enemy.id = last_id
	return enemy
}

create_jumper :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity(30, position)
	enemy.type = .JUMPER
	enemy.speed = 18
	enemy.id = last_id
	enemy.attack_timer = JUMPER_ATTACK_TIME
	enemy.state = .WALKING
	return enemy
}


create_gunner :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_entity(20, position)
	enemy.type = .GUNNER
	enemy.speed = 25
	enemy.id = last_id
	enemy.attack_timer = GUNNER_ATTACK_TIME
	enemy.state = .WALKING
	return enemy
}


create_bby_slugs :: proc(position: Vector2) {
	num := rand.int_max(4) + 2
	for i := 0; i < num; i += 1 {
		append(
			&game_data.enemies,
			create_bby_slug(position + {rand.float32_range(-3, 3), rand.float32_range(-3, 3)}),
		)
	}
}

move_entity_towards_player :: proc(entity: ^Entity, dt: f32, speed: f32) {
	if (entity.stun_timer > 0) {
		return
	}
	target_position := game_data.player.position
	distance_from_target := linalg.distance(target_position, entity.position)
	delta_x: f32 = target_position.x - entity.position.x
	delta_y: f32 = target_position.x - entity.position.y


	move_direction := linalg.normalize(target_position - entity.position)

	x := entity.position.x + move_direction.x * dt * speed
	y := entity.position.y + move_direction.y * dt * speed
	potential_pos: Vector2 = {x, y}

	can_move_x := true
	can_move_y := true


	for &enemy in game_data.enemies {
		if !enemy.active ||
		   enemy.health <= 0 ||
		   entity == &enemy ||
		   enemy.knockback_timer > 0 ||
		   enemy.stun_timer > 0 ||
		   enemy.spawn_indicator_timer > 0 ||
		   speed > enemy.speed ||
		   enemy.state == .ATTACKING ||
		   enemy.state == .IDLE {
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

crawler_update_logic :: proc(entity: ^Enemy, dt: f32) {
	move_entity_towards_player(entity, dt, entity.speed)
	entity.state = .WALKING

	if circles_overlap(entity.position, entity.collision_radius, game_data.player.position, 4) {
		damage_player(1, .physical)
	}
}


slug_update_logic :: proc(entity: ^Enemy, dt: f32) {
	move_entity_towards_player(entity, dt, entity.speed)
	entity.state = .WALKING

	if circles_overlap(entity.position, entity.collision_radius, game_data.player.position, 4) {
		damage_player(1, .physical)
	}
}


bby_slug_update_logic :: proc(entity: ^Enemy, dt: f32) {
	move_entity_towards_player(entity, dt, entity.speed)
	entity.state = .WALKING

	if circles_overlap(entity.position, entity.collision_radius, game_data.player.position, 4) {
		damage_player(1, .physical)
	}
}

barrel_crawler_update_logic :: proc(entity: ^Enemy, dt: f32) {
	move_entity_towards_player(entity, dt, entity.speed)
	entity.state = .WALKING

	if circles_overlap(
		entity.position,
		entity.collision_radius + 4,
		game_data.player.position,
		game_data.player.collision_radius + 4,
	) {
		damage_enemy(entity, entity.health, V2_ZERO)
	}
}


JUMP_VELOCITY: f32 : 400
ENT_GRAVITY: f32 : 2000
jumper_update_logic :: proc(entity: ^Enemy, dt: f32) {

	if entity.attack_timer <= 0 {
		entity.attack_timer = JUMPER_ATTACK_TIME
		entity.state = .JUMPING
		entity.jump_velocity = JUMP_VELOCITY
		entity.ground_y = entity.position.y
	}


	if entity.state == .JUMPING {
		entity.jump_velocity -= ENT_GRAVITY * dt
		entity.position.y += entity.jump_velocity * dt
		if entity.position.y < entity.ground_y {
			entity.state = .IDLE
			create_quintuple_projectiles(entity.position, .PLAYER)
			camera_shake(0.6)
		}
	} else if entity.state == .WALKING {
		move_entity_towards_player(entity, dt, entity.speed)
		if linalg.distance(entity.position, game_data.player.position) <= 15 &&
		   entity.attack_timer >= JUMPER_ATTACK_TIME * 0.75 {
			entity.attack_timer -= JUMPER_ATTACK_TIME * 0.5
		}
	} else if entity.state == .IDLE {
		if run_every_seconds(1) {
			entity.state = .WALKING
		}
	}

}


BAT_FIRE_DIST :: 50

bat_update_logic :: proc(entity: ^Enemy, dt: f32) {
	target_position := game_data.player.position
	distance_from_target := linalg.distance(target_position, entity.position)
	speed := entity.speed
	if distance_from_target <= BAT_FIRE_DIST {
		speed = speed * 0.25
		if entity.attack_timer <= 0 {
			entity.attack_timer = BAT_ATTACK_TIME
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
			projectile.target = .PLAYER
			projectile.damage_to_deal = 1
			append(&game_data.projectiles, projectile)
			entity.state = .ATTACKING
		} else {
			entity.state = .WALKING
		}
	} else {
		entity.state = .WALKING
	}
	move_entity_towards_player(entity, dt, speed)
}

GUNNER_FIRE_DIST :: 130
GUNNER_BULLETS_PER_ATTACK :: 4
gunner_update_logic :: proc(entity: ^Enemy, dt: f32) {
	target_position := game_data.player.position
	distance_from_target := linalg.distance(target_position, entity.position)
	speed := entity.speed
	if distance_from_target <= GUNNER_FIRE_DIST {
		speed = speed * 0.15
		if entity.attack_timer <= 0 {
			entity.state = .ATTACKING
			if entity.bullets_fired <= GUNNER_BULLETS_PER_ATTACK {

				if run_every_seconds(0.2) {
					play_sound("event:/enemy_gunshot", entity.position)
					rotation_z := calc_rotation_to_target(target_position, entity.position)
					rotation_with_randomness :=
						rotation_z + math.to_radians(rand.float32_range(-10, 10))
					attack_direction: Vector2 = {
						math.cos(rotation_with_randomness),
						math.sin(rotation_with_randomness),
					}
					entity.bullets_fired += 1
					delta_x := PLAYER_GUN_MOVE_DIST * math.cos(-rotation_z)
					delta_y := PLAYER_GUN_MOVE_DIST * math.sin(-rotation_z)
					attack_position: Vector2 = entity.position + {delta_x, -delta_y}

					projectile: Projectile
					projectile.sprite_cell_start = {0, 0}
					projectile.animation_count = 1
					projectile.time_per_frame = 0.02
					projectile.position = attack_position
					projectile.active = true
					projectile.distance_limit = 250
					projectile.rotation = rotation_z
					projectile.velocity = attack_direction * 80
					projectile.target = .PLAYER
					projectile.damage_to_deal = 1
					append(&game_data.projectiles, projectile)
				}
			} else {
				entity.attack_timer = GUNNER_ATTACK_TIME
				entity.bullets_fired = 0
			}
		}
	} else {
		entity.state = .WALKING
	}
	move_entity_towards_player(entity, dt, speed)
}


BULL_CHARGE_DIST :: 120
BULL_MAX_CHARGE_DIST: f32 : 140
BULL_CHARGE_SPEED: f32 : 160
BULL_CHARGE_UP_TIME: f32 : 1.2
// time to attack
// charge direction

BULL_ATTACK_COOLDOWN: f32 : 3
bull_update_logic :: proc(entity: ^Enemy, dt: f32) {
	target_position := game_data.player.position
	distance_from_target := linalg.distance(target_position, entity.position)


	#partial switch (entity.state) {
	case .IDLE:
		entity.state = .WALKING
		entity.weapon_cooldown_timer = BULL_ATTACK_COOLDOWN
	case .WALKING:
		move_entity_towards_player(entity, dt, entity.speed)
		entity.charge_distance = 0
		if entity.weapon_cooldown_timer <= 0 && distance_from_target <= BULL_CHARGE_DIST {
			entity.state = .PREP_ATTACK
			entity.attack_direction = linalg.normalize(target_position - entity.position)
			entity.charge_up_time = BULL_CHARGE_UP_TIME
		}
	case .PREP_ATTACK:
		entity.charge_up_time -= dt
		if entity.charge_up_time <= 0 {
			entity.state = .ATTACKING
		}
	case .ATTACKING:
		x := entity.attack_direction.x * dt * BULL_CHARGE_SPEED
		y := entity.attack_direction.y * dt * BULL_CHARGE_SPEED
		dist_this_frame := linalg.length(Vector2{x, y})
		entity.charge_distance += dist_this_frame

		entity.position += {x, y}
		x_normalized := math.sign(x)
		if run_every_seconds(0.05) {
			spawn_walking_particles(
				entity.position + {-x_normalized * 2, -5},
				COLOR_WHITE,
				{-x, -y},
			)
		}

		if entity.charge_distance >= BULL_MAX_CHARGE_DIST {
			entity.attack_direction = V2_ZERO
			entity.weapon_cooldown_timer = 0
			entity.charge_distance = 0
			entity.state = .IDLE
		}

		if circles_overlap(
			entity.position,
			entity.collision_radius,
			game_data.player.position,
			4,
		) {
			damage_player(1, .physical)
		}
	}

}

cactus_update_logic :: proc(entity: ^Entity, dt: f32) {
	if circles_overlap(entity.position, entity.collision_radius, game_data.player.position, 4) {
		damage_player(1, .physical)
	}
}

get_min_wave_for_enemy_spawn :: proc(enemy_type: EnemyType) -> int {
	switch (enemy_type) {
	case .CRAWLER:
		return 1
	case .BAT:
		return 1
	case .BULL:
		return 1
	case .SLUG:
		return 2
	case .BBY_SLUG:
		return 10000
	case .BARREL_CRAWLER:
		return 1
	case .JUMPER:
		return 1
	case .GUNNER:
		return 3
	}

	return 0
}
// LARGER NUMBER = MORE FREQUENT
get_enemy_base_propability :: proc(enemy_type: EnemyType) -> f32 {
	switch (enemy_type) {
	case .CRAWLER:
		return 0.5
	case .BAT:
		return 0.25
	case .BULL:
		return 1.0
	case .SLUG:
		return 0.1
	case .BBY_SLUG:
		return 0
	case .BARREL_CRAWLER:
		return 0.1
	case .JUMPER:
		return 0.1
	case .GUNNER:
		return 0.8
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
		case .BBY_SLUG:
			append(&game_data.enemies, create_bby_slug(position))
		case .SLUG:
			append(&game_data.enemies, create_slug(position))
		case .BARREL_CRAWLER:
			append(&game_data.enemies, create_barrel_crawler(position))
		case .JUMPER:
			append(&game_data.enemies, create_jumper(position))
		case .GUNNER:
			append(&game_data.enemies, create_gunner(position))
		}


		game_data.enemies[len(game_data.enemies) - 1].spawn_indicator_timer = SPAWN_INDICATOR_TIME
		unordered_remove(&spawn_bag, spawn_bag_index)
	}
}

knockback_enemy :: proc(enemy: ^Enemy, direction: Vector2) {
	switch (enemy.type) {
	case .CRAWLER:
	case .BBY_SLUG:
	case .SLUG:

	case .GUNNER:
	case .JUMPER:
		enemy.attack_timer = JUMPER_ATTACK_TIME + ENEMY_KNOCKBACK_TIME

	case .BAT:
		enemy.attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME
	case .BULL:
		enemy.attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME

	case .BARREL_CRAWLER:
	}

	if enemy.type == .BARREL_CRAWLER || enemy.type == .BULL && enemy.attack_direction != V2_ZERO {
		return
	}

	knockback_ent(&enemy.entity, direction)
}


damage_enemy :: proc(e: ^Enemy, damage_to_deal: f32, bullet_velocity: Vector2) {

	dmg := damage_to_deal
	scale: f32 = 1.0
	color := COLOR_WHITE
	// e.g if this is 10 then 
	if math.min(game_data.crit_chance, PLAYER_MAX_CRIT_CHANCE) >= rand.float32_range(0.0, 100) {
		dmg += damage_to_deal * 0.45
		scale = 1.3
		color = hex_to_rgb(0xe84444)
	}

	e.health -= dmg

	popup_txt: PopupText = DEFAULT_POPUP_TXT
	popup_txt.active = true
	popup_txt.text = fmt.tprintf("%d", int(dmg))
	popup_txt.alpha = 1.0
	popup_txt.scale = scale
	popup_txt.position = e.position
	popup_txt.color = color
	append(&game_data.popup_text, popup_txt)

	if e.health <= 0 {
		create_enemybody_permanence(e, bullet_velocity * 0.5)
	} else {
		knockback_enemy(e, linalg.normalize(bullet_velocity))
	}
}


enemy_update :: proc(enemy: ^Enemy, dt: f32) {
	switch (enemy.type) {
	case .CRAWLER:
		crawler_update_logic(enemy, dt)
	case .BAT:
		bat_update_logic(enemy, dt)
	case .BULL:
		bull_update_logic(enemy, dt)
	case .SLUG:
		slug_update_logic(enemy, dt)

	case .BBY_SLUG:
		bby_slug_update_logic(enemy, dt)
	case .BARREL_CRAWLER:
		barrel_crawler_update_logic(enemy, dt)
	case .JUMPER:
		jumper_update_logic(enemy, dt)
	case .GUNNER:
		gunner_update_logic(enemy, dt)
	}

}
