-- ███████╗ ██████╗██╗  ██╗ █████╗ ██████╗ ███╗   ███╗ █████╗ ███╗   ██╗
-- ██╔════╝██╔════╝██║  ██║██╔══██╗██╔══██╗████╗ ████║██╔══██╗████╗  ██║
-- ███████╗██║     ███████║███████║██████╔╝██╔████╔██║███████║██╔██╗ ██║
-- ╚════██║██║     ██╔══██║██╔══██║██╔══██╗██║╚██╔╝██║██╔══██║██║╚██╗██║
-- ███████║╚██████╗██║  ██║██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║██║ ╚████║
-- ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
-- CLIENT - MODE COURSE POURSUITE V3.9.13 FINAL - TOUS BUGS CORRIGÉS
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
local blockExitTimerThread = nil  -- ✅ V3.9.12: Thread timer séparé
local vehicleExitThread = nil
local damageZoneThread = nil
local warZoneThread = nil
local warningMessageActive = false
local zoneWaitingThread = nil
local vehicleShootBlockThread = nil
local deathInVehicleThread = nil  -- ✅ V3.9.11: Thread mort avant combat

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

-- ═════════════════════════════════════════════════════════════
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
            
            -- ✅ V3.9.13: Protection contre warZonePosition nil
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
-- ✅ V3.9.11: THREAD SURVEILLANCE MORT AVANT COMBAT
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
            
            -- ✅ CHASSEUR: Surveiller jusqu'à création de SA zone
            if iAmChasseur and not zoneCreatedByMe then
                shouldMonitor = true
            end
            
            -- ✅ CIBLE: Surveiller jusqu'à entrée dans la zone adverse
            if iAmCible and not iAmInZone then
                shouldMonitor = true
            end
            
            -- Si on ne doit plus surveiller, arrêter le thread
            if not shouldMonitor then
                Config.InfoPrint('[DEATH] ✅ Conditions combat remplies, fin surveillance pré-combat')
                break
            end
            
            -- Détecter la mort
            if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
                Config.InfoPrint('[DEATH] 💀 MORT AVANT COMBAT! Rôle: ' .. string.upper(myRole))
                Config.InfoPrint('[DEATH] - Zone créée par moi: ' .. tostring(zoneCreatedByMe))
                Config.InfoPrint('[DEATH] - Je suis dans zone: ' .. tostring(iAmInZone))
                
                -- Afficher écran de mort
                SendNUIMessage({ action = 'showDeathScreen' })
                Wait(2000)
                
                -- ✅ CRITIQUE: Signaler au serveur pour déclencher fin de round
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
-- ✅ V3.9.10: THREAD BLOCAGE TIRS EN VÉHICULE
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
-- DÉCOMPTE 3-2-1-GO
-- ═══════════════════════════════════════════════════════════════

local function StartCountdown()
    Config.InfoPrint('⏱️ DÉCOMPTE 3-2-1-GO')
    
    local ped = PlayerPedId()
    
    FreezeEntityPosition(ped, true)
    if currentVehicle and DoesEntityExist(currentVehicle) then
        FreezeEntityPosition(currentVehicle, true)
        SetVehicleEngineOn(currentVehicle, false, true, false)
    end
    Config.DebugPrint('Joueur et véhicule freezés pour décompte')
    
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
        while inGame and warZoneActive do
            Wait(Config.CoursePoursuit.DamageInterval)
            
            -- ✅ V3.9.13: Protection contre warZonePosition nil
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
                            
                            -- ✅ V3.9.13: Vérifier warZonePosition avant utilisation
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
-- ✅ V3.9.12/13: THREAD BLOCAGE SORTIE VÉHICULE (CORRIGÉ)
-- ═══════════════════════════════════════════════════════════════

