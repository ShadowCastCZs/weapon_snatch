Config = {}

Config.Locale = 'cs'

--- auto | esx | qb
Config.Framework = 'auto'

--- auto | qs | ox | esx | qb
--- qs = qs-inventory, ox = ox_inventory, esx = ESX loadout / esx items, qb = qb-inventory
Config.Inventory = 'auto'

--- Built-in ox_target on players (disable when using exports / another target)
Config.BuiltinOxTarget = {
	Enabled = true,
	Label = 'take_weapon_target',
	Icon = 'fas fa-hand-back-fist',
	Name = 'weapon_snatch_take',
	Distance = 2.5,
}

--- Optional test command (/takeweapon) for custom setups
Config.Command = {
	Enabled = false,
	Name = 'takeweapon',
}

Config.Enabled = true
Config.Chance = 0.5
Config.MaxDistance = 2.5
Config.Cooldown = 8
Config.EquipOnSuccess = true
Config.RequireTargetAimingAtOfficer = true
Config.RequireTargetArmed = true

Config.WeaponPatterns = { 'pistol', 'revolver' }
Config.Exclude = { 'weapon_unarmed', 'weapon_stungun', 'weapon_radargun' }

--- qs-inventory event prefix
Config.InventoryPrefix = 'inventory'

--- Optional job gate (ignored when RegisterCanAttempt export is used)
Config.RequireJob = false
Config.AllowedJobs = {
	police = true,
}
Config.RequireOnDuty = false
Config.PoliceJobName = 'police'

--- Custom interaction export: return false to use built-in attempt logic
Config.CustomInteraction = {
	Enabled = false,
}
