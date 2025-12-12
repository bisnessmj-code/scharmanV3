-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION SYSTÈME DE STATISTIQUES & ELO
-- ═══════════════════════════════════════════════════════════════

Config.Stats = {}

-- Active ou désactive le système de stats
Config.Stats.Enabled = true

-- ELO de départ pour les nouveaux joueurs
Config.Stats.StartingElo = 1000

-- K-Factor pour le calcul ELO (plus c'est élevé, plus les changements sont importants)
Config.Stats.KFactor = 32

-- Points ELO gagnés/perdus par kill/mort (si pas de victoire/défaite)
Config.Stats.EloPerKill = 5
Config.Stats.EloPerDeath = -5

-- Système de rangs basé sur l'ELO
Config.Stats.Ranks = {
    {
        name = "Bronze",
        minElo = 0,
        maxElo = 999,
        color = {r = 205, g = 127, b = 50}, -- Couleur bronze
        icon = "🥉",
        description = "Débutant"
    },
    {
        name = "Silver",
        minElo = 1000,
        maxElo = 1299,
        color = {r = 192, g = 192, b = 192}, -- Couleur argent
        icon = "🥈",
        description = "Intermédiaire"
    },
    {
        name = "Gold",
        minElo = 1300,
        maxElo = 1599,
        color = {r = 255, g = 215, b = 0}, -- Couleur or
        icon = "🥇",
        description = "Avancé"
    },
    {
        name = "Platinum",
        minElo = 1600,
        maxElo = 1899,
        color = {r = 229, g = 228, b = 226}, -- Couleur platine
        icon = "💎",
        description = "Expert"
    },
    {
        name = "Diamond",
        minElo = 1900,
        maxElo = 9999,
        color = {r = 185, g = 242, b = 255}, -- Couleur diamant
        icon = "💠",
        description = "Légende"
    }
}

-- Nombre de joueurs affichés dans le leaderboard
Config.Stats.LeaderboardLimit = 50

-- Afficher les notifications de changement d'ELO
Config.Stats.ShowEloNotifications = true

-- Afficher les notifications de changement de rang
Config.Stats.ShowRankUpNotifications = true

-- Sauvegarder les stats en temps réel (true) ou à la fin de la partie (false)
Config.Stats.SaveInRealTime = false

-- Messages de notification
Config.Stats.Notifications = {
    eloGain = "📈 +%d ELO (Total: %d)",
    eloLoss = "📉 %d ELO (Total: %d)",
    rankUp = "🎉 RANK UP! %s → %s",
    rankDown = "⚠️ Rank Down: %s → %s",
    statsUpdated = "✅ Statistiques sauvegardées",
    statsLoadError = "❌ Erreur chargement stats"
}
