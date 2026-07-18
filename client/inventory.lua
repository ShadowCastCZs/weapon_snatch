WeaponSnatchInventory = WeaponSnatchInventory or {}

local function inventoryPrefix()
	return Config.InventoryPrefix or 'inventory'
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

function WeaponSnatchInventory.GetHandWeaponData()
	local ped = PlayerPedId()
	local weaponHash = GetSelectedPedWeapon(ped)
	if not weaponHash or weaponHash == `WEAPON_UNARMED` then
		return nil
	end

	local kind = WeaponSnatchFramework.GetInventory()

	if kind == 'qs' and GetResourceState('qs-inventory') == 'started' then
		local ok, weapon = pcall(function()
			return exports['qs-inventory']:GetCurrentWeapon()
		end)
		if ok and weapon and weapon.name then
			return weapon
		end
	end

	if kind == 'ox' and GetResourceState('ox_inventory') == 'started' then
		local ok, weapon = pcall(function()
			return exports.ox_inventory:getCurrentWeapon()
		end)
		if ok and weapon and weapon.name then
			return weapon
		end
	end

	if kind == 'qb' then
		local ok, weapon = pcall(function()
			return exports['qb-inventory']:GetCurrentWeapon()
		end)
		if ok and weapon and (weapon.name or weapon.item) then
			weapon.name = weapon.name or weapon.item
			return weapon
		end
	end

	local weaponName = weaponNameFromHash(weaponHash)
	if not weaponName then
		return nil
	end

	return {
		name = weaponName,
		hash = weaponHash,
		ammo = GetAmmoInPedWeapon(ped, weaponHash),
		info = { ammo = GetAmmoInPedWeapon(ped, weaponHash) },
	}
end

function WeaponSnatchInventory.Disarm()
	local ped = PlayerPedId()
	local kind = WeaponSnatchFramework.GetInventory()
	local prefix = inventoryPrefix()

	if kind == 'qs' and GetResourceState('qs-inventory') == 'started' then
		TriggerEvent('weapons:client:DrawWeapon', nil)
		TriggerEvent('weapons:client:SetCurrentWeapon', nil, false)
		TriggerEvent('weapons:ResetHolster')
		TriggerEvent(prefix .. ':ClearWeapons')
	elseif kind == 'ox' and GetResourceState('ox_inventory') == 'started' then
		TriggerEvent('ox_inventory:disarm', true)
	elseif kind == 'qb' then
		if GetResourceState('qb-weapons') == 'started' then
			TriggerEvent('qb-weapons:client:ResetHand')
		elseif GetResourceState('qbx_weapons') == 'started' then
			TriggerEvent('qbx_weapons:client:ResetHand')
		end
	else
		TriggerEvent('esx:restoreLoadout')
	end

	SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
	RemoveAllPedWeapons(ped, true)
end

function WeaponSnatchInventory.Equip(weaponData)
	if type(weaponData) ~= 'table' or not weaponData.name then
		return
	end

	local kind = WeaponSnatchFramework.GetInventory()
	local prefix = inventoryPrefix()

	if kind == 'qs' and GetResourceState('qs-inventory') == 'started' then
		Wait(120)
		TriggerEvent(prefix .. ':client:UseWeapon', weaponData, true)
		return
	end

	if kind == 'ox' and GetResourceState('ox_inventory') == 'started' then
		if weaponData.slot then
			exports.ox_inventory:useSlot(weaponData.slot)
		end
		return
	end

	if kind == 'qb' then
		local ped = PlayerPedId()
		local hash = weaponData.hash or joaat(weaponData.name)
		GiveWeaponToPed(ped, hash, weaponData.info and weaponData.info.ammo or 0, false, true)
		SetCurrentPedWeapon(ped, hash, true)
		if weaponData.slot and GetResourceState('qb-inventory') == 'started' then
			TriggerServerEvent('qb-inventory:server:useItemSlot', weaponData.slot)
		end
		return
	end

	local ped = PlayerPedId()
	local hash = weaponData.hash or joaat(weaponData.name)
	local ammo = weaponData.ammo or (weaponData.info and weaponData.info.ammo) or 0
	GiveWeaponToPed(ped, hash, ammo, false, true)
	SetCurrentPedWeapon(ped, hash, true)
end

if lib and lib.callback then
	lib.callback.register('weapon_snatch:client:getHandWeaponData', function()
		return WeaponSnatchInventory.GetHandWeaponData()
	end)
end
