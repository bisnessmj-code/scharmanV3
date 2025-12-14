-- ███████╗ ██████╗██╗  ██╗ █████╗ ██████╗ ███╗   ███╗ █████╗ ███╗   ██╗
-- ██╔════╝██╔════╝██║  ██║██╔══██╗██╔══██╗████╗ ████║██╔══██╗████╗  ██║
-- ███████╗██║     ███████║███████║██████╔╝██╔████╔██║███████║██╔██╗ ██║
-- ╚════██║██║     ██╔══██║██╔══██║██╔══██╗██║╚██╔╝██║██╔══██║██║╚██╗██║
-- ███████║╚██████╗██║  ██║██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║██║ ╚████║
-- ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
-- CLIENT - MODE COURSE POURSUITE V4.0.1 - FIX SYNCHRONISATION
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- VARIABLES LOCALES
-- ═══════════════════════════════════════════════════════════════

local inGame = false
local currentVehicle = nil
local instanceId = nil
local currentBucket = 0
local myRole = nil
local opponentId = nil

-- Threads
local blockExitThread = nil
local blockExitTimerThread = nil
local vehicleExitThread = nil
local damageZoneThread = nil
local warZoneThread = nil
local warningMessageActive = false
local zoneWaitingThread = nil
local vehicleShootBlockThread = nil
local deathInVehicleThread = nil

-- ✅ NOUVEAU V4.0: Threads pour les timers
local chasseurTimerThread = nil
local cibleTimerThread = nil

-- Timers
local gameEndTime = nil
local gameStartTime = nil

-- ✅ NOUVEAU V4.0: Timers spécifiques
local chasseurZoneTimeLeft = 0
local cibleZoneTimeLeft = 0
local chasseurTimerActive = false
local cibleTimerActive = false

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

-- ✅ NOUVEAU V4.0.1: État de synchronisation
local isReadyForStart = false

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

local function ResurrectPlayerWithAnimation(ped, coords)
    Config.InfoPrint('[REVIVE] Réanimation du joueur avec animation...')
    
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.w)
    
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w, true, false)
    Wait(500)
    
    local attempts = 0
    while GetEntityHealth(ped) <= 0 and attempts < 3 do
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w, true, false)
        Wait(500)
        attempts = attempts + 1
    end
    
    SetEntityHealth(ped, 200)
    SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
    
    RequestAnimDict("get_up@directional@movement@from_knees@action")
    while not HasAnimDictLoaded("get_up@directional@movement@from_knees@action") do
        Wait(10)
    end
    
    TaskPlayAnim(ped, "get_up@directional@movement@from_knees@action", "getup_l_0", 8.0, -8.0, 1000, 0, 0, false, false, false)
    Wait(1000)
    
    ClearPedTasksImmediately(ped)
    
    Config.SuccessPrint('[REVIVE] Réanimation complète!')
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ NOUVEAU V4.0: GESTION TIMERS CHASSEUR
-- ═══════════════════════════════════════════════════════════════

local function StartChasseurTimer()
    if chasseurTimerThread or not iAmChasseur then return end
    
    Config.InfoPrint('[TIMER CHASSEUR] 🔫 Démarrage timer zone (60s)')
    
    chasseurZoneTimeLeft = Config.CoursePoursuit.ChasseurZoneTimer
    chasseurTimerActive = true
    
    -- Afficher le timer
    SendNUIMessage({
        action = 'showTimer',
        data = {
            role = 'chasseur',
            duration = chasseurZoneTimeLeft,
            message = 'Créez la zone de guerre !'
        }
    })
    
    chasseurTimerThread = CreateThread(function()
        while chasseurTimerActive and chasseurZoneTimeLeft > 0 and not zoneCreatedByMe do
            Wait(1000)
            chasseurZoneTimeLeft = chasseurZoneTimeLeft - 1
            
            -- Mettre à jour le timer UI
            SendNUIMessage({
                action = 'updateTimer',
                data = {
                    timeLeft = chasseurZoneTimeLeft
                }
            })
            
            -- Avertissements
            if chasseurZoneTimeLeft == 30 then
                ShowGameNotification(string.format(Config.CoursePoursuit.Notifications.chasseurTimerWarning, 30), 3000, 'warning')
            elseif chasseurZoneTimeLeft == 10 then
                ShowGameNotification(string.format(Config.CoursePoursuit.Notifications.chasseurTimerWarning, 10), 3000, 'error')
            end
        end
        
        -- Vérifier si timeout
        if chasseurTimerActive and chasseurZoneTimeLeft <= 0 and not zoneCreatedByMe then
            Config.ErrorPrint('[TIMER CHASSEUR] ⏱️ TIMEOUT! Zone non créée')
            ShowGameNotification(Config.CoursePoursuit.Notifications.chasseurTimeout, 5000, 'error')
            
            -- Masquer le timer
            SendNUIMessage({ action = 'hideTimer' })
            
            -- Signaler au serveur
            TriggerServerEvent('scharman:server:chasseurTimeout', instanceId)
        else
            -- Zone créée à temps
            SendNUIMessage({ action = 'hideTimer' })
        end
        
        chasseurTimerThread = nil
        chasseurTimerActive = false
    end)
