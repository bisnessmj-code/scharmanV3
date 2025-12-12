-- CLIENT - SYSTÈME DE STATISTIQUES V4.0 - FIX FOCUS
if not Config.Stats or not Config.Stats.Enabled then return end

local myStats = nil
local leaderboard = nil
local statsInterfaceOpen = false

local function RequestMyStats()
    TriggerServerEvent('scharman:server:getMyStats')
end

local function RequestLeaderboard(limit)
    TriggerServerEvent('scharman:server:getLeaderboard', limit or Config.Stats.LeaderboardLimit)
end

local function OpenStatsInterface()
    if statsInterfaceOpen then return end
    
    Config.InfoPrint('[STATS] Ouverture interface')
    statsInterfaceOpen = true
    
    RequestMyStats()
    RequestLeaderboard()
    Wait(500)
    
    -- ✅ FIX : ACTIVER LE FOCUS NUI
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'openStats',
        data = {
            myStats = myStats,
            leaderboard = leaderboard,
            ranks = Config.Stats.Ranks
        }
    })
end

local function CloseStatsInterface()
    if not statsInterfaceOpen then return end
    
    Config.InfoPrint('[STATS] Fermeture interface')
    statsInterfaceOpen = false
    
    SetNuiFocus(false, false)
    
    SendNUIMessage({ action = 'closeStats' })
end

RegisterNetEvent('scharman:client:receiveMyStats', function(stats)
    myStats = stats
    if statsInterfaceOpen then
        SendNUIMessage({ action = 'updateMyStats', data = myStats })
    end
end)

RegisterNetEvent('scharman:client:receiveLeaderboard', function(data)
    leaderboard = data
    if statsInterfaceOpen then
        SendNUIMessage({ action = 'updateLeaderboard', data = leaderboard })
    end
end)

RegisterNetEvent('scharman:client:openStatsInterface', OpenStatsInterface)
RegisterNetEvent('scharman:client:closeStatsInterface', CloseStatsInterface)

-- ✅ FIX : Gestion touche ESC
CreateThread(function()
    while true do
        Wait(0)
        if statsInterfaceOpen and IsControlJustReleased(0, 322) then
            CloseStatsInterface()
        end
        if not statsInterfaceOpen then Wait(500) end
    end
end)

if Config.Debug then
    RegisterCommand('mystats', function()
        if statsInterfaceOpen then
            CloseStatsInterface()
        else
            OpenStatsInterface()
        end
    end, false)
end

Config.DebugPrint('client/stats.lua FIX chargé')
