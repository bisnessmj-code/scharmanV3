-- ═══════════════════════════════════════════════════════════════
-- SERVER - SYSTÈME DE STATISTIQUES V4.0
-- Gestion des kills, morts, ELO, rangs et leaderboard
-- ═══════════════════════════════════════════════════════════════

if not Config.Stats or not Config.Stats.Enabled then return end

local statsCache = {} -- Cache des stats en mémoire pour éviter trop de requêtes SQL

-- ═══════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════

local function GetRankByElo(elo)
    for _, rank in ipairs(Config.Stats.Ranks) do
        if elo >= rank.minElo and elo <= rank.maxElo then
            return rank
        end
    end
    return Config.Stats.Ranks[1] -- Bronze par défaut
end

local function CalculateEloChange(winnerElo, loserElo, kFactor)
    local expectedWinner = 1 / (1 + 10^((loserElo - winnerElo) / 400))
    local eloChange = math.floor(kFactor * (1 - expectedWinner))
    return math.max(1, eloChange) -- Minimum 1 point
end

local function CalculateRatio(kills, deaths)
    if deaths == 0 then
        return kills > 0 and kills or 0
    end
    return math.floor((kills / deaths) * 100) / 100
end

-- ═══════════════════════════════════════════════════════════════
-- BASE DE DONNÉES
-- ═══════════════════════════════════════════════════════════════

local function LoadPlayerStats(identifier)
    if statsCache[identifier] then
        return statsCache[identifier]
    end
    
    local result = MySQL.query.await('SELECT * FROM scharman_stats WHERE identifier = ?', {identifier})
    
    if result and #result > 0 then
        local stats = result[1]
        statsCache[identifier] = stats
        Config.DebugPrint('[STATS] Stats chargées pour ' .. identifier)
        return stats
    end
    
    -- Créer nouvelles stats pour nouveau joueur
    local defaultRank = GetRankByElo(Config.Stats.StartingElo)
    
    MySQL.insert.await('INSERT INTO scharman_stats (identifier, kills, deaths, wins, losses, elo, rank) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        identifier,
        0,
        0,
        0,
        0,
        Config.Stats.StartingElo,
        defaultRank.name
    })
    
    local newStats = {
        identifier = identifier,
        kills = 0,
        deaths = 0,
        wins = 0,
        losses = 0,
        elo = Config.Stats.StartingElo,
        rank = defaultRank.name
    }
    
    statsCache[identifier] = newStats
    Config.SuccessPrint('[STATS] Nouvelles stats créées pour ' .. identifier)
    
    return newStats
end

local function SavePlayerStats(identifier, stats)
    MySQL.update.await('UPDATE scharman_stats SET kills = ?, deaths = ?, wins = ?, losses = ?, elo = ?, rank = ?, last_played = NOW() WHERE identifier = ?', {
        stats.kills,
        stats.deaths,
        stats.wins,
        stats.losses,
        stats.elo,
        stats.rank,
        identifier
    })
    
    statsCache[identifier] = stats
    Config.DebugPrint('[STATS] Stats sauvegardées pour ' .. identifier)
end

-- ═══════════════════════════════════════════════════════════════
-- GESTION KILLS/DEATHS
-- ═══════════════════════════════════════════════════════════════