end

local function StopChasseurTimer()
    if chasseurTimerThread then
        chasseurTimerActive = false
        chasseurTimerThread = nil
        SendNUIMessage({ action = 'hideTimer' })
        Config.InfoPrint('[TIMER CHASSEUR] ⏹️ Timer arrêté')
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ NOUVEAU V4.0: GESTION TIMERS CIBLE
-- ═══════════════════════════════════════════════════════════════

local function StartCibleTimer()
    if cibleTimerThread or not iAmCible then return end
    
    Config.InfoPrint('[TIMER CIBLE] 🎯 Démarrage timer zone (60s)')
    
    cibleZoneTimeLeft = Config.CoursePoursuit.CibleZoneTimer
    cibleTimerActive = true
    
    -- Afficher le timer
    SendNUIMessage({
        action = 'showTimer',
        data = {
            role = 'cible',
            duration = cibleZoneTimeLeft,
            message = 'Rejoignez la zone de guerre !'
        }
    })
    
    cibleTimerThread = CreateThread(function()
        while cibleTimerActive and cibleZoneTimeLeft > 0 and not iAmInZone do
            Wait(1000)
            cibleZoneTimeLeft = cibleZoneTimeLeft - 1
            
            -- Mettre à jour le timer UI
            SendNUIMessage({
                action = 'updateTimer',
                data = {
                    timeLeft = cibleZoneTimeLeft
                }
            })
            
            -- Avertissements
            if cibleZoneTimeLeft == 30 then
                ShowGameNotification(string.format(Config.CoursePoursuit.Notifications.cibleTimerWarning, 30), 3000, 'warning')
            elseif cibleZoneTimeLeft == 10 then
                ShowGameNotification(string.format(Config.CoursePoursuit.Notifications.cibleTimerWarning, 10), 3000, 'error')
            end
        end
        
        -- Vérifier si timeout
        if cibleTimerActive and cibleZoneTimeLeft <= 0 and not iAmInZone then
            Config.ErrorPrint('[TIMER CIBLE] ⏱️ TIMEOUT! Zone non rejointe')
            ShowGameNotification(Config.CoursePoursuit.Notifications.cibleTimeout, 5000, 'error')
            
            -- Masquer le timer
            SendNUIMessage({ action = 'hideTimer' })
            
            -- Signaler au serveur
            TriggerServerEvent('scharman:server:cibleTimeout', instanceId)
        else
            -- Zone rejointe à temps
            SendNUIMessage({ action = 'hideTimer' })
        end
        
        cibleTimerThread = nil
        cibleTimerActive = false
    end)
end

local function StopCibleTimer()
    if cibleTimerThread then
        cibleTimerActive = false
        cibleTimerThread = nil
        SendNUIMessage({ action = 'hideTimer' })
        Config.InfoPrint('[TIMER CIBLE] ⏹️ Timer arrêté')
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
    
    if warZoneBlip then
        RemoveBlip(warZoneBlip)
    end
    
    warZoneBlip = AddBlipForRadius(position.x, position.y, position.z, warZoneRadius)
    SetBlipHighDetail(warZoneBlip, true)
    SetBlipColour(warZoneBlip, Config.CoursePoursuit.WarZoneBlipColor)
    SetBlipAlpha(warZoneBlip, 180)
    
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
            
            if not warZonePosition then
                Wait(100)
                goto continue
            end
            
            local pos = warZonePosition
            
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
    
    -- ✅ V4.0: Arrêter le timer chasseur
    StopChasseurTimer()
    
    if not CreateWarZoneVisuals(position) then
        Config.ErrorPrint('Échec création visuels zone')
        return false
    end
    
    StartWarZoneThread()
    
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
-- THREAD SURVEILLANCE MORT AVANT COMBAT
-- ═══════════════════════════════════════════════════════════════

