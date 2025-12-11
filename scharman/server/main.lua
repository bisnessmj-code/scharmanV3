-- SERVER - MAIN
ESX = exports['es_extended']:getSharedObject()
local playersWithNuiOpen = {}

RegisterNetEvent('scharman:server:nuiOpened', function()
    playersWithNuiOpen[source] = true
end)

RegisterNetEvent('scharman:server:nuiClosed', function()
    playersWithNuiOpen[source] = nil
end)

RegisterCommand('scharman_list', function(source, args, rawCommand)
    if source > 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end
    end
    
    print('═══════════════════════════════════════════════════════════════')
    print('Joueurs avec interface Scharman ouverte:')
    local count = 0
    for playerId, _ in pairs(playersWithNuiOpen) do
        count = count + 1
        local xPlayer = ESX.GetPlayerFromId(playerId)
        local name = xPlayer and xPlayer.getName() or 'Inconnu'
        print(count .. '. ' .. name .. ' [ID: ' .. playerId .. ']')
    end
    if count == 0 then print('Aucun joueur') end
    print('Total: ' .. count .. ' joueur(s)')
    print('═══════════════════════════════════════════════════════════════')
end, true)

Config.DebugPrint('server/main.lua chargé')
