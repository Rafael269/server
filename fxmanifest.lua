fx_version 'cerulean'
game 'gta5'

description 'dream-postal'
author 'DreamScripts Kale'
version '1.0.0'

shared_scripts {
	'config.lua',
    'locales/*.lua',
    'translate_util.lua',
    "@ox_lib/init.lua", -- UNCOMMENT IF USING OX_LIB
    -- UNCOMMENT '@ox_lib/init.lua' IF USING OX_LIB
    -- '@ox_lib/init.lua',
}

client_scripts {
	'client.lua',
    'client_util.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

lua54 'yes'