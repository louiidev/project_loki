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
	}


	return "ERROR"
}
