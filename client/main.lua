local AIM_STATE_KEY = 'weapon_snatch_aimTarget'
local lastReportedAimTarget = nil
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

local function getTargetPlayerIndex(entity)
	if not entity or not DoesEntityExist(entity) then
		return nil
	end
	local playerIdx = NetworkGetPlayerIndexFromPed(entity)
	if playerIdx == -1 then
		return nil
	end
	return playerIdx
end

local function getTargetServerId(entity)
	local playerIdx = getTargetPlayerIndex(entity)
	if not playerIdx then
		return nil
	end
	local targetId = GetPlayerServerId(playerIdx)
	if targetId == 0 or targetId == GetPlayerServerId(PlayerId()) then
		return nil
	end
	return targetId
end

local function rotationToDirection(rotation)
	local radX = math.rad(rotation.x)
	local radZ = math.rad(rotation.z)
	local cosX = math.abs(math.cos(radX))
	return vector3(-math.sin(radZ) * cosX, math.cos(radZ) * cosX, math.sin(radX))
end

local function weaponNameFromHash(weaponHash)
	local esx = WeaponSnatchFramework.GetESX()
	if esx and esx.GetWeaponFromHash then
		local weapon = esx.GetWeaponFromHash(weaponHash)
		if weapon and weapon.name then
			return string.lower(weapon.name)
		end
	end

	local qb = WeaponSnatchFramework.GetQBCore()
	if qb and qb.Shared and qb.Shared.Weapons then
		for name, data in pairs(qb.Shared.Weapons) do
			if data.hash == weaponHash or joaat(name) == weaponHash then
				return string.lower(name)
			end
		end
	end

	return nil
end

local function isExcludedWeaponHash(weaponHash)
	local excluded = cfg().Exclude or Config.Exclude or { 'weapon_unarmed', 'weapon_stungun' }
	for i = 1, #excluded do
		if weaponHash == joaat(excluded[i]) then
			return true
		end
	end
	return false
end

local function matchesWeaponPatterns(name)
	if type(name) ~= 'string' then
		return false
	end

	local patterns = cfg().WeaponPatterns or Config.WeaponPatterns or { 'pistol', 'revolver' }
	name = string.lower(name)

	for i = 1, #patterns do
		if name:find(string.lower(patterns[i]), 1, true) then
			return true
		end
	end

	return false
end

local function isSmallHandgunHash(weaponHash)
	if not weaponHash or weaponHash == `WEAPON_UNARMED` then
		return false
	end

	if isExcludedWeaponHash(weaponHash) then
		return false
	end

	local weaponName = weaponNameFromHash(weaponHash)
	if weaponName and matchesWeaponPatterns(weaponName) then
		return true
	end

	return GetWeapontypeGroup(weaponHash) == `GROUP_PISTOL`
end

local function isPlayerAiming(playerIdx, includeLocalCam)
	if IsPlayerFreeAiming(playerIdx) then
		return true
	end

	if includeLocalCam and playerIdx == PlayerId() then
		return IsAimCamActive() or IsAimCamThirdPersonActive()
	end

	return false
end

local function getAimTargetFromCamera(maxDistance)
	local ped = PlayerPedId()
	if not IsPedArmed(ped, 4) then
		return nil
	end

	local camCoord = GetGameplayCamCoord()
	local camDir = rotationToDirection(GetGameplayCamRot(2))
	local bestId, bestDot = nil, 0.82

	for _, playerIdx in ipairs(GetActivePlayers()) do
		if playerIdx ~= PlayerId() then
			local targetPed = GetPlayerPed(playerIdx)
			if DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed, true) then
				local targetCoords = GetPedBoneCoords(targetPed, 11816, 0.0, 0.0, 0.0)
				local toTarget = targetCoords - camCoord
				local dist = #toTarget
				if dist > 0.5 and dist <= maxDistance then
					local norm = toTarget / dist
					local dot = camDir.x * norm.x + camDir.y * norm.y + camDir.z * norm.z
					if dot > bestDot and HasEntityClearLosToEntity(ped, targetPed, 17) then
						bestDot = dot
						bestId = GetPlayerServerId(playerIdx)
					end
				end
			end
		end
	end

	return bestId
end

local function reportLocalAimTarget()
	local playerIdx = PlayerId()
	local aimTarget = nil

	if isPlayerAiming(playerIdx, true) and IsPedArmed(PlayerPedId(), 4) then
		local _, entity = GetEntityPlayerIsFreeAimingAt(playerIdx)
		if entity and entity ~= 0 and DoesEntityExist(entity) and IsEntityAPed(entity) and IsPedAPlayer(entity) then
			local idx = NetworkGetPlayerIndexFromPed(entity)
			if idx ~= -1 then
				aimTarget = GetPlayerServerId(idx)
			end
		end

		if not aimTarget then
			aimTarget = getAimTargetFromCamera((cfg().MaxDistance or Config.MaxDistance or 2.5) + 4.0)
		end
	end

	if aimTarget ~= lastReportedAimTarget then
		lastReportedAimTarget = aimTarget
		LocalPlayer.state:set(AIM_STATE_KEY, aimTarget, true)
	end
