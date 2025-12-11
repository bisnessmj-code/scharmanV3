-- CLIENT - MAIN
ESX = exports['es_extended']:getSharedObject()

CreateThread(function()
    Config.InfoPrint('Initialisation script client...')
    while not ESX.IsPlayerLoaded() do Wait(100) end
    Config.SuccessPrint('Script client initialisé!')
    Config.DebugPrint('Version: 4.0.0 - SYSTÈME DE TIMERS')
end)

if Config.Debug then
    RegisterCommand('scharman_info', function()
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        print('═══════════════════════════════════════════════════════════════')
        print('Position: ' .. coords.x .. ', ' .. coords.y .. ', ' .. coords.z)
        print('Heading: ' .. heading)
        print('Format Config: vector4(' .. coords.x .. ', ' .. coords.y .. ', ' .. coords.z .. ', ' .. heading .. ')')
        print('═══════════════════════════════════════════════════════════════')
    end, false)
    
    Config.InfoPrint('Commande debug: /scharman_info')
end

Config.DebugPrint('client/main.lua chargé')
