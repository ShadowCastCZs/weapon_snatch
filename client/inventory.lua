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

local function normalizeWeaponData(weaponData)
	if type(weaponData) ~= 'table' or not weaponData.name then
		return nil
	end

	local data = {}
	for key, value in pairs(weaponData) do
		data[key] = value
	end

	data.name = string.lower(data.name)
	data.info = data.info or data.metadata or {}
	if type(data.info) ~= 'table' then
		data.info = {}
	end
	if data.info.ammo == nil then
		data.info.ammo = data.ammo or 0
	end
	data.hash = data.hash or joaat(data.name)
	return data
end

local function applyAttachments(ped, hash, info)
	if type(info) ~= 'table' or type(info.attachments) ~= 'table' then
		return
	end

	for _, attachment in pairs(info.attachments) do
		if attachment.tint then
			SetPedWeaponTintIndex(ped, hash, attachment.tint)
		elseif attachment.component then
			GiveWeaponComponentToPed(ped, hash, joaat(attachment.component))
		end
	end
end

local function forceEquipPedWeapon(weaponData)
	local ped = PlayerPedId()
	local hash = weaponData.hash or joaat(weaponData.name)
	local ammo = tonumber(weaponData.info and weaponData.info.ammo) or tonumber(weaponData.ammo) or 0

	GiveWeaponToPed(ped, hash, ammo, false, true)
	SetPedAmmo(ped, hash, ammo)
	SetCurrentPedWeapon(ped, hash, true)
	applyAttachments(ped, hash, weaponData.info)
	return GetSelectedPedWeapon(ped) == hash
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

local function equipQs(weaponData)
	local prefix = inventoryPrefix()

	-- Holster first so qs UseWeapon does not toggle-off the same weapon name.
	TriggerEvent('weapons:client:DrawWeapon', nil)
	TriggerEvent('weapons:client:SetCurrentWeapon', nil, false)
	SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)

	Wait(200)

	-- Prefer inventory UseWeapon with recipient slot when available.
	if weaponData.slot then
		TriggerEvent(prefix .. ':client:UseWeapon', weaponData, true)
		Wait(100)
		if GetSelectedPedWeapon(PlayerPedId()) == (weaponData.hash or joaat(weaponData.name)) then
			return true
		end
	end

	-- Direct equip path (same as qs UseWeapon else-branch), avoids toggle + slot issues.
	TriggerEvent('weapons:client:DrawWeapon', weaponData.name)
	TriggerEvent('weapons:client:SetCurrentWeapon', weaponData, true)
	return forceEquipPedWeapon(weaponData)
end

local function equipOx(weaponData)
	if weaponData.slot then
		local ok = pcall(function()
			exports.ox_inventory:useSlot(weaponData.slot)
		end)
		if ok then
			Wait(150)
			if GetSelectedPedWeapon(PlayerPedId()) == (weaponData.hash or joaat(weaponData.name)) then
				return true
			end
		end
	end

	-- Fallback: find slot by name on client inventory, then use it.
	local okSearch, items = pcall(function()
		return exports.ox_inventory:Search('slots', weaponData.name)
	end)
	if okSearch and type(items) == 'table' then
		for _, item in pairs(items) do
			if type(item) == 'table' and item.slot then
				local matched = true
				local meta = item.metadata or item.info
				local want = weaponData.metadata or weaponData.info
				if type(want) == 'table' and type(meta) == 'table' then
					if want.serial and meta.serial and want.serial ~= meta.serial then
						matched = false
					elseif want.serie and meta.serie and want.serie ~= meta.serie then
						matched = false
					end
				end
				if matched then
					pcall(function()
						exports.ox_inventory:useSlot(item.slot)
					end)
					Wait(150)
					if GetSelectedPedWeapon(PlayerPedId()) == (weaponData.hash or joaat(weaponData.name)) then
						return true
					end
				end
			end
		end
	end

	return forceEquipPedWeapon(weaponData)
end

local function equipQb(weaponData)
	if weaponData.slot and GetResourceState('qb-inventory') == 'started' then
		TriggerServerEvent('qb-inventory:server:useItemSlot', weaponData.slot)
		Wait(150)
		if GetSelectedPedWeapon(PlayerPedId()) == (weaponData.hash or joaat(weaponData.name)) then
			return true
		end
	end
	return forceEquipPedWeapon(weaponData)
end

function WeaponSnatchInventory.Equip(weaponData)
	weaponData = normalizeWeaponData(weaponData)
	if not weaponData then
		return
	end

	CreateThread(function()
		local kind = WeaponSnatchFramework.GetInventory()

		-- Let inventory sync the newly added item first.
		Wait(250)

		for _ = 1, 4 do
			local equipped = false

			if kind == 'qs' and GetResourceState('qs-inventory') == 'started' then
				equipped = equipQs(weaponData)
			elseif kind == 'ox' and GetResourceState('ox_inventory') == 'started' then
				equipped = equipOx(weaponData)
			elseif kind == 'qb' then
				equipped = equipQb(weaponData)
			else
				equipped = forceEquipPedWeapon(weaponData)
			end

			if equipped then
				return
			end

			Wait(200)
		end

		-- Last resort natives if inventory adapters failed to select the weapon.
		forceEquipPedWeapon(weaponData)
	end)
end

if lib and lib.callback then
	lib.callback.register('weapon_snatch:client:getHandWeaponData', function()
		return WeaponSnatchInventory.GetHandWeaponData()
	end)
end
