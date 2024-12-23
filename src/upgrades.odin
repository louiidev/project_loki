package main


get_upgrade_heading :: proc(upgrade: Upgrade) -> string {
	switch upgrade {
	case .FORK_SHOT:
		return "Fork Shot"
	case .HEALTH:
		return "Health"
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
	case .FORK_SHOT:
		return "Creates a fork of the shot when hitting an enemy"
	case .HEALTH:
		return "Upgrades the players health by +2"
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
