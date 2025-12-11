Config.CoursePoursuit = {}

Config.CoursePoursuit.Enabled = true
Config.CoursePoursuit.MaxPlayersPerInstance = 2
Config.CoursePoursuit.MaxInstances = 25
Config.CoursePoursuit.GameDuration = 300

Config.CoursePoursuit.Roles = {
    cible = {
        name = "🔫 CHASSEUR",
        description = "Vous poursuivez votre cible !",
        color = {r = 255, g = 0, b = 0},
        canCreateZone = true,
        mustJoinZone = false
    },
    chasseur = {
        name = "🎯 CIBLE",
        description = "Vous devez rejoindre la zone !",
        color = {r = 0, g = 100, b = 255},
        canCreateZone = false,
        mustJoinZone = true
    }
}

Config.CoursePoursuit.SpawnCoords = {
    chasseur = vector4(-55.674724, -1110.118652, 26.432250, 70.866142),
    cible = vector4(-44.189010, -1113.652710, 26.432250, 73.700790)
}

Config.CoursePoursuit.ReturnToNormalCoords = vector4(-2660.294434, -765.257142, 5.993408, 269.291352)

Config.CoursePoursuit.EnableRounds = true
Config.CoursePoursuit.MaxRounds = 3
Config.CoursePoursuit.RoundsToWin = 2
Config.CoursePoursuit.TimeBetweenRounds = 3000
Config.CoursePoursuit.ShowRoundScoreboard = true
Config.CoursePoursuit.RoundRespawnDelay = 3000

Config.CoursePoursuit.PlayerHealth = 200
Config.CoursePoursuit.PlayerArmor = 100  -- ✅ NOUVEAU: Armor au début de chaque round

-- ✅ NOUVEAU: Timers pour chasseur et cible
Config.CoursePoursuit.ChasseurZoneTimer = 60  -- 60 secondes (1 minute) pour créer la zone
Config.CoursePoursuit.CibleZoneTimer = 60     -- 60 secondes (1 minute) pour rejoindre la zone

Config.CoursePoursuit.VehicleModel = 'Kuruma2'
Config.CoursePoursuit.VehicleList = {
    'sultan', 'futo', 'elegy2', 'jester', 'massacro'
}
Config.CoursePoursuit.RandomVehicle = false

Config.CoursePoursuit.VehicleCustomization = {
    cible = {
        primaryColor = {r = 255, g = 0, b = 0},
        secondaryColor = {r = 0, g = 0, b = 0},
        plate = 'CHASSEUR'
    },
    chasseur = {
        primaryColor = {r = 0, g = 100, b = 255},
        secondaryColor = {r = 0, g = 0, b = 0},
        plate = 'CIBLE'
    },
    mods = {
        engine = 3,
        brakes = 2,
        transmission = 2,
        suspension = 1,
        turbo = true
    }
}

Config.CoursePoursuit.EnableCountdown = true
Config.CoursePoursuit.BlockExitVehicle = true
Config.CoursePoursuit.BlockExitDuration = 15

Config.CoursePoursuit.EnableWarZone = true
Config.CoursePoursuit.WarZoneRadius = 50.0
Config.CoursePoursuit.WarZoneLightHeight = 150.0
Config.CoursePoursuit.WarZoneBlipSprite = 84
Config.CoursePoursuit.WarZoneBlipColor = 1

Config.CoursePoursuit.OutOfZoneDamage = 20
Config.CoursePoursuit.DamageInterval = 1000

Config.CoursePoursuit.WarZoneColor = {
    r = 255, g = 0, b = 0, a = 100
}

Config.CoursePoursuit.WeaponHash = 'WEAPON_PISTOL50'
Config.CoursePoursuit.WeaponAmmo = 250

Config.CoursePoursuit.BucketRange = {
    min = 1000,
    max = 2000
}
Config.CoursePoursuit.BucketLockdown = 'strict'

Config.CoursePoursuit.Notifications = {
    searching = "🔍 Recherche d'un adversaire...",
    playerFound = "✅ Adversaire trouvé ! Préparation...",
    roleChasseur = "🔫 Vous êtes le cible ! trouvez un drop parfait !",
    roleCible = "🎯 Vous êtes le chasseur !",
    teleporting = "🚀 Téléportation en cours...",
    starting = "🏁 La partie commence dans 3 secondes...",
    started = "🏁 C'est parti ! Éliminez votre adversaire !",
    vehicleLocked = "🔒 Véhicule verrouillé pendant 15 secondes",
    canExitVehicle = "✅ Vous pouvez maintenant sortir du véhicule!",
    warZoneCreated = "🔴 ZONE DE GUERRE créée à votre position !",
    weaponGiven = "🔫 Pistolet Cal .50 équipé !",
    armorGiven = "🛡️ Gilet pare-balles équipé !",  -- ✅ NOUVEAU
    mustJoinZone = "⚠️ Vous devez d'abord REJOINDRE LA ZONE pour descendre !",
    joinZoneFirst = "🎯 Rejoignez la zone rouge sur votre carte !",
    zoneJoined = "✅ Zone rejointe ! Vous pouvez descendre !",
    waitingCible = "⏳ En attente que la cible rejoigne la zone...",
    cibleInZone = "✅ Le chasseur a rejoint la zone ! Combat !",
    opponentCreatedZone = "⚠️ Votre adversaire a créé la zone de guerre !",
    opponentInZone = "✅ Votre adversaire a rejoint la zone !",
    waitingOpponent = "⏳ Attendez que votre adversaire rejoigne la zone...",
    outOfZone = "⚠️ HORS ZONE! Revenez ou vous allez mourir!",
    takingDamage = "⚡ DÉGÂTS ZONE: -%d HP",
    playerJoined = "✅ %s a rejoint la partie",
    playerLeft = "❌ %s a quitté la partie",
    youWon = "🏆 VICTOIRE ! Vous avez gagné !",
    youLost = "💀 DÉFAITE ! Vous êtes mort !",
    ended = "🏁 La partie est terminée !",
    instanceFull = "❌ Cette instance est pleine",
    noPlayerFound = "❌ Aucun joueur trouvé. Réessayez.",
    errorCreatingInstance = "❌ Impossible de créer une instance",
    chasseurTimerWarning = "⏰ CHASSEUR: %d secondes pour créer la zone !",  -- ✅ NOUVEAU
    chasseurTimeout = "⏱️ TEMPS ÉCOULÉ ! La cible n'a pas créé la zone !",  -- ✅ NOUVEAU
    cibleTimerWarning = "⏰ CHASSEUR: %d secondes pour rejoindre la zone !",  -- ✅ NOUVEAU
    cibleTimeout = "⏱️ TEMPS ÉCOULÉ ! La cible n'a pas rejoint la zone !"  -- ✅ NOUVEAU
}

Config.CoursePoursuit.MessageDuration = 3000

Config.CoursePoursuit.DebugMode = true
Config.CoursePoursuit.LogEvents = true
