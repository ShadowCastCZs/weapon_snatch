WeaponSnatchFramework = WeaponSnatchFramework or {}

local cachedFramework = nil
local cachedInventory = nil

local function resourceStarted(name)
	return GetResourceState(name) == 'started'
end

function WeaponSnatchFramework.Get()
	if cachedFramework then
		return cachedFramework
	end

	local configured = Config.Framework
	if configured and configured ~= 'auto' then
		cachedFramework = configured
		return cachedFramework
	end

	if resourceStarted('qb-core') or resourceStarted('qbx_core') then
		cachedFramework = 'qb'
	elseif resourceStarted('es_extended') then
		cachedFramework = 'esx'
	else
		cachedFramework = 'esx'
	end

	return cachedFramework
end

function WeaponSnatchFramework.GetInventory()
	if cachedInventory then
		return cachedInventory
	end

	local configured = Config.Inventory
	if configured and configured ~= 'auto' then
		cachedInventory = configured
		return cachedInventory
	end

	if resourceStarted('qs-inventory') then
		cachedInventory = 'qs'
	elseif resourceStarted('ox_inventory') then
		cachedInventory = 'ox'
	elseif resourceStarted('qb-inventory') then
		cachedInventory = 'qb'
	elseif WeaponSnatchFramework.Get() == 'qb' then
		cachedInventory = 'qb'
	else
		cachedInventory = 'esx'
	end

	return cachedInventory
end

function WeaponSnatchFramework.ResetCache()
	cachedFramework = nil
	cachedInventory = nil
end

function WeaponSnatchFramework.GetESX()
	if WeaponSnatchFramework.Get() ~= 'esx' then
		return nil
	end

	if ESX then
		return ESX
	end

	if resourceStarted('es_extended') then
		local ok, obj = pcall(function()
			return exports['es_extended']:getSharedObject()
		end)
		if ok and obj then
			ESX = obj
			return ESX
		end
	end

	return nil
end

function WeaponSnatchFramework.GetQBCore()
	if WeaponSnatchFramework.Get() ~= 'qb' then
		return nil
	end

	if QBCore then
		return QBCore
	end

	if resourceStarted('qb-core') then
		local ok, obj = pcall(function()
			return exports['qb-core']:GetCoreObject()
		end)
		if ok and obj then
			QBCore = obj
			return QBCore
		end
	end

	if resourceStarted('qbx_core') then
		local ok, obj = pcall(function()
			return exports['qbx_core']:GetCoreObject()
		end)
		if ok and obj then
			QBCore = obj
			return QBCore
		end
	end

	return nil
end