local function StartDeathInVehicleMonitor()
    if deathInVehicleThread then return end
    
    Config.InfoPrint('[DEATH] 🚨 Thread surveillance mort pré-combat démarré')
    Config.InfoPrint('[DEATH] Mon rôle: ' .. string.upper(myRole or 'INCONNU'))
    
    deathInVehicleThread = CreateThread(function()
        while inGame do
            Wait(500)
            
            local ped = PlayerPedId()
            local shouldMonitor = false
            
            if iAmChasseur and not zoneCreatedByMe then
                shouldMonitor = true
            end
            
            if iAmCible and not iAmInZone then
                shouldMonitor = true
            end
            
            if not shouldMonitor then
                Config.InfoPrint('[DEATH] ✅ Conditions combat remplies, fin surveillance pré-combat')
                break
            end
            
            if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
                Config.InfoPrint('[DEATH] 💀 MORT AVANT COMBAT! Rôle: ' .. string.upper(myRole))
                Config.InfoPrint('[DEATH] - Zone créée par moi: ' .. tostring(zoneCreatedByMe))
                Config.InfoPrint('[DEATH] - Je suis dans zone: ' .. tostring(iAmInZone))
                
                SendNUIMessage({ action = 'showDeathScreen' })
                Wait(2000)
                
                TriggerServerEvent('scharman:server:playerDied', instanceId)
                
                Config.ErrorPrint('[DEATH] Événement mort envoyé au serveur!')
                break
            end
        end
        
        deathInVehicleThread = nil
        Config.DebugPrint('[DEATH] Thread surveillance pré-combat arrêté')
    end)
end

local function StopDeathInVehicleMonitor()
    if deathInVehicleThread then
        deathInVehicleThread = nil
        Config.InfoPrint('[DEATH] Thread surveillance pré-combat réinitialisé')
    end
end

-- ═══════════════════════════════════════════════════════════════
-- THREAD BLOCAGE TIRS EN VÉHICULE
-- ═══════════════════════════════════════════════════════════════

local function StartVehicleShootBlockThread()
    if vehicleShootBlockThread then return end
    
    Config.InfoPrint('[VEHICLE] 🚫 Thread blocage tirs véhicule démarré')
    
    vehicleShootBlockThread = CreateThread(function()
        while inGame do
            Wait(0)
            
            local ped = PlayerPedId()
            
            if IsPedInAnyVehicle(ped, false) then
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 69, true)
                DisableControlAction(0, 70, true)
                DisableControlAction(0, 92, true)
                DisableControlAction(0, 114, true)
                DisableControlAction(0, 331, true)
                DisableControlAction(1, 140, true)
                DisableControlAction(1, 141, true)
                DisableControlAction(1, 142, true)
            end
        end
        
        vehicleShootBlockThread = nil
        Config.InfoPrint('[VEHICLE] 🚫 Thread blocage tirs arrêté')
    end)
end

local function StopVehicleShootBlockThread()
    if vehicleShootBlockThread then
        vehicleShootBlockThread = nil
        Config.InfoPrint('[VEHICLE] 🚫 Thread blocage tirs réinitialisé')
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ NOUVEAU V4.0.1: DÉCOMPTE SYNCHRONISÉ
-- ═══════════════════════════════════════════════════════════════

local function StartSynchronizedCountdown()
    Config.InfoPrint('⏱️ DÉCOMPTE SYNCHRONISÉ 3-2-1-GO')
    
    local ped = PlayerPedId()
    
    -- Freeze pendant le décompte
    FreezeEntityPosition(ped, true)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        FreezeEntityPosition(currentVehicle, true)
        SetVehicleEngineOn(currentVehicle, false, true, false)
    end
    
    SendNUIMessage({ action = 'showCountdown', data = { number = 3 } })
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    Wait(1000)
    
    SendNUIMessage({ action = 'showCountdown', data = { number = 2 } })
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    Wait(1000)
    
    SendNUIMessage({ action = 'showCountdown', data = { number = 1 } })
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
    Wait(1000)
    
    SendNUIMessage({ action = 'showCountdown', data = { number = 'GO!' } })
    PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
    Wait(1000)
    
    -- Défreeze après GO
    FreezeEntityPosition(ped, false)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        FreezeEntityPosition(currentVehicle, false)
        SetVehicleEngineOn(currentVehicle, true, true, false)
    end
    
    SendNUIMessage({ action = 'hideCountdown' })
    
    -- Enregistrer le temps de départ
    gameStartTime = GetGameTimer()
    
    -- Démarrer les threads de jeu
    StartBlockExitThread()
    StartVehicleExitDetectionThread()
    StartZonePresenceCheckThread()
    StartDeathInVehicleMonitor()
    StartVehicleShootBlockThread()
    
    Config.SuccessPrint('✅ Décompte terminé - Partie lancée!')
