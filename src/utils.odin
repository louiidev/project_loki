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
