-- SERVER - VERSION
local SCRIPT_NAME = 'Scharman PVP 1v1'
local SCRIPT_VERSION = '3.2.0 FINALE - TOUS BUGS FIXÉS'
local SCRIPT_AUTHOR = 'Scharman Dev Team'

local function CheckDependencies()
    if GetResourceState('es_extended') ~= 'started' then
        Config.ErrorPrint('ESX Legacy n\'est pas démarré')
        return false
    end
    Config.SuccessPrint('ESX détecté')
    
    if GetResourceState('oxmysql') ~= 'started' then
        Config.ErrorPrint('oxmysql n\'est pas démarré')
        return false
    end
    Config.SuccessPrint('oxmysql détecté')
    return true
end

CreateThread(function()
    print('^6═══════════════════════════════════════════════════════════════^7')
    print('^2Script ' .. SCRIPT_NAME .. ' démarré avec succès!^7')
    print('^6Version:^7 ' .. SCRIPT_VERSION)
    print('^6Auteur:^7 ' .. SCRIPT_AUTHOR)
    print('^6═══════════════════════════════════════════════════════════════^7')
    
    if not CheckDependencies() then
        Config.ErrorPrint('Échec vérification dépendances')
        return
    end
    Config.SuccessPrint('Toutes les dépendances OK')
end)

Config.DebugPrint('server/version.lua chargé')
