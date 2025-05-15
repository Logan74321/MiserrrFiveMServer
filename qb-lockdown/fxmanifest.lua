fx_version 'cerulean'
game 'gta5'

description 'QB Lockdown Protocol - PvPvE Extraction Mode'
author 'Your Name'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/spawns.lua',
    'client/extraction.lua',
    'client/police.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/instance.lua',
    'server/rewards.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/script.js',
    'ui/style.css',
    'ui/fonts/*.ttf',
    'ui/img/*.png',
}

lua54 'yes'