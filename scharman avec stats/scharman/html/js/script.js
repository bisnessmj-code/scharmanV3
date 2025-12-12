/* ═══════════════════════════════════════════════════════════════
   SCHARMAN V4.0 - SCRIPT NUI AVEC SYSTÈME DE STATS
   JavaScript optimisé et professionnel
   ═══════════════════════════════════════════════════════════════ */

const AppState = {
    isOpen: false,
    isAnimating: false,
    debugMode: false,
    countdownActive: false,
    vehicleLockActive: false,
    vehicleLockTimer: null,
    timerActive: false,
    timerInterval: null,
    timerDuration: 0,
    timerTimeLeft: 0,
    timerRole: '',
    statsOpen: false,
    myStats: null,
    leaderboard: null,
    currentTab: 'myStats' // 'myStats' ou 'leaderboard'
};

const Elements = {
    app: null,
    closeBtn: null,
    gameCards: [],
    notificationContainer: null,
    countdownContainer: null,
    countdownNumber: null,
    vehicleLockContainer: null,
    vehicleLockTimer: null,
    vehicleLockProgress: null,
    timerContainer: null,
    timerValue: null,
    timerProgressFill: null,
    timerContent: null,
    timerIcon: null,
    timerTitle: null,
    timerMessage: null,
    statsContainer: null,
    statsCloseBtn: null,
    myStatsTab: null,
    leaderboardTab: null,
    myStatsContent: null,
    leaderboardContent: null
};

/* ═══════════════════════════════════════════════════════════════
   UTILITAIRES
   ═══════════════════════════════════════════════════════════════ */

function debugLog(message, type = 'info') {
    if (!AppState.debugMode) return;
    const styles = {
        info: 'color: #00fff7; font-weight: bold;',
        error: 'color: #ff0055; font-weight: bold;',
        success: 'color: #00ff88; font-weight: bold;',
        warning: 'color: #ff6b00; font-weight: bold;'
    };
    console.log(`%c[Scharman V4] ${message}`, styles[type] || styles.info);
}

