package main


aabb_collide :: proc(a: Vector4, b: Vector4) -> (bool, Vector2) {
	// Calculate overlap on each axis
	dx := (a.z + a.x) / 2 - (b.z + b.x) / 2
	dy := (a.w + a.y) / 2 - (b.w + b.y) / 2

	overlap_x := (a.z - a.x) / 2 + (b.z - b.x) / 2 - abs(dx)
	overlap_y := (a.w - a.y) / 2 + (b.w - b.y) / 2 - abs(dy)

	// If there is no overlap on any axis, there is no collision
	if overlap_x <= 0 || overlap_y <= 0 {
		return false, Vector2{}
	}

	// Find the penetration vector
	penetration := Vector2{}
	if overlap_x < overlap_y {
		penetration.x = overlap_x if dx > 0 else -overlap_x
	} else {
		penetration.y = overlap_y if dy > 0 else -overlap_y
	}

	return true, penetration
}


aabb_contains :: proc(center_position: Vector2, size: Vector2, p: Vector2) -> bool {
	return(
		(p.x >= center_position.x - size.x * 0.5) &&
		(p.x <= center_position.x + size.x * 0.5) &&
		(p.y >= center_position.y - size.y * 0.5) &&
		(p.y <= center_position.y + size.y * 0.5)
	)
}
