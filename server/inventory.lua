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

local function cloneWeapon(weapon)
	local copy = {}
	for key, value in pairs(weapon) do
		copy[key] = value
	end
	return copy
end

local function matchWeaponMeta(item, weapon)
	if type(item) ~= 'table' or not item.name then
		return false
	end
	if string.lower(item.name) ~= string.lower(weapon.name) then
		return false
	end

	local itemInfo = item.info or item.metadata
	local weaponInfo = weapon.info or weapon.metadata
	if type(weaponInfo) ~= 'table' then
		return true
	end
	if type(itemInfo) ~= 'table' then
		return false
	end

	if weaponInfo.serie and itemInfo.serie then
		return itemInfo.serie == weaponInfo.serie
	end
	if weaponInfo.serial and itemInfo.serial then
		return itemInfo.serial == weaponInfo.serial
	end

	return true
end

local function findQsWeaponItem(source, weapon)
	local inventories = {
		function()
			return exports['qs-inventory']:GetInventory(source)
		end,
		function()
			return exports['qs-inventory']:GetInventory(source, source)
		end,
	}

	for i = 1, #inventories do
		local ok, inv = pcall(inventories[i])
		if ok and type(inv) == 'table' then
			local fallback = nil
			for slot, item in pairs(inv) do
				if matchWeaponMeta(item, weapon) then
					item.slot = item.slot or tonumber(slot) or slot
					if (item.info and item.info.serie) or (item.info and item.info.serial) then
						return item
					end
					fallback = fallback or item
				end
			end
			if fallback then
				return fallback
			end
		end
	end

	local okItem, item = pcall(function()
		return exports['qs-inventory']:GetItemByName(source, weapon.name)
	end)
	if okItem and type(item) == 'table' and item.name then
		return item
	end

	local okItems, items = pcall(function()
		return exports['qs-inventory']:GetItemsByName(source, weapon.name)
	end)
	if okItems and type(items) == 'table' then
		for j = 1, #items do
			if matchWeaponMeta(items[j], weapon) then
				return items[j]
			end
		end
		if items[1] then
			return items[1]
		end
	end

	return nil
end

local function findOxWeaponItem(source, weapon)
	local metadata = weapon.metadata or weapon.info
	local ok, items = pcall(function()
		return exports.ox_inventory:Search(source, 'slots', weapon.name)
	end)
	if not ok or type(items) ~= 'table' then
		return nil
	end

	local fallback = nil
	for _, item in pairs(items) do
		if type(item) == 'table' and item.slot then
			local itemMeta = item.metadata or item.info
			if type(metadata) == 'table' and type(itemMeta) == 'table' then
				if metadata.serial and itemMeta.serial and metadata.serial == itemMeta.serial then
					return item
				end
				if metadata.serie and itemMeta.serie and metadata.serie == itemMeta.serie then
					return item
				end
			end
			fallback = fallback or item
		end
	end

	return fallback
end

local function findQbWeaponItem(source, weapon)
	local qb = WeaponSnatchFramework.GetQBCore()
	local player = qb and qb.Functions.GetPlayer(source)
	if not player then
		return nil
	end

	local items = player.PlayerData and player.PlayerData.items
	if type(items) ~= 'table' then
		return nil
	end

	local fallback = nil
	for slot, item in pairs(items) do
		if matchWeaponMeta(item, weapon) then
			item.slot = item.slot or tonumber(slot) or slot
			local info = item.info or item.metadata
			if info and (info.serie or info.serial) then
				return item
			end
			fallback = fallback or item
		end
	end

	return fallback
end

--- Returns given weapon table (with recipient slot) on success, otherwise false.
function WeaponSnatchInventory.GiveHandgun(source, weapon)
	if type(weapon) ~= 'table' or not weapon.name then
		return false
	end

	local adapter = weapon.adapter or WeaponSnatchFramework.GetInventory()
	local given = cloneWeapon(weapon)

	if adapter == 'qs' then
		local ok, added = pcall(function()
			return exports['qs-inventory']:AddItem(source, weapon.name, 1, nil, weapon.info, nil, weapon.created, nil, true)
		end)
		if not ok or added == false then
			return false
		end

		local item = findQsWeaponItem(source, weapon)
		if item then
			given.slot = item.slot
			given.info = item.info or given.info or {}
			given.amount = item.amount or 1
			given.created = item.created or given.created
		else
			-- Never equip using the victim's old slot.
			given.slot = nil
			given.info = given.info or {}
		end
		given.adapter = 'qs'
		return given
	end

	if adapter == 'ox' then
		local ok, success, response = pcall(function()
			return exports.ox_inventory:AddItem(source, weapon.name, 1, weapon.metadata or weapon.info)
		end)
		if not ok or success == false or success == nil then
			return false
		end

		-- ox_inventory: true + slot/item, or sometimes slot/item alone.
		if type(response) == 'number' then
			given.slot = response
		elseif type(response) == 'table' then
			if response.slot then
				given.slot = response.slot
				given.metadata = response.metadata or given.metadata or given.info
			elseif response[1] and response[1].slot then
				given.slot = response[1].slot
				given.metadata = response[1].metadata or given.metadata or given.info
			end
		elseif type(success) == 'number' then
			given.slot = success
		elseif type(success) == 'table' then
			given.slot = success.slot or (success[1] and success[1].slot) or given.slot
			given.metadata = success.metadata
				or (success[1] and success[1].metadata)
				or given.metadata
				or given.info
		end

		if not given.slot then
			local item = findOxWeaponItem(source, weapon)
			if item then
				given.slot = item.slot
				given.metadata = item.metadata or given.metadata or given.info
			end
		end

		given.adapter = 'ox'
		return given
	end

	if adapter == 'qb' then
		local qb = WeaponSnatchFramework.GetQBCore()
		local player = qb and qb.Functions.GetPlayer(source)
		if not player then
			return false
		end
		local info = weapon.info or weapon.metadata
		local added = false

		-- Always add into a free slot; victim slot is invalid on recipient.
		if GetResourceState('qb-inventory') == 'started' then
			local ok, result = pcall(function()
				return exports['qb-inventory']:AddItem(source, weapon.name, 1, false, info)
			end)
			added = ok and result ~= false
		end
		if not added then
			added = player.Functions.AddItem(weapon.name, 1, false, info) == true
		end
		if not added then
			return false
		end

		local item = findQbWeaponItem(source, weapon)
		if item then
			given.slot = item.slot
			given.info = item.info or info or {}
		else
			given.slot = nil
			given.info = info or {}
		end
		given.adapter = 'qb'
		return given
	end

	local esx = WeaponSnatchFramework.GetESX()
	local xPlayer = esx and esx.GetPlayerFromId(source)
	if not xPlayer then
		return false
	end

	if adapter == 'esx_loadout' or weapon.ammo ~= nil then
		xPlayer.addWeapon(weapon.name, weapon.ammo or 0)
		given.adapter = 'esx_loadout'
		return given
	end

	if xPlayer.canCarryItem and not xPlayer.canCarryItem(weapon.name, 1) then
		return false
	end

	xPlayer.addInventoryItem(weapon.name, 1, weapon.info)
	given.adapter = 'esx_item'
	return given
end
