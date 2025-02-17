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

ENEMY_FREEZE_TIME: f32 : 8.0


Status :: enum {
	Frozen,
	Poison,
}


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
	statuses:              [Status]bool,
	statuses_timers:       [Status]f32,
	damage:                f32,
	rotation:              f32,
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
	CHASER,
	JUMPER,
	GUNNER,
	EXPLOSIVE_CHASER,
	TANK,
	DISK,
}

create_enemy :: proc(health: f32, position: Vector2 = V2_ZERO, speed: f32 = 20) -> Entity {
	entity := DEFAULT_ENT
	last_id += 1
	entity.id = last_id
	entity.health = health + WAVE_ENEMY_HEALTH_MODIFIER * auto_cast game_data.current_wave
	entity.max_health = entity.health
	entity.position = position
	return entity
}


create_bat :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(20, position)
	enemy.type = .BAT
	enemy.speed = 35
	enemy.weapon_cooldown_timer = 10
	enemy.id = last_id
	enemy.attack_timer = BAT_ATTACK_TIME
	enemy.damage = 5
	return enemy
}

create_crawler :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(20, position)
	enemy.type = .CRAWLER
	enemy.speed = 20
	enemy.id = last_id
	enemy.damage = 4
	return enemy
}

create_bull :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(50, position)
	enemy.type = .BULL
	enemy.speed = 18
	enemy.damage = 10
	enemy.id = last_id
	return enemy
}


create_slug :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(50, position)
	enemy.type = .SLUG
	enemy.speed = 15
	enemy.id = last_id
	enemy.damage = 5
	return enemy
}

create_bby_slug :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(10, position)
	enemy.type = .BBY_SLUG
	enemy.speed = 20
	enemy.id = last_id
	enemy.damage = 2
	return enemy
}

create_explosive_chaser :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(30, position)
	enemy.type = .EXPLOSIVE_CHASER
	enemy.speed = 15
	enemy.id = last_id

	return enemy
}

create_jumper :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(30, position)
	enemy.type = .JUMPER
	enemy.speed = 18
	enemy.id = last_id
	enemy.attack_timer = JUMPER_ATTACK_TIME
	enemy.state = .WALKING
	enemy.damage = 8
	return enemy
}


create_gunner :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(20, position)
	enemy.type = .GUNNER
	enemy.speed = 25
	enemy.id = last_id
	enemy.attack_timer = GUNNER_ATTACK_TIME
	enemy.state = .WALKING
	enemy.damage = 4
	return enemy
}

create_chaser :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(30, position)
	enemy.type = .CHASER
	enemy.speed = 35
	enemy.id = last_id
	enemy.attack_timer = GUNNER_ATTACK_TIME
	enemy.state = .WALKING
	enemy.damage = 5
	return enemy
}

create_tank :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(100, position)
	enemy.type = .TANK
	enemy.speed = 10
	enemy.id = last_id
	enemy.attack_timer = GUNNER_ATTACK_TIME
	enemy.state = .WALKING
	enemy.damage = 10
	return enemy
}

