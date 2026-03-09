fx_version 'cerulean'
game 'gta5'
author 'S82 Dev'
description 's82 Market Fluctuations'
version '2.1.0'

shared_script 'config.lua'

server_scripts {
    '@ox_lib/init.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    '@ox_lib/init.lua',
    'client/main.lua'
}

ui_page 'view/index.html'

files {
    'view/index.html',
    'view/css/style.css',
    'view/js/app.js'
}
