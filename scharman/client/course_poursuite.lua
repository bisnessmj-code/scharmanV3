-- ███████╗ ██████╗██╗  ██╗ █████╗ ██████╗ ███╗   ███╗ █████╗ ███╗   ██╗
-- ██╔════╝██╔════╝██║  ██║██╔══██╗██╔══██╗████╗ ████║██╔══██╗████╗  ██║
-- ███████╗██║     ███████║███████║██████╔╝██╔████╔██║███████║██╔██╗ ██║
-- ╚════██║██║     ██╔══██║██╔══██║██╔══██╗██║╚██╔╝██║██╔══██║██║╚██╗██║
-- ███████║╚██████╗██║  ██║██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║██║ ╚████║
-- ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
-- CLIENT - MODE COURSE POURSUITE V3.5 FINALE (CHASSEUR vs CIBLE)
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- VARIABLES LOCALES
-- ═══════════════════════════════════════════════════════════════

local inGame = false
local currentVehicle = nil
local instanceId = nil
local currentBucket = 0
local myRole = nil -- 'chasseur' ou 'cible'
local opponentId = nil

-- Threads
local blockExitThread = nil
local vehicleExitThread = nil
local damageZoneThread = nil
local warZoneThread = nil
local warningMessageActive = false
local zoneWaitingThread = nil

-- Timers
local gameEndTime = nil
local gameStartTime = nil

-- Zone de guerre
local canExitVehicle = false
local warZoneActive = false
local warZonePosition = nil
local warZoneBlip = nil
local warZoneCenterBlip = nil
local warZoneRadius = Config.CoursePoursuit.WarZoneRadius

-- États
local iAmChasseur = false
local iAmCible = false
local zoneCreatedByMe = false
local zoneCreatedByOpponent = false
local iAmInZone = false

-- ═══════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════

local function ShowGameNotification(message, duration, notifType)
    SendNUIMessage({
        action = 'showNotification',
        data = {
            message = message,
            duration = duration or Config.CoursePoursuit.MessageDuration,
            type = notifType or 'info'
        }
    })
end

local function LoadModel(model)
    local modelHash = GetHashKey(model)
    
    if not IsModelValid(modelHash) then
        Config.ErrorPrint('Modèle invalide: ' .. model)
        return false
    end
    
    Config.DebugPrint('Chargement modèle: ' .. model)
    RequestModel(modelHash)
    
    local timeout = 0
    while not HasModelLoaded(modelHash) do
        Wait(100)
        timeout = timeout + 100
        
        if timeout >= 10000 then
            Config.ErrorPrint('Timeout chargement modèle: ' .. model)
            return false
        end
    end
    
    Config.SuccessPrint('Modèle chargé: ' .. model)
    return true
end

local function ForcePlayerIntoVehicle(ped, vehicle, seat)
    if not ped or not DoesEntityExist(ped) then
        Config.ErrorPrint('PED invalide!')
        return false
    end
    
    if not vehicle or not DoesEntityExist(vehicle) then
        Config.ErrorPrint('Véhicule invalide!')
        return false
    end
    
    Config.DebugPrint('Placement joueur dans véhicule...')
    
    SetVehicleOnGroundProperly(vehicle)
    Wait(100)
    
    TaskWarpPedIntoVehicle(ped, vehicle, seat)
    Wait(500)
    
    local attempts = 0
    local maxAttempts = 10
    
    while GetVehiclePedIsIn(ped, false) ~= vehicle and attempts < maxAttempts do
        attempts = attempts + 1
        Config.DebugPrint('Tentative ' .. attempts .. '/' .. maxAttempts)
        
        TaskWarpPedIntoVehicle(ped, vehicle, seat)
        Wait(300)
        
        if GetVehiclePedIsIn(ped, false) ~= vehicle then
            SetPedIntoVehicle(ped, vehicle, seat)
            Wait(300)
        end
    end
    
    local isInVehicle = GetVehiclePedIsIn(ped, false) == vehicle
    
    if isInVehicle then
        Config.SuccessPrint('Joueur placé dans véhicule!')
        return true
    else
        Config.ErrorPrint('ÉCHEC placement après ' .. attempts .. ' tentatives')
        return false
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ZONE DE GUERRE
-- ═══════════════════════════════════════════════════════════════

