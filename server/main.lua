local snatchCooldowns = {}
local canAttemptOverride = nil
local customTakeHandler = nil
local runtimeConfig = {}

local function cfg()
	return runtimeConfig
end

local function mergeConfig(overrides)
	runtimeConfig = {}
	for key, value in pairs(Config) do
		runtimeConfig[key] = value
	end
	if type(overrides) == 'table' then
		for key, value in pairs(overrides) do
			runtimeConfig[key] = value
		end
	end
	WeaponSnatchFramework.ResetCache()
end

local function enabled()
	local value = cfg().Enabled
	if value == nil then
		value = Config.Enabled
	end
	return value ~= false
end

local function defaultCanAttempt(source, targetId)
	if canAttemptOverride then
		return canAttemptOverride(source, targetId) == true
	end

	if cfg().RequireJob == true or Config.RequireJob == true then
		local framework = WeaponSnatchFramework.Get()

		if framework == 'qb' then
			local qb = WeaponSnatchFramework.GetQBCore()
			local player = qb and qb.Functions.GetPlayer(source)
			if not player then
				return false
			end
			local job = player.PlayerData.job
			local allowed = cfg().AllowedJobs or Config.AllowedJobs or {}
			if not allowed[job.name] then
				return false
			end
			if cfg().RequireOnDuty ~= false and Config.RequireOnDuty ~= false and not job.onduty then
				return false
			end
			return true
		end

		local esx = WeaponSnatchFramework.GetESX()
		local xPlayer = esx and esx.GetPlayerFromId(source)
		if not xPlayer then
			return false
		end

		local jobName = xPlayer.job.name
		local allowed = cfg().AllowedJobs or Config.AllowedJobs or {}
		if not allowed[jobName] then
			return false
		end

		if cfg().RequireOnDuty ~= false and Config.RequireOnDuty ~= false then
			local policeJob = cfg().PoliceJobName or Config.PoliceJobName or 'police'
			if GetResourceState('dw_duty') == 'started' then
				return exports.dw_duty:IsOnDutyForJob(source, policeJob)
			end
			return xPlayer.job.onDuty == true
		end
	end

	return true
end

local function isOnCooldown(source)
	local untilAt = snatchCooldowns[source]
	return untilAt and untilAt > os.time()
end

local function setCooldown(source)
	local seconds = tonumber(cfg().Cooldown or Config.Cooldown) or 8
	if seconds > 0 then
		snatchCooldowns[source] = os.time() + seconds
	end
end

local function isExcludedWeapon(name)
	if type(name) ~= 'string' then
		return true
	end

	name = string.lower(name)
	local excluded = cfg().Exclude or Config.Exclude or { 'weapon_unarmed', 'weapon_stungun' }

	for i = 1, #excluded do
		if string.lower(excluded[i]) == name then
			return true
		end
	end

	return false
end

local function isSmallHandgunItem(name)
	if type(name) ~= 'string' or name:sub(1, 7) ~= 'weapon_' then
		return false
	end

	if isExcludedWeapon(name) then
		return false
	end

	name = string.lower(name)
	local patterns = cfg().WeaponPatterns or Config.WeaponPatterns or { 'pistol', 'revolver' }
	for i = 1, #patterns do
		if name:find(string.lower(patterns[i]), 1, true) then
			return true
		end
	end

	return false
end

local function attemptTake(source, targetId, targetAiming)
	targetId = tonumber(targetId)

	if customTakeHandler then
		return customTakeHandler(source, targetId, targetAiming) == true
	end

	if not enabled() or not targetId or targetId == source then
		return false
	end

	if not defaultCanAttempt(source, targetId) then
		NotifyPlayer(source, 'take_weapon_denied')
		return false
	end

	if isOnCooldown(source) then
		NotifyPlayer(source, 'take_weapon_cooldown')
		return false
	end

	local srcPed = GetPlayerPed(source)
	local tgtPed = GetPlayerPed(targetId)
	if not srcPed or srcPed == 0 or not tgtPed or tgtPed == 0 then
		return false
	end

	if GetEntityHealth(srcPed) <= 0 or GetEntityHealth(tgtPed) <= 0 then
		return false
	end

	if GetVehiclePedIsIn(srcPed, false) ~= 0 or GetVehiclePedIsIn(tgtPed, false) ~= 0 then
		NotifyPlayer(source, 'take_weapon_in_vehicle')
		return false
	end

	local maxDistance = tonumber(cfg().MaxDistance or Config.MaxDistance) or 2.5
	if #(GetEntityCoords(srcPed) - GetEntityCoords(tgtPed)) > maxDistance + 0.5 then
		NotifyPlayer(source, 'take_weapon_too_far')
		return false
	end

	local requireAim = cfg().RequireTargetAimingAtOfficer
	if requireAim == nil then
		requireAim = Config.RequireTargetAimingAtOfficer
	end

	if requireAim ~= false then
		local aimedAt = Player(targetId).state.weapon_snatch_aimTarget
		if aimedAt ~= source and targetAiming ~= true then
			NotifyPlayer(source, 'take_weapon_not_aiming')
			return false
		end
	end

	local weapon = WeaponSnatchInventory.GetEquippedHandgun(targetId)
	if not weapon or not isSmallHandgunItem(weapon.name) then
		NotifyPlayer(source, 'take_weapon_no_handgun')
		return false
	end

	setCooldown(source)

	local chance = tonumber(cfg().Chance or Config.Chance) or 0.5
	if math.random() > chance then
		NotifyPlayer(source, 'take_weapon_failed')
		NotifyPlayer(targetId, 'take_weapon_failed_target')
		return false
	end

	if not WeaponSnatchInventory.RemoveHandgun(targetId, weapon) then
		NotifyPlayer(source, 'take_weapon_failed')
		return false
	end

	local given = WeaponSnatchInventory.GiveHandgun(source, weapon)
	if not given then
		WeaponSnatchInventory.GiveHandgun(targetId, weapon)
		NotifyPlayer(source, 'take_weapon_inventory_full')
		return false
	end

	TriggerClientEvent('weapon_snatch:disarm', targetId)

	local equipOnSuccess = cfg().EquipOnSuccess
	if equipOnSuccess == nil then
		equipOnSuccess = Config.EquipOnSuccess
	end

	if equipOnSuccess ~= false then
		-- Use recipient weapon data (new slot). Victim slot breaks inventory equip.
		TriggerClientEvent('weapon_snatch:equip', source, given)
	end

	NotifyPlayer(source, 'take_weapon_success')
	NotifyPlayer(targetId, 'take_weapon_lost')
	return true
end

function RegisterCanAttempt(fn)
	if type(fn) == 'function' then
		canAttemptOverride = fn
	end
end

function RegisterCustomTakeHandler(fn)
	if type(fn) == 'function' then
		customTakeHandler = fn
	end
end

function ApplyConfig(overrides)
	mergeConfig(overrides)
end

exports('RegisterCanAttempt', RegisterCanAttempt)
exports('RegisterCustomTakeHandler', RegisterCustomTakeHandler)
exports('ApplyConfig', ApplyConfig)
exports('AttemptTake', attemptTake)

RegisterNetEvent('weapon_snatch:attempt', function(targetId, targetAiming)
	attemptTake(source, targetId, targetAiming)
end)

mergeConfig(nil)

AddEventHandler('playerDropped', function()
	snatchCooldowns[source] = nil
end)
