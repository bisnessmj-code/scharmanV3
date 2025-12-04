# 🎮 SCHARMAN V3.1.0 - PVP 1v1 CHASSEUR vs CIBLE

Script FiveM de mini-jeux PVP avec système de matchmaking automatique, rôles asymétriques (CHASSEUR vs CIBLE), zone de guerre synchronisée et combat 1v1.

---

## ⚡ NOUVEAUTÉS VERSION 3.1.0

### ✅ Système CHASSEUR vs CIBLE
- **CHASSEUR (Rouge)** : Le premier joueur matchmakté, peut créer la zone immédiatement après 30 secondes
- **CIBLE (Bleu)** : Le deuxième joueur, DOIT rejoindre la zone avant de pouvoir descendre
- **Zone synchronisée** : Seul le CHASSEUR crée la zone, la CIBLE doit la rejoindre
- **Blocage intelligent** : La CIBLE ne peut PAS descendre tant qu'elle n'est pas dans la zone

### 🔧 Corrections Majeures V3.1
- ✅ **FIX**: Retour téléportation après partie fonctionne parfaitement
- ✅ **FIX**: Plus d'erreurs `nil value` dans les logs
- ✅ **FIX**: HP des joueurs reset à 200 avant le début
- ✅ **FIX**: Variables `warZonePosition` protégées contre les `nil`
- ✅ **FIX**: Seul le CHASSEUR peut créer la zone (validé côté serveur)
- ✅ **FIX**: La CIBLE reçoit des messages spécifiques HTML/CSS/JS

### 🎯 Améliorations
- **Messages dédiés** : Notifications différentes pour CHASSEUR et CIBLE
- **Validation serveur** : Protection contre les tricheries (création zone, entrée zone)
- **Gestion propre** : Tous les threads sont correctement arrêtés
- **Reset complet** : Ressuscitation, HP, téléportation, tout est nettoyé

---

## 📥 INSTALLATION

### 1️⃣ Extraire dans `resources/`
```bash
Extraire le ZIP → Renommer en "scharman" → Placer dans resources/
```

### 2️⃣ Configurer les Positions

**Position du PED** → `config/config.lua` ligne 8:
```lua
Config.Ped.coords = vector4(x, y, z, heading)
```

**Positions spawn joueurs** → `config/course_poursuite.lua` lignes 33-36:
```lua
Config.CoursePoursuit.SpawnCoords = {
    chasseur = vector4(x, y, z, heading), -- ⚠️ CHANGE-MOI!
    cible = vector4(x, y, z, heading)     -- ⚠️ CHANGE-MOI!
}
```

**Position retour** → `config/course_poursuite.lua` ligne 39:
```lua
Config.CoursePoursuit.ReturnToNormalCoords = vector4(x, y, z, heading)
```

💡 **Astuce:** Utilise `/scharman_info` en jeu pour copier tes coordonnées !

### 3️⃣ Démarrer
```
ensure scharman
```

---

## 🎯 COMMENT JOUER

### Lancer une Partie PVP
1. Va au PED Scharman
2. Appuie sur **E** pour ouvrir l'interface
3. Clique sur **"Rejoindre le Matchmaking"**
4. Attends qu'un adversaire soit trouvé
5. Tu seras téléporté avec ton adversaire dans des véhicules séparés

### Rôles

#### 🔫 CHASSEUR (Rouge)
- **Objectif** : Poursuivre la cible et créer la zone de guerre
- **Avantage** : Peut créer la zone immédiatement après 30 secondes
- **Véhicule** : Rouge/Noir avec plaque "CHASSEUR"

#### 🎯 CIBLE (Bleu)
- **Objectif** : Fuir et rejoindre la zone créée par le chasseur
- **Contrainte** : DOIT rejoindre la zone avant de pouvoir descendre
- **Véhicule** : Bleu/Noir avec plaque "CIBLE"

### Déroulement de la Partie

1. **Décompte 3-2-1-GO** : Prépare-toi !

2. **Blocage véhicule 30 secondes** : Personne ne peut sortir immédiatement

3. **Création de la zone (CHASSEUR uniquement)** :
   - Après 30 secondes, **seul le CHASSEUR** peut descendre
   - Quand il descend, une **zone de guerre** se crée à sa position
   - La **CIBLE** voit la zone apparaître sur sa carte (blip rouge)

