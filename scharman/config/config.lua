Config = {}

Config.Debug = true
Config.Locale = 'fr'

-- ⚠️ À MODIFIER: Position du PED
Config.Ped = {
    model = 'a_m_y_business_03',
    coords = vector4(-2148.92, -330.63, 12.99, 141.73), -- ⚠️ CHANGE-MOI!
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    invincible = true,
    freeze = true,
    blockEvents = true
}

Config.Blip = {
    enabled = true,
    sprite = 478,
    display = 4,
    scale = 0.8,
    color = 3,
    name = 'Scharman - Mini Jeux PVP'
}

Config.Marker = {
    enabled = true,
    type = 1,
    size = {x = 1.5, y = 1.5, z = 1.0},
    color = {r = 0, g = 212, b = 255, a = 100},
    bobUpAndDown = true,
    faceCamera = false,
    rotate = false
}

Config.Interaction = {
    distance = 2.5,
    key = 38,
    label = '[E] Ouvrir Scharman'
}

Config.NUI = {
    openSound = 'SELECT',
    closeSound = 'CANCEL',
    openAnimationDuration = 500,
    closeAnimationDuration = 400,
    enableBlur = true,
    blurIntensity = 300
}

Config.DisabledControls = {
    1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37,
    44, 45, 47, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68,
    69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85,
    86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101,
    102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115,
    116, 117, 118, 119, 140, 141, 142, 143, 257, 263, 264, 331
}

function Config.DebugPrint(message)
    if Config.Debug then
        print('^5[DEBUG]^7 ' .. message)
    end
end

function Config.InfoPrint(message)
    print('^6[INFO]^7 ' .. message)
end

function Config.SuccessPrint(message)
    print('^2[SUCCESS]^7 ' .. message)
end

function Config.ErrorPrint(message)
    print('^1[ERROR]^7 ' .. message)
end
