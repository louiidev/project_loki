package main

import "core:math"
import "core:math/rand"

Particle :: struct {
	position:         Vector2,
	active:           bool,
	velocity:         Vector2,
	rotation:         f32,
	lifetime:         f32,
	current_lifetime: f32,
	size:             f32,
	color:            Vector4,
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


update_render_particles :: proc(dt: f32) {

	for &particle in &game_data.particles {

		if !particle.active {
			continue
		}

		particle.current_lifetime += dt


		normalized_life := particle.current_lifetime / particle.lifetime
		// normalized_life := 1.0 - (particle.current_lifetime / particle.lifetime)
		scale := (1.0 - normalized_life) * (1.0 - normalized_life)

		current_size := particle.size * scale
		if current_size <= 0 || particle.current_lifetime >= particle.lifetime {
			particle.active = false

		}

		current_velocity := particle.velocity * scale
		particle.position += current_velocity * dt
		draw_rect_center_xform(
			transform_2d(particle.position),
			{current_size, current_size},
			particle.color,
		)
	}


	for i := len(game_data.particles) - 1; i >= 0; i -= 1 {
		particle := &game_data.particles[i]
		if !particle.active {
			ordered_remove(&game_data.particles, i)
		}
	}

}