local function AddKill(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    local stats = LoadPlayerStats(identifier)
    
    stats.kills = stats.kills + 1
    
    -- Optionnel: Petit gain d'ELO par kill
    if Config.Stats.EloPerKill > 0 then
        local oldElo = stats.elo
        local oldRank = stats.rank
        
        stats.elo = stats.elo + Config.Stats.EloPerKill
        local newRank = GetRankByElo(stats.elo)
        stats.rank = newRank.name
        
        -- Notifications
        if Config.Stats.ShowEloNotifications then
            TriggerClientEvent('scharman:client:courseNotification', playerId, 
                string.format(Config.Stats.Notifications.eloGain, Config.Stats.EloPerKill, stats.elo), 2000, 'success')
        end
        
        if Config.Stats.ShowRankUpNotifications and oldRank ~= stats.rank then
            local oldRankData = GetRankByElo(oldElo)
            TriggerClientEvent('scharman:client:courseNotification', playerId, 
                string.format(Config.Stats.Notifications.rankUp, oldRankData.name, newRank.name), 5000, 'success')
        end
    end
    
    if Config.Stats.SaveInRealTime then
        SavePlayerStats(identifier, stats)
    end
    
    Config.DebugPrint('[STATS] Kill ajouté pour ' .. identifier .. ' (Total: ' .. stats.kills .. ')')
end

local function AddDeath(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    local identifier = xPlayer.identifier
    local stats = LoadPlayerStats(identifier)
    
    stats.deaths = stats.deaths + 1
    
    -- Optionnel: Petite perte d'ELO par mort
    if Config.Stats.EloPerDeath < 0 then
        local oldElo = stats.elo
        local oldRank = stats.rank
        
        stats.elo = math.max(0, stats.elo + Config.Stats.EloPerDeath) -- Minimum 0
        local newRank = GetRankByElo(stats.elo)
        stats.rank = newRank.name
        
        -- Notifications
        if Config.Stats.ShowEloNotifications then
            TriggerClientEvent('scharman:client:courseNotification', playerId, 
                string.format(Config.Stats.Notifications.eloLoss, Config.Stats.EloPerDeath, stats.elo), 2000, 'error')
        end
        
        if Config.Stats.ShowRankUpNotifications and oldRank ~= stats.rank then
            local oldRankData = GetRankByElo(oldElo)
            TriggerClientEvent('scharman:client:courseNotification', playerId, 
                string.format(Config.Stats.Notifications.rankDown, oldRankData.name, newRank.name), 5000, 'warning')
        end
    end
    
    if Config.Stats.SaveInRealTime then
        SavePlayerStats(identifier, stats)
    end
    
    Config.DebugPrint('[STATS] Mort ajoutée pour ' .. identifier .. ' (Total: ' .. stats.deaths .. ')')
end

-- ═══════════════════════════════════════════════════════════════
-- GESTION VICTOIRE/DÉFAITE (ELO)
-- ═══════════════════════════════════════════════════════════════

local function ProcessMatchResult(winnerId, loserId)
    local xWinner = ESX.GetPlayerFromId(winnerId)
    local xLoser = ESX.GetPlayerFromId(loserId)
    
    if not xWinner or not xLoser then return end
    
    local winnerIdentifier = xWinner.identifier
    local loserIdentifier = xLoser.identifier
    
    local winnerStats = LoadPlayerStats(winnerIdentifier)
    local loserStats = LoadPlayerStats(loserIdentifier)
    
    local oldWinnerElo = winnerStats.elo
    local oldLoserElo = loserStats.elo
    local oldWinnerRank = winnerStats.rank
    local oldLoserRank = loserStats.rank
    
    -- Calcul changement ELO
    local eloChange = CalculateEloChange(winnerStats.elo, loserStats.elo, Config.Stats.KFactor)
    
    -- Mise à jour ELO
    winnerStats.elo = winnerStats.elo + eloChange
    loserStats.elo = math.max(0, loserStats.elo - eloChange)
    
    -- Mise à jour W/L
    winnerStats.wins = winnerStats.wins + 1
    loserStats.losses = loserStats.losses + 1
    
    -- Mise à jour rangs
    local newWinnerRank = GetRankByElo(winnerStats.elo)
    local newLoserRank = GetRankByElo(loserStats.elo)
    
    winnerStats.rank = newWinnerRank.name
    loserStats.rank = newLoserRank.name
    
    -- Sauvegarder
    SavePlayerStats(winnerIdentifier, winnerStats)
    SavePlayerStats(loserIdentifier, loserStats)
    
    -- Notifications
    if Config.Stats.ShowEloNotifications then
        TriggerClientEvent('scharman:client:courseNotification', winnerId, 
            string.format(Config.Stats.Notifications.eloGain, eloChange, winnerStats.elo), 3000, 'success')
        TriggerClientEvent('scharman:client:courseNotification', loserId, 
            string.format(Config.Stats.Notifications.eloLoss, -eloChange, loserStats.elo), 3000, 'error')
    end
    
    if Config.Stats.ShowRankUpNotifications then
        if oldWinnerRank ~= winnerStats.rank then
            local oldRankData = GetRankByElo(oldWinnerElo)
            TriggerClientEvent('scharman:client:courseNotification', winnerId, 
                string.format(Config.Stats.Notifications.rankUp, oldRankData.name, newWinnerRank.name), 5000, 'success')
        end
        
        if oldLoserRank ~= loserStats.rank then
            local oldRankData = GetRankByElo(oldLoserElo)
            TriggerClientEvent('scharman:client:courseNotification', loserId, 
                string.format(Config.Stats.Notifications.rankDown, oldRankData.name, newLoserRank.name), 5000, 'warning')
        end
    end
    
    Config.SuccessPrint('[STATS] Match terminé:')
    Config.InfoPrint('  Gagnant: ' .. xWinner.getName() .. ' (+' .. eloChange .. ' ELO → ' .. winnerStats.elo .. ')')
    Config.InfoPrint('  Perdant: ' .. xLoser.getName() .. ' (-' .. eloChange .. ' ELO → ' .. loserStats.elo .. ')')
end

-- ═══════════════════════════════════════════════════════════════
-- LEADERBOARD
-- ═══════════════════════════════════════════════════════════════

local function GetLeaderboard(limit)
    limit = limit or Config.Stats.LeaderboardLimit
    
    local result = MySQL.query.await([[
        SELECT identifier, kills, deaths, wins, losses, elo, rank
        FROM scharman_stats
        ORDER BY elo DESC
        LIMIT ?
    ]], {limit})
    
    if not result then return {} end
    
    local leaderboard = {}
    
    for i, row in ipairs(result) do
        local ratio = CalculateRatio(row.kills, row.deaths)
        local rankData = GetRankByElo(row.elo)
        
        -- Récupérer le nom du joueur
        local xPlayer = ESX.GetPlayerFromIdentifier(row.identifier)
        local playerName = 'Joueur Inconnu'
        
        if xPlayer then
            playerName = xPlayer.getName()
        else
            -- Si le joueur n'est pas connecté, essayer de récupérer depuis la DB
            local users = MySQL.query.await('SELECT firstname, lastname FROM users WHERE identifier = ?', {row.identifier})
            if users and #users > 0 then
                playerName = users[1].firstname .. ' ' .. users[1].lastname
            end
        end
        
        table.insert(leaderboard, {
            position = i,
            name = playerName,
            kills = row.kills,
            deaths = row.deaths,
            wins = row.wins,
            losses = row.losses,
            ratio = ratio,
            elo = row.elo,
            rank = row.rank,
            rankData = rankData
        })
    end
    
    return leaderboard
end

-- ═══════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scharman:server:getMyStats', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    local stats = LoadPlayerStats(xPlayer.identifier)
    local ratio = CalculateRatio(stats.kills, stats.deaths)
    local rankData = GetRankByElo(stats.elo)
    
    TriggerClientEvent('scharman:client:receiveMyStats', source, {
        kills = stats.kills,
        deaths = stats.deaths,
        wins = stats.wins,
        losses = stats.losses,
        ratio = ratio,
        elo = stats.elo,
        rank = stats.rank,
        rankData = rankData
    })
end)

RegisterNetEvent('scharman:server:getLeaderboard', function(limit)
    local source = source
    local leaderboard = GetLeaderboard(limit)
    
    TriggerClientEvent('scharman:client:receiveLeaderboard', source, leaderboard)
end)

-- Hook dans le système de combat existant
RegisterNetEvent('scharman:server:recordKill', function(victimId)
    local killerId = source
    AddKill(killerId)
    AddDeath(victimId)
end)

RegisterNetEvent('scharman:server:recordMatchResult', function(winnerId, loserId)
    ProcessMatchResult(winnerId, loserId)
end)

-- Commande admin pour reset les stats
RegisterCommand('stats_reset', function(source, args, rawCommand)
    if source > 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        print('Usage: /stats_reset [player_id]')
        return
    end
    
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then
        print('Joueur introuvable')
        return
    end
    
    local identifier = xTarget.identifier
    local defaultRank = GetRankByElo(Config.Stats.StartingElo)
    
    MySQL.update.await('UPDATE scharman_stats SET kills = 0, deaths = 0, wins = 0, losses = 0, elo = ?, rank = ? WHERE identifier = ?', {
        Config.Stats.StartingElo,
        defaultRank.name,
        identifier
    })
    
    statsCache[identifier] = nil
    
    print('Stats reset pour ' .. xTarget.getName())
    TriggerClientEvent('scharman:client:courseNotification', targetId, '✅ Vos stats ont été réinitialisées', 5000, 'info')
end, true)

Config.DebugPrint('server/stats.lua V4.0 chargé')

-- Export des fonctions pour utilisation externe
exports('AddKill', AddKill)
exports('AddDeath', AddDeath)
exports('ProcessMatchResult', ProcessMatchResult)
exports('GetLeaderboard', GetLeaderboard)
exports('LoadPlayerStats', LoadPlayerStats)