4. **Rejoindre la zone (CIBLE uniquement)** :
   - La **CIBLE** reçoit un message : "⚠️ Vous devez REJOINDRE LA ZONE"
   - La CIBLE **NE PEUT PAS DESCENDRE** tant qu'elle n'est pas dans la zone
   - Une fois dans la zone : "✅ Zone rejointe ! Vous pouvez descendre !"

5. **Combat** :
   - Les **deux joueurs** reçoivent un **Pistolet Cal .50**
   - Affrontez-vous dans la zone de guerre (rayon 50m)
   - **ATTENTION** : Si vous sortez de la zone, vous prenez **-20 HP par seconde** !

6. **Victoire** :
   - Tuez votre adversaire pour gagner
   - Si votre adversaire quitte, vous gagnez automatiquement

---

## 🆘 COMMANDES

```lua
/quit_course          -- Quitter la partie en cours
/course_info          -- [DEBUG] Afficher l'état de la partie
/scharman_info        -- Copier position actuelle (pour config)
```

### Commandes Admin
```lua
/course_instances     -- Lister toutes les instances actives
/course_kick [id]     -- Éjecter un joueur d'une partie
```

---

## ⚙️ CONFIGURATION

### Fichier: `config/course_poursuite.lua`

#### Santé Joueurs
```lua
Config.CoursePoursuit.PlayerHealth = 200 -- HP de départ
```

#### Durée de Partie
```lua
Config.CoursePoursuit.GameDuration = 300 -- 5 minutes (0 = infini)
```

#### Zone de Guerre
```lua
Config.CoursePoursuit.WarZoneRadius = 50.0      -- Rayon en mètres
Config.CoursePoursuit.OutOfZoneDamage = 20      -- HP perdus par seconde hors zone
Config.CoursePoursuit.DamageInterval = 1000     -- Délai entre dégâts (ms)
```

#### Arme Donnée
```lua
Config.CoursePoursuit.WeaponHash = 'WEAPON_PISTOL50' -- Cal .50
Config.CoursePoursuit.WeaponAmmo = 250                 -- Munitions
```

#### Véhicules
```lua
Config.CoursePoursuit.VehicleModel = 'sultan'
Config.CoursePoursuit.RandomVehicle = false -- true = aléatoire
```

#### Routing Buckets
```lua
Config.CoursePoursuit.BucketRange = {
    min = 1000,
    max = 2000
}
```

---

## 🎨 SYSTÈME DE RÔLES

### CHASSEUR (Joueur Rouge)
- **Nom** : 🔫 CHASSEUR
- **Description** : Vous poursuivez votre cible !
- **Couleur véhicule** : Rouge/Noir
- **Plaque** : CHASSEUR
- **Pouvoir** : Peut créer la zone immédiatement
- **Restriction** : Aucune

### CIBLE (Joueur Bleu)
- **Nom** : 🎯 CIBLE
- **Description** : Vous devez rejoindre la zone !
- **Couleur véhicule** : Bleu/Noir
- **Plaque** : CIBLE
- **Pouvoir** : Aucun
- **Restriction** : DOIT rejoindre la zone avant de descendre

---

## 🐛 DÉPANNAGE

### Pas d'adversaire trouvé ?
- Attends qu'un autre joueur rejoigne le matchmaking
- La file d'attente est FIFO (First In First Out)

### Je ne peux pas descendre du véhicule ?
- **CHASSEUR** : Attends 30 secondes après le spawn
- **CIBLE** : Tu DOIS d'abord rejoindre la zone rouge sur ta carte !

### Je suis CIBLE et je vois pas la zone ?
- Vérifie ta carte (M), un blip rouge devrait apparaître
- Utilise `/course_info` pour voir si la zone est active
- Si aucune zone : le CHASSEUR n'est pas encore descendu

### Dégâts ne fonctionnent pas ?
- Assure-toi d'être **hors de la zone** (> 50m du centre)
- Vérifie avec `/course_info` que la zone est active

### Pas téléporté après la partie ?
- **FIXÉ en V3.1** : Le retour fonctionne maintenant
- Si problème persiste : `/quit_course`

### Erreurs dans F8 ?
- **FIXÉ en V3.1** : Plus d'erreurs `nil value`
- Vérifie que tu as la dernière version (3.1.0)

---

## 📊 ARCHITECTURE TECHNIQUE

