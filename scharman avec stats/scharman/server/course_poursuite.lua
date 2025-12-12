-- ═══════════════════════════════════════════════════════════════
-- SERVER - MODE COURSE POURSUITE V4.0.0 - SYSTÈME DE TIMERS
-- ═══════════════════════════════════════════════════════════════

ESX = exports['es_extended']:getSharedObject()

local activeInstances = {}
local playersInGame = {}
local waitingPlayers = {}
local lastUsedBucket = Config.CoursePoursuit.BucketRange.min - 1

-- ═══════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════

local function GetNextAvailableBucket()
    lastUsedBucket = lastUsedBucket + 1
    if lastUsedBucket > Config.CoursePoursuit.BucketRange.max then
        lastUsedBucket = Config.CoursePoursuit.BucketRange.min
    end
    
    for _, instance in pairs(activeInstances) do
        if instance.bucket == lastUsedBucket then
            return GetNextAvailableBucket()
        end
    end
    
    return lastUsedBucket
end

local function GenerateInstanceId()
    return 'course_' .. os.time() .. '_' .. math.random(1000, 9999)
end

local function GetVehicleModel()
    if Config.CoursePoursuit.RandomVehicle and #Config.CoursePoursuit.VehicleList > 0 then
        return Config.CoursePoursuit.VehicleList[math.random(1, #Config.CoursePoursuit.VehicleList)]
    end
    return Config.CoursePoursuit.VehicleModel
end

-- ═══════════════════════════════════════════════════════════════
-- GESTION INSTANCES
-- ═══════════════════════════════════════════════════════════════

local function CreateInstance(chasseurId, cibleId)
    local instanceCount = 0
    for _ in pairs(activeInstances) do instanceCount = instanceCount + 1 end
    
    if instanceCount >= Config.CoursePoursuit.MaxInstances then
        Config.ErrorPrint('Nombre max instances atteint')
        return nil
    end
    
    local instanceId = GenerateInstanceId()
    local bucket = GetNextAvailableBucket()
    
    local instance = {
        id = instanceId,
        bucket = bucket,
        players = {
            chasseur = chasseurId,
            cible = cibleId
        },
        createdAt = os.time(),
        vehicleModel = GetVehicleModel(),
        warZone = {
            active = false,
            position = nil,
            createdBy = nil
        },
        cibleInZone = false,
        currentRound = 1,
        score = {
            playerA = 0,
            playerB = 0
        },
        playerAId = chasseurId,
        playerBId = cibleId,
        roundInProgress = false,
        matchFinished = false,
        vehicles = {}
    }
    
    SetRoutingBucketPopulationEnabled(bucket, false)
    SetRoutingBucketEntityLockdownMode(bucket, Config.CoursePoursuit.BucketLockdown)
    
    activeInstances[instanceId] = instance
    
    Config.SuccessPrint('Instance créée: ' .. instanceId)
    Config.InfoPrint('  Bucket: ' .. bucket)
    Config.InfoPrint('  CHASSEUR: ' .. chasseurId)
    Config.InfoPrint('  CIBLE: ' .. cibleId)
    
    return instance
end

local function DeleteInstance(instanceId)
    local instance = activeInstances[instanceId]
    if not instance then return false end
    
    if instance.vehicles then
        for _, veh in pairs(instance.vehicles) do
            if DoesEntityExist(veh) then
                DeleteEntity(veh)
            end
        end
    end
    
    if instance.players.chasseur then
        RemovePlayerFromInstance(instance.players.chasseur, instanceId)
    end
    
    if instance.players.cible then
        RemovePlayerFromInstance(instance.players.cible, instanceId)
    end
    
    activeInstances[instanceId] = nil
    Config.SuccessPrint('Instance supprimée: ' .. instanceId)
    
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- GESTION JOUEURS
-- ═══════════════════════════════════════════════════════════════

local function AddPlayerToInstance(playerId, instance, role)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return false end
    
    if playersInGame[playerId] then return false end
    
    local opponentId = (role == 'chasseur') and instance.players.cible or instance.players.chasseur
    
    playersInGame[playerId] = {
        instanceId = instance.id,
        bucket = instance.bucket,
        originalBucket = GetPlayerRoutingBucket(playerId),
        joinedAt = os.time(),
        role = role,
        opponentId = opponentId
    }
    
    SetPlayerRoutingBucket(playerId, instance.bucket)
    Wait(1000)
    
    local success, vehicleNetId = pcall(function()
        local spawnCoords = Config.CoursePoursuit.SpawnCoords[role]
        local vehicleHash = GetHashKey(instance.vehicleModel)
        
        local vehicle = CreateVehicle(vehicleHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, true)
        Wait(500)
        
        if not DoesEntityExist(vehicle) then
            error('[SERVER] Échec création véhicule')
        end
        
        SetEntityRoutingBucket(vehicle, instance.bucket)
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        
        if netId == 0 or netId == nil then
            DeleteEntity(vehicle)
            error('[SERVER] Échec récupération Network ID')
        end
        
        instance.vehicles[role] = vehicle
        
        Config.SuccessPrint('[SERVER] Véhicule créé pour ' .. string.upper(role) .. ': ' .. vehicle .. ' NetID: ' .. netId)
        return netId
    end)
    
    if not success then
        Config.ErrorPrint('[SERVER] Erreur véhicule: ' .. tostring(vehicleNetId))
        playersInGame[playerId] = nil
        SetPlayerRoutingBucket(playerId, 0)
        TriggerClientEvent('scharman:client:courseNotification', playerId, '❌ Erreur création véhicule', 5000, 'error')
        return false
    end
    
    TriggerClientEvent('scharman:client:startCoursePoursuit', playerId, {
        instanceId = instance.id,
        spawnCoords = Config.CoursePoursuit.SpawnCoords[role],
        vehicleModel = instance.vehicleModel,
        bucketId = instance.bucket,
        vehicleNetId = vehicleNetId,
        role = role,
        opponentId = opponentId
    })
    
    Config.SuccessPrint('Joueur ' .. playerId .. ' ajouté à l\'instance (Rôle: ' .. string.upper(role) .. ')')
    
    return true
end

function RemovePlayerFromInstance(playerId, instanceId)
    local playerData = playersInGame[playerId]
    if not playerData then return false end
    
    local instance = activeInstances[instanceId or playerData.instanceId]
    if not instance then return false end
    
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local playerName = xPlayer and xPlayer.getName() or 'Inconnu'
    
    SetPlayerRoutingBucket(playerId, playerData.originalBucket or 0)
    
    local opponentId = playerData.opponentId
    if opponentId and playersInGame[opponentId] then
        TriggerClientEvent('scharman:client:courseNotification', opponentId, 
            string.format(Config.CoursePoursuit.Notifications.playerLeft, playerName), 3000)
        
        TriggerClientEvent('scharman:client:stopCoursePoursuit', opponentId, true)
    end
    
    playersInGame[playerId] = nil
    
    TriggerClientEvent('scharman:client:stopCoursePoursuit', playerId)
    
    DeleteInstance(instance.id)
    
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- MATCHMAKING
-- ═══════════════════════════════════════════════════════════════

local function FindOpponent(playerId)
    for i, waitingPlayerId in ipairs(waitingPlayers) do
        if waitingPlayerId ~= playerId and GetPlayerPing(waitingPlayerId) > 0 then
            table.remove(waitingPlayers, i)
            return waitingPlayerId
        end
    end
    
    return nil
end

local function StartMatchmaking(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end
    
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    Config.InfoPrint('MATCHMAKING: Joueur ' .. playerId .. ' (' .. xPlayer.getName() .. ')')
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    
    TriggerClientEvent('scharman:client:courseNotification', playerId, 
        Config.CoursePoursuit.Notifications.searching, 5000, 'info')
    
    local opponentId = FindOpponent(playerId)
    
    if opponentId then
        Config.SuccessPrint('MATCH TROUVÉ: ' .. playerId .. ' vs ' .. opponentId)
        
        local xOpponent = ESX.GetPlayerFromId(opponentId)
        
        TriggerClientEvent('scharman:client:courseNotification', playerId, 
            Config.CoursePoursuit.Notifications.playerFound, 3000, 'success')
        TriggerClientEvent('scharman:client:courseNotification', opponentId, 
            Config.CoursePoursuit.Notifications.playerFound, 3000, 'success')
        
        local chasseurId = opponentId
        local cibleId = playerId
        
        local instance = CreateInstance(chasseurId, cibleId)
        
        if not instance then
            TriggerClientEvent('scharman:client:courseNotification', playerId, 
                Config.CoursePoursuit.Notifications.errorCreatingInstance, 3000, 'error')
            TriggerClientEvent('scharman:client:courseNotification', opponentId, 
                Config.CoursePoursuit.Notifications.errorCreatingInstance, 3000, 'error')
            return
        end
        
        Wait(500)
        AddPlayerToInstance(chasseurId, instance, 'chasseur')
        Wait(500)
        AddPlayerToInstance(cibleId, instance, 'cible')
        
        Config.SuccessPrint('PARTIE LANCÉE:')
        Config.InfoPrint('  CHASSEUR: ' .. xOpponent.getName() .. ' [' .. opponentId .. ']')
        Config.InfoPrint('  CIBLE: ' .. xPlayer.getName() .. ' [' .. playerId .. ']')
    else
        Config.InfoPrint('Aucun adversaire trouvé, ajout file d\'attente')
        table.insert(waitingPlayers, playerId)
        
        TriggerClientEvent('scharman:client:courseNotification', playerId, 
            '⏳ En attente d\'un adversaire...', 5000, 'info')
    end
end

-- ═══════════════════════════════════════════════════════════════
-- GESTION ZONE DE GUERRE
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scharman:server:zoneCreated', function(instanceId, position)
    local source = source
    local instance = activeInstances[instanceId]
    
    if not instance then
        Config.ErrorPrint('[ZONE] Instance introuvable: ' .. tostring(instanceId))
        return
    end
    
    local playerData = playersInGame[source]
    if not playerData then
        Config.ErrorPrint('[ZONE] Joueur introuvable: ' .. source)
        return
    end
    
    if playerData.role ~= 'chasseur' then
        Config.ErrorPrint('[ZONE] ⚠️ TENTATIVE CRÉATION PAR CIBLE - BLOQUÉ!')
        return
    end
    
    Config.InfoPrint('[ZONE] 🔴 ZONE CRÉÉE par CHASSEUR ' .. source)
    Config.DebugPrint('[ZONE] Position: ' .. tostring(position))
    
    instance.warZone.active = true
    instance.warZone.position = position
    instance.warZone.createdBy = source
    
    local cibleId = instance.players.cible
    if cibleId and cibleId ~= source then
        Config.InfoPrint('[ZONE] Notification CIBLE: ' .. cibleId)
        TriggerClientEvent('scharman:client:opponentCreatedZone', cibleId, position)
    else
        Config.ErrorPrint('[ZONE] CIBLE introuvable!')
    end
end)

RegisterNetEvent('scharman:server:playerEnteredZone', function(instanceId)
    local source = source
    local instance = activeInstances[instanceId]
    
    if not instance then
        Config.ErrorPrint('[ZONE] Instance introuvable: ' .. tostring(instanceId))
        return
    end
    
    local playerData = playersInGame[source]
    if not playerData then
        Config.ErrorPrint('[ZONE] Joueur introuvable: ' .. source)
        return
    end
    
    if playerData.role ~= 'cible' then
        Config.ErrorPrint('[ZONE] ⚠️ TENTATIVE ENTRÉE PAR CHASSEUR - IGNORÉ!')
        return
    end
    
    Config.InfoPrint('[ZONE] ✅ CIBLE ' .. source .. ' a rejoint la zone')
    
    instance.cibleInZone = true
    
    local chasseurId = instance.players.chasseur
    if chasseurId and chasseurId ~= source then
        Config.InfoPrint('[ZONE] Notification CHASSEUR: ' .. chasseurId)
        TriggerClientEvent('scharman:client:opponentEnteredZone', chasseurId)
    else
        Config.ErrorPrint('[ZONE] CHASSEUR introuvable!')
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ✅ NOUVEAU V4.0: GESTION TIMEOUTS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scharman:server:chasseurTimeout', function(instanceId)
    local source = source
    local instance = activeInstances[instanceId]
    
    if not instance then
        Config.ErrorPrint('[TIMEOUT] Instance introuvable')
        return
    end
    
    local playerData = playersInGame[source]
    if not playerData or playerData.role ~= 'chasseur' then
        Config.ErrorPrint('[TIMEOUT] Joueur invalide ou pas chasseur')
        return
    end
    
    Config.InfoPrint('[TIMEOUT] ⏱️ CHASSEUR ' .. source .. ' n\'a pas créé la zone à temps!')
    
    -- Le chasseur perd la manche
    local winnerId = instance.players.cible
    local loserId = source
    
    -- Incrémenter score du gagnant
    if winnerId == instance.playerAId then
        instance.score.playerA = instance.score.playerA + 1
        Config.InfoPrint('[SCORE] Joueur A gagne (timeout chasseur)! Score: ' .. instance.score.playerA .. '-' .. instance.score.playerB)
    else
        instance.score.playerB = instance.score.playerB + 1
        Config.InfoPrint('[SCORE] Joueur B gagne (timeout chasseur)! Score: ' .. instance.score.playerA .. '-' .. instance.score.playerB)
    end
    
    -- Notifier les joueurs
    TriggerClientEvent('scharman:client:courseNotification', winnerId, '🏆 VICTOIRE ! Le chasseur n\'a pas créé la zone à temps', 5000, 'success')
    TriggerClientEvent('scharman:client:courseNotification', loserId, '💀 DÉFAITE ! Vous n\'avez pas créé la zone à temps', 5000, 'error')
    
    -- Gérer le round suivant
    HandleRoundEnd(instance, winnerId)
end)

RegisterNetEvent('scharman:server:cibleTimeout', function(instanceId)
    local source = source
    local instance = activeInstances[instanceId]
    
    if not instance then
        Config.ErrorPrint('[TIMEOUT] Instance introuvable')
        return
    end
    
    local playerData = playersInGame[source]
    if not playerData or playerData.role ~= 'cible' then
        Config.ErrorPrint('[TIMEOUT] Joueur invalide ou pas cible')
        return
    end
    
    Config.InfoPrint('[TIMEOUT] ⏱️ CIBLE ' .. source .. ' n\'a pas rejoint la zone à temps!')
    
    -- La cible perd la manche
    local winnerId = instance.players.chasseur
    local loserId = source
    
    -- Incrémenter score du gagnant
    if winnerId == instance.playerAId then
        instance.score.playerA = instance.score.playerA + 1
        Config.InfoPrint('[SCORE] Joueur A gagne (timeout cible)! Score: ' .. instance.score.playerA .. '-' .. instance.score.playerB)
    else
        instance.score.playerB = instance.score.playerB + 1
        Config.InfoPrint('[SCORE] Joueur B gagne (timeout cible)! Score: ' .. instance.score.playerA .. '-' .. instance.score.playerB)
    end
    
    -- Notifier les joueurs
    TriggerClientEvent('scharman:client:courseNotification', winnerId, '🏆 VICTOIRE ! La cible n\'a pas rejoint la zone à temps', 5000, 'success')
    TriggerClientEvent('scharman:client:courseNotification', loserId, '💀 DÉFAITE ! Vous n\'avez pas rejoint la zone à temps', 5000, 'error')
    
    -- Gérer le round suivant
    HandleRoundEnd(instance, winnerId)
end)

-- ═══════════════════════════════════════════════════════════════
-- SYSTÈME DE ROUNDS
-- ═══════════════════════════════════════════════════════════════

local function CheckMatchEnd(instance)
    local playerAWins = instance.score.playerA
    local playerBWins = instance.score.playerB
    
    if playerAWins >= Config.CoursePoursuit.RoundsToWin then
        Config.SuccessPrint('[MATCH] JOUEUR A GAGNE LE MATCH ' .. playerAWins .. '-' .. playerBWins)
        return true, instance.playerAId
    elseif playerBWins >= Config.CoursePoursuit.RoundsToWin then
        Config.SuccessPrint('[MATCH] JOUEUR B GAGNE LE MATCH ' .. playerBWins .. '-' .. playerAWins)
        return true, instance.playerBId
    end
    
    return false, nil
end

local function EndMatch(instance, winnerId)
    instance.matchFinished = true
    
    local chasseurId = instance.players.chasseur
    local cibleId = instance.players.cible
    
    Config.InfoPrint('[MATCH] Match terminé - Gagnant final: ' .. winnerId)
    
    
    TriggerClientEvent('scharman:client:showMatchEnd', chasseurId, {
        winner = (winnerId == chasseurId) and 'me' or 'opponent',
        finalScore = instance.score,
        isPlayerA = (chasseurId == instance.playerAId)
    })
    
    TriggerClientEvent('scharman:client:showMatchEnd', cibleId, {
        winner = (winnerId == cibleId) and 'me' or 'opponent',
        finalScore = instance.score,
        isPlayerA = (cibleId == instance.playerAId)
    })
    
    if Config.Stats and Config.Stats.Enabled then
        local loserId = (winnerId == chasseurId) and cibleId or chasseurId
        TriggerEvent('scharman:server:recordMatchResult', winnerId, loserId)
    end
    
    Wait(3000)
    
    TriggerClientEvent('scharman:client:stopCoursePoursuit', chasseurId, (winnerId == chasseurId))
    TriggerClientEvent('scharman:client:stopCoursePoursuit', cibleId, (winnerId == cibleId))
    
    Wait(3000)
    DeleteInstance(instance.id)
end

local function StartNextRound(instance)
    instance.currentRound = instance.currentRound + 1
    instance.roundInProgress = false
    
    if instance.currentRound > 1 then
        local tempChasseur = instance.players.chasseur
        instance.players.chasseur = instance.players.cible
        instance.players.cible = tempChasseur
        
        Config.InfoPrint('[ROUND] 🔄 INVERSION DES RÔLES:')
        Config.InfoPrint('  Nouveau CHASSEUR: ' .. instance.players.chasseur)
        Config.InfoPrint('  Nouvelle CIBLE: ' .. instance.players.cible)
        
        if playersInGame[tempChasseur] then
            playersInGame[tempChasseur].role = 'cible'
            playersInGame[tempChasseur].opponentId = instance.players.chasseur
        end
        if playersInGame[instance.players.chasseur] then
            playersInGame[instance.players.chasseur].role = 'chasseur'
            playersInGame[instance.players.chasseur].opponentId = instance.players.cible
        end
    end
    
    instance.warZone.active = false
    instance.warZone.position = nil
    instance.warZone.createdBy = nil
    instance.cibleInZone = false
    
    Config.InfoPrint('[ROUND] ═══ DÉMARRAGE MANCHE ' .. instance.currentRound .. ' ═══')
    
    local chasseurId = instance.players.chasseur
    local cibleId = instance.players.cible
    
    Wait(Config.CoursePoursuit.TimeBetweenRounds)
    
    TriggerClientEvent('scharman:client:hideRoundScoreboard', chasseurId)
    TriggerClientEvent('scharman:client:hideRoundScoreboard', cibleId)
    
    if instance.vehicles then
        for role, veh in pairs(instance.vehicles) do
            if DoesEntityExist(veh) then
                DeleteEntity(veh)
                Config.DebugPrint('[SERVER] Ancien véhicule ' .. role .. ' supprimé')
            end
        end
        instance.vehicles = {}
    end
    
    Wait(500)
    
    local vehicleModel = instance.vehicleModel
    local chasseurSpawn = Config.CoursePoursuit.SpawnCoords.chasseur
    local cibleSpawn = Config.CoursePoursuit.SpawnCoords.cible
    
    local chasseurVehicle = CreateVehicle(GetHashKey(vehicleModel), chasseurSpawn.x, chasseurSpawn.y, chasseurSpawn.z, chasseurSpawn.w, true, true)
    Wait(500)
    
    if not DoesEntityExist(chasseurVehicle) then
        Config.ErrorPrint('[SERVER] Échec création véhicule CHASSEUR')
        return
    end
    
    SetEntityRoutingBucket(chasseurVehicle, instance.bucket)
    local chasseurNetId = NetworkGetNetworkIdFromEntity(chasseurVehicle)
    instance.vehicles['chasseur'] = chasseurVehicle
    
    Config.SuccessPrint('[SERVER] Véhicule CHASSEUR créé: ' .. chasseurVehicle .. ' NetID: ' .. chasseurNetId)
    
    local cibleVehicle = CreateVehicle(GetHashKey(vehicleModel), cibleSpawn.x, cibleSpawn.y, cibleSpawn.z, cibleSpawn.w, true, true)
    Wait(500)
    
    if not DoesEntityExist(cibleVehicle) then
        Config.ErrorPrint('[SERVER] Échec création véhicule CIBLE')
        DeleteEntity(chasseurVehicle)
        return
    end
    
    SetEntityRoutingBucket(cibleVehicle, instance.bucket)
    local cibleNetId = NetworkGetNetworkIdFromEntity(cibleVehicle)
    instance.vehicles['cible'] = cibleVehicle
    
    Config.SuccessPrint('[SERVER] Véhicule CIBLE créé: ' .. cibleVehicle .. ' NetID: ' .. cibleNetId)
    
    Wait(1000)
    
    instance.roundInProgress = true
    
    TriggerClientEvent('scharman:client:startNextRound', chasseurId, {
        instanceId = instance.id,
        round = instance.currentRound,
        score = instance.score,
        isPlayerA = (chasseurId == instance.playerAId),
        vehicleNetId = chasseurNetId,
        role = 'chasseur'
    })
    
    TriggerClientEvent('scharman:client:startNextRound', cibleId, {
        instanceId = instance.id,
        round = instance.currentRound,
        score = instance.score,
        isPlayerA = (cibleId == instance.playerAId),
        vehicleNetId = cibleNetId,
        role = 'cible'
    })
    
    Config.SuccessPrint('[ROUND] Manche ' .. instance.currentRound .. ' lancée avec succès!')
end

-- ✅ NOUVELLE FONCTION V4.0: Gestion de fin de round (pour morts ET timeouts)
function HandleRoundEnd(instance, winnerId)
    local matchEnded, matchWinner = CheckMatchEnd(instance)
    
    if matchEnded then
        Config.SuccessPrint('[MATCH] Match terminé ' .. instance.score.playerA .. '-' .. instance.score.playerB .. ' - Passage direct à fin de match')
        
        Wait(2000)
        
        TriggerClientEvent('scharman:client:stopRound', instance.players.chasseur)
        TriggerClientEvent('scharman:client:stopRound', instance.players.cible)
        
        Wait(1000)
        
        EndMatch(instance, matchWinner)
    else
        Config.InfoPrint('[MATCH] Manche ' .. instance.currentRound .. ' terminée - Manche suivante')
        
        TriggerClientEvent('scharman:client:showRoundVictory', winnerId, {
            round = instance.currentRound,
            score = instance.score,
            isPlayerA = (winnerId == instance.playerAId)
        })
        
        Wait(3000)
        
        local chasseurId = instance.players.chasseur
        local cibleId = instance.players.cible
        
        TriggerClientEvent('scharman:client:showRoundScoreboard', chasseurId, {
            round = instance.currentRound,
            score = instance.score,
            isPlayerA = (chasseurId == instance.playerAId),
            timeUntilNext = Config.CoursePoursuit.TimeBetweenRounds
        })
        
        TriggerClientEvent('scharman:client:showRoundScoreboard', cibleId, {
            round = instance.currentRound,
            score = instance.score,
            isPlayerA = (cibleId == instance.playerAId),
            timeUntilNext = Config.CoursePoursuit.TimeBetweenRounds
        })
        
        Wait(2000)
        TriggerClientEvent('scharman:client:stopRound', instance.players.chasseur)
        TriggerClientEvent('scharman:client:stopRound', instance.players.cible)
        
        Wait(1000)
        StartNextRound(instance)
    end
end

RegisterNetEvent('scharman:server:playerDied', function(instanceId)
    local source = source
    local instance = activeInstances[instanceId]
    
    if not instance then return end
    
    local playerData = playersInGame[source]
    if not playerData then return end
    
    Config.InfoPrint('💀 Joueur ' .. source .. ' (' .. string.upper(playerData.role) .. ') est mort')
    
    local loserId = source
    local loserRole = playerData.role
    local winnerId = playerData.opponentId
    local winnerRole = (loserRole == 'chasseur') and 'cible' or 'chasseur'
    
    -- ✅ NOUVEAU: Enregistrer les stats (kill/mort)
    if Config.Stats and Config.Stats.Enabled then
        TriggerEvent('scharman:server:recordKill', winnerId, loserId)
    end
    
    if winnerId == instance.playerAId then
        instance.score.playerA = instance.score.playerA + 1
        Config.InfoPrint('[SCORE] Joueur A gagne! Score: ' .. instance.score.playerA .. '-' .. instance.score.playerB)
    else
        instance.score.playerB = instance.score.playerB + 1
        Config.InfoPrint('[SCORE] Joueur B gagne! Score: ' .. instance.score.playerA .. '-' .. instance.score.playerB)
    end
    
    HandleRoundEnd(instance, winnerId)
end)

-- ═══════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scharman:server:joinCoursePoursuit', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    if not Config.CoursePoursuit.Enabled then
        TriggerClientEvent('scharman:client:courseNotification', source, '❌ Mode désactivé', 3000)
        return
    end
    
    if playersInGame[source] then
        TriggerClientEvent('scharman:client:courseNotification', source, '❌ Vous êtes déjà en partie', 3000)
        return
    end
    
    for _, waitingId in ipairs(waitingPlayers) do
        if waitingId == source then
            TriggerClientEvent('scharman:client:courseNotification', source, '⏳ Déjà en file d\'attente', 3000)
            return
        end
    end
    
    StartMatchmaking(source)
end)

RegisterNetEvent('scharman:server:coursePoursuiteLeft', function()
    local source = source
    local playerData = playersInGame[source]
    
    if playerData then
        RemovePlayerFromInstance(source, playerData.instanceId)
    end
    
    for i, waitingId in ipairs(waitingPlayers) do
        if waitingId == source then
            table.remove(waitingPlayers, i)
            Config.InfoPrint('Joueur ' .. source .. ' retiré de la file d\'attente')
            break
        end
    end
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local playerData = playersInGame[source]
    
    if playerData then
        RemovePlayerFromInstance(source, playerData.instanceId)
    end
    
    for i, waitingId in ipairs(waitingPlayers) do
        if waitingId == source then
            table.remove(waitingPlayers, i)
            break
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('course_instances', function(source, args, rawCommand)
    if source > 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end
    end
    
    print('═══════════════════════════════════════════════════════════════')
    print('Instances Course Poursuite actives:')
    local count = 0
    for instanceId, instance in pairs(activeInstances) do
        count = count + 1
        print(string.format('%d. Instance: %s (Bucket: %d)', count, instanceId, instance.bucket))
        print(string.format('   CHASSEUR: %d | CIBLE: %d', instance.players.chasseur, instance.players.cible))
        print(string.format('   Manche: %d | Score: Joueur A: %d - Joueur B: %d', instance.currentRound, instance.score.playerA, instance.score.playerB))
        print(string.format('   Véhicule: %s', instance.vehicleModel))
        print(string.format('   Zone active: %s', instance.warZone.active and 'OUI' or 'NON'))
    end
    if count == 0 then print('Aucune instance active') end
    print('═══════════════════════════════════════════════════════════════')
    print('File d\'attente:')
    if #waitingPlayers > 0 then
        for i, playerId in ipairs(waitingPlayers) do
            local xPlayer = ESX.GetPlayerFromId(playerId)
            local name = xPlayer and xPlayer.getName() or 'Inconnu'
            print(string.format('%d. %s [ID: %d]', i, name, playerId))
        end
    else
        print('Aucun joueur en attente')
    end
    print('═══════════════════════════════════════════════════════════════')
end, true)

RegisterCommand('course_kick', function(source, args, rawCommand)
    if source > 0 then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        print('Usage: /course_kick [player_id]')
        return
    end
    
    if playersInGame[targetId] then
        RemovePlayerFromInstance(targetId)
        print('Joueur ' .. targetId .. ' éjecté')
    else
        print('Le joueur n\'est pas en jeu')
    end
end, true)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for instanceId, instance in pairs(activeInstances) do
        DeleteInstance(instanceId)
    end
end)

Config.DebugPrint('server/course_poursuite.lua V4.0.0 chargé')
