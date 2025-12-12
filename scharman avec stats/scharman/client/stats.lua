-- ═══════════════════════════════════════════════════════════════
-- CLIENT - SYSTÈME DE STATISTIQUES V4.0
-- Gestion affichage stats personnelles et leaderboard
-- ═══════════════════════════════════════════════════════════════

if not Config.Stats or not Config.Stats.Enabled then return end

local myStats = nil
local leaderboard = nil

-- ═══════════════════════════════════════════════════════════════
-- RÉCUPÉRATION DES STATS
-- ═══════════════════════════════════════════════════════════════

local function RequestMyStats()
    Config.DebugPrint('[STATS] Demande de mes stats au serveur...')
    TriggerServerEvent('scharman:server:getMyStats')
end

local function RequestLeaderboard(limit)
    Config.DebugPrint('[STATS] Demande du leaderboard au serveur...')
    TriggerServerEvent('scharman:server:getLeaderboard', limit or Config.Stats.LeaderboardLimit)
end

-- ═══════════════════════════════════════════════════════════════
-- AFFICHAGE INTERFACE
-- ═══════════════════════════════════════════════════════════════

local function OpenStatsInterface()
    Config.InfoPrint('[STATS] Ouverture interface statistiques')
    
    -- Demander les stats fraîches
    RequestMyStats()
    RequestLeaderboard()
    
    -- Attendre un peu que les stats arrivent
    Wait(500)
    
    -- Envoyer à l'interface NUI
    SendNUIMessage({
        action = 'openStats',
        data = {
            myStats = myStats,
            leaderboard = leaderboard,
            ranks = Config.Stats.Ranks
        }
    })
end

-- ═══════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scharman:client:receiveMyStats', function(stats)
    myStats = stats
    Config.SuccessPrint('[STATS] Stats reçues: ' .. stats.kills .. ' kills, ' .. stats.deaths .. ' morts, ELO: ' .. stats.elo)
    
    -- Si l'interface est ouverte, mettre à jour
    SendNUIMessage({
        action = 'updateMyStats',
        data = myStats
    })
end)

RegisterNetEvent('scharman:client:receiveLeaderboard', function(data)
    leaderboard = data
    Config.SuccessPrint('[STATS] Leaderboard reçu: ' .. #data .. ' joueurs')
    
    -- Si l'interface est ouverte, mettre à jour
    SendNUIMessage({
        action = 'updateLeaderboard',
        data = leaderboard
    })
end)

RegisterNetEvent('scharman:client:openStatsInterface', function()
    OpenStatsInterface()
end)

-- Callback NUI pour ouvrir les stats
RegisterNUICallback('openStats', function(data, cb)
    OpenStatsInterface()
    cb('ok')
end)

RegisterNUICallback('closeStats', function(data, cb)
    Config.InfoPrint('[STATS] Fermeture interface statistiques')
    
    SendNUIMessage({
        action = 'closeStats'
    })
    
    cb('ok')
end)

RegisterNUICallback('refreshStats', function(data, cb)
    Config.InfoPrint('[STATS] Rafraîchissement stats')
    RequestMyStats()
    RequestLeaderboard()
    cb('ok')
end)

-- Commande pour ouvrir les stats (debug)
if Config.Debug then
    RegisterCommand('mystats', function()
        OpenStatsInterface()
    end, false)
end

Config.DebugPrint('client/stats.lua V4.0 chargé')