### Client → Serveur
- `scharman:server:joinCoursePoursuit` → Demander matchmaking
- `scharman:server:coursePoursuiteLeft` → Quitter la partie
- `scharman:server:zoneCreated` → [CHASSEUR] J'ai créé la zone de guerre
- `scharman:server:playerEnteredZone` → [CIBLE] Je suis entré dans la zone
- `scharman:server:playerDied` → Je suis mort

### Serveur → Client
- `scharman:client:startCoursePoursuit` → Lancer la partie (avec rôle)
- `scharman:client:stopCoursePoursuit` → Terminer la partie
- `scharman:client:opponentCreatedZone` → [CIBLE] Le CHASSEUR a créé la zone
- `scharman:client:opponentEnteredZone` → [CHASSEUR] La CIBLE est dans la zone
- `scharman:client:opponentDied` → L'adversaire est mort (victoire)
- `scharman:client:courseNotification` → Notification

---

## 🔐 SÉCURITÉ

- **Routing Buckets** : Isolation complète (strict lockdown)
- **Validation serveur** : 
  - Seul le CHASSEUR peut créer la zone (vérifié côté serveur)
  - Seule la CIBLE peut rejoindre la zone (vérifié côté serveur)
- **Anti-cheat** : Détection des déconnexions et tricheries basiques
- **Population désactivée** : Pas de PNJ/véhicules dans les buckets de jeu

---

## 📝 CHANGELOG

### Version 3.1.0 (27 Novembre 2025)
- ✅ **NOUVEAU** : Système CHASSEUR vs CIBLE avec rôles asymétriques
- ✅ **FIX** : Retour téléportation après partie fonctionne
- ✅ **FIX** : HP des joueurs reset à 200 avant le début
- ✅ **FIX** : Plus d'erreurs `nil value` dans les logs
- ✅ **FIX** : Seul le CHASSEUR peut créer la zone (validé serveur)
- ✅ **FIX** : La CIBLE ne peut descendre QUE dans la zone
- ✅ **NOUVEAU** : Messages HTML/CSS/JS dédiés pour chaque rôle
- 🔧 **MODIFIÉ** : Architecture client-serveur optimisée avec validation
- 🔧 **MODIFIÉ** : Gestion propre des threads et variables
- 🔧 **MODIFIÉ** : Nettoyage complet en fin de partie

### Version 3.0.0 (27 Novembre 2025)
- ✅ **NOUVEAU** : Système matchmaking automatique 1v1
- ✅ **NOUVEAU** : Zone de guerre synchronisée entre joueurs
- ✅ **NOUVEAU** : Détection victoire/défaite automatique
- ✅ **NOUVEAU** : Couleurs véhicules différentes par joueur

---

## 📞 SUPPORT

### En cas de problème :
1. Vérifie la console F8 pour les logs
2. Utilise `/course_info` pour l'état de la partie
3. Vérifie que ESX et oxmysql sont bien démarrés
4. Assure-toi que les positions sont bien configurées
5. Vérifie que tu as bien la version 3.1.0

---

**Version:** 3.1.0 CHASSEUR vs CIBLE  
**Date:** 27 Novembre 2025  
**Auteur:** Scharman Dev Team

**🎉 SYSTÈME CHASSEUR vs CIBLE COMPLET - TOUS LES BUGS FIXÉS !**

---

## 🔑 POINTS CLÉS À RETENIR

### ✅ Ce qui a été FIXÉ en V3.1 :
1. **Retour téléportation** : Fonctionne à 100%
2. **HP reset** : Joueurs à 200 HP au début
3. **Création zone** : SEUL le CHASSEUR peut créer (validé serveur)
4. **Sortie véhicule CIBLE** : Bloquée jusqu'à entrée dans zone
5. **Erreurs `nil`** : Toutes corrigées
6. **Nettoyage** : Threads et variables correctement gérés

### ⚠️ IMPORTANT À CONFIGURER :
1. **Positions spawn** : `chasseur` et `cible` dans `config/course_poursuite.lua`
2. **Position retour** : `ReturnToNormalCoords` dans `config/course_poursuite.lua`
3. **Position PED** : `Config.Ped.coords` dans `config/config.lua`

### 🎮 LOGIQUE DU JEU :
- Le **premier joueur** en attente devient **CHASSEUR**
- Le **deuxième joueur** qui rejoint devient **CIBLE**
- **CHASSEUR** : Peut créer la zone après 30s
- **CIBLE** : Doit rejoindre la zone avant de descendre
