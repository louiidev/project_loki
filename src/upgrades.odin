package main

Upgrade :: enum {
	PIERCING_SHOT,
	BOUNCE_SHOT,
	RELOAD_SPEED,
	ROLL_SPEED,
	ROLL_STAMINIA,
	HEALTH,
	MAX_HEALTH,
	AMMO_UPGRADE,
}


get_upgrade_heading :: proc(upgrade: Upgrade) -> string {
	switch upgrade {
	case .BOUNCE_SHOT:
		return "Bounce Shot"
	case .MAX_HEALTH:
		return "Max Health +1"
	case .HEALTH:
		return "Health +1"
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
	}


	return "ERROR"
}


get_upgrade_description :: proc(upgrade: Upgrade) -> string {
	switch upgrade {
	case .BOUNCE_SHOT:
		return "Bounces off enemy after hit"
	case .HEALTH:
		return "Replenishes the players health by +1"
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
	}


	return "ERROR"
}
