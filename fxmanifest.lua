fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'phil'
description 'Advanced Job Center taken from https://github.com/SteffWS/steff_jobcenter'
version '1.0.0'

shared_scripts {
   
    '@ox_lib/init.lua',
    'locales/*.lua',
    'config.lua'
}

client_script {
    'client/cl_main.lua'
}

server_script {
    'server/sv_main.lua'
}

dependencies {
  'rsg-core',
  'ox_lib'
}
