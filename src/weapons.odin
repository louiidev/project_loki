package main
import "core:math"

Weapon :: enum {
	Revolver,
	Shotgun,
	SMG,
	MachineGun,
	Sniper,
}


// SHOTGUN
PLAYER_SHOTGUN_BULLET_RANGE: f32 : 75
PLAYER_SHOTGUN_RELOAD_TIME: f32 : 1.8
PLAYER_SHOTGUN_BULLETS: int : 5
PLAYER_SHOTGUN_BULLET_SPREAD: f32 : 25.0

// SMG
PLAYER_SMG_BULLET_RANGE: f32 : 120
PLAYER_SMG_RELOAD_TIME: f32 : 1.3
PLAYER_SMG_BULLETS: int : 15
PLAYER_SMG_BULLET_DMG: f32 : 8
PLAYER_SMG_BULLET_VELOCITY :: 700.0
PLAYER_SMG_BULLET_SPREAD: f32 : 25.0
PLAYER_SMG_FIRE_RATE: f32 : 0.1

// MACHINE_GUN
PLAYER_MACHINE_GUN_BULLET_RANGE: f32 : 220
PLAYER_MACHINE_GUN_RELOAD_TIME: f32 : 1.8
PLAYER_MACHINE_GUN_BULLETS: int : 20
PLAYER_MACHINE_GUN_BULLET_DMG: f32 : 10
PLAYER_MACHINE_GUN_BULLET_VELOCITY :: 600.0
PLAYER_MACHINE_GUN_BULLET_SPREAD: f32 : 15.0
PLAYER_MACHINE_GUN_FIRE_RATE: f32 : 0.17

// SNIPER
PLAYER_SNIPER_BULLET_RANGE: f32 : 300
PLAYER_SNIPER_RELOAD_TIME: f32 : 2.0
PLAYER_SNIPER_BULLETS: int : 6
PLAYER_SNIPER_BULLET_DMG: f32 : 15
PLAYER_SNIPER_BULLET_VELOCITY :: 800.0
PLAYER_SNIPER_BULLET_SPREAD: f32 : 2.0
PLAYER_SNIPER_FIRE_RATE: f32 : 0.8

add_shotgun_to_player :: proc() {
	game_data.player_upgrade[.SHOTGUN] = 1
	game_data.player_upgrade[.BULLETS] = math.max(
		game_data.player_upgrade[.BULLETS],
		PLAYER_SHOTGUN_BULLETS,
	)
	game_data.max_bullets = PLAYER_SHOTGUN_BULLETS
	increase_upgrade_by_percentage(50, &game_data.weapon_bullet_dmg)
	game_data.weapon_bullet_range = PLAYER_SHOTGUN_BULLET_RANGE
	game_data.player.last_weapon_pickup = .Shotgun
	game_data.weapon_time_to_reload = PLAYER_SHOTGUN_RELOAD_TIME
	game_data.weapon_bullet_spread = PLAYER_SHOTGUN_BULLET_SPREAD
	game_data.weapon_bullet_scale = 0.3
	game_data.current_bullets_count = game_data.max_bullets

}

add_smg_to_player :: proc() {
	game_data.player_upgrade[.SMG] = 1
	game_data.weapon_max_bullets = auto_cast PLAYER_SMG_BULLETS
	game_data.weapon_bullet_dmg = PLAYER_SMG_BULLET_DMG
	game_data.weapon_bullet_range = PLAYER_SMG_BULLET_RANGE
	game_data.player.last_weapon_pickup = .SMG
	game_data.weapon_time_to_reload = PLAYER_SMG_RELOAD_TIME
	game_data.weapon_bullet_spread = PLAYER_SMG_BULLET_SPREAD
	game_data.weapon_bullet_velocity = PLAYER_SMG_BULLET_VELOCITY
	game_data.weapon_fire_rate = PLAYER_SMG_FIRE_RATE
	game_data.current_bullets_count = game_data.max_bullets

}

add_machine_gun_to_player :: proc() {
	game_data.player_upgrade[.MACHINE_GUN] = 1
	game_data.max_bullets = PLAYER_MACHINE_GUN_BULLETS
	game_data.weapon_bullet_dmg = PLAYER_MACHINE_GUN_BULLET_DMG
	game_data.weapon_bullet_range = PLAYER_MACHINE_GUN_BULLET_RANGE
	game_data.player.last_weapon_pickup = .MachineGun
	game_data.weapon_time_to_reload = PLAYER_MACHINE_GUN_RELOAD_TIME
	game_data.weapon_bullet_spread = PLAYER_MACHINE_GUN_BULLET_SPREAD
	game_data.weapon_bullet_velocity = PLAYER_MACHINE_GUN_BULLET_VELOCITY
	game_data.weapon_fire_rate = PLAYER_MACHINE_GUN_FIRE_RATE
	game_data.current_bullets_count = game_data.max_bullets

}


add_sniper_to_player :: proc() {
	game_data.bullet_scale = -0.3
	game_data.player_upgrade[.SNIPER] = 1
	game_data.max_bullets = 6
	game_data.weapon_bullet_dmg = PLAYER_SNIPER_BULLET_DMG
	game_data.weapon_bullet_range = PLAYER_SNIPER_BULLET_RANGE
	game_data.player.last_weapon_pickup = .Sniper
	game_data.weapon_time_to_reload = PLAYER_SNIPER_RELOAD_TIME
	game_data.weapon_bullet_spread = PLAYER_SNIPER_BULLET_SPREAD
	game_data.weapon_bullet_velocity = PLAYER_SNIPER_BULLET_VELOCITY
	game_data.weapon_fire_rate = PLAYER_SNIPER_FIRE_RATE
	game_data.current_bullets_count = game_data.max_bullets
	increase_upgrade_by_percentage(100, &game_data.chance_for_piercing_shot)

}

pickup_to_weapon_enum :: proc(pickup_enum: PickupType) -> Weapon {
	#partial switch (pickup_enum) {
	case .Shotgun:
		return .Shotgun
	case .SMG:
		return .SMG
	case .Sniper:
		return .Sniper
	case .MachineGun:
		return .MachineGun
	}

	assert(false, "Missing enum conversion")
	return .Revolver
}


weapon_to_pickup_enum :: proc(weapon_enum: Weapon) -> PickupType {
	#partial switch (weapon_enum) {
	case .Shotgun:
		return .Shotgun
	case .SMG:
		return .SMG
	case .Sniper:
		return .Sniper
	case .MachineGun:
		return .MachineGun
	}

	assert(false, "Missing enum conversion")
	return .Ammo
}
