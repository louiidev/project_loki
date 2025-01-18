package main

import "core:fmt"
import "core:math"
import "core:math/rand"

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
	BOMB_DROP_RELOAD,
	PIERCING_SPIKE_RELOAD,
	ROTATING_ORB,
	ORB_DAMAGE_INCREASE,
	BULLET_DMG,
}


// Returns 0 for probability if they dont have upgrade
only_if_has_upgrade :: proc(upgrade: Upgrade) -> f32 {
	return game_data.player_upgrade[upgrade] > 0 ? 1.0 : 0.0
}

// Returns 0 for probability if they have upgrade
only_if_dont_have_upgrade :: proc(upgrade: Upgrade) -> f32 {
	return game_data.player_upgrade[upgrade] > 0 ? 0.0 : 1.0
}


get_base_percentage :: proc(upgrade: Upgrade) -> f32 {
	#partial switch (upgrade) {
	case .BOMB_DROP_RELOAD:
		return 20
	case .PIERCING_SPIKE_RELOAD:
		return 100
	}


	return 10
}

upgrade_percentage_modifier :: proc(upgrade: Upgrade) -> f32 {
	#partial switch (upgrade) {
	case .BOMB_DROP_RELOAD:
		return 1.5
	}


	return 1
}


get_upgrade_percentage :: proc(upgrade: Upgrade) -> f32 {
	upgrade_amount := game_data.player_upgrade[upgrade]


	switch upgrade_amount {
	case 0 ..= 1:
		return get_base_percentage(upgrade)
	case 2 ..= 4:
		return 5 * upgrade_percentage_modifier(upgrade)
	}

	return 2.5 * upgrade_percentage_modifier(upgrade)
}


get_upgrade_cost_additional :: proc(upgrade: Upgrade) -> int {
	upgrade_amount := game_data.player_upgrade[upgrade]


	switch upgrade_amount {
	case 0 ..= 1:
		return 0
	case 2 ..= 4:
		return 2
	}

	return 4
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
	case .BOMB_DROP_RELOAD:
		return "Bombs drop on reload"
	case .PIERCING_SPIKE_RELOAD:
		return "Piercing spikes on reload"
	case .ROTATING_ORB:
		return "Rotating Orb +1"
	case .ORB_DAMAGE_INCREASE:
		return "Increased Orb Damage"
	case .BULLET_DMG:
		return "Increases Bullet Damage"
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
		return fmt.tprintf("Upgrades by reload speed by %.0f%%", percentage)
	case .ROLL_SPEED:
		return fmt.tprintf("Upgrades by roll speed by %.0f%%", percentage)
	case .ROLL_STAMINIA:
		return fmt.tprintf("Upgrades the roll staminia by %.0f%%", percentage)
	case .AMMO_UPGRADE:
		return "Upgrades the ammo by 2+"
	case .BULLETS:
		return "Upgrades the amount of bullets you fire by 1+"
	case .EXPLODING_ENEMIES:
		return fmt.tprintf("%.0f%% chance an enemy explodes on death", percentage)
	case .PICKUP_RADIUS:
		return fmt.tprintf("Increases Radius by %.0f%%", percentage)
	case .WALKING_SPEED:
		return fmt.tprintf("Increases Speed by %.0f%%", percentage)
	case .STUN_TIME:
		return fmt.tprintf("Increases Stun time by %.0f%%", percentage)
	case .BIGGER_BULLETS:
		return fmt.tprintf("Increases Bullet size by %.0f%%", percentage)
	case .BOMB_DROP_RELOAD:
		return fmt.tprintf("%.0f%% chance a bomb drops on reload", percentage)
	case .PIERCING_SPIKE_RELOAD:
		return "Fires Piercing spikes on reload"
	case .ROTATING_ORB:
		return "Creates an Orb that rotates around the player and deals damage"
	case .ORB_DAMAGE_INCREASE:
		return fmt.tprintf("Increases Orb Damage by %.0f%%", percentage)
	case .BULLET_DMG:
		return fmt.tprintf("Increases Bullet Damage by %.0f%%", percentage)
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
	case .ORB_DAMAGE_INCREASE:
		increase_upgrade_by_percentage(percentage, &game_data.orb_damage_per_hit)
	case .BULLET_DMG:
		increase_upgrade_by_percentage(percentage, &game_data.bullet_dmg)
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
	case .BOMB_DROP_RELOAD:
		return 2
	case .PIERCING_SPIKE_RELOAD:
		return 6
	case .ROTATING_ORB:
		return 4
	case .ORB_DAMAGE_INCREASE:
		return 4
	case .BULLET_DMG:
		return 4
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
	case .BOMB_DROP_RELOAD:
		return 0.2
	case .PIERCING_SPIKE_RELOAD:
		return only_if_dont_have_upgrade(.PIERCING_SPIKE_RELOAD) * 0.1
	case .ROTATING_ORB:
		return 0.1
	case .ORB_DAMAGE_INCREASE:
		return only_if_has_upgrade(.ROTATING_ORB) * 0.1
	case .BULLET_DMG:
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


should_spawn_upgrade :: proc(upgrade: Upgrade) -> bool {
	if game_data.player_upgrade[upgrade] == 0 {
		return false
	}
	return get_upgrade_percentage(upgrade) >= (rand.float32_range(0, 1.0) * 100)
}
