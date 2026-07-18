WeaponSnatchInventory = WeaponSnatchInventory or {}

local function awaitClientWeaponData(source)
	if lib and lib.callback then
		return lib.callback.await('weapon_snatch:client:getHandWeaponData', source, false)
	end
	return nil
end

local function getQsWeapon(source)
	if GetResourceState('qs-inventory') ~= 'started' then
		return nil
	end

	local ok, weapon = pcall(function()
		return exports['qs-inventory']:GetCurrentWeapon(source)
	end)

	if ok and weapon and weapon.name and weapon.slot then
		weapon.adapter = 'qs'
		return weapon
	end

	return nil
end

local function getOxWeapon(source)
	if GetResourceState('ox_inventory') ~= 'started' then
		return nil
	end

	local ok, weapon = pcall(function()
		return exports.ox_inventory:GetCurrentWeapon(source)
	end)

	if ok and weapon and weapon.name then
		weapon.adapter = 'ox'
		return weapon
	end

	return nil
end

local function getQbWeapon(source)
	local qb = WeaponSnatchFramework.GetQBCore()
	if not qb then
		return nil
	end

	if GetResourceState('qb-inventory') == 'started' then
		local ok, weapon = pcall(function()
			return exports['qb-inventory']:GetCurrentWeapon(source)
		end)
		if ok and weapon and (weapon.name or weapon.item) then
			weapon.name = weapon.name or weapon.item
			weapon.adapter = 'qb'
			return weapon
		end
	end

	local data = awaitClientWeaponData(source)
	if not data or not data.name then
		return nil
	end

	local player = qb.Functions.GetPlayer(source)
	if not player then
		return nil
	end

	local item = player.Functions.GetItemByName(data.name)
	if item then
		item.adapter = 'qb'
		item.name = data.name
		return item
	end

	return nil
end

local function getEsxWeapon(source)
	local esx = WeaponSnatchFramework.GetESX()
	if not esx then
		return nil
	end

	local xPlayer = esx.GetPlayerFromId(source)
	if not xPlayer then
		return nil
	end

	local data = awaitClientWeaponData(source)
	if not data or not data.name then
		return nil
	end

	if xPlayer.hasWeapon and xPlayer.hasWeapon(data.name) then
		local _, weapon = xPlayer.getWeapon(data.name)
		data.adapter = 'esx_loadout'
		data.ammo = weapon and weapon.ammo or data.ammo or 0
		return data
	end

	local item = xPlayer.getInventoryItem(data.name)
	if item and item.count and item.count > 0 then
		data.adapter = 'esx_item'
		return data
	end

	return nil
end

function WeaponSnatchInventory.GetEquippedHandgun(source)
	local kind = WeaponSnatchFramework.GetInventory()

	if kind == 'qs' then
		return getQsWeapon(source)
	end
	if kind == 'ox' then
		return getOxWeapon(source)
	end
	if kind == 'qb' then
		return getQbWeapon(source)
	end

	return getEsxWeapon(source)
end

function WeaponSnatchInventory.RemoveHandgun(source, weapon)
	if type(weapon) ~= 'table' or not weapon.name then
		return false
	end

	local adapter = weapon.adapter or WeaponSnatchFramework.GetInventory()

	if adapter == 'qs' then
		local ok, removed = pcall(function()
			return exports['qs-inventory']:RemoveItem(source, weapon.name, 1, weapon.slot, weapon.info, true)
		end)
		return ok and removed ~= false
	end

	if adapter == 'ox' then
		local ok, removed = pcall(function()
			return exports.ox_inventory:RemoveItem(source, weapon.name, 1, weapon.metadata or weapon.info, weapon.slot)
		end)
		return ok and removed ~= false
	end

	if adapter == 'qb' then
		local qb = WeaponSnatchFramework.GetQBCore()
		local player = qb and qb.Functions.GetPlayer(source)
		if not player then
			return false
		end
		if weapon.slot then
			local ok, removed = pcall(function()
				return exports['qb-inventory']:RemoveItem(source, weapon.name, 1, weapon.slot)
			end)
			if ok and removed ~= false then
				return true
			end
		end
		return player.Functions.RemoveItem(weapon.name, 1) == true
	end

	local esx = WeaponSnatchFramework.GetESX()
	local xPlayer = esx and esx.GetPlayerFromId(source)
	if not xPlayer then
		return false
	end

	if xPlayer.hasWeapon and xPlayer.hasWeapon(weapon.name) then
		xPlayer.removeWeapon(weapon.name)
		return true
	end

	local item = xPlayer.getInventoryItem(weapon.name)
	if item and item.count and item.count > 0 then
		xPlayer.removeInventoryItem(weapon.name, 1)
		return true
	end

	return false
end

function WeaponSnatchInventory.GiveHandgun(source, weapon)
	if type(weapon) ~= 'table' or not weapon.name then
		return false
	end

	local adapter = weapon.adapter or WeaponSnatchFramework.GetInventory()

	if adapter == 'qs' then
		local ok, added = pcall(function()
			return exports['qs-inventory']:AddItem(source, weapon.name, 1, nil, weapon.info, nil, weapon.created, nil, true)
		end)
		return ok and added ~= false
	end

	if adapter == 'ox' then
		local ok, added = pcall(function()
			return exports.ox_inventory:AddItem(source, weapon.name, 1, weapon.metadata or weapon.info)
		end)
		return ok and added ~= false
	end

	if adapter == 'qb' then
		local qb = WeaponSnatchFramework.GetQBCore()
		local player = qb and qb.Functions.GetPlayer(source)
		if not player then
			return false
		end
		local info = weapon.info or weapon.metadata
		if weapon.slot and GetResourceState('qb-inventory') == 'started' then
			local ok, added = pcall(function()
				return exports['qb-inventory']:AddItem(source, weapon.name, 1, false, info, weapon.slot)
			end)
			if ok and added ~= false then
				return true
			end
		end
		return player.Functions.AddItem(weapon.name, 1, false, info) == true
	end

	local esx = WeaponSnatchFramework.GetESX()
	local xPlayer = esx and esx.GetPlayerFromId(source)
	if not xPlayer then
		return false
	end

	if adapter == 'esx_loadout' or weapon.ammo ~= nil then
		xPlayer.addWeapon(weapon.name, weapon.ammo or 0)
		return true
	end

	if xPlayer.canCarryItem and not xPlayer.canCarryItem(weapon.name, 1) then
		return false
	end

	xPlayer.addInventoryItem(weapon.name, 1, weapon.info)
	return true
end
