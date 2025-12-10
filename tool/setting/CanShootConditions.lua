local module = {
	[1] = function(Tool, Humanoid, Heat, MaxHeat, Mag, AmmoPerMag, Ammo, MaxAmmo, ShootCounts, CurrentFireRate)
		return true
	end,
}

return table.isfrozen(module) and module or table.freeze(module)
