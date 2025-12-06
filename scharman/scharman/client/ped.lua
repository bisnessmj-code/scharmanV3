-- CLIENT - PED
local scharmanPed = nil
local scharmanBlip = nil

local function SpawnScharmanPed()
    local modelHash = GetHashKey(Config.Ped.model)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) do
        Wait(100)
        timeout = timeout + 100
        if timeout >= 10000 then return false end
    end
    
    scharmanPed = CreatePed(4, modelHash, Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z, Config.Ped.coords.w, false, true)
    if not DoesEntityExist(scharmanPed) then return false end
    
    SetEntityInvincible(scharmanPed, Config.Ped.invincible)
    FreezeEntityPosition(scharmanPed, Config.Ped.freeze)
    SetBlockingOfNonTemporaryEvents(scharmanPed, Config.Ped.blockEvents)
    if Config.Ped.scenario then
        TaskStartScenarioInPlace(scharmanPed, Config.Ped.scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(modelHash)
    Config.SuccessPrint('PED spawné')
    return true
end

local function CreateScharmanBlip()
    if not Config.Blip.enabled then return end
    scharmanBlip = AddBlipForCoord(Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z)
    SetBlipSprite(scharmanBlip, Config.Blip.sprite)
    SetBlipDisplay(scharmanBlip, Config.Blip.display)
    SetBlipScale(scharmanBlip, Config.Blip.scale)
    SetBlipColour(scharmanBlip, Config.Blip.color)
    SetBlipAsShortRange(scharmanBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.name)
    EndTextCommandSetBlipName(scharmanBlip)
end

CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local pedCoords = vector3(Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z)
        local distance = #(playerCoords - pedCoords)
        
        if distance < 10.0 then
            sleep = 0
            if Config.Marker.enabled and distance < 5.0 then
                DrawMarker(Config.Marker.type, Config.Ped.coords.x, Config.Ped.coords.y, Config.Ped.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
                    Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
                    Config.Marker.bobUpAndDown, Config.Marker.faceCamera, 2, Config.Marker.rotate, nil, nil, false)
            end
            
            if distance < Config.Interaction.distance then
                ESX.ShowHelpNotification(Config.Interaction.label)
                if IsControlJustReleased(0, Config.Interaction.key) then
                    TriggerEvent('scharman:client:openNUI')
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    SpawnScharmanPed()
    CreateScharmanBlip()
end)

Config.DebugPrint('client/ped.lua chargé')
