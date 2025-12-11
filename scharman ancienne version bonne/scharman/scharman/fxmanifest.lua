shared_script '@WaveShield/resource/include.lua'

fx_version 'cerulean'
game 'gta5'

author 'Scharman Dev Team'
description 'Script PVP 1v1 Scharman - V4.0.0 SYSTÈME DE TIMERS'
version '4.0.0'
lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    'config/config.lua',
    'config/course_poursuite.lua'
}

client_scripts {
    'client/main.lua',
    'client/ped.lua',
    'client/nui.lua',
    'client/course_poursuite.lua'
}

server_scripts {
    'server/main.lua',
    'server/version.lua',
    'server/course_poursuite.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/script.js'
}

dependencies {
    'es_extended',
    'oxmysql'
}
