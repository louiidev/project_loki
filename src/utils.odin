package main

import "base:intrinsics"
import "core:math"
import "core:math/linalg"


almost_equals :: proc(a, b, epsilon: f32) -> bool {
	return math.abs(a - b) <= epsilon
}

animate_f32_to_target :: proc(value: ^f32, target: f32, delta_t: f32, rate: f32) -> bool {
	value^ += (target - value^) * (1 - math.pow(2.0, -rate * delta_t))
	if (almost_equals(value^, target, 0.001)) {
		value^ = target
		return true
	}

	return false
}

animate_v2_to_target :: proc(value: ^Vector2, target: Vector2, delta_t: f32, rate: f32) {
	animate_f32_to_target(&value.x, target.x, delta_t, rate)
	animate_f32_to_target(&value.y, target.y, delta_t, rate)
}


camera_shake :: proc(amount: f32) {
	if amount > game_data.shake_amount {
		game_data.shake_amount = amount
	}
}


sine_breathe_alpha :: proc(p: $T) -> T where intrinsics.type_is_float(T) {
	return (math.sin((p - .25) * 2.0 * math.PI) / 2.0) + 0.5
}

cos_breathe_alpha :: proc(p: $T) -> T where intrinsics.type_is_float(T) {
	return (math.cos((p - .25) * 2.0 * math.PI) / 2.0) + 0.5
}

ticks_per_second: u64
run_every_seconds :: proc(s: f32) -> bool {

	test := f32(game_data.ticks) / f32(ticks_per_second)

	interval: f32 = s * f32(ticks_per_second)

	if interval < 1.0 {
		log("run_every_seconds is ticking each frame, can't go faster than this")
	}

	run := (game_data.ticks % u64(interval)) == 0
	return run
}


generate_points_rotation_around_circle :: proc(
	radius: f32,
	num_points: int,
	circle_degrees: f32,
) -> (
	[]Vector2,
	[]f32,
) {
	points: []Vector2 = make([]Vector2, num_points)
	rotations: []f32 = make([]f32, num_points)

	angle_step: f32 = circle_degrees / auto_cast num_points

	for i := 0; i < num_points; i += 1 {
		angle: f32 = math.to_radians(angle_step * auto_cast i)
		points[i] = Vector2{radius * math.cos(angle), radius * math.sin(angle)}
		rotations[i] = angle
	}

	return points, rotations
}