end

-- ═══════════════════════════════════════════════════════════════
-- THREAD DÉGÂTS ZONE
-- ═══════════════════════════════════════════════════════════════

local function StartDamageZoneThread()
    if damageZoneThread then return end
    
    Config.InfoPrint('[DAMAGE] 🔴 Démarrage thread dégâts')
    
    damageZoneThread = CreateThread(function()
        while inGame and warZoneActive do
            Wait(Config.CoursePoursuit.DamageInterval)
            
            if not warZonePosition then
                Config.DebugPrint('[DAMAGE] warZonePosition nil, attente...')
                Wait(500)
                goto continue
            end
            
            local ped = PlayerPedId()
            
            if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
                Config.InfoPrint('[DAMAGE] 💀 Joueur mort')
                
                SendNUIMessage({ action = 'showDeathScreen' })
                Wait(3000)
                
                TriggerServerEvent('scharman:server:playerDied', instanceId)
                
                break
            end
            
            local playerCoords = GetEntityCoords(ped)
            local distance = #(playerCoords - vector3(warZonePosition.x, warZonePosition.y, warZonePosition.z))
            
            if distance > warZoneRadius then
                local currentHealth = GetEntityHealth(ped)
                local newHealth = currentHealth - Config.CoursePoursuit.OutOfZoneDamage
                
                Config.InfoPrint(string.format('[DAMAGE] ⚡ HORS ZONE! Distance: %.1fm | HP: %d → %d', distance, currentHealth, newHealth))
                
                if not warningMessageActive then
                    warningMessageActive = true
                    
                    CreateThread(function()
                        while inGame and warZonePosition and distance > warZoneRadius do
                            ShowGameNotification(Config.CoursePoursuit.Notifications.outOfZone, 1500, 'warning')
                            Wait(2000)
                            
                            if not warZonePosition then break end
                            
                            local newCoords = GetEntityCoords(PlayerPedId())
                            distance = #(newCoords - vector3(warZonePosition.x, warZonePosition.y, warZonePosition.z))
                        end
                        
                        warningMessageActive = false
                        if inGame then
                            ShowGameNotification('✅ Retour dans la zone!', 2000, 'success')
                        end
                    end)
                end
                
                SetEntityHealth(ped, math.max(0, newHealth))
                ShowGameNotification(string.format(Config.CoursePoursuit.Notifications.takingDamage, Config.CoursePoursuit.OutOfZoneDamage), 1500, 'error')
            else
                warningMessageActive = false
            end
            
            ::continue::
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
    
    Config.InfoPrint('[BLOCK EXIT] Thread blocage sortie démarré')
    
    blockExitTimerThread = CreateThread(function()
        Config.InfoPrint('[BLOCK EXIT] ⏰ Thread timer démarré (' .. Config.CoursePoursuit.BlockExitDuration .. 's)')
        
        SendNUIMessage({
            action = 'showVehicleLock',
            data = { duration = Config.CoursePoursuit.BlockExitDuration * 1000 }
        })
        
        Wait(Config.CoursePoursuit.BlockExitDuration * 1000)
        
        if not inGame then
            Config.InfoPrint('[BLOCK EXIT] ⏰ Timer annulé (plus en jeu)')
            blockExitTimerThread = nil
            return
        end
        
        if iAmChasseur then
            canExitVehicle = true
            Config.SuccessPrint('[BLOCK EXIT] ✅ Sortie véhicule autorisée (CHASSEUR)!')
            ShowGameNotification(Config.CoursePoursuit.Notifications.canExitVehicle, 5000, 'success')
            
            -- ✅ V4.0: Démarrer le timer chasseur
            StartChasseurTimer()
        else
            Config.InfoPrint('[BLOCK EXIT] ⏳ CIBLE en attente de la zone...')
            ShowGameNotification(Config.CoursePoursuit.Notifications.mustJoinZone, 5000, 'warning')
        end
        
        SendNUIMessage({ action = 'hideVehicleLock' })
        
        blockExitTimerThread = nil
        Config.DebugPrint('[BLOCK EXIT] ⏰ Thread timer terminé')
    end)
    
    blockExitThread = CreateThread(function()
        Config.DebugPrint('[BLOCK EXIT] 🚫 Thread contrôle démarré')
        
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
        Config.DebugPrint('[BLOCK EXIT] 🚫 Thread contrôle arrêté (canExitVehicle = true)')
    end)
end

local function StopBlockExitThread()
    if blockExitThread then
        blockExitThread = nil
        Config.InfoPrint('[BLOCK EXIT] 🚫 Thread contrôle réinitialisé')
    end
    
    if blockExitTimerThread then
        blockExitTimerThread = nil
        Config.InfoPrint('[BLOCK EXIT] ⏰ Thread timer réinitialisé')
    end
    
    SendNUIMessage({ action = 'hideVehicleLock' })
end

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
            
            if canExitVehicle and not IsPedInAnyVehicle(ped, false) then
                local coords = GetEntityCoords(ped)
                
                if CreateWarZone(coords) then
                    local weaponHash = GetHashKey(Config.CoursePoursuit.WeaponHash)
                    GiveWeaponToPed(ped, weaponHash, Config.CoursePoursuit.WeaponAmmo, false, true)
                    SetCurrentPedWeapon(ped, weaponHash, true)
                    
                    ShowGameNotification(Config.CoursePoursuit.Notifications.weaponGiven, 3000, 'success')
                    ShowGameNotification(Config.CoursePoursuit.Notifications.waitingCible, 5000, 'info')
                    Config.SuccessPrint('[CHASSEUR] Zone créée & arme donnée')
                    
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
        
        -- ✅ V4.0: Démarrer le timer cible
        StartCibleTimer()
        
        while inGame and iAmCible and not iAmInZone and warZonePosition do
            Wait(500)
            
            if not warZonePosition then
                Config.DebugPrint('[CIBLE] warZonePosition nil, arrêt')
                break
            end
            
            local ped = PlayerPedId()
            local playerCoords = GetEntityCoords(ped)
            local distance = #(playerCoords - vector3(warZonePosition.x, warZonePosition.y, warZonePosition.z))
            
            if distance <= warZoneRadius then
                iAmInZone = true
                canExitVehicle = true
                
                -- ✅ V4.0: Arrêter le timer cible
                StopCibleTimer()
                
                Config.SuccessPrint('[CIBLE] ✅ Je suis dans la zone adverse!')
                
                TriggerServerEvent('scharman:server:playerEnteredZone', instanceId)
                
                ShowGameNotification(Config.CoursePoursuit.Notifications.zoneJoined, 5000, 'success')
                
                local weaponHash = GetHashKey(Config.CoursePoursuit.WeaponHash)
                GiveWeaponToPed(ped, weaponHash, Config.CoursePoursuit.WeaponAmmo, false, true)
                SetCurrentPedWeapon(ped, weaponHash, true)
                ShowGameNotification(Config.CoursePoursuit.Notifications.weaponGiven, 3000, 'success')
                Config.SuccessPrint('[CIBLE] Arme donnée!')
                
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
-- ✅ NOUVEAU V4.0.1: PRÉPARATION JEU (SANS COUNTDOWN)
-- ═══════════════════════════════════════════════════════════════

local function PrepareCoursePoursuiteGame(data)
    if inGame then return end
    
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    Config.InfoPrint('PRÉPARATION COURSE POURSUITE V4.0.1 - SYNCHRONISATION')
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
        
        local spawnCoords = data.spawnCoords
        
        -- Notification de rôle
        if iAmChasseur then
            ShowGameNotification(Config.CoursePoursuit.Notifications.roleChasseur, 5000, 'info')
        else
            ShowGameNotification(Config.CoursePoursuit.Notifications.roleCible, 5000, 'info')
        end
        
        ShowGameNotification('⏳ Préparation de la partie...', 2000, 'info')
        
        -- Fade out
        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do Wait(10) end
        
        -- Téléportation
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
        SetEntityHeading(ped, spawnCoords.w)
        
        currentBucket = data.bucketId or 0
        
        if currentBucket > 0 then
            Config.InfoPrint('Synchronisation bucket ' .. currentBucket)
            Wait(2000)
            Config.SuccessPrint('Synchro terminée')
        else
            Wait(1000)
        end
        
        -- Appliquer HP et ARMOR
        SetEntityHealth(ped, Config.CoursePoursuit.PlayerHealth)
        SetPedArmour(ped, Config.CoursePoursuit.PlayerArmor)
        Config.SuccessPrint('HP joueur: ' .. Config.CoursePoursuit.PlayerHealth)
        Config.SuccessPrint('Armor joueur: ' .. Config.CoursePoursuit.PlayerArmor)
        ShowGameNotification(Config.CoursePoursuit.Notifications.armorGiven, 3000, 'success')
        
        Wait(500)
        
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
        
        -- Placement joueur dans véhicule
        Config.InfoPrint('═══ PLACEMENT JOUEUR ═══')
        local placementSuccess = ForcePlayerIntoVehicle(ped, currentVehicle, -1)
        
        if not placementSuccess then
            error('Impossible de placer joueur')
        end
        
        -- Fade in
        DoScreenFadeIn(500)
        while not IsScreenFadedIn() do Wait(10) end
        
        -- Marquer comme prêt
        inGame = true
        isReadyForStart = true
        
        Config.SuccessPrint('✅ PRÉPARATION TERMINÉE - EN ATTENTE ADVERSAIRE')
        
        -- ✅ NOUVEAU: Signaler au serveur qu'on est prêt
        TriggerServerEvent('scharman:server:playerReady', instanceId)
        
        ShowGameNotification('✅ Prêt! En attente de l\'adversaire...', 3000, 'info')
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
        isReadyForStart = false
    end
end

-- ═══════════════════════════════════════════════════════════════
-- ARRÊT JEU
-- ═══════════════════════════════════════════════════════════════

local function StopCoursePoursuiteGame(showVictory)
    if not inGame then return end
    
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    Config.InfoPrint('ARRÊT COURSE POURSUITE V4.0.1')
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    
    inGame = false
    isReadyForStart = false
    
    Wait(100)
    
    -- ✅ V4.0: Arrêter les timers
    StopChasseurTimer()
    StopCibleTimer()
    
    StopBlockExitThread()
    blockExitThread = nil
    vehicleExitThread = nil
    damageZoneThread = nil
    zoneWaitingThread = nil
    StopVehicleShootBlockThread()
    StopDeathInVehicleMonitor()
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
    
    SendNUIMessage({ action = 'hideDeathScreen' })
    SendNUIMessage({ action = 'hideVehicleLock' })
    SendNUIMessage({ action = 'hideCountdown' })
    SendNUIMessage({ action = 'hideTimer' })
    
    DeleteWarZone()
    
    local ped = PlayerPedId()
    
    RemoveAllPedWeapons(ped, true)
    
    if Config.CoursePoursuit.ReturnToNormalCoords then
        DoScreenFadeOut(500)
        Wait(500)
        
        local returnCoords = Config.CoursePoursuit.ReturnToNormalCoords
        
        if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
            NetworkResurrectLocalPlayer(returnCoords.x, returnCoords.y, returnCoords.z, returnCoords.w, true, false)
            Wait(500)
        end
        
        SetEntityHealth(ped, 200)
        SetPedArmour(ped, 0)
        ClearPedTasksImmediately(ped)
        
        SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, true)
        SetEntityHeading(ped, returnCoords.w)
        
        Config.SuccessPrint('Téléportation retour réussie')
        
        Wait(500)
        
        if showVictory ~= nil then
            if showVictory then
                ShowGameNotification(Config.CoursePoursuit.Notifications.youWon, 5000, 'success')
            else
                ShowGameNotification(Config.CoursePoursuit.Notifications.youLost, 5000, 'error')
            end
        end
        
        DoScreenFadeIn(500)
    end
    
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

