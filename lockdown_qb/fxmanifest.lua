fx_version('cerulean')
games({ 'gta5' })


shared_scripts('config.lua');

server_scripts({
    'server.lua',
    'config.lua',
    '@oxmysql/lib/MySQL.lua'
});

ui_page({'html/index.html'})

files({
    'html/index.html',
    'html/style.css',
    'html/index.js',
    'html/winning.mp3',
    'html/loot.mp3'
})

shared_scripts { 
	'config.lua'
}


client_scripts({
    'client.lua',
    'config.lua'
});