Config.CoursePoursuit = {}

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION GÉNÉRALE
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.Enabled = true
Config.CoursePoursuit.MaxPlayersPerInstance = 2 -- 1v1 uniquement
Config.CoursePoursuit.MaxInstances = 25
Config.CoursePoursuit.GameDuration = 300 -- 5 minutes (0 = infini)

-- ═══════════════════════════════════════════════════════════════
-- SYSTÈME DE RÔLES
-- ═══════════════════════════════════════════════════════════════

-- CHASSEUR (Joueur 1) : Peut créer la zone immédiatement
-- CIBLE (Joueur 2) : Doit rejoindre la zone avant de descendre

Config.CoursePoursuit.Roles = {
    chasseur = {
        name = "🔫 CHASSEUR",
        description = "Vous poursuivez votre cible !",
        color = {r = 255, g = 0, b = 0}, -- Rouge
        canCreateZone = true,
        mustJoinZone = false
    },
    cible = {
        name = "🎯 CIBLE",
        description = "Vous devez rejoindre la zone !",
        color = {r = 0, g = 100, b = 255}, -- Bleu
        canCreateZone = false,
        mustJoinZone = true
    }
}

-- ═══════════════════════════════════════════════════════════════
-- POSITIONS (⚠️ À MODIFIER)
-- ═══════════════════════════════════════════════════════════════

-- Position spawn CHASSEUR (celui qui crée la zone)
Config.CoursePoursuit.SpawnCoords = {
    chasseur = vector4(-2124.83, -301.81, 13.09, 73.70), -- ⚠️ CHANGE-MOI!
    cible = vector4(-2134.83, -311.81, 13.09, 73.70)     -- ⚠️ CHANGE-MOI!
}

-- Position de retour après partie
Config.CoursePoursuit.ReturnToNormalCoords = vector4(-2148.92, -330.63, 12.99, 141.73) -- ⚠️ CHANGE-MOI!

-- ═══════════════════════════════════════════════════════════════
-- SYSTÈME DE ROUNDS (BEST OF 3)
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.EnableRounds = true           -- Activer système de manches
Config.CoursePoursuit.MaxRounds = 3                 -- Nombre de manches maximum
Config.CoursePoursuit.RoundsToWin = 2               -- Victoires nécessaires pour gagner
Config.CoursePoursuit.TimeBetweenRounds = 7000      -- Temps entre manches (ms)
Config.CoursePoursuit.ShowRoundScoreboard = true    -- Afficher score entre manches
Config.CoursePoursuit.RoundRespawnDelay = 3000      -- Délai respawn après mort (ms)

-- ═══════════════════════════════════════════════════════════════
-- SANTÉ JOUEURS
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.PlayerHealth = 200 -- HP de départ

-- ═══════════════════════════════════════════════════════════════
-- VÉHICULES
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.VehicleModel = 'sultan'
Config.CoursePoursuit.VehicleList = {
    'sultan', 'futo', 'elegy2', 'jester', 'massacro'
}
Config.CoursePoursuit.RandomVehicle = false