-- ✅ NOUVEAU V4.0.1: Événement de préparation (sans countdown)
RegisterNetEvent('scharman:client:prepareCoursePoursuit', function(data)
    PrepareCoursePoursuiteGame(data)
end)

-- ✅ NOUVEAU V4.0.1: Événement de démarrage synchronisé (avec countdown)
RegisterNetEvent('scharman:client:startSynchronizedGame', function()
    if not isReadyForStart then
        Config.ErrorPrint('Reçu startSynchronizedGame mais pas prêt!')
        return
    end
    
    Config.InfoPrint('🚀 DÉMARRAGE SYNCHRONISÉ REÇU!')
    
    if Config.CoursePoursuit.EnableCountdown then
        StartSynchronizedCountdown()
    else
        gameStartTime = GetGameTimer()
        StartBlockExitThread()
        StartVehicleExitDetectionThread()
        StartZonePresenceCheckThread()
        StartDeathInVehicleMonitor()
        StartVehicleShootBlockThread()
    end
end)

RegisterNetEvent('scharman:client:stopCoursePoursuit', function(showVictory)
    StopCoursePoursuiteGame(showVictory)
end)

RegisterNetEvent('scharman:client:courseNotification', function(message, duration, notifType)
    ShowGameNotification(message, duration or 3000, notifType or 'info')
end)

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

RegisterNetEvent('scharman:client:opponentEnteredZone', function()
    Config.InfoPrint('[CHASSEUR] ✅ CIBLE DANS LA ZONE!')
    
    ShowGameNotification(Config.CoursePoursuit.Notifications.cibleInZone, 5000, 'success')
    
    if not damageZoneThread and warZoneActive then
        StartDamageZoneThread()
    end
end)

RegisterNetEvent('scharman:client:opponentDied', function()
    Config.InfoPrint('🏆 ADVERSAIRE MORT - VICTOIRE!')
    
    Wait(2000)
    StopCoursePoursuiteGame(true)
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
        print('Prêt: ' .. (isReadyForStart and 'OUI' or 'NON'))
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
        print('─────────────────────────────────────────────────────────────')
        print('Timer chasseur actif: ' .. (chasseurTimerActive and 'OUI' or 'NON'))
        print('Timer cible actif: ' .. (cibleTimerActive and 'OUI' or 'NON'))
        print('═══════════════════════════════════════════════════════════════')
    end, false)
end

Config.DebugPrint('client/course_poursuite.lua V4.0.1 - FIX SYNCHRONISATION chargé')

-- ═══════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS ROUNDS
-- ═══════════════════════════════════════════════════════════════

RegisterNetEvent('scharman:client:showRoundVictory', function(data)
    SendNUIMessage({ action = 'showVictoryScreen' })
end)

