fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'weapon_snatch'
author 'DW Scripts'
description 'Snatch a small handgun from a player aiming at you — ESX/QB, qs/ox/esx/qb inventory'
version '1.1.0'

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua',
	'shared/framework.lua',
	'shared/locale.lua',
	'locales/*.lua',
}

client_scripts {
	'client/inventory.lua',
	'client/main.lua',
	'client/integrations.lua',
	'client/ox_target.lua',
}

server_scripts {
	'server/inventory.lua',
	'server/main.lua',
}

exports {
	'CanTakeFrom',
	'IsTargetAimingAtMe',
	'IsTargetHoldingSmallHandgun',
	'IsBusy',
	'AttemptTake',
	'ApplyConfig',
	'GetInteractionExport',
	'GetTargetOptions',
	'RegisterInteractionHandler',
}

server_exports {
	'AttemptTake',
	'RegisterCanAttempt',
	'RegisterCustomTakeHandler',
	'ApplyConfig',
}

dependencies {
	'ox_lib',
}
