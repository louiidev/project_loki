package main

import "core:math"
import "core:math/linalg"
import "core:math/rand"

Particle :: struct {
	using _:          BaseEntity,
	velocity:         Vector2,
	rotation:         f32,
	lifetime:         f32,
	current_lifetime: f32,
	size:             f32,
	color:            Vector4,
	imageId:          ImageId,
}


SpriteParticle :: struct {
	using _:                Particle,
	time_per_frame:         f32,
	sprite_cell_start:      Vector2Int,
	animation_count:        int,
	current_frame:          int,
	current_animation_time: f32,
	scale:                  f32,
}


PARTICLE_LIFETIME: f32 : 0.5

PARTICLE_VELOCITY: f32 : 50

spawn_particles :: proc(position: Vector2, color: Vector4 = COLOR_WHITE) {
	num_particles := rand.int_max(5) + 4
	last_dir: f32 = 0
	for i := 0; i < num_particles; i += 1 {

		rand_direction: f32 = math.to_radians(rand.float32_range(0, 360)) + last_dir
		last_dir = rand_direction
		particle: Particle
		particle.position = position
		particle.active = true
		particle.color = color
		particle.lifetime = PARTICLE_LIFETIME
		particle.size = 5.0 + rand.float32_range(-1.5, 1.5)


		particle.velocity =
			{math.cos(rand_direction), math.sin(rand_direction)} * PARTICLE_VELOCITY
		append(&game_data.particles, particle)
	}
}


spawn_walking_particles :: proc(position: Vector2, color: Vector4, direction: Vector2) {
	num_particles := rand.int_max(1) + 1
	last_dir: f32 = 0
	for i := 0; i < num_particles; i += 1 {

		rand_direction: f32 = rand.float32_range(-1.5, 1.5)

		particle: Particle
		particle.position = position + rand_direction
		particle.active = true
		particle.color = color
		particle.lifetime = PARTICLE_LIFETIME
		particle.size = 3.0 + rand.float32_range(0, 1.5)
		particle.imageId = .circle


		particle.velocity = {math.cos(direction.x), math.sin(direction.y)} * PARTICLE_VELOCITY
		append(&game_data.particles, particle)
	}
}


update_render_particles :: proc(dt: f32) {

	for &particle in &game_data.particles {

		if !particle.active {
			continue
		}

		particle.current_lifetime += dt


		normalized_life := particle.current_lifetime / particle.lifetime
		scale := (1.0 - normalized_life) * (1.0 - normalized_life)

		current_size := particle.size * scale
		if current_size <= 0 || particle.current_lifetime >= particle.lifetime {
			particle.active = false

		}

		current_velocity := particle.velocity * scale
		particle.position += current_velocity * dt
		draw_quad_center_xform(
			transform_2d(particle.position),
			{current_size, current_size},
			particle.imageId,
			DEFAULT_UV,
			particle.color,
		)
	}


	for &particle in &game_data.sprite_particles {


		if particle.current_frame >= particle.animation_count - 1 {
			particle.active = false
		}
		if !particle.active {
			continue
		}

		particle.current_animation_time += dt

		if particle.current_frame < particle.animation_count - 1 &&
		   particle.current_animation_time > particle.time_per_frame {
			particle.current_frame += 1
			particle.current_animation_time = 0
		}


		xform :=
			linalg.matrix4_translate(Vector3{particle.position.x, particle.position.y, 0.0}) *
			linalg.matrix4_rotate(particle.rotation, Vector3{0, 0, 1})

		uvs := get_frame_uvs(
			.sprite_particles,
			{particle.sprite_cell_start.x + particle.current_frame, particle.sprite_cell_start.y},
			{16, 16},
		)
		draw_quad_center_xform(xform, {auto_cast 16, auto_cast 16}, .sprite_particles, uvs)
	}

}

create_bullet_death :: proc(projectile: ^Projectile) {
	sp: SpriteParticle
	sp.active = true
	sp.position = projectile.position
	sp.sprite_cell_start = projectile.sprite_cell_start
	sp.scale = projectile.scale
	sp.animation_count = 7
	sp.time_per_frame = 0.05
	sp.rotation = projectile.rotation
	append(&game_data.sprite_particles, sp)
}