RegisterNetEvent('scharman:client:showRoundScoreboard', function(data)
    local myScore = data.isPlayerA and data.score.playerA or data.score.playerB
    local opponentScore = data.isPlayerA and data.score.playerB or data.score.playerA
    
    local scoreboardData = {
        round = data.round,
        score = {
            chasseur = myScore,
            cible = opponentScore
        },
        timeUntilNext = data.timeUntilNext
    }
    
    SendNUIMessage({
        action = 'showRoundScoreboard',
        data = scoreboardData
    })
end)

RegisterNetEvent('scharman:client:hideRoundScoreboard', function()
    SendNUIMessage({ action = 'hideRoundScoreboard' })
end)

RegisterNetEvent('scharman:client:showMatchEnd', function(data)
    local myScore = data.isPlayerA and data.finalScore.playerA or data.finalScore.playerB
    local opponentScore = data.isPlayerA and data.finalScore.playerB or data.finalScore.playerA
    
    local matchEndData = {
        winner = data.winner,
        finalScore = {
            chasseur = myScore,
            cible = opponentScore
        }
    }
    
    SendNUIMessage({
        action = 'showMatchEnd',
        data = matchEndData
    })
    
    CreateThread(function()
        Wait(3000)
        SendNUIMessage({ action = 'hideMatchEnd' })
        Config.InfoPrint('[MATCH END] Écran masqué automatiquement')
    end)
end)

