-- CLIENT - NUI
local isNuiOpen = false
local disableControlsThread = nil

local function OpenNUI()
    if isNuiOpen then return end
    isNuiOpen = true
    PlaySoundFrontend(-1, Config.NUI.openSound, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    if Config.NUI.enableBlur then TriggerScreenblurFadeIn(Config.NUI.blurIntensity) end
    SendNUIMessage({action = 'open', data = {animationDuration = Config.NUI.openAnimationDuration}})
    SetNuiFocus(true, true)
    
    disableControlsThread = CreateThread(function()
        while isNuiOpen do
            Wait(0)
            for _, control in ipairs(Config.DisabledControls) do
                DisableControlAction(0, control, true)
            end
        end
        disableControlsThread = nil
    end)
end

local function CloseNUI()
    if not isNuiOpen then return end
    isNuiOpen = false
    PlaySoundFrontend(-1, Config.NUI.closeSound, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    if Config.NUI.enableBlur then TriggerScreenblurFadeOut(Config.NUI.blurIntensity) end
    SendNUIMessage({action = 'close', data = {animationDuration = Config.NUI.closeAnimationDuration}})
    SetNuiFocus(false, false)
    TriggerServerEvent('scharman:server:nuiClosed')
end

RegisterNetEvent('scharman:client:openNUI', OpenNUI)
RegisterNetEvent('scharman:client:closeNUI', CloseNUI)
RegisterNUICallback('close', function(data, cb) CloseNUI() cb('ok') end)
RegisterNUICallback('joinCoursePoursuit', function(data, cb)
    CloseNUI()
    TriggerServerEvent('scharman:server:joinCoursePoursuit')
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(0)
        if isNuiOpen and IsControlJustReleased(0, 322) then CloseNUI() else Wait(500) end
    end
end)

Config.DebugPrint('client/nui.lua chargé')
