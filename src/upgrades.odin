package main

import "core:fmt"
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
	PICKUP_RADIUS,
	WALKING_SPEED,
	STUN_TIME,
	BIGGER_BULLETS,
}


get_upgrade_percentage :: proc(upgrade: Upgrade) -> f32 {
	upgrade_amount := game_data.player_upgrade[upgrade]


	switch upgrade_amount {
	case 0 ..= 1:
		return 10
	case 2 ..= 4:
		return 5
	}

	return 2.5
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
	case .PICKUP_RADIUS:
		return "Increased Pickup Radius"
	case .WALKING_SPEED:
		return "Increased Walking Speed"
	case .STUN_TIME:
		return "Increased Stun Time"
	case .BIGGER_BULLETS:
		return "Increased Bullet Size"

	}


	return "ERROR"
}


get_upgrade_description :: proc(upgrade: Upgrade) -> string {


	percentage := get_upgrade_percentage(upgrade)
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
		return fmt.tprintf("Upgrades by roll speed by 0.f%", percentage)
	case .ROLL_STAMINIA:
		return fmt.tprintf("Upgrades the roll staminia by 0.f%", percentage)
	case .AMMO_UPGRADE:
		return "Upgrades the ammo by 2+"
	case .BULLETS:
		return "Upgrades the amount of bullets you fire by 1+"
	case .EXPLODING_ENEMIES:
		return "5%+ chance an enemy explodes on death"
	case .PICKUP_RADIUS:
		return fmt.tprintf("Increases Radius by 0.f%", percentage)
	case .WALKING_SPEED:
		return fmt.tprintf("Increases Speed by 0.f%", percentage)
	case .STUN_TIME:
		return fmt.tprintf("Increases Stun time by 0.f%", percentage)
	case .BIGGER_BULLETS:
		return "Increases Bullet size by "
	}


	return "ERROR"
}


increase_upgrade_by_percentage :: proc(percentage: f32, upgrade: ^f32) {
	upgrade^ += upgrade^ * (percentage / 100)
}


purchase_shop_upgrade :: proc(shop_upgrade: ^ShopUpgrade) {
	shop_upgrade.purchased = true
	game_data.money -= shop_upgrade.cost
	assert(game_data.money >= 0)
	log(game_data.money, shop_upgrade.cost)
	percentage := get_upgrade_percentage(shop_upgrade.upgrade)
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
	case .ROLL_STAMINIA:
		increase_upgrade_by_percentage(percentage, &game_data.player.max_roll_stamina)
	case .ROLL_SPEED:
		increase_upgrade_by_percentage(percentage, &game_data.player.roll_speed)
	case .WALKING_SPEED:
		increase_upgrade_by_percentage(percentage, &game_data.player.speed)
		increase_upgrade_by_percentage(percentage, &game_data.player.speed_while_shooting)
	case .PICKUP_RADIUS:
		increase_upgrade_by_percentage(percentage, &game_data.money_pickup_radius)
	case .STUN_TIME:
		increase_upgrade_by_percentage(percentage, &game_data.enemy_stun_time)
	}


}


get_upgrade_cost :: proc(upgrade: Upgrade) -> int {


	switch upgrade {
	case .BOUNCE_SHOT:
		return 5
	case .MAX_HEALTH:
		return 3
	case .HEALTH:
		return 2
	case .HEALTH_2:
		return 3
	case .PIERCING_SHOT:
		return 2
	case .RELOAD_SPEED:
		return 1
	case .ROLL_SPEED:
		return 1
	case .ROLL_STAMINIA:
		return 1
	case .AMMO_UPGRADE:
		return 2
	case .BULLETS:
		return 6
	case .EXPLODING_ENEMIES:
		return 1
	case .PICKUP_RADIUS:
		return 1
	case .WALKING_SPEED:
		return 1
	case .STUN_TIME:
		return 2
	case .BIGGER_BULLETS:
		return 3
	}

	return 0


}
// LARGER NUMBER = MORE FREQUENT
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
	case .PICKUP_RADIUS:
		return 0.3
	case .WALKING_SPEED:
		return 0.3
	case .STUN_TIME:
		return 0.25
	case .BIGGER_BULLETS:
		return 0.1
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