end

local function isTargetAimingAtMeFallback(entity, myPed)
	local playerIdx = getTargetPlayerIndex(entity)
	if not playerIdx or not isPlayerAiming(playerIdx, false) then
		return false
	end

	if not IsPedArmed(entity, 4) then
		return false
	end

	local success, aimedEntity = GetEntityPlayerIsFreeAimingAt(playerIdx)
	if success and aimedEntity == myPed then
		return true
	end

	local maxDistance = cfg().MaxDistance or Config.MaxDistance or 2.5
	local pedPos = GetEntityCoords(entity)
	local myPos = GetEntityCoords(myPed)
	local diff = myPos - pedPos
	local dist = #diff
	if dist > maxDistance or dist < 0.3 then
		return false
	end

	local dirToMe = diff / dist
	local from = GetPedBoneCoords(entity, 31086, 0.0, 0.0, 0.0)
	local handle = StartShapeTestRay(from.x, from.y, from.z, myPos.x, myPos.y, myPos.z, -1, entity, 0)
	local _, hit, _, _, entityHit = GetShapeTestResult(handle)
	if hit == 1 and entityHit == myPed then
		return true
	end

	local fwd = GetEntityForwardVector(entity)
	local dot = fwd.x * dirToMe.x + fwd.y * dirToMe.y + fwd.z * dirToMe.z
	return dot >= 0.65 and HasEntityClearLosToEntity(entity, myPed, 17)
end

local function isEnabled()
	local enabled = cfg().Enabled
	if enabled == nil then
		enabled = Config.Enabled
	end
	return enabled ~= false
end

function IsTargetAimingAtMe(entity)
	local targetId = getTargetServerId(entity)
	if not targetId then
		return false
	end

	local myServerId = GetPlayerServerId(PlayerId())
	local ok, aimedAt = pcall(function()
		return Player(targetId).state[AIM_STATE_KEY]
	end)

	if ok and aimedAt == myServerId then
		return true
	end

	return isTargetAimingAtMeFallback(entity, PlayerPedId())
end

function IsTargetHoldingSmallHandgun(entity)
	if not entity or not DoesEntityExist(entity) then
		return false
	end

	if not IsPedArmed(entity, 4) then
		return false
	end

	return isSmallHandgunHash(GetSelectedPedWeapon(entity))
end

function CanTakeFrom(entity)
	if not isEnabled() then
		return false
	end

	if not entity or entity == PlayerPedId() or not DoesEntityExist(entity) then
		return false
	end

	if IsPedInAnyVehicle(entity, false) or IsPedDeadOrDying(entity, true) then
		return false
	end

	local maxDistance = cfg().MaxDistance or Config.MaxDistance or 2.5
	if #(GetEntityCoords(entity) - GetEntityCoords(PlayerPedId())) > maxDistance then
		return false
	end

	if cfg().RequireTargetAimingAtOfficer ~= false and not IsTargetAimingAtMe(entity) then
		return false
	end

	if cfg().RequireTargetArmed ~= false and not IsTargetHoldingSmallHandgun(entity) then
		return false
	end

	return true
end

function IsBusy()
	return false
end

RegisterNetEvent('weapon_snatch:disarm', function()
	WeaponSnatchInventory.Disarm()
end)

RegisterNetEvent('weapon_snatch:equip', function(weaponData)
	if type(weaponData) ~= 'table' then
		return
	end
	WeaponSnatchInventory.Equip(weaponData)
end)

function AttemptTake(targetId)
	targetId = tonumber(targetId)
	if not targetId then
		return
	end

	local playerIdx = GetPlayerFromServerId(targetId)
	local entity = playerIdx ~= -1 and GetPlayerPed(playerIdx) or 0
	local aiming = entity ~= 0 and IsTargetAimingAtMe(entity) or false
	TriggerServerEvent('weapon_snatch:attempt', targetId, aiming == true)
end

function GetWeaponSnatchRuntimeConfig()
	return runtimeConfig
end

function ApplyConfig(overrides)
	mergeConfig(overrides)
	if RefreshWeaponSnatchTarget then
		RefreshWeaponSnatchTarget()
	end
end

exports('CanTakeFrom', CanTakeFrom)
exports('IsTargetAimingAtMe', IsTargetAimingAtMe)
exports('IsTargetHoldingSmallHandgun', IsTargetHoldingSmallHandgun)
exports('IsBusy', IsBusy)
exports('AttemptTake', AttemptTake)
exports('ApplyConfig', ApplyConfig)

mergeConfig(nil)

CreateThread(function()
	while true do
		reportLocalAimTarget()
		Wait(IsPedArmed(PlayerPedId(), 4) and 0 or 200)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	if lastReportedAimTarget ~= nil then
		LocalPlayer.state:set(AIM_STATE_KEY, nil, true)
	end
end)