local function CreateWarZoneVisuals(position)
    if not position then
        Config.ErrorPrint('[ZONE] Position invalide')
        return false
    end
    
    -- Créer le blip de rayon (zone rouge)
    if warZoneBlip then
        RemoveBlip(warZoneBlip)
    end
    
    warZoneBlip = AddBlipForRadius(position.x, position.y, position.z, warZoneRadius)
    SetBlipHighDetail(warZoneBlip, true)
    SetBlipColour(warZoneBlip, Config.CoursePoursuit.WarZoneBlipColor)
    SetBlipAlpha(warZoneBlip, 180)
    
    -- Créer le blip centre (crâne)
    if warZoneCenterBlip then
        RemoveBlip(warZoneCenterBlip)
    end
    
    warZoneCenterBlip = AddBlipForCoord(position.x, position.y, position.z)
    SetBlipSprite(warZoneCenterBlip, Config.CoursePoursuit.WarZoneBlipSprite)
    SetBlipDisplay(warZoneCenterBlip, 4)
    SetBlipScale(warZoneCenterBlip, 1.2)
    SetBlipColour(warZoneCenterBlip, Config.CoursePoursuit.WarZoneBlipColor)
    SetBlipAsShortRange(warZoneCenterBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("🔴 ZONE DE GUERRE")
    EndTextCommandSetBlipName(warZoneCenterBlip)
    
    Config.SuccessPrint('Visuels zone de guerre créés')
    return true
end

local function StartWarZoneThread()
    if warZoneThread then return end
    
    Config.InfoPrint('Thread rendu zone démarré')
    
    warZoneThread = CreateThread(function()
        while inGame and warZoneActive do
            Wait(0)
            
            -- CRITICAL: Vérifier que warZonePosition existe
            if not warZonePosition then
                Wait(100)
                goto continue
            end
            
            local pos = warZonePosition
            
            -- Colonne de lumière rouge (cylindre vertical)
            DrawMarker(
                28,
                pos.x, pos.y, pos.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                warZoneRadius, warZoneRadius, Config.CoursePoursuit.WarZoneLightHeight,
                Config.CoursePoursuit.WarZoneColor.r,
                Config.CoursePoursuit.WarZoneColor.g,
                Config.CoursePoursuit.WarZoneColor.b,
                Config.CoursePoursuit.WarZoneColor.a,
                false, false, 2, false, nil, nil, false
            )
            
            -- Cercle au sol
            DrawMarker(
                1,
                pos.x, pos.y, pos.z - 1.0,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                warZoneRadius * 2, warZoneRadius * 2, 1.0,
                Config.CoursePoursuit.WarZoneColor.r,
                Config.CoursePoursuit.WarZoneColor.g,
                Config.CoursePoursuit.WarZoneColor.b,
                150,
                false, false, 2, false, nil, nil, false
            )
            
            ::continue::
        end
        
        warZoneThread = nil
        Config.DebugPrint('Thread rendu zone arrêté')
    end)
end

local function CreateWarZone(position)
    Config.InfoPrint('🔴 CRÉATION ZONE DE GUERRE')
    Config.DebugPrint('[ZONE] Position: ' .. tostring(position))
    
    warZonePosition = position
    warZoneActive = true
    zoneCreatedByMe = true
    
    if not CreateWarZoneVisuals(position) then
        Config.ErrorPrint('Échec création visuels zone')
        return false
    end
    
    StartWarZoneThread()
    
    -- Informer le serveur
    TriggerServerEvent('scharman:server:zoneCreated', instanceId, position)
    
    ShowGameNotification(Config.CoursePoursuit.Notifications.warZoneCreated, 5000, 'warning')
    
    Config.SuccessPrint('Zone créée à: ' .. tostring(position))
    return true
end

local function DeleteWarZone()
    Config.DebugPrint('Suppression zone de guerre...')
    
    warZoneActive = false
    warZonePosition = nil
    zoneCreatedByMe = false
    zoneCreatedByOpponent = false
    iAmInZone = false
    
    if warZoneBlip then
        RemoveBlip(warZoneBlip)
        warZoneBlip = nil
    end
    
    if warZoneCenterBlip then
        RemoveBlip(warZoneCenterBlip)
        warZoneCenterBlip = nil
    end
    
    if warZoneThread then
        warZoneThread = nil
    end
    
    Config.SuccessPrint('Zone supprimée')
end

-- ═══════════════════════════════════════════════════════════════
-- DÉCOMPTE 3-2-1-GO
-- ═══════════════════════════════════════════════════════════════

local function StartCountdown()
    Config.InfoPrint('⏱️ DÉCOMPTE 3-2-1-GO')
    
    local ped = PlayerPedId()
    
    -- FREEZE le joueur ET le véhicule pendant tout le décompte
    FreezeEntityPosition(ped, true)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        FreezeEntityPosition(currentVehicle, true)
        SetVehicleEngineOn(currentVehicle, false, true, false)
    end
    Config.DebugPrint('Joueur et véhicule freezés pour décompte')
    
    -- 3
    SendNUIMessage({ action = 'showCountdown', data = { number = 3 } })
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    Wait(1000)
    
    -- 2
    SendNUIMessage({ action = 'showCountdown', data = { number = 2 } })
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    Wait(1000)
    
    -- 1
    SendNUIMessage({ action = 'showCountdown', data = { number = 1 } })
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    Wait(1000)
    
    -- GO!
    SendNUIMessage({ action = 'showCountdown', data = { number = 'GO!' } })
    PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
    Wait(1000)
    
    -- DÉFREEZE le joueur ET le véhicule - tous partent en même temps
    FreezeEntityPosition(ped, false)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        FreezeEntityPosition(currentVehicle, false)
        SetVehicleEngineOn(currentVehicle, true, true, false)
    end
    Config.SuccessPrint('Joueur et véhicule défreezés - GO!')
    
    SendNUIMessage({ action = 'hideCountdown' })
    Config.SuccessPrint('✅ Décompte terminé!')
end

-- ═══════════════════════════════════════════════════════════════
-- THREAD DÉGÂTS ZONE
-- ═══════════════════════════════════════════════════════════════

local function StartDamageZoneThread()
    if damageZoneThread then return end
    
    Config.InfoPrint('[DAMAGE] 🔴 Démarrage thread dégâts')
    
    damageZoneThread = CreateThread(function()
        while inGame and warZoneActive and warZonePosition do
            Wait(Config.CoursePoursuit.DamageInterval)
            
            local ped = PlayerPedId()
            
            -- Vérifier mort
            if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
                Config.InfoPrint('[DAMAGE] 💀 Joueur mort')
                
                SendNUIMessage({ action = 'showDeathScreen' })
                Wait(3000)
                
                -- Informer serveur de la mort
                TriggerServerEvent('scharman:server:playerDied', instanceId)
                
                break
            end
            
            local playerCoords = GetEntityCoords(ped)
            local distance = #(playerCoords - vector3(warZonePosition.x, warZonePosition.y, warZonePosition.z))
            
            -- Si hors zone
            if distance > warZoneRadius then
                local currentHealth = GetEntityHealth(ped)
                local newHealth = currentHealth - Config.CoursePoursuit.OutOfZoneDamage
                
                Config.InfoPrint(string.format('[DAMAGE] ⚡ HORS ZONE! Distance: %.1fm | HP: %d → %d', distance, currentHealth, newHealth))
                
                -- Message d'avertissement
                if not warningMessageActive then
                    warningMessageActive = true
                    
                    CreateThread(function()
                        while inGame and warZonePosition and distance > warZoneRadius do
                            ShowGameNotification(Config.CoursePoursuit.Notifications.outOfZone, 1500, 'warning')
                            Wait(2000)
                            
                            local newCoords = GetEntityCoords(PlayerPedId())
                            distance = #(newCoords - vector3(warZonePosition.x, warZonePosition.y, warZonePosition.z))
                        end
                        
                        warningMessageActive = false
                        if inGame then
                            ShowGameNotification('✅ Retour dans la zone!', 2000, 'success')
                        end
                    end)
                end
                
                -- Infliger dégâts
                SetEntityHealth(ped, math.max(0, newHealth))
                ShowGameNotification(string.format(Config.CoursePoursuit.Notifications.takingDamage, Config.CoursePoursuit.OutOfZoneDamage), 1500, 'error')
            else
                warningMessageActive = false
            end
        end
        
        damageZoneThread = nil
        Config.InfoPrint('[DAMAGE] 🔴 Thread dégâts arrêté')
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- THREAD BLOCAGE SORTIE VÉHICULE
-- ═══════════════════════════════════════════════════════════════

local function StartBlockExitThread()
    if blockExitThread then return end
    
    Config.DebugPrint('Thread blocage sortie démarré')
    
    -- Timer 30 secondes
    CreateThread(function()
        SendNUIMessage({
            action = 'showVehicleLock',
            data = { duration = Config.CoursePoursuit.BlockExitDuration * 1000 }
        })
        
        Wait(Config.CoursePoursuit.BlockExitDuration * 1000)
        
        -- IMPORTANT: Seul le CHASSEUR peut sortir après 30s
        if iAmChasseur then
            canExitVehicle = true
            Config.SuccessPrint('✅ Sortie véhicule autorisée (CHASSEUR)!')
            ShowGameNotification(Config.CoursePoursuit.Notifications.canExitVehicle, 5000, 'success')
        else
            Config.InfoPrint('⏳ CIBLE en attente de la zone...')
            ShowGameNotification(Config.CoursePoursuit.Notifications.mustJoinZone, 5000, 'warning')
        end
        
        SendNUIMessage({ action = 'hideVehicleLock' })
    end)
    
    blockExitThread = CreateThread(function()
        while inGame and Config.CoursePoursuit.BlockExitVehicle and not canExitVehicle do
            Wait(0)
            
            local ped = PlayerPedId()
            local isInVehicle = IsPedInVehicle(ped, currentVehicle, false)
            
            DisableControlAction(0, 75, true)
            
            if IsDisabledControlJustPressed(0, 75) then
                local timeElapsed = (GetGameTimer() - gameStartTime) / 1000
                local timeLeft = math.max(0, Config.CoursePoursuit.BlockExitDuration - timeElapsed)
                
                if iAmCible and timeLeft <= 0 then
                    ShowGameNotification(Config.CoursePoursuit.Notifications.mustJoinZone, 3000, 'warning')
                else
                    ShowGameNotification(string.format('⏰ Attendez encore %d secondes!', math.ceil(timeLeft)), 3000, 'warning')
                end
            end
            
            if DoesEntityExist(currentVehicle) and not isInVehicle then
                ForcePlayerIntoVehicle(ped, currentVehicle, -1)
                if iAmCible then
                    ShowGameNotification(Config.CoursePoursuit.Notifications.joinZoneFirst, 3000, 'warning')
                else
                    ShowGameNotification('🚗 Retour forcé - Attendez', 3000, 'warning')
                end
            end
        end
        
        blockExitThread = nil
        Config.DebugPrint('Thread blocage sortie arrêté (canExitVehicle = true)')
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- THREAD DÉTECTION SORTIE VÉHICULE (CHASSEUR uniquement)
-- ═══════════════════════════════════════════════════════════════

local function StartVehicleExitDetectionThread()
    if not iAmChasseur then
        Config.InfoPrint('[CHASSEUR] Thread détection sortie ignoré (je suis CIBLE)')
        return
    end
    
    if vehicleExitThread then return end
    
    vehicleExitThread = CreateThread(function()
        Config.DebugPrint('[CHASSEUR] Thread détection sortie démarré')
        
        while inGame and not zoneCreatedByMe and iAmChasseur do
            Wait(500)
            
            local ped = PlayerPedId()
            
            -- Si peut sortir ET n'est PAS dans véhicule
            if canExitVehicle and not IsPedInAnyVehicle(ped, false) then
                -- Créer zone de guerre
                local coords = GetEntityCoords(ped)
                
                if CreateWarZone(coords) then
                    -- Donner arme
                    local weaponHash = GetHashKey(Config.CoursePoursuit.WeaponHash)
                    GiveWeaponToPed(ped, weaponHash, Config.CoursePoursuit.WeaponAmmo, false, true)
                    SetCurrentPedWeapon(ped, weaponHash, true)
                    
                    ShowGameNotification(Config.CoursePoursuit.Notifications.weaponGiven, 3000, 'success')
                    ShowGameNotification(Config.CoursePoursuit.Notifications.waitingCible, 5000, 'info')
                    Config.SuccessPrint('[CHASSEUR] Zone créée & arme donnée')
                    
                    -- Démarrer thread dégâts
                    StartDamageZoneThread()
                else
                    Config.ErrorPrint('[CHASSEUR] Échec création zone')
                end
                
                break
            end
        end
        
        vehicleExitThread = nil
        Config.DebugPrint('[CHASSEUR] Thread détection sortie arrêté')
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- THREAD VÉRIFICATION PRÉSENCE DANS ZONE (CIBLE uniquement)
-- ═══════════════════════════════════════════════════════════════

local function StartZonePresenceCheckThread()
    if not iAmCible then
        Config.InfoPrint('[CIBLE] Thread présence zone ignoré (je suis CHASSEUR)')
        return
    end
    
    if zoneWaitingThread then return end
    
    zoneWaitingThread = CreateThread(function()
        Config.InfoPrint('[CIBLE] Attente zone adverse...')
        
        while inGame and not warZonePosition do
            Wait(500)
        end
        
        if not inGame then
            zoneWaitingThread = nil
            return
        end
        
        Config.InfoPrint('[CIBLE] Zone détectée! Vérification présence...')
        
        while inGame and iAmCible and not iAmInZone and warZonePosition do
            Wait(500)
            
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local distance = #(playerCoords - vector3(warZonePosition.x, warZonePosition.y, warZonePosition.z))
            
            -- Si dans la zone
            if distance <= warZoneRadius then
                iAmInZone = true
                canExitVehicle = true
                
                Config.SuccessPrint('[CIBLE] ✅ Je suis dans la zone adverse!')
                
                -- Informer serveur
                TriggerServerEvent('scharman:server:playerEnteredZone', instanceId)
                
                ShowGameNotification(Config.CoursePoursuit.Notifications.zoneJoined, 5000, 'success')
                
                -- IMPORTANT: Donner arme dès maintenant (même si encore dans véhicule)
                local weaponHash = GetHashKey(Config.CoursePoursuit.WeaponHash)
                GiveWeaponToPed(ped, weaponHash, Config.CoursePoursuit.WeaponAmmo, false, true)
                SetCurrentPedWeapon(ped, weaponHash, true)
                ShowGameNotification(Config.CoursePoursuit.Notifications.weaponGiven, 3000, 'success')
                Config.SuccessPrint('[CIBLE] Arme donnée!')
                
                -- CRITIQUE: Démarrer thread dégâts pour CIBLE aussi (détection mort)
                StartDamageZoneThread()
                Config.SuccessPrint('[CIBLE] Thread dégâts démarré')
                
                break
            end
        end
        
        zoneWaitingThread = nil
        Config.DebugPrint('[CIBLE] Thread présence zone arrêté')
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- DÉMARRAGE JEU
-- ═══════════════════════════════════════════════════════════════

local function StartCoursePoursuiteGame(data)
    if inGame then return end
    
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    Config.InfoPrint('DÉMARRAGE COURSE POURSUITE V3.5 FINALE (CHASSEUR vs CIBLE)')
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    
    local success, err = pcall(function()
        local ped = PlayerPedId()
        instanceId = data.instanceId
        myRole = data.role
        opponentId = data.opponentId
        
        iAmChasseur = (myRole == 'chasseur')
        iAmCible = (myRole == 'cible')
        
        Config.InfoPrint('Mon rôle: ' .. string.upper(myRole))
        Config.InfoPrint('Adversaire: ' .. opponentId)
        
        -- Sélection spawn
        local spawnCoords = data.spawnCoords
        local vehicleModel = data.vehicleModel or Config.CoursePoursuit.VehicleModel
        
        -- Afficher rôle
        if iAmChasseur then
            ShowGameNotification(Config.CoursePoursuit.Notifications.roleChasseur, 5000, 'info')
        else
            ShowGameNotification(Config.CoursePoursuit.Notifications.roleCible, 5000, 'info')
        end
        
        ShowGameNotification(Config.CoursePoursuit.Notifications.teleporting, 2000, 'info')
        
        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do Wait(10) end
        
        -- Téléportation
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
        SetEntityHeading(ped, spawnCoords.w)
        
        -- Stocker bucket
        currentBucket = data.bucketId or 0
        
        if currentBucket > 0 then
            Config.InfoPrint('Synchronisation bucket ' .. currentBucket)
            Wait(3000)
            Config.SuccessPrint('Synchro terminée')
        else
            Wait(3000)
        end
        
        -- Reset HP à 200
        SetEntityHealth(ped, Config.CoursePoursuit.PlayerHealth)
        Config.SuccessPrint('HP joueur: ' .. Config.CoursePoursuit.PlayerHealth)
        
        Wait(1000)
        
        -- Récupération véhicule
        local vehicleNetId = data.vehicleNetId
        
        if vehicleNetId then
            Config.InfoPrint('═══ RÉCUPÉRATION VÉHICULE ═══')
            
            local maxAttempts = 100
            local attempt = 0
            
            repeat
                currentVehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
                
                if currentVehicle and DoesEntityExist(currentVehicle) then
                    Config.SuccessPrint('Véhicule récupéré: ' .. currentVehicle)
                    break
                end
                
                attempt = attempt + 1
                Wait(100)
            until attempt >= maxAttempts
            
            if not currentVehicle or not DoesEntityExist(currentVehicle) then
                error('Échec récupération véhicule')
            end
            
            SetVehicleOnGroundProperly(currentVehicle)
            Wait(500)
        end
        
        -- Personnalisation véhicule
        local customKey = iAmChasseur and 'chasseur' or 'cible'
        local customization = Config.CoursePoursuit.VehicleCustomization[customKey]
        
        SetVehicleCustomPrimaryColour(currentVehicle, customization.primaryColor.r, customization.primaryColor.g, customization.primaryColor.b)
        SetVehicleCustomSecondaryColour(currentVehicle, customization.secondaryColor.r, customization.secondaryColor.g, customization.secondaryColor.b)
        SetVehicleNumberPlateText(currentVehicle, customization.plate)
        
        local mods = Config.CoursePoursuit.VehicleCustomization.mods
        SetVehicleMod(currentVehicle, 11, mods.engine, false)
        SetVehicleMod(currentVehicle, 12, mods.brakes, false)
        SetVehicleMod(currentVehicle, 13, mods.transmission, false)
        SetVehicleMod(currentVehicle, 15, mods.suspension, false)
        ToggleVehicleMod(currentVehicle, 18, mods.turbo)
        
        SetVehicleEngineHealth(currentVehicle, 1000.0)
        SetVehicleBodyHealth(currentVehicle, 1000.0)
        SetVehicleDoorsLocked(currentVehicle, 2)
        
        Config.SuccessPrint('Véhicule personnalisé')
        
        -- Placement joueur
        Config.InfoPrint('═══ PLACEMENT JOUEUR ═══')
        local placementSuccess = ForcePlayerIntoVehicle(ped, currentVehicle, -1)
        
        if not placementSuccess then
            error('Impossible de placer joueur')
        end
        
        -- Fade in
        DoScreenFadeIn(500)
        while not IsScreenFadedIn() do Wait(10) end
        
        inGame = true
        gameStartTime = GetGameTimer()
        
        -- Décompte
        if Config.CoursePoursuit.EnableCountdown then
            StartCountdown()
        end
        
        -- Timer fin de jeu
        if Config.CoursePoursuit.GameDuration > 0 then
            gameEndTime = GetGameTimer() + (Config.CoursePoursuit.GameDuration * 1000)
        end
        
        -- Démarrer threads
        StartBlockExitThread()
        StartVehicleExitDetectionThread() -- Seulement si CHASSEUR
        StartZonePresenceCheckThread()     -- Seulement si CIBLE
        
        Config.SuccessPrint('PARTIE DÉMARRÉE!')
    end)
    
    if not success then
        Config.ErrorPrint('ERREUR: ' .. tostring(err))
        
        if IsScreenFadedOut() then
            DoScreenFadeIn(500)
        end
        
        if DoesEntityExist(currentVehicle) then
            DeleteEntity(currentVehicle)
            currentVehicle = nil
        end
        
        DeleteWarZone()
        
        ShowGameNotification('❌ Erreur: ' .. tostring(err), 5000, 'error')
        TriggerServerEvent('scharman:server:coursePoursuiteLeft', instanceId)
        
        inGame = false
        instanceId = nil
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ARRÊT JEU
-- ═══════════════════════════════════════════════════════════════

local function StopCoursePoursuiteGame(showVictory)
    if not inGame then return end
    
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    Config.InfoPrint('ARRÊT COURSE POURSUITE V3.5 FINALE')
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    
    -- CRITIQUE: Arrêter inGame EN PREMIER pour stopper tous les threads
    inGame = false
    
    -- Attendre que les threads se terminent
    Wait(100)
    
    -- Reset variables threads
    blockExitThread = nil
    vehicleExitThread = nil
    damageZoneThread = nil
    zoneWaitingThread = nil
    gameEndTime = nil
    gameStartTime = nil
    canExitVehicle = false
    zoneCreatedByMe = false
    zoneCreatedByOpponent = false
    iAmInZone = false
    iAmChasseur = false
    iAmCible = false
    currentBucket = 0
    warningMessageActive = false
    myRole = nil
    opponentId = nil
    
    -- Masquer écrans
    SendNUIMessage({ action = 'hideDeathScreen' })
    SendNUIMessage({ action = 'hideVehicleLock' })
    SendNUIMessage({ action = 'hideCountdown' })
    
    -- Supprimer zone AVANT téléportation (CRITIQUE)
    DeleteWarZone()
    
    local ped = PlayerPedId()
    
    -- Retirer armes
    RemoveAllPedWeapons(ped, true)
    
    -- Téléportation retour
    if Config.CoursePoursuit.ReturnToNormalCoords then
        DoScreenFadeOut(500)
        Wait(500)
        
        local returnCoords = Config.CoursePoursuit.ReturnToNormalCoords
        
        -- Ressusciter si mort AVANT téléportation
        if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
            NetworkResurrectLocalPlayer(returnCoords.x, returnCoords.y, returnCoords.z, returnCoords.w, true, false)
            Wait(500)
        end
        
        -- Reset HP complet
        SetEntityHealth(ped, 200)
        ClearPedTasksImmediately(ped)
        
        -- Téléportation SANS boucle de placement véhicule
        SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, true)
        SetEntityHeading(ped, returnCoords.w)
        
        Config.SuccessPrint('Téléportation retour réussie')
        
        Wait(500)
        
        -- Message victoire/défaite
        if showVictory ~= nil then
            if showVictory then
                ShowGameNotification(Config.CoursePoursuit.Notifications.youWon, 5000, 'success')
            else
                ShowGameNotification(Config.CoursePoursuit.Notifications.youLost, 5000, 'error')
            end
        end
        
        DoScreenFadeIn(500)
    end
    
    -- Supprimer véhicule
    if DoesEntityExist(currentVehicle) then
        DeleteEntity(currentVehicle)
        currentVehicle = nil
    end
    
    instanceId = nil
    
    Config.SuccessPrint('NETTOYAGE TERMINÉ')
end

-- ═══════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS RÉSEAU
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scharman:client:startCoursePoursuit', function(data)
    StartCoursePoursuiteGame(data)
end)

RegisterNetEvent('scharman:client:stopCoursePoursuit', function(showVictory)
    StopCoursePoursuiteGame(showVictory)
end)

RegisterNetEvent('scharman:client:courseNotification', function(message, duration, notifType)
    ShowGameNotification(message, duration or 3000, notifType or 'info')
end)

-- Événement: L'adversaire (CHASSEUR) a créé la zone
RegisterNetEvent('scharman:client:opponentCreatedZone', function(position)
    if not position then
        Config.ErrorPrint('[CIBLE] Position zone invalide reçue')
        return
    end
    
    Config.InfoPrint('[CIBLE] ⚠️ CHASSEUR A CRÉÉ LA ZONE!')
    Config.DebugPrint('[CIBLE] Position: ' .. tostring(position))
    
    warZonePosition = position
    warZoneActive = true
    zoneCreatedByOpponent = true
    
    if not CreateWarZoneVisuals(position) then
        Config.ErrorPrint('[CIBLE] Échec création visuels zone')
        return
    end
    
    StartWarZoneThread()
    
    ShowGameNotification(Config.CoursePoursuit.Notifications.opponentCreatedZone, 5000, 'warning')
    ShowGameNotification(Config.CoursePoursuit.Notifications.joinZoneFirst, 5000, 'info')
end)

-- Événement: La CIBLE a rejoint la zone
RegisterNetEvent('scharman:client:opponentEnteredZone', function()
    Config.InfoPrint('[CHASSEUR] ✅ CIBLE DANS LA ZONE!')
    
    ShowGameNotification(Config.CoursePoursuit.Notifications.cibleInZone, 5000, 'success')
    
    -- Démarrer thread dégâts si pas déjà fait
    if not damageZoneThread and warZoneActive then
        StartDamageZoneThread()
    end
end)

-- Événement: L'adversaire est mort
RegisterNetEvent('scharman:client:opponentDied', function()
    Config.InfoPrint('🏆 ADVERSAIRE MORT - VICTOIRE!')
    
    Wait(2000)
    StopCoursePoursuiteGame(true) -- true = victoire
end)

-- ═══════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════

RegisterCommand('quit_course', function()
    if inGame then
        StopCoursePoursuiteGame()
        TriggerServerEvent('scharman:server:coursePoursuiteLeft', instanceId)
        ShowGameNotification('✅ Vous avez quitté', 3000, 'success')
    else
        ShowGameNotification('❌ Vous n\'êtes pas en partie', 3000, 'error')
    end
end, false)

if Config.Debug then
    RegisterCommand('course_info', function()
        print('═══════════════════════════════════════════════════════════════')
        print('État: ' .. (inGame and 'EN JEU' or 'PAS EN JEU'))
        print('Rôle: ' .. (myRole or 'Aucun'))
        print('Instance: ' .. (instanceId or 'Aucune'))
        print('Adversaire: ' .. (opponentId or 'Aucun'))
        print('Véhicule: ' .. (currentVehicle or 'Aucun'))
        print('Bucket: ' .. currentBucket)
        print('Zone active: ' .. (warZoneActive and 'OUI' or 'NON'))
        print('Zone position: ' .. (warZonePosition and tostring(warZonePosition) or 'Aucune'))
        print('Zone créée par moi: ' .. (zoneCreatedByMe and 'OUI' or 'NON'))
        print('Zone créée par adversaire: ' .. (zoneCreatedByOpponent and 'OUI' or 'NON'))
        print('Je suis dans zone: ' .. (iAmInZone and 'OUI' or 'NON'))
        print('Peut sortir véhicule: ' .. (canExitVehicle and 'OUI' or 'NON'))
        print('═══════════════════════════════════════════════════════════════')
    end, false)
end

Config.DebugPrint('client/course_poursuite.lua V3.5 FINALE chargé')

-- ═══════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS ROUNDS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scharman:client:showRoundVictory', function(data)
    SendNUIMessage({ action = 'showVictoryScreen' })
end)

RegisterNetEvent('scharman:client:showRoundScoreboard', function(data)
    SendNUIMessage({
        action = 'showRoundScoreboard',
        data = data
    })
end)

RegisterNetEvent('scharman:client:hideRoundScoreboard', function()
    SendNUIMessage({ action = 'hideRoundScoreboard' })
end)

RegisterNetEvent('scharman:client:showMatchEnd', function(data)
    SendNUIMessage({
        action = 'showMatchEnd',
        data = data
    })
end)

RegisterNetEvent('scharman:client:stopRound', function()
    -- Arrêter la manche en cours (reset minimal)
    SendNUIMessage({ action = 'hideDeathScreen' })
    SendNUIMessage({ action = 'hideVictoryScreen' })
    
    -- ARRÊTER threads avant suppression
    inGame = false
    Wait(100)
    inGame = true  -- Réactiver pour manche suivante
    
    DeleteWarZone()
    
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)
    
    if DoesEntityExist(currentVehicle) then
        DeleteEntity(currentVehicle)
        currentVehicle = nil
    end
    
    canExitVehicle = false
    warZoneActive = false
    warZonePosition = nil
    zoneCreatedByMe = false
    zoneCreatedByOpponent = false
    iAmInZone = false
    
    Config.InfoPrint('[ROUND] Manche arrêtée - En attente prochaine manche')
end)

RegisterNetEvent('scharman:client:startNextRound', function(data)
    Config.InfoPrint('[ROUND] Démarrage manche ' .. data.round)
    
    local ped = PlayerPedId()
    
    -- Téléporter à la position spawn
    local spawnCoords = iAmChasseur and Config.CoursePoursuit.SpawnCoords.chasseur or Config.CoursePoursuit.SpawnCoords.cible
    
    -- Ressusciter si mort
    if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
        NetworkResurrectLocalPlayer(spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
        Wait(500)
    end
    
    -- Téléporter au spawn
    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(ped, spawnCoords.w)
    SetEntityHealth(ped, Config.CoursePoursuit.PlayerHealth)
    
    Wait(500)
    
    ShowGameNotification('🔄 Manche ' .. data.round .. ' - Score: ' .. data.score.chasseur .. '-' .. data.score.cible, 5000, 'info')
    
    -- RECRÉER VÉHICULE
    Config.InfoPrint('═══ RÉCUPÉRATION VÉHICULE ═══')
    
    local vehicleNetId = nil
    while not vehicleNetId do
        Wait(100)
        vehicleNetId = GetPlayerVehicleNetId(PlayerId())
    end
    
    currentVehicle = NetToVeh(vehicleNetId)
    
    while not DoesEntityExist(currentVehicle) do
        Wait(100)
        currentVehicle = NetToVeh(vehicleNetId)
    end
    
    Config.SuccessPrint('Véhicule récupéré: ' .. currentVehicle)
    
    -- Customiser véhicule
    SetVehicleNumberPlateText(currentVehicle, 'SCHARMAN')
    SetVehicleColours(currentVehicle, iAmChasseur and 27 or 64, iAmChasseur and 27 or 64)
    SetVehicleEngineOn(currentVehicle, true, true, false)
    SetVehicleDirtLevel(currentVehicle, 0.0)
    Config.SuccessPrint('Véhicule personnalisé')
    
    -- Placer joueur dans véhicule
    Config.InfoPrint('═══ PLACEMENT JOUEUR ═══')
    ForcePlayerIntoVehicle(ped, currentVehicle, -1)
    
    Wait(1000)
    
    -- Relancer décompte et tout
    StartCountdown()
    StartBlockExitThread()
    
    if iAmChasseur then
        StartVehicleExitDetectionThread()
    else
        StartZonePresenceCheckThread()
    end
end)