function post(action, data = {}) {
    fetch(`https://scharman/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(resp => resp.json()).then(() => {
        debugLog(`Callback ${action} OK`, 'success');
    }).catch(error => {
        debugLog(`Callback ${action} FAIL: ${error}`, 'error');
    });
}

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

/* ═══════════════════════════════════════════════════════════════
   NOTIFICATIONS
   ═══════════════════════════════════════════════════════════════ */

function showNotification(message, duration = 3000, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `game-notification ${type}`;
    notification.textContent = message;
    Elements.notificationContainer.appendChild(notification);
    
    debugLog(`Notif: ${message}`, type === 'error' ? 'error' : 'info');
    
    setTimeout(() => {
        notification.classList.add('closing');
        setTimeout(() => {
            if (notification.parentElement) {
                notification.parentElement.removeChild(notification);
            }
        }, 200);
    }, duration);
}

/* ═══════════════════════════════════════════════════════════════
   INTERFACE PRINCIPALE
   ═══════════════════════════════════════════════════════════════ */

function openInterface(animationDuration = 400) {
    if (AppState.isOpen || AppState.isAnimating) return;
    debugLog('Opening interface...', 'info');
    
    AppState.isAnimating = true;
    Elements.app.classList.remove('hidden');
    
    setTimeout(() => {
        AppState.isOpen = true;
        AppState.isAnimating = false;
        debugLog('Interface opened', 'success');
    }, animationDuration);
}

function closeInterface(animationDuration = 300) {
    if (!AppState.isOpen || AppState.isAnimating) return;
    debugLog('Closing interface...', 'info');
    
    AppState.isAnimating = true;
    const tablet = Elements.app.querySelector('.tablet');
    if (tablet) tablet.classList.add('closing');
    
    setTimeout(() => {
        if (tablet) tablet.classList.remove('closing');
        Elements.app.classList.add('hidden');
        AppState.isOpen = false;
        AppState.isAnimating = false;
        debugLog('Interface closed', 'success');
        post('close');
    }, animationDuration);
}

/* ═══════════════════════════════════════════════════════════════
   MATCHMAKING
   ═══════════════════════════════════════════════════════════════ */

function startCoursePoursuiteMode() {
    debugLog('Starting matchmaking...', 'info');
    showNotification('🔍 Recherche adversaire...', 2000, 'info');
    closeInterface();
    setTimeout(() => {
        post('joinCoursePoursuit', {});
    }, 400);
}

function handleCardClick(cardElement, index) {
    debugLog(`Card ${index} clicked`, 'info');
    
    const gameMode = cardElement.getAttribute('data-mode');
    const button = cardElement.querySelector('.btn-primary');
    
    if (button && button.disabled) {
        showNotification('❌ Mode non disponible', 2000, 'warning');
        return;
    }
    
    switch (gameMode) {
        case 'course':
            startCoursePoursuiteMode();
            break;
        case 'stats':
            openStats();
            break;
        default:
            showNotification('❌ Mode non reconnu', 2000, 'error');
            break;
    }
}

/* ═══════════════════════════════════════════════════════════════
   INTERFACE STATISTIQUES
   ═══════════════════════════════════════════════════════════════ */

function openStats() {
    debugLog('Opening stats interface...', 'info');
    closeInterface();
    
    setTimeout(() => {
        post('openStats', {});
    }, 400);
}

function displayStats(data) {
    if (!data) {
        debugLog('No stats data received', 'error');
        return;
    }
    
    AppState.statsOpen = true;
    AppState.myStats = data.myStats;
    AppState.leaderboard = data.leaderboard;
    
    if (Elements.statsContainer) {
        Elements.statsContainer.classList.remove('hidden');
    }
    
    // Afficher l'onglet "Mes Stats" par défaut
    showMyStats();
    
    debugLog('Stats interface displayed', 'success');
}

function closeStats() {
    debugLog('Closing stats interface...', 'info');
    
    AppState.statsOpen = false;
    
    if (Elements.statsContainer) {
        Elements.statsContainer.classList.add('hidden');
    }
    
    post('closeStats');
}

function showMyStats() {
    AppState.currentTab = 'myStats';
    
    if (Elements.myStatsTab) Elements.myStatsTab.classList.add('active');
    if (Elements.leaderboardTab) Elements.leaderboardTab.classList.remove('active');
    
    if (Elements.myStatsContent) Elements.myStatsContent.classList.remove('hidden');
    if (Elements.leaderboardContent) Elements.leaderboardContent.classList.add('hidden');
    
    // Remplir les stats personnelles
    if (AppState.myStats) {
        updateMyStatsDisplay(AppState.myStats);
    }
}

function showLeaderboard() {
    AppState.currentTab = 'leaderboard';
    
    if (Elements.myStatsTab) Elements.myStatsTab.classList.remove('active');
    if (Elements.leaderboardTab) Elements.leaderboardTab.classList.add('active');
    
    if (Elements.myStatsContent) Elements.myStatsContent.classList.add('hidden');
    if (Elements.leaderboardContent) Elements.leaderboardContent.classList.remove('hidden');
    
    // Remplir le leaderboard
    if (AppState.leaderboard) {
        updateLeaderboardDisplay(AppState.leaderboard);
    }
}

function updateMyStatsDisplay(stats) {
    // Mise à jour des stats personnelles dans le DOM
    const killsEl = document.getElementById('my-kills');
    const deathsEl = document.getElementById('my-deaths');
    const ratioEl = document.getElementById('my-ratio');
    const winsEl = document.getElementById('my-wins');
    const lossesEl = document.getElementById('my-losses');
    const eloEl = document.getElementById('my-elo');
    const rankEl = document.getElementById('my-rank');
    const rankIconEl = document.getElementById('my-rank-icon');
    
    if (killsEl) killsEl.textContent = formatNumber(stats.kills);
    if (deathsEl) deathsEl.textContent = formatNumber(stats.deaths);
    if (ratioEl) ratioEl.textContent = stats.ratio.toFixed(2);
    if (winsEl) winsEl.textContent = formatNumber(stats.wins);
    if (lossesEl) lossesEl.textContent = formatNumber(stats.losses);
    if (eloEl) eloEl.textContent = formatNumber(stats.elo);
    if (rankEl) rankEl.textContent = stats.rank;
    if (rankIconEl) rankIconEl.textContent = stats.rankData.icon;
    
    // Couleur du rang
    if (rankEl && stats.rankData) {
        rankEl.style.color = `rgb(${stats.rankData.color.r}, ${stats.rankData.color.g}, ${stats.rankData.color.b})`;
    }
    
    debugLog('My stats updated', 'success');
}

function updateLeaderboardDisplay(leaderboard) {
    const leaderboardBody = document.getElementById('leaderboard-body');
    
    if (!leaderboardBody) {
        debugLog('Leaderboard body not found', 'error');
        return;
    }
    
    leaderboardBody.innerHTML = '';
    
    if (!leaderboard || leaderboard.length === 0) {
        leaderboardBody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 20px;">Aucune donnée disponible</td></tr>';
        return;
    }
    
    leaderboard.forEach(player => {
        const row = document.createElement('tr');
        
        // Position
        let positionClass = '';
        if (player.position === 1) positionClass = 'first';
        else if (player.position === 2) positionClass = 'second';
        else if (player.position === 3) positionClass = 'third';
        
        row.innerHTML = `
            <td class="position ${positionClass}">#${player.position}</td>
            <td class="player-name">${escapeHtml(player.name)}</td>
            <td>${formatNumber(player.kills)}</td>
            <td>${formatNumber(player.deaths)}</td>
            <td>${player.ratio.toFixed(2)}</td>
            <td class="elo">${formatNumber(player.elo)}</td>
            <td class="rank" style="color: rgb(${player.rankData.color.r}, ${player.rankData.color.g}, ${player.rankData.color.b})">
                ${player.rankData.icon} ${player.rank}
            </td>
        `;
        
        leaderboardBody.appendChild(row);
    });
    
    debugLog('Leaderboard updated with ' + leaderboard.length + ' players', 'success');
}

function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, m => map[m]);
}

/* ═══════════════════════════════════════════════════════════════
   COUNTDOWN - 3 2 1 GO
   ═══════════════════════════════════════════════════════════════ */

function showCountdown(number) {
    debugLog(`Countdown: ${number}`, 'info');
    
    AppState.countdownActive = true;
    Elements.countdownContainer.classList.remove('hidden');
    Elements.countdownNumber.textContent = number;
    
    if (number === 'GO!') {
        Elements.countdownNumber.classList.add('go');
    } else {
        Elements.countdownNumber.classList.remove('go');
    }
    
    // Reset animation
    Elements.countdownNumber.style.animation = 'none';
    void Elements.countdownNumber.offsetWidth;
    Elements.countdownNumber.style.animation = '';
}

function hideCountdown() {
    debugLog('Hiding countdown', 'info');
    AppState.countdownActive = false;
    Elements.countdownContainer.classList.add('hidden');
    Elements.countdownNumber.classList.remove('go');
}

/* ═══════════════════════════════════════════════════════════════
   VEHICLE LOCK
   ═══════════════════════════════════════════════════════════════ */

function showVehicleLock(duration = 30000) {
    debugLog(`Vehicle lock: ${duration}ms`, 'info');
    
    AppState.vehicleLockActive = true;
    Elements.vehicleLockContainer.classList.remove('hidden');
    Elements.vehicleLockProgress.style.width = '100%';
    
    let timeLeft = duration / 1000;
    Elements.vehicleLockTimer.textContent = `${timeLeft}s`;
    
    const startTime = Date.now();
    
    if (AppState.vehicleLockTimer) {
        clearInterval(AppState.vehicleLockTimer);
    }
    
    AppState.vehicleLockTimer = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const remaining = Math.max(0, duration - elapsed);
        timeLeft = Math.ceil(remaining / 1000);
        
        Elements.vehicleLockTimer.textContent = `${timeLeft}s`;
        const progress = (remaining / duration) * 100;
        Elements.vehicleLockProgress.style.width = `${progress}%`;
        
        if (remaining <= 0) {
            hideVehicleLock();
        }
    }, 100);
}

function hideVehicleLock() {
    debugLog('Hiding vehicle lock', 'info');
    
    if (AppState.vehicleLockTimer) {
        clearInterval(AppState.vehicleLockTimer);
        AppState.vehicleLockTimer = null;
    }
    
    AppState.vehicleLockActive = false;
    Elements.vehicleLockContainer.classList.add('hidden');
}

/* ═══════════════════════════════════════════════════════════════
   TIMER CHASSEUR/CIBLE
   ═══════════════════════════════════════════════════════════════ */

function showTimer(data) {
    debugLog(`Timer ${data.role}: ${data.duration}s`, 'info');
    
    AppState.timerActive = true;
    AppState.timerDuration = data.duration;
    AppState.timerTimeLeft = data.duration;
    AppState.timerRole = data.role;
    
    const container = Elements.timerContainer;
    const content = container.querySelector('.timer-content');
    const icon = container.querySelector('.timer-icon');
    const title = container.querySelector('.timer-title');
    const message = container.querySelector('.timer-message');
    
    // Configuration selon le rôle
    content.classList.remove('chasseur', 'cible');
    
    if (data.role === 'chasseur') {
        content.classList.add('chasseur');
        icon.textContent = '🔫';
        title.textContent = 'TIMER CHASSEUR';
    } else {
        content.classList.add('cible');
        icon.textContent = '🎯';
        title.textContent = 'TIMER CIBLE';
    }
    
    message.textContent = data.message || 'Temps restant...';
    Elements.timerValue.textContent = AppState.timerTimeLeft + 's';
    Elements.timerProgressFill.style.width = '100%';
    Elements.timerValue.classList.remove('warning', 'critical');
    
    container.classList.remove('hidden');
    
    // Démarrer le compte à rebours
    if (AppState.timerInterval) {
        clearInterval(AppState.timerInterval);
    }
    
    AppState.timerInterval = setInterval(() => {
        AppState.timerTimeLeft--;
        
        if (AppState.timerTimeLeft <= 0) {
            hideTimer();
            return;
        }
        
        Elements.timerValue.textContent = AppState.timerTimeLeft + 's';
        
        const progress = (AppState.timerTimeLeft / AppState.timerDuration) * 100;
        Elements.timerProgressFill.style.width = progress + '%';
        
        // Changement de couleur
        Elements.timerValue.classList.remove('warning', 'critical');
        if (AppState.timerTimeLeft <= 10) {
            Elements.timerValue.classList.add('critical');
        } else if (AppState.timerTimeLeft <= 30) {
            Elements.timerValue.classList.add('warning');
        }
    }, 1000);
}

function updateTimer(data) {
    if (!AppState.timerActive) return;
    
    AppState.timerTimeLeft = data.timeLeft;
    Elements.timerValue.textContent = AppState.timerTimeLeft + 's';
    
    const progress = (AppState.timerTimeLeft / AppState.timerDuration) * 100;
    Elements.timerProgressFill.style.width = progress + '%';
    
    Elements.timerValue.classList.remove('warning', 'critical');
    if (AppState.timerTimeLeft <= 10) {
        Elements.timerValue.classList.add('critical');
    } else if (AppState.timerTimeLeft <= 30) {
        Elements.timerValue.classList.add('warning');
    }
}

function hideTimer() {
    debugLog('Hiding timer', 'info');
    
    if (AppState.timerInterval) {
        clearInterval(AppState.timerInterval);
        AppState.timerInterval = null;
    }
    
    AppState.timerActive = false;
    Elements.timerContainer.classList.add('hidden');
}

/* ═══════════════════════════════════════════════════════════════
   ÉCRANS DE FIN
   ═══════════════════════════════════════════════════════════════ */

function showDeathScreen() {
    debugLog('Showing death screen', 'error');
    const container = document.getElementById('death-screen-container');
    if (container) container.classList.remove('hidden');
}

function hideDeathScreen() {
    debugLog('Hiding death screen', 'info');
    const container = document.getElementById('death-screen-container');
    if (container) container.classList.add('hidden');
}

function showVictoryScreen() {
    debugLog('Showing victory screen', 'success');
    const container = document.getElementById('victory-screen-container');
    if (container) container.classList.remove('hidden');
}

function hideVictoryScreen() {
    debugLog('Hiding victory screen', 'info');
    const container = document.getElementById('victory-screen-container');
    if (container) container.classList.add('hidden');
}

/* ═══════════════════════════════════════════════════════════════
   SCOREBOARD
   ═══════════════════════════════════════════════════════════════ */

function showRoundScoreboard(data) {
    debugLog(`Scoreboard: Round ${data.round}`, 'info');
    
    const container = document.getElementById('round-scoreboard-container');
    const roundNumber = document.getElementById('round-number');
    const scoreChasseur = document.getElementById('score-chasseur');
    const scoreCible = document.getElementById('score-cible');
    const nextRoundNumber = document.getElementById('next-round-number');
    const nextRoundTimer = document.getElementById('next-round-timer');
    
    if (!container) return;
    
    roundNumber.textContent = data.round;
    scoreChasseur.textContent = data.score.chasseur;
    scoreCible.textContent = data.score.cible;
    nextRoundNumber.textContent = data.round + 1;
    
    container.classList.remove('hidden');
    
    // Countdown timer
    let timeLeft = Math.floor(data.timeUntilNext / 1000);
    nextRoundTimer.textContent = timeLeft;
    
    const countdown = setInterval(() => {
        timeLeft--;
        if (timeLeft > 0) {
            nextRoundTimer.textContent = timeLeft;
        } else {
            clearInterval(countdown);
        }
    }, 1000);
}

function hideRoundScoreboard() {
    debugLog('Hiding scoreboard', 'info');
    const container = document.getElementById('round-scoreboard-container');
    if (container) container.classList.add('hidden');
}

/* ═══════════════════════════════════════════════════════════════
   MATCH END
   ═══════════════════════════════════════════════════════════════ */

function showMatchEnd(data) {
    debugLog(`Match end: ${data.winner}`, 'success');
    
    const container = document.getElementById('match-end-container');
    const title = document.getElementById('match-end-title');
    const trophy = container.querySelector('.match-end-trophy');
    const finalScoreChasseur = document.getElementById('final-score-chasseur');
    const finalScoreCible = document.getElementById('final-score-cible');
    
    if (!container) return;
    
    if (data.winner === 'me') {
        title.textContent = 'VICTOIRE !';
        title.classList.remove('defeat');
        trophy.textContent = '🏆';
    } else {
        title.textContent = 'DÉFAITE';
        title.classList.add('defeat');
        trophy.textContent = '💀';
    }
    
    finalScoreChasseur.textContent = data.finalScore.chasseur;
    finalScoreCible.textContent = data.finalScore.cible;
    
    container.classList.remove('hidden');
}

function hideMatchEnd() {
    debugLog('Hiding match end', 'info');
    const container = document.getElementById('match-end-container');
    if (container) container.classList.add('hidden');
}

/* ═══════════════════════════════════════════════════════════════
   EVENT LISTENERS
   ═══════════════════════════════════════════════════════════════ */

function initEventListeners() {
    debugLog('Initializing event listeners...', 'info');
    
    // Close button
    if (Elements.closeBtn) {
        Elements.closeBtn.addEventListener('click', () => {
            debugLog('Close button clicked', 'info');
            closeInterface();
        });
    }
    
    // Stats close button
    if (Elements.statsCloseBtn) {
        Elements.statsCloseBtn.addEventListener('click', () => {
            debugLog('Stats close button clicked', 'info');
            closeStats();
        });
    }
    
    // Tabs
    if (Elements.myStatsTab) {
        Elements.myStatsTab.addEventListener('click', () => showMyStats());
    }
    
    if (Elements.leaderboardTab) {
        Elements.leaderboardTab.addEventListener('click', () => showLeaderboard());
    }
    
    // Escape key
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            if (AppState.statsOpen) {
                closeStats();
            } else if (AppState.isOpen) {
                closeInterface();
            }
        }
    });
    
    // Disable right click
    document.addEventListener('contextmenu', (e) => e.preventDefault());
    
    // Game cards
    Elements.gameCards.forEach((card, index) => {
        card.addEventListener('click', () => handleCardClick(card, index));
        
        const button = card.querySelector('.btn-primary');
        if (button) {
            button.addEventListener('click', (e) => {
                e.stopPropagation();
                if (!button.disabled) {
                    handleCardClick(card, index);
                }
            });
        }
    });
    
    debugLog('Event listeners initialized', 'success');
}

/* ═══════════════════════════════════════════════════════════════
   MESSAGE HANDLER
   ═══════════════════════════════════════════════════════════════ */

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    
    debugLog(`Message: ${data.action}`, 'info');
    
    switch (data.action) {
        case 'open':
            openInterface(data.data?.animationDuration || 400);
            break;
        case 'close':
            closeInterface(data.data?.animationDuration || 300);
            break;
        case 'showNotification':
            showNotification(data.data.message, data.data.duration || 3000, data.data.type || 'info');
            break;
        case 'showCountdown':
            showCountdown(data.data.number);
            break;
        case 'hideCountdown':
            hideCountdown();
            break;
        case 'showVehicleLock':
            showVehicleLock(data.data.duration || 30000);
            break;
        case 'hideVehicleLock':
            hideVehicleLock();
            break;
        case 'showTimer':
            showTimer(data.data);
            break;
        case 'updateTimer':
            updateTimer(data.data);
            break;
        case 'hideTimer':
            hideTimer();
            break;
        case 'showDeathScreen':
            showDeathScreen();
            break;
        case 'hideDeathScreen':
            hideDeathScreen();
            break;
        case 'showVictoryScreen':
            showVictoryScreen();
            break;
        case 'hideVictoryScreen':
            hideVictoryScreen();
            break;
        case 'showRoundScoreboard':
            showRoundScoreboard(data.data);
            break;
        case 'hideRoundScoreboard':
            hideRoundScoreboard();
            break;
        case 'showMatchEnd':
            showMatchEnd(data.data);
            break;
        case 'hideMatchEnd':
            hideMatchEnd();
            break;
        case 'openStats':
            displayStats(data.data);
            break;
        case 'closeStats':
            closeStats();
            break;
        case 'updateMyStats':
            updateMyStatsDisplay(data.data);
            break;
        case 'updateLeaderboard':
            updateLeaderboardDisplay(data.data);
            break;
    }
});

/* ═══════════════════════════════════════════════════════════════
   INITIALISATION
   ═══════════════════════════════════════════════════════════════ */

function init() {
    debugLog('═══════════════════════════════════════', 'info');
    debugLog('Scharman NUI V4.0 - Initializing...', 'info');
    debugLog('═══════════════════════════════════════', 'info');
    
    // Cache DOM elements
    Elements.app = document.getElementById('app');
    Elements.closeBtn = document.getElementById('closeBtn');
    Elements.gameCards = Array.from(document.querySelectorAll('.game-card'));
    Elements.notificationContainer = document.getElementById('notification-container');
    Elements.countdownContainer = document.getElementById('countdown-container');
    Elements.countdownNumber = Elements.countdownContainer?.querySelector('.countdown-number');
    Elements.vehicleLockContainer = document.getElementById('vehicle-lock-container');
    Elements.vehicleLockTimer = document.getElementById('vehicle-lock-timer');
    Elements.vehicleLockProgress = document.getElementById('vehicle-lock-progress');
    Elements.timerContainer = document.getElementById('timer-container');
    Elements.timerValue = document.getElementById('timer-value');
    Elements.timerProgressFill = document.getElementById('timer-progress-fill');
    Elements.statsContainer = document.getElementById('stats-container');
    Elements.statsCloseBtn = document.getElementById('stats-close-btn');
    Elements.myStatsTab = document.getElementById('my-stats-tab');
    Elements.leaderboardTab = document.getElementById('leaderboard-tab');
    Elements.myStatsContent = document.getElementById('my-stats-content');
    Elements.leaderboardContent = document.getElementById('leaderboard-content');
    
    // Validate required elements
    if (!Elements.app || !Elements.closeBtn || !Elements.notificationContainer) {
        debugLog('ERROR: Required elements missing!', 'error');
        return;
    }
    
    // Initialize
    initEventListeners();
    Elements.app.classList.add('hidden');
    if (Elements.statsContainer) Elements.statsContainer.classList.add('hidden');
    
    debugLog('═══════════════════════════════════════', 'info');
    debugLog('Scharman NUI V4.0 - Ready!', 'success');
    debugLog('- Timer system: OK', 'success');
    debugLog('- Countdown: OK', 'success');
    debugLog('- Scoreboard: OK', 'success');
    debugLog('- Stats system: OK', 'success');
    debugLog('═══════════════════════════════════════', 'info');
}

// Start
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