-- ═══════════════════════════════════════════════════════════════
-- FIX: Arrêt de manche propre avec réanimation
-- ═══════════════════════════════════════════════════════════════
RegisterNetEvent('scharman:client:stopRound', function()
    Config.InfoPrint('[ROUND] ═══ ARRÊT MANCHE ═══')
    
    -- ✅ V4.0: Arrêter les timers
    StopChasseurTimer()
    StopCibleTimer()
    
    SendNUIMessage({ action = 'hideDeathScreen' })
    SendNUIMessage({ action = 'hideVictoryScreen' })
    SendNUIMessage({ action = 'hideTimer' })
    
    local ped = PlayerPedId()
    
    if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
        local spawnCoords = iAmChasseur and Config.CoursePoursuit.SpawnCoords.chasseur or Config.CoursePoursuit.SpawnCoords.cible
        NetworkResurrectLocalPlayer(spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
        Wait(500)
        Config.SuccessPrint('[ROUND] Joueur réanimé!')
    end
    
    RemoveAllPedWeapons(ped, true)
    
    if DoesEntityExist(currentVehicle) then
        DeleteEntity(currentVehicle)
        currentVehicle = nil
    end
    
    DeleteWarZone()
    canExitVehicle = false
    zoneCreatedByMe = false
    zoneCreatedByOpponent = false
    iAmInZone = false
    isReadyForStart = false
    
    StopBlockExitThread()
    StopDeathInVehicleMonitor()
    
    Config.InfoPrint('[ROUND] Manche arrêtée - En attente prochaine manche')
end)

-- ═══════════════════════════════════════════════════════════════
-- FIX: Démarrage prochain round avec nouveau véhicule
-- ═══════════════════════════════════════════════════════════════
RegisterNetEvent('scharman:client:startNextRound', function(data)
    Config.InfoPrint('[ROUND] ═══ DÉMARRAGE MANCHE ' .. data.round .. ' ═══')
    
    if data.role then
        myRole = data.role
        iAmChasseur = (myRole == 'chasseur')
        iAmCible = (myRole == 'cible')
        Config.InfoPrint('[ROUND] 🔄 Mon NOUVEAU rôle: ' .. string.upper(myRole))
        
        if iAmChasseur then
            Config.InfoPrint('[ROUND] → Je suis maintenant CHASSEUR')
        else
            Config.InfoPrint('[ROUND] → Je suis maintenant CIBLE')
        end
    else
        Config.ErrorPrint('[ROUND] ⚠️ Aucun rôle reçu du serveur!')
    end
    
    local ped = PlayerPedId()
    
    local spawnCoords = iAmChasseur and Config.CoursePoursuit.SpawnCoords.chasseur or Config.CoursePoursuit.SpawnCoords.cible
    
    DoScreenFadeOut(300)
    Wait(300)
    
    if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
        ResurrectPlayerWithAnimation(ped, spawnCoords)
    end
    
    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
    SetEntityHeading(ped, spawnCoords.w)
    
    -- ✅ V4.0: Appliquer HP et ARMOR
    SetEntityHealth(ped, Config.CoursePoursuit.PlayerHealth)
    SetPedArmour(ped, Config.CoursePoursuit.PlayerArmor)
    ShowGameNotification(Config.CoursePoursuit.Notifications.armorGiven, 3000, 'success')
    
    ClearPedTasksImmediately(ped)
    
    Wait(500)
    
    local myScore = data.isPlayerA and data.score.playerA or data.score.playerB
    local opponentScore = data.isPlayerA and data.score.playerB or data.score.playerA
    
    ShowGameNotification('🔄 Manche ' .. data.round .. ' - Score: Vous ' .. myScore .. '-' .. opponentScore .. ' Adversaire', 5000, 'info')
    
    Config.InfoPrint('═══ RÉCUPÉRATION NOUVEAU VÉHICULE ═══')
    
    local vehicleNetId = data.vehicleNetId
    if not vehicleNetId then
        Config.ErrorPrint('[ROUND] Pas de vehicleNetId reçu!')
        return
    end
    
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
        Config.ErrorPrint('[ROUND] Échec récupération véhicule!')
        return
    end
    
    local customKey = iAmChasseur and 'chasseur' or 'cible'
    local customization = Config.CoursePoursuit.VehicleCustomization[customKey]
    
    SetVehicleCustomPrimaryColour(currentVehicle, customization.primaryColor.r, customization.primaryColor.g, customization.primaryColor.b)
    SetVehicleCustomSecondaryColour(currentVehicle, customization.secondaryColor.r, customization.secondaryColor.g, customization.secondaryColor.b)
    SetVehicleNumberPlateText(currentVehicle, customization.plate)
    SetVehicleEngineOn(currentVehicle, true, true, false)
    SetVehicleDirtLevel(currentVehicle, 0.0)
    SetVehicleOnGroundProperly(currentVehicle)
    
    Config.SuccessPrint('Véhicule personnalisé')
    
    Config.InfoPrint('═══ PLACEMENT JOUEUR ═══')
    Wait(500)
    
    ForcePlayerIntoVehicle(ped, currentVehicle, -1)
    
    Wait(1000)
    
    DoScreenFadeIn(300)
    
    isReadyForStart = true
    
    -- ✅ NOUVEAU V4.0.1: Signaler qu'on est prêt pour cette manche
    TriggerServerEvent('scharman:server:roundPlayerReady', instanceId, data.round)
    
    ShowGameNotification('✅ Prêt! En attente de l\'adversaire...', 3000, 'info')
end)

-- ✅ NOUVEAU V4.0.1: Démarrage synchronisé de la manche
RegisterNetEvent('scharman:client:startSynchronizedRound', function()
    if not isReadyForStart then
        Config.ErrorPrint('Reçu startSynchronizedRound mais pas prêt!')
        return
    end
    
    Config.InfoPrint('🚀 DÉMARRAGE MANCHE SYNCHRONISÉ!')
    
    StartSynchronizedCountdown()
end)
