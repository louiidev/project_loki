
package main
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"

Permanence :: struct {
	using base:    BaseEntity,
	type:          PermanenceType,
	life_time:     f32,
	max_life_time: f32,
	size:          f32,
	alpha:         f32,
	rotation:      f32,
	frame:         Vector2Int,
	enemy_type:    EnemyType,
	direction:     Vector2,
	velocity:      Vector2,
	scale:         f32,
}


PermanenceType :: enum {
	bullet_shell,
	enemy_body,
	explosion,
	blood,
	prop,
}


create_prop_permanence :: proc(prop: EnvironmentProp) {
	perm: Permanence
	perm.active = true
	perm.position = prop.position
	perm.type = .prop
	perm.life_time = 15
	perm.max_life_time = 15

	perm.frame = {1, auto_cast prop.type}
	append(&game_data.permanence, perm)
}


create_bullet_shell_permanence :: proc(player: ^Entity, bullet_direction: Vector2) {
	perm: Permanence
	perm.active = true
	perm.position = player.position
	perm.type = .bullet_shell
	perm.life_time = 8
	perm.max_life_time = 8
	perm.velocity = -(bullet_direction * 0.5)

	append(&game_data.permanence, perm)
}


create_explosion_permanence :: proc(explosion: ^Explosion) {
	perm: Permanence
	perm.active = true
	perm.position = explosion.position
	perm.type = .explosion
	perm.life_time = 15
	perm.max_life_time = 15
	perm.size = explosion.size
	append(&game_data.permanence, perm)
}


create_enemybody_permanence :: proc(e: ^Enemy, velocity: Vector2) {
	perm: Permanence
	perm.active = true
	perm.position = e.position
	perm.type = .enemy_body
	perm.life_time = 15
	perm.max_life_time = 15
	perm.enemy_type = e.type
	perm.frame = {1, auto_cast e.type}
	perm.velocity = velocity
	append(&game_data.permanence, perm)
}

create_blood_permanence :: proc(bullet: ^Projectile, position: Vector2) {
	perm: Permanence
	perm.active = true
	perm.position = position
	perm.type = .blood
	perm.life_time = 15
	perm.max_life_time = 15
	perm.rotation = bullet.rotation
	perm.frame = {rand.int_max(4), 0}
	append(&game_data.permanence, perm)
}

magnitude :: proc(v: Vector2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

GRAVITY: f32 : -1200.0 // Acceleration due to gravity
DRAG: f32 : 2200.0 // Friction to slow down the velocit
update_arch_velocity :: proc(velocity: ^Vector2, dt: f32) {
	velocity_magnitude := magnitude(velocity^)

	if velocity_magnitude > 0.0 {
		// Normalize velocity
		normalized_velocity := linalg.normalize(velocity^)

		// Apply drag to slow down
		velocity.x -= dt * DRAG * normalized_velocity.x
		velocity.y -= dt * DRAG * normalized_velocity.y

		// Apply gravity to create the arc
		velocity.y += dt * GRAVITY

		// If velocity is very small, set it to zero
		if magnitude(velocity^) < 0.5 {
			velocity^ = V2_ZERO
		}
	}
}

render_update_permanence :: proc(dt: f32) {
	for &permanence in &game_data.permanence {
		permanence.life_time -= dt
		if permanence.life_time <= 0 {
			permanence.active = false
		}
		if !permanence.active {
			continue
		}


		switch permanence.type {

		case .prop:
			alpha: f32 = 0.0
			max_alpha: f32 = 1.0
			alpha = math.lerp(
				alpha,
				max_alpha,
				1.0 - permanence.life_time / permanence.max_life_time,
			)

			flash_amount: f32 = permanence.life_time >= permanence.max_life_time - 0.3 ? 1 : 0

			uv := get_frame_uvs(.environment_prop, permanence.frame, {18, 18})
			draw_quad_center_xform(
				transform_2d(permanence.position, permanence.rotation),
				{18, 18},
				.environment_prop,
				uv,
				{0.9, 0.9, 0.9, 1.0} - {alpha, alpha, alpha, alpha},
				flash_amount,
			)

		case .bullet_shell:
			alpha: f32 = 0.0
			max_alpha: f32 = 1.0

			alpha = math.lerp(
				alpha,
				max_alpha,
				1.0 - permanence.life_time / permanence.max_life_time,
			)

			// scale := math.lerp(f32(1.0), f32(0.0), permanence.life_time / permanence.max_life_time)
			update_arch_velocity(&permanence.velocity, dt)
			permanence.position += permanence.velocity * dt
			if magnitude(permanence.velocity) > 10 {
				permanence.rotation += dt * 10
			}
			draw_quad_center_xform(
				transform_2d(permanence.position, permanence.rotation, 1.0),
				{5, 5},
				.bullet_shell,
				DEFAULT_UV,
				COLOR_WHITE - {0, 0, 0, alpha},
			)

		case .enemy_body:
			alpha: f32 = 0.0
			max_alpha: f32 = 1.0
			alpha = math.lerp(
				alpha,
				max_alpha,
				1.0 - permanence.life_time / permanence.max_life_time,
			)
			if permanence.enemy_type != .EXPLOSIVE_CHASER {


				permanence.velocity =
					magnitude(permanence.velocity) > 0 ? permanence.velocity - dt * 1000 * linalg.normalize(permanence.velocity) : V2_ZERO

				permanence.position += permanence.velocity * dt

			}

			flash_amount: f32 = permanence.life_time >= permanence.max_life_time - 0.3 ? 1 : 0

			uv := get_frame_uvs(.enemies, permanence.frame, {18, 18})
			draw_quad_center_xform(
				transform_2d(permanence.position, permanence.rotation),
				{18, 18},
				.enemies,
				uv,
				{0.9, 0.9, 0.9, 1.0} - {alpha, alpha, alpha, alpha},
				flash_amount,
			)

		case .blood:
			alpha: f32 = 0.0
			max_alpha: f32 = 1.0

			alpha = math.lerp(
				alpha,
				max_alpha,
				1.0 - permanence.life_time / permanence.max_life_time,
			)
			uv := get_frame_uvs(.blood, permanence.frame, {40, 40})
			draw_quad_center_xform(
				transform_2d(permanence.position, permanence.rotation),
				{18, 18},
				.blood,
				uv,
				COLOR_WHITE - {0, 0, 0, alpha},
			)
		case .explosion:
			alpha: f32 = 0.6
			max_alpha: f32 = 1.0

			alpha = math.lerp(
				alpha,
				max_alpha,
				1.0 - permanence.life_time / permanence.max_life_time,
			)
			draw_quad_center_xform(
				transform_2d(permanence.position),
				{permanence.size - 5, permanence.size - 5},
				.explosion,
				DEFAULT_UV,
				COLOR_BLACK - {0, 0, 0, alpha},
			)
		}
	}
}
