package main
import "core:math/rand"


PropType :: enum {
	cactus,
	tnt,
	shrub,
	rock,
	small_rock,
	small_shrub,
	tomb_stone,
	mud,
	brick,
	reids,
	cross,
	brick2,
	mud2,
}


EnvironmentProp :: struct {
	using _:      BaseEntity,
	type:         PropType,
	destructible: bool,
}


setup_scene_props :: proc() {


	tiles_x := LEVEL_BOUNDS.x / 18
	tiles_y := LEVEL_BOUNDS.y / 18
	probabilities := get_prop_spawn_probabilities()

	spawn_bag: [dynamic]PropType
	defer delete(spawn_bag)


	for type in PropType {
		prob := int(probabilities[type] * 1000)

		for i := 0; i < prob; i += 1 {
			append(&spawn_bag, type)
		}
	}

	for x: int = 0; x < auto_cast (tiles_x); x += 1 {
		for y: int = 0; y < auto_cast (tiles_y); y += 1 {
			if x <= 1 || y <= 1 || rand.int_max(10) >= 1 {
				continue
			}


			prop_type := rand.int_max(len(spawn_bag))
			prop: EnvironmentProp
			prop.type = spawn_bag[prop_type]
			ordered_remove(&spawn_bag, prop_type)
			prop.active = true
			prop.destructible = is_destructable(prop.type)
			prop.position = {auto_cast (x * 18), auto_cast (y * 18)} - LEVEL_BOUNDS * 0.5


			append(&game_data.environment_prop, prop)
		}
	}

}


is_destructable :: proc(type: PropType) -> bool {
	#partial switch type {
	case .cactus, .tnt, .tomb_stone, .cross:
		return true
	}
	return false
}

update_render_props :: proc() {
	//@enviroment_props
	for &prop in &game_data.environment_prop {
		if !prop.active {
			continue
		}
		uvs := get_frame_uvs(.environment_prop, {0, auto_cast prop.type}, {18, 18})
		draw_quad_center_xform(
			transform_2d(prop.position),
			{18, 18},
			.environment_prop,
			uvs,
			COLOR_WHITE,
		)
	}
}


// LARGER NUMBER = MORE FREQUENT
get_prop_base_propability :: proc(prop_type: PropType) -> f32 {
	switch (prop_type) {
	case .cactus:
		return 0.13
	case .tnt:
		return 0.15
	case .tomb_stone:
		return 0.1
	case .cross:
		return 0.1
	case .brick:
		return 0.99
	case .brick2:
		return 0.99
	case .rock:
		return 0.3
	case .small_rock:
		return 0.45
	case .mud:
		return 0.95
	case .mud2:
		return 0.95
	case .reids:
		return 0.3
	case .shrub:
		return 0.3
	case .small_shrub:
		return 0.43
	}

	return 0


}


get_prop_spawn_probabilities :: proc() -> [PropType]f32 {
	probabilities: [PropType]f32
	wave_number := game_data.current_wave
	for type in PropType {
		probabilities[type] = get_prop_base_propability(type)
	}

	return probabilities
}