local function StartBlockExitThread()
    if blockExitThread then return end
    
    Config.InfoPrint('[BLOCK EXIT] Thread blocage sortie démarré')
    
    -- ✅ V3.9.12: Stocker le thread timer dans une variable
    blockExitTimerThread = CreateThread(function()
        Config.InfoPrint('[BLOCK EXIT] ⏰ Thread timer démarré (' .. Config.CoursePoursuit.BlockExitDuration .. 's)')
        
        SendNUIMessage({
            action = 'showVehicleLock',
            data = { duration = Config.CoursePoursuit.BlockExitDuration * 1000 }
        })
        
        Wait(Config.CoursePoursuit.BlockExitDuration * 1000)
        
        -- ✅ V3.9.12: Vérifier si toujours en jeu avant de modifier l'état
        if not inGame then
            Config.InfoPrint('[BLOCK EXIT] ⏰ Timer annulé (plus en jeu)')
            blockExitTimerThread = nil
            return
        end
        
        if iAmChasseur then
            canExitVehicle = true
            Config.SuccessPrint('[BLOCK EXIT] ✅ Sortie véhicule autorisée (CHASSEUR)!')
            ShowGameNotification(Config.CoursePoursuit.Notifications.canExitVehicle, 5000, 'success')
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

-- ✅ V3.9.12: Nouvelle fonction pour arrêter proprement les threads de blocage
local function StopBlockExitThread()
    if blockExitThread then
        blockExitThread = nil
        Config.InfoPrint('[BLOCK EXIT] 🚫 Thread contrôle réinitialisé')
    end
    
    if blockExitTimerThread then
        blockExitTimerThread = nil
        Config.InfoPrint('[BLOCK EXIT] ⏰ Thread timer réinitialisé')
    end
    
    -- Masquer le UI lock si affiché
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
        
        while inGame and iAmCible and not iAmInZone and warZonePosition do
            Wait(500)
            
            -- ✅ V3.9.13: Vérifier warZonePosition avant utilisation
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
-- DÉMARRAGE JEU
-- ═══════════════════════════════════════════════════════════════

local function StartCoursePoursuiteGame(data)
    if inGame then return end
    
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    Config.InfoPrint('DÉMARRAGE COURSE POURSUITE V3.9.13')
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
        local vehicleModel = data.vehicleModel or Config.CoursePoursuit.VehicleModel
        
        if iAmChasseur then
            ShowGameNotification(Config.CoursePoursuit.Notifications.roleChasseur, 5000, 'info')
        else
            ShowGameNotification(Config.CoursePoursuit.Notifications.roleCible, 5000, 'info')
        end
        
        ShowGameNotification(Config.CoursePoursuit.Notifications.teleporting, 2000, 'info')
        
        DoScreenFadeOut(800)
        while not IsScreenFadedOut() do Wait(10) end
        
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
        SetEntityHeading(ped, spawnCoords.w)
        
        currentBucket = data.bucketId or 0
        
        if currentBucket > 0 then
            Config.InfoPrint('Synchronisation bucket ' .. currentBucket)
            Wait(3000)
            Config.SuccessPrint('Synchro terminée')
        else
            Wait(3000)
        end
        
        SetEntityHealth(ped, Config.CoursePoursuit.PlayerHealth)
        Config.SuccessPrint('HP joueur: ' .. Config.CoursePoursuit.PlayerHealth)
        
        Wait(1000)
        
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
        
        Config.InfoPrint('═══ PLACEMENT JOUEUR ═══')
        local placementSuccess = ForcePlayerIntoVehicle(ped, currentVehicle, -1)
        
        if not placementSuccess then
            error('Impossible de placer joueur')
        end
        
        DoScreenFadeIn(500)
        while not IsScreenFadedIn() do Wait(10) end
        
        inGame = true
        gameStartTime = GetGameTimer()
        
        if Config.CoursePoursuit.EnableCountdown then
            StartCountdown()
        end
        
        if Config.CoursePoursuit.GameDuration > 0 then
            gameEndTime = GetGameTimer() + (Config.CoursePoursuit.GameDuration * 1000)
        end
        
        StartBlockExitThread()
        StartVehicleExitDetectionThread()
        StartZonePresenceCheckThread()
        StartDeathInVehicleMonitor()
        StartVehicleShootBlockThread()
        
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
    Config.InfoPrint('ARRÊT COURSE POURSUITE V3.9.13')
    Config.InfoPrint('═══════════════════════════════════════════════════════════════')
    
    inGame = false
    
    Wait(100)
    
    -- ✅ V3.9.12: Arrêter TOUS les threads proprement
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

RegisterNetEvent('scharman:client:startCoursePoursuit', function(data)
    StartCoursePoursuiteGame(data)
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
        print('Thread mort actif: ' .. (deathInVehicleThread and 'OUI' or 'NON'))
        print('─────────────────────────────────────────────────────────────')
        print('Thread blocage contrôle: ' .. (blockExitThread and 'OUI' or 'NON'))
        print('Thread blocage timer: ' .. (blockExitTimerThread and 'OUI' or 'NON'))
        print('═══════════════════════════════════════════════════════════════')
    end, false)
end

Config.DebugPrint('client/course_poursuite.lua V3.9.13 chargé')

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
    
    SendNUIMessage({ action = 'hideDeathScreen' })
    SendNUIMessage({ action = 'hideVictoryScreen' })
    
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
    
    -- ✅ V3.9.12: Arrêter TOUS les threads proprement
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
    SetEntityHealth(ped, Config.CoursePoursuit.PlayerHealth)
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
    
    gameStartTime = GetGameTimer()
    
    StartCountdown()
    StartBlockExitThread()
    
    if iAmChasseur then
        StartVehicleExitDetectionThread()
    else
        StartZonePresenceCheckThread()
    end
    
    -- ✅ V3.9.11: CRITIQUE - Relancer la surveillance des morts pour le nouveau round
    StartDeathInVehicleMonitor()
    
    Config.SuccessPrint('[ROUND] Manche ' .. data.round .. ' lancée!')
end)