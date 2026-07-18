Locales = Locales or {}

local function localeTable()
	return Locales[Config.Locale or 'en'] or Locales.en or {}
end

function L(key, ...)
	local str = localeTable()[key] or Locales.en[key] or key
	if select('#', ...) > 0 then
		return string.format(str, ...)
	end
	return str
end

function NotifyPlayer(source, key, ntype)
	local msg = L(key)

	if source == 0 or source == nil then
		if lib and lib.notify then
			lib.notify({ description = msg, type = ntype or 'inform' })
		elseif ESX and ESX.ShowNotification then
			ESX.ShowNotification(msg)
		end
		return
	end

	if WeaponSnatchFramework.Get() == 'qb' then
		TriggerClientEvent('QBCore:Notify', source, msg, ntype or 'error')
		return
	end

	local esx = WeaponSnatchFramework.GetESX()
	local xPlayer = esx and esx.GetPlayerFromId(source)
	if xPlayer and xPlayer.showNotification then
		xPlayer.showNotification(msg)
	end
end

Notify = NotifyPlayer
