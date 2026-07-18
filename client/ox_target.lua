local registered = false

local function cfg()
	if GetWeaponSnatchRuntimeConfig then
		return GetWeaponSnatchRuntimeConfig()
	end
	return Config
end

local function targetCfg()
	local builtin = cfg().BuiltinOxTarget
	if type(builtin) == 'table' then
		return builtin
	end
	return Config.BuiltinOxTarget or {}
end

local function isEnabled()
	local enabled = cfg().Enabled
	if enabled == nil then
		enabled = Config.Enabled
	end
	return enabled ~= false and targetCfg().Enabled ~= false
end

local function registerTarget()
	if registered or not isEnabled() then
		return
	end
	if GetResourceState('ox_target') ~= 'started' then
		return
	end

	local interaction = GetInteractionExport()

	exports.ox_target:addGlobalPlayer({
		{
			name = interaction.name,
			icon = interaction.icon,
			label = interaction.label,
			distance = interaction.distance,
			canInteract = interaction.canInteract,
			onSelect = interaction.onSelect,
		},
	})
	registered = true
end

local function unregisterTarget()
	if not registered or GetResourceState('ox_target') ~= 'started' then
		registered = false
		return
	end

	local interaction = GetInteractionExport()
	pcall(function()
		exports.ox_target:removeGlobalPlayer(interaction.name)
	end)
	registered = false
end

function RefreshWeaponSnatchTarget()
	unregisterTarget()
	registerTarget()
end

CreateThread(function()
	while WeaponSnatchFramework.Get() == 'esx' and (not ESX or not ESX.PlayerLoaded) do
		Wait(200)
	end
	while WeaponSnatchFramework.Get() == 'qb' and not WeaponSnatchFramework.GetQBCore() do
		Wait(200)
	end
	registerTarget()
end)

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == 'ox_target' or resourceName == GetCurrentResourceName() then
		Wait(500)
		registerTarget()
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		unregisterTarget()
	end
end)