-- Personnalisation véhicules
Config.CoursePoursuit.VehicleCustomization = {
    chasseur = {
        primaryColor = {r = 255, g = 0, b = 0},   -- Rouge
        secondaryColor = {r = 0, g = 0, b = 0},   -- Noir
        plate = 'CHASSEUR'
    },
    cible = {
        primaryColor = {r = 0, g = 100, b = 255}, -- Bleu
        secondaryColor = {r = 0, g = 0, b = 0},   -- Noir
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

-- ═══════════════════════════════════════════════════════════════
-- DÉCOMPTE & BLOCAGE VÉHICULE
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.EnableCountdown = true
Config.CoursePoursuit.BlockExitVehicle = true
Config.CoursePoursuit.BlockExitDuration = 30 -- secondes

-- ═══════════════════════════════════════════════════════════════
-- ZONE DE GUERRE (PVP)
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.EnableWarZone = true
Config.CoursePoursuit.WarZoneRadius = 50.0 -- mètres
Config.CoursePoursuit.WarZoneLightHeight = 150.0
Config.CoursePoursuit.WarZoneBlipSprite = 84 -- Crâne
Config.CoursePoursuit.WarZoneBlipColor = 1  -- Rouge

-- Dégâts hors zone
Config.CoursePoursuit.OutOfZoneDamage = 20    -- HP par seconde
Config.CoursePoursuit.DamageInterval = 1000    -- ms entre chaque dégât

-- Couleur de la zone
Config.CoursePoursuit.WarZoneColor = {
    r = 255, g = 0, b = 0, a = 100
}

-- ═══════════════════════════════════════════════════════════════
-- ARMES
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.WeaponHash = 'WEAPON_PISTOL50' -- Cal .50
Config.CoursePoursuit.WeaponAmmo = 250

-- ═══════════════════════════════════════════════════════════════
-- ROUTING BUCKETS
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.BucketRange = {
    min = 1000,
    max = 2000
}
Config.CoursePoursuit.BucketLockdown = 'strict'

-- ═══════════════════════════════════════════════════════════════
-- MESSAGES & NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.Notifications = {
    -- Recherche de joueur
    searching = "🔍 Recherche d'un adversaire...",
    playerFound = "✅ Adversaire trouvé ! Préparation...",
    
    -- Rôles
    roleChasseur = "🔫 Vous êtes le CHASSEUR ! Poursuivez votre cible !",
    roleCible = "🎯 Vous êtes la CIBLE ! Fuyez et rejoignez la zone !",
    
    -- Démarrage
    teleporting = "🚀 Téléportation en cours...",
    starting = "🏁 La partie commence dans 3 secondes...",
    started = "🏁 C'est parti ! Éliminez votre adversaire !",
    
    -- Zone de guerre
    vehicleLocked = "🔒 Véhicule verrouillé pendant 30 secondes",
    canExitVehicle = "✅ Vous pouvez maintenant sortir du véhicule!",
    warZoneCreated = "🔴 ZONE DE GUERRE créée à votre position !",
    weaponGiven = "🔫 Pistolet Cal .50 équipé !",
    
    -- CIBLE spécifique
    mustJoinZone = "⚠️ Vous devez d'abord REJOINDRE LA ZONE pour descendre !",
    joinZoneFirst = "🎯 Rejoignez la zone rouge sur votre carte !",
    zoneJoined = "✅ Zone rejointe ! Vous pouvez descendre !",
    
    -- CHASSEUR spécifique
    waitingCible = "⏳ En attente que la cible rejoigne la zone...",
    cibleInZone = "✅ La cible a rejoint la zone ! Combat !",
    
    -- Adversaire
    opponentCreatedZone = "⚠️ Votre adversaire a créé la zone de guerre !",
    opponentInZone = "✅ Votre adversaire a rejoint la zone !",
    waitingOpponent = "⏳ Attendez que votre adversaire rejoigne la zone...",
    
    -- Dégâts
    outOfZone = "⚠️ HORS ZONE! Revenez ou vous allez mourir!",
    takingDamage = "⚡ DÉGÂTS ZONE: -%d HP",
    
    -- Fin de partie
    playerJoined = "✅ %s a rejoint la partie",
    playerLeft = "❌ %s a quitté la partie",
    youWon = "🏆 VICTOIRE ! Vous avez gagné !",
    youLost = "💀 DÉFAITE ! Vous êtes mort !",
    ended = "🏁 La partie est terminée !",
    
    -- Erreurs
    instanceFull = "❌ Cette instance est pleine",
    noPlayerFound = "❌ Aucun joueur trouvé. Réessayez.",
    errorCreatingInstance = "❌ Impossible de créer une instance"
}

Config.CoursePoursuit.MessageDuration = 3000

-- ═══════════════════════════════════════════════════════════════
-- DEBUG
-- ═══════════════════════════════════════════════════════════════

Config.CoursePoursuit.DebugMode = true
Config.CoursePoursuit.LogEvents = true
