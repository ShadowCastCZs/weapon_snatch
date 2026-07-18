local customInteractionHandler = nil

local function targetDistance()
	local cfg = GetWeaponSnatchRuntimeConfig and GetWeaponSnatchRuntimeConfig() or Config
	local builtin = cfg.BuiltinOxTarget or Config.BuiltinOxTarget or {}
	return builtin.Distance or cfg.MaxDistance or Config.MaxDistance or 2.5
end

local function targetLabel()
	local cfg = GetWeaponSnatchRuntimeConfig and GetWeaponSnatchRuntimeConfig() or Config
	local builtin = cfg.BuiltinOxTarget or Config.BuiltinOxTarget or {}
	return L(builtin.Label or 'take_weapon_target')
end

local function targetIcon()
	local cfg = GetWeaponSnatchRuntimeConfig and GetWeaponSnatchRuntimeConfig() or Config
	local builtin = cfg.BuiltinOxTarget or Config.BuiltinOxTarget or {}
	return builtin.Icon or 'fas fa-hand-back-fist'
end

local function getTargetServerIdFromEntity(entity)
	if not entity or not DoesEntityExist(entity) then
		return nil
	end
	local playerIdx = NetworkGetPlayerIndexFromPed(entity)
	if playerIdx == -1 then
		return nil
	end
	local targetId = GetPlayerServerId(playerIdx)
	if targetId == 0 or targetId == GetPlayerServerId(PlayerId()) then
		return nil
	end
	return targetId
end

local function runTake(entity)
	local targetId = getTargetServerIdFromEntity(entity)
	if not targetId then
		return false
	end

	if customInteractionHandler then
		local handled = customInteractionHandler(entity, targetId)
		if handled ~= nil then
			return handled
		end
	end

	AttemptTake(targetId)
	return true
end

--- Returns a ready-to-use table for ox_target, qb-target, etc.
function GetInteractionExport()
	return {
		name = (Config.BuiltinOxTarget or {}).Name or 'weapon_snatch_take',
		icon = targetIcon(),
		label = targetLabel(),
		distance = targetDistance(),
		canInteract = function(entity)
			return CanTakeFrom(entity)
		end,
		onSelect = function(data)
			runTake(data.entity)
		end,
		action = function(entity)
			runTake(entity)
		end,
	}
end

--- Register handler that runs before default AttemptTake. Return true/false to override, nil to continue.
function RegisterInteractionHandler(fn)
	if type(fn) == 'function' then
		customInteractionHandler = fn
	end
end

exports('GetInteractionExport', GetInteractionExport)
exports('RegisterInteractionHandler', RegisterInteractionHandler)
exports('GetTargetOptions', GetInteractionExport)

if (Config.Command or {}).Enabled then
	RegisterCommand((Config.Command or {}).Name or 'takeweapon', function(_, args)
		local targetId = tonumber(args[1])
		if targetId then
			AttemptTake(targetId)
		end
	end, false)
end
