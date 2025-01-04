package main

import "core:math"

Upgrade :: enum {
	PIERCING_SHOT,
	BOUNCE_SHOT,
	RELOAD_SPEED,
	ROLL_SPEED,
	ROLL_STAMINIA,
	HEALTH,
	HEALTH_2,
	MAX_HEALTH,
	AMMO_UPGRADE,
	BULLETS,
	EXPLODING_ENEMIES,
}


get_upgrade_heading :: proc(upgrade: Upgrade) -> string {
	switch upgrade {
	case .BOUNCE_SHOT:
		return "Bounce Shot"
	case .MAX_HEALTH:
		return "Max Health +1"
	case .HEALTH:
		return "Health +1"
	case .HEALTH_2:
		return "Health +2"
	case .PIERCING_SHOT:
		return "Piecing Shot"
	case .RELOAD_SPEED:
		return "Reload Speed"
	case .ROLL_SPEED:
		return "Roll Speed"
	case .ROLL_STAMINIA:
		return "Roll staminia"
	case .AMMO_UPGRADE:
		return "Ammo Upgrade"
	case .BULLETS:
		return "Bullets +1"
	case .EXPLODING_ENEMIES:
		return "Enemies Explode on Death"
	}


	return "ERROR"
}


get_upgrade_description :: proc(upgrade: Upgrade) -> string {
	switch upgrade {
	case .BOUNCE_SHOT:
		return "Bounces off enemy after hit"
	case .HEALTH:
		return "Replenishes the players health by +1"
	case .HEALTH_2:
		return "Replenishes the players health by +2"
	case .MAX_HEALTH:
		return "Upgrades the players max health by +1"
	case .PIERCING_SHOT:
		return "Pierces through enemies"
	case .RELOAD_SPEED:
		return "Upgrades by reload speed by 5%"
	case .ROLL_SPEED:
		return "Upgrades by roll speed by 5%"
	case .ROLL_STAMINIA:
		return "Upgrades the roll staminia by 10%"
	case .AMMO_UPGRADE:
		return "Upgrades the ammo by 2+"
	case .BULLETS:
		return "Upgrades the amount of bullets you fire by 1+"

	case .EXPLODING_ENEMIES:
		return "5%+ chance an enemy explodes on death"
	}


	return "ERROR"
}


purchase_shop_upgrade :: proc(shop_upgrade: ^ShopUpgrade) {
	shop_upgrade.purchased = true
	game_data.money -= shop_upgrade.cost
	assert(game_data.money >= 0)
	log(game_data.money, shop_upgrade.cost)

	game_data.player_upgrade[shop_upgrade.upgrade] += 1

	#partial switch (shop_upgrade.upgrade) {
	case .AMMO_UPGRADE:
		game_data.max_bullets += 2
	case .HEALTH:
		game_data.player.health = math.min(
			game_data.player.max_health,
			game_data.player.health + 1,
		)
	case .MAX_HEALTH:
		game_data.player.max_health += 1

	case .HEALTH_2:
		game_data.player.health = math.min(
			game_data.player.max_health,
			game_data.player.health + 2,
		)

	case .RELOAD_SPEED:
		game_data.time_to_reload = math.max(
			PLAYER_MIN_POSSIBLE_RELOAD_TIME,
			game_data.time_to_reload - (game_data.time_to_reload * 0.05),
		)
	}


}


get_upgrade_propability :: proc(upgrade: Upgrade) -> f32 {
	switch upgrade {
	case .BOUNCE_SHOT:
		return 0.1
	case .MAX_HEALTH:
		return 0.1
	case .HEALTH:
		return 0.3
	case .HEALTH_2:
		return 0.2
	case .PIERCING_SHOT:
		return 0.15
	case .RELOAD_SPEED:
		return 0.24
	case .ROLL_SPEED:
		return 0.25
	case .ROLL_STAMINIA:
		return 0.25
	case .AMMO_UPGRADE:
		return 0.25
	case .BULLETS:
		return 0.1
	case .EXPLODING_ENEMIES:
		return 0.3
	}

	return 0


}


get_upgrade_shop_probabilities :: proc() -> [Upgrade]f32 {
	probabilities: [Upgrade]f32
	for type in Upgrade {
		base_prob := get_upgrade_propability(type)
		probabilities[type] = base_prob
	}

	return probabilities
}