create_disk :: proc(position: Vector2) -> Enemy {
	enemy: Enemy
	enemy.entity = create_enemy(100, position)
	enemy.type = .DISK
	enemy.speed = DISK_SPEED
	enemy.id = last_id
	enemy.state = .WALKING
	enemy.damage = 40
	enemy.velocity = quad_directions[rand.int_max(len(quad_directions))] * DISK_SPEED
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

move_entity_towards_player :: proc(entity: ^Enemy, dt: f32, speed: f32) {
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


	speed := speed
	if entity.statuses[.Frozen] {
		speed *= game_data.freeze_slowdown
	}

	if entity.statuses[.Poison] && game_data.player_upgrade[.POISON_CAUSES_SLOWDOWN] > 0 {
		speed *= game_data.poison_slowdown
	}


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

	if !can_move_x && !can_move_y {
		if !can_move_x {
			move_direction.x = 0
			move_direction.y += 0.5 * math.sign(target_position.y - entity.position.y)
		}

		if !can_move_y {
			move_direction.y = 0
			move_direction.x += 0.5 * math.sign(target_position.x - entity.position.x)
		}

		move_direction = linalg.normalize(move_direction)

		entity.position.x += move_direction.x * speed * dt
		entity.position.y += move_direction.y * speed * dt
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


BAT_FIRE_DIST :: 65

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
			create_enemy_projectile(
				entity.position,
				rotation_z,
				attack_direction * 75,
				entity.damage,
			)
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

				if run_every_seconds(0.3) {
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
					create_enemy_projectile(
						attack_position,
						rotation_z,
						attack_direction * 80,
						entity.damage,
					)
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

quad_directions: [4]Vector2 = {{1, 1}, {1, -1}, {-1, -1}, {-1, 1}}
DISK_SPEED: f32 : 70
disk_update_logic :: proc(entity: ^Enemy, dt: f32) {
	potential_pos := entity.position + entity.velocity * dt
	entity.rotation += dt * 30
	// left wall
	if check_wall_collision(potential_pos, entity.collision_radius, WALLS[0]) {
		reflection := linalg.reflect(linalg.normalize(entity.velocity), Vector2{1, 0})
		entity.velocity = reflection * entity.speed
		potential_pos := entity.position + entity.velocity * dt
	} else if check_wall_collision(potential_pos, entity.collision_radius, WALLS[1]) {
		reflection := linalg.reflect(linalg.normalize(entity.velocity), Vector2{0, 1})
		entity.velocity = reflection * entity.speed
		potential_pos := entity.position + entity.velocity * dt
	} else if check_wall_collision(potential_pos, entity.collision_radius, WALLS[2]) {
		reflection := linalg.reflect(linalg.normalize(entity.velocity), Vector2{-1, 0})
		entity.velocity = reflection * entity.speed
		potential_pos := entity.position + entity.velocity * dt
	} else if check_wall_collision(potential_pos, entity.collision_radius, WALLS[3]) {
		reflection := linalg.reflect(linalg.normalize(entity.velocity), Vector2{0, -1})
		entity.velocity = reflection * entity.speed
		potential_pos := entity.position + entity.velocity * dt
	}

	entity.position = potential_pos

	for &enemy in game_data.enemies {
		if !enemy.active || enemy.stun_timer > 0 || enemy.type == .DISK {
			continue
		}

		if circles_overlap(
			enemy.position,
			enemy.collision_radius,
			entity.position,
			entity.collision_radius,
		) {
			damage_enemy(&enemy, entity.damage, linalg.normalize(entity.velocity))
		}
	}

	if circles_overlap(
		game_data.player.position,
		game_data.player.collision_radius,
		entity.position,
		entity.collision_radius,
	) {
		damage_player(entity.damage, .projectile)
	}
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
			damage_player(entity.damage, .physical)
		}
	}

}


get_min_wave_for_enemy_spawn :: proc(enemy_type: EnemyType) -> int {
	switch (enemy_type) {
	case .CRAWLER:
		return 1
	case .BAT:
		return 1
	case .BULL:
		return 6
	case .SLUG:
		return 2
	case .BBY_SLUG:
		return 1
	case .EXPLOSIVE_CHASER:
		return 4
	case .JUMPER:
		return 2
	case .GUNNER:
		return 5
	case .CHASER:
		return 2
	case .TANK:
		return 3
	case .DISK:
		return 7
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
		return 0.05
	case .SLUG:
		return 0.2
	case .BBY_SLUG:
		return 0
	case .EXPLOSIVE_CHASER:
		return 0.1
	case .JUMPER:
		return 0.1
	case .GUNNER:
		return 0.8
	case .CHASER:
		return 0.2
	case .TANK:
		return 0.15
	case .DISK:
		return .01
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
		case .EXPLOSIVE_CHASER:
			append(&game_data.enemies, create_explosive_chaser(position))
		case .JUMPER:
			append(&game_data.enemies, create_jumper(position))
		case .GUNNER:
			append(&game_data.enemies, create_gunner(position))
		case .CHASER:
			append(&game_data.enemies, create_chaser(position))
		case .TANK:
			append(&game_data.enemies, create_tank(position))
		case .DISK:
			append(&game_data.enemies, create_disk(position))
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
	case .EXPLOSIVE_CHASER:
	case .CHASER:
	case .TANK:
	case .DISK:

	case .GUNNER:
	case .JUMPER:
		enemy.attack_timer = JUMPER_ATTACK_TIME + ENEMY_KNOCKBACK_TIME

	case .BAT:
		enemy.attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME
	case .BULL:
		enemy.attack_timer = BAT_ATTACK_TIME + ENEMY_KNOCKBACK_TIME


	}

	if enemy.stun_timer > 0 ||
	   enemy.type == .BULL && enemy.attack_direction != V2_ZERO ||
	   enemy.type == .DISK {
		return
	}

	knockback_ent(&enemy.entity, direction)
}


poison_dmg_enemy :: proc(e: ^Enemy, damage_to_deal: f32) {
	e.health -= game_data.poison_dmg
	popup_txt: PopupText = DEFAULT_POPUP_TXT
	popup_txt.active = true
	popup_txt.text = fmt.tprintf("%.0f", game_data.poison_dmg)
	popup_txt.alpha = 1.0
	popup_txt.scale = 1.0
	popup_txt.position = e.position
	popup_txt.color = hex_to_rgb(0xccf61f)
	// play_sound("event:/enemy_hit", e.position)
	append(&game_data.popup_text, popup_txt)

	if e.health <= 0 {
		create_enemybody_permanence(e, {})
	}
}

damage_enemy :: proc(e: ^Enemy, damage_to_deal: f32, bullet_velocity: Vector2) {
	if e.spawn_indicator_timer > 0 || !e.active || e.health <= 0 {
		return
	}
	dmg := damage_to_deal
	scale: f32 = 1.0
	color := COLOR_WHITE
	// e.g if this is 10 then 
	if math.min(game_data.crit_chance, PLAYER_MAX_CRIT_CHANCE) >= rand.float32_range(0.0, 100) {
		dmg += damage_to_deal * 0.45
		scale = 1.3
		color = hex_to_rgb(0xe84444)
	}

	e.stun_timer = game_data.enemy_stun_time

	e.health -= dmg

	popup_txt: PopupText = DEFAULT_POPUP_TXT
	popup_txt.active = true
	popup_txt.text = fmt.tprintf("%d", int(dmg))
	popup_txt.alpha = 1.0
	popup_txt.scale = scale
	popup_txt.position = e.position
	popup_txt.color = color
	play_sound("event:/enemy_hit", e.position, 20)
	append(&game_data.popup_text, popup_txt)

	if e.health <= 0 {
		create_enemybody_permanence(e, bullet_velocity * 0.5)
		if dmg > damage_to_deal && game_data.player_upgrade[.CRITS_CAUSE_EXPLOSIONS] > 0 {
			create_explosion(e.position)
		}
	} else {
		knockback_enemy(e, linalg.normalize(bullet_velocity))
	}
}

ENEMY_POISON_DMG_TIME: f32 : 3.0
enemy_update :: proc(enemy: ^Enemy, dt: f32) {

	if enemy.statuses[.Poison] {
		enemy.statuses_timers[.Poison] += dt
		if enemy.statuses_timers[.Poison] >= ENEMY_POISON_DMG_TIME {
			enemy.statuses_timers[.Poison] = 0
			poison_dmg_enemy(enemy, game_data.poison_dmg)
		}
	}

	if enemy.statuses[.Frozen] {
		enemy.statuses_timers[.Frozen] += dt
		if enemy.statuses_timers[.Frozen] >= ENEMY_FREEZE_TIME {
			enemy.statuses[.Frozen] = false
			enemy.statuses_timers[.Frozen] = 0
		}


	}

	switch (enemy.type) {
	case .CRAWLER, .SLUG, .BBY_SLUG, .CHASER, .TANK:
		move_entity_towards_player(enemy, dt, enemy.speed)
		enemy.state = .WALKING

		if circles_overlap(enemy.position, enemy.collision_radius, game_data.player.position, 4) {
			damage_player(enemy.damage, .physical)
		}
	case .BAT:
		bat_update_logic(enemy, dt)
	case .BULL:
		bull_update_logic(enemy, dt)
	case .EXPLOSIVE_CHASER:
		barrel_crawler_update_logic(enemy, dt)
	case .JUMPER:
		jumper_update_logic(enemy, dt)
	case .GUNNER:
		gunner_update_logic(enemy, dt)
	case .DISK:
		disk_update_logic(enemy, dt)
	}

}
