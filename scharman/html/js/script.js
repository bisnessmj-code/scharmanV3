/* ═══════════════════════════════════════════════════════════════
   SCHARMAN V4.0 - SCRIPT INTERFACE PROFESSIONNELLE
   Gestion des onglets, stats, et matchmaking
   ═══════════════════════════════════════════════════════════════ */

const AppState = {
    isOpen: false,
    currentTab: 'lobby',
    myStats: null,
    leaderboard: null
};

const Elements = {
    app: null,
    closeBtn: null,
    tabs: [],
    sections: [],
    modeCards: [],
    notificationContainer: null
};

/* ═══════════════════════════════════════════════════════════════
   UTILITAIRES
   ═══════════════════════════════════════════════════════════════ */

function debugLog(message, type = 'info') {
    console.log(`%c[Scharman] ${message}`, `color: ${type === 'error' ? '#ef4444' : '#2563eb'}`);
}

function post(action, data = {}) {
    fetch(`https://scharman/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(error => debugLog(`Callback ${action} failed: ${error}`, 'error'));
}

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

function escapeHtml(text) {
    const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
    return text.replace(/[&<>"']/g, m => map[m]);
}

/* ═══════════════════════════════════════════════════════════════
   GESTION DES ONGLETS
   ═══════════════════════════════════════════════════════════════ */

function switchTab(tabName) {
    if (AppState.currentTab === tabName) return;
    
    debugLog(`Switching to tab: ${tabName}`);
    AppState.currentTab = tabName;
    
    // Mise à jour des onglets
    Elements.tabs.forEach(tab => {
        const isActive = tab.dataset.tab === tabName;
        tab.classList.toggle('active', isActive);
    });
    
    // Mise à jour des sections
    Elements.sections.forEach(section => {
        const sectionName = section.id.replace('-section', '');
        section.classList.toggle('active', sectionName === tabName);
    });
    
    // Charger les données si nécessaire
    if (tabName === 'my-stats' && !AppState.myStats) {
        loadMyStats();
    } else if (tabName === 'leaderboard' && !AppState.leaderboard) {
        loadLeaderboard();
    }
}

/* ═══════════════════════════════════════════════════════════════
   INTERFACE PRINCIPALE
   ═══════════════════════════════════════════════════════════════ */

function openInterface() {
    if (AppState.isOpen) return;
    
    debugLog('Opening interface');
    AppState.isOpen = true;
    Elements.app.classList.remove('hidden');
    
    // Charger les stats au démarrage
    if (!AppState.myStats) {
        loadMyStats();
    }
}

function closeInterface() {
    if (!AppState.isOpen) return;
    
    debugLog('Closing interface');
    AppState.isOpen = false;
    Elements.app.classList.add('hidden');
    post('close');
}

/* ═══════════════════════════════════════════════════════════════
   NOTIFICATIONS
   ═══════════════════════════════════════════════════════════════ */

function showNotification(message, duration = 3000, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `game-notification ${type}`;
    notification.textContent = message;
    Elements.notificationContainer.appendChild(notification);
    
    setTimeout(() => {
        notification.classList.add('closing');
        setTimeout(() => notification.remove(), 200);
    }, duration);
}

/* ═══════════════════════════════════════════════════════════════
   MATCHMAKING
   ═══════════════════════════════════════════════════════════════ */

function startMatchmaking(mode) {
    debugLog(`Starting matchmaking for mode: ${mode}`);
    
    if (mode === 'course') {
        showNotification('🔍 Recherche d\'un adversaire...', 2000, 'info');
        closeInterface();
        setTimeout(() => post('joinCoursePoursuit', {}), 300);
    } else {
        showNotification('❌ Ce mode n\'est pas encore disponible', 2000, 'warning');
    }
}

/* ═══════════════════════════════════════════════════════════════
   STATISTIQUES PERSONNELLES
   ═══════════════════════════════════════════════════════════════ */

function loadMyStats() {
    debugLog('Loading my stats');
    post('openStats', {});
}

function updateMyStatsDisplay(stats) {
    debugLog('Updating my stats display');
    AppState.myStats = stats;
    
    // Mise à jour des éléments DOM
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
}

/* ═══════════════════════════════════════════════════════════════
   CLASSEMENT GLOBAL
   ═══════════════════════════════════════════════════════════════ */

function loadLeaderboard() {
    debugLog('Loading leaderboard');
    post('getLeaderboard', { limit: 50 });
}

function updateLeaderboardDisplay(leaderboard) {
    debugLog(`Updating leaderboard with ${leaderboard.length} players`);
    AppState.leaderboard = leaderboard;
    
    const tbody = document.getElementById('leaderboard-body');
    if (!tbody) return;
    
    tbody.innerHTML = '';
    
    if (!leaderboard || leaderboard.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 40px; color: var(--text-tertiary);">Aucune donnée disponible</td></tr>';
        return;
    }
    
    leaderboard.forEach(player => {
        const row = document.createElement('tr');
        
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
            <td class="rank">
                <span>${player.rankData.icon}</span>
                <span>${player.rank}</span>
            </td>
        `;
        
        tbody.appendChild(row);
    });
}

/* ═══════════════════════════════════════════════════════════════
   ÉCRANS DE JEU (COUNTDOWN, TIMERS, ETC.)
   ═══════════════════════════════════════════════════════════════ */

// Countdown
function showCountdown(number) {
    const container = document.getElementById('countdown-container');
    const numberEl = container.querySelector('.countdown-number');
    
    container.classList.remove('hidden');
    numberEl.textContent = number;
    numberEl.classList.toggle('go', number === 'GO!');
    
    // Reset animation
    numberEl.style.animation = 'none';
    void numberEl.offsetWidth;
    numberEl.style.animation = '';
}

function hideCountdown() {
    document.getElementById('countdown-container').classList.add('hidden');
}

// Timer
let timerInterval = null;
let timerTimeLeft = 0;
let timerDuration = 0;

function showTimer(data) {
    const container = document.getElementById('timer-container');
    const valueEl = document.getElementById('timer-value');
    const progressEl = document.getElementById('timer-progress-fill');
    
    timerDuration = data.duration;
    timerTimeLeft = data.duration;
    
    container.classList.remove('hidden');
    valueEl.textContent = timerTimeLeft + 's';
    progressEl.style.width = '100%';
    
    if (timerInterval) clearInterval(timerInterval);
    
    timerInterval = setInterval(() => {
        timerTimeLeft--;
        
        if (timerTimeLeft <= 0) {
            hideTimer();
            return;
        }
        
        valueEl.textContent = timerTimeLeft + 's';
        const progress = (timerTimeLeft / timerDuration) * 100;
        progressEl.style.width = progress + '%';
    }, 1000);
}

function hideTimer() {
    if (timerInterval) {
        clearInterval(timerInterval);
        timerInterval = null;
    }
    document.getElementById('timer-container').classList.add('hidden');
}

// Vehicle Lock
let vehicleLockTimer = null;

function showVehicleLock(duration = 30000) {
    const container = document.getElementById('vehicle-lock-container');
    const timerEl = document.getElementById('vehicle-lock-timer');
    const progressEl = document.getElementById('vehicle-lock-progress');
    
    container.classList.remove('hidden');
    progressEl.style.width = '100%';
    
    let timeLeft = duration / 1000;
    timerEl.textContent = `${timeLeft}s`;
    
    const startTime = Date.now();
    
    if (vehicleLockTimer) clearInterval(vehicleLockTimer);
    
    vehicleLockTimer = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const remaining = Math.max(0, duration - elapsed);
        timeLeft = Math.ceil(remaining / 1000);
        
        timerEl.textContent = `${timeLeft}s`;
        const progress = (remaining / duration) * 100;
        progressEl.style.width = `${progress}%`;
        
        if (remaining <= 0) {
            hideVehicleLock();
        }
    }, 100);
}

function hideVehicleLock() {
    if (vehicleLockTimer) {
        clearInterval(vehicleLockTimer);
        vehicleLockTimer = null;
    }
    document.getElementById('vehicle-lock-container').classList.add('hidden');
}

// Death/Victory screens
function showDeathScreen() {
    document.getElementById('death-screen-container').classList.remove('hidden');
}

function hideDeathScreen() {
    document.getElementById('death-screen-container').classList.add('hidden');
}

function showVictoryScreen() {
    document.getElementById('victory-screen-container').classList.remove('hidden');
}

function hideVictoryScreen() {
    document.getElementById('victory-screen-container').classList.add('hidden');
}

// Scoreboard
function showRoundScoreboard(data) {
    const container = document.getElementById('round-scoreboard-container');
    document.getElementById('round-number').textContent = data.round;
    document.getElementById('score-chasseur').textContent = data.score.chasseur;
    document.getElementById('score-cible').textContent = data.score.cible;
    document.getElementById('next-round-number').textContent = data.round + 1;
    
    container.classList.remove('hidden');
    
    let timeLeft = Math.floor(data.timeUntilNext / 1000);
    const timerEl = document.getElementById('next-round-timer');
    timerEl.textContent = timeLeft;
    
    const countdown = setInterval(() => {
        timeLeft--;
        if (timeLeft > 0) {
            timerEl.textContent = timeLeft;
        } else {
            clearInterval(countdown);
        }
    }, 1000);
}

function hideRoundScoreboard() {
    document.getElementById('round-scoreboard-container').classList.add('hidden');
}

// Match end
function showMatchEnd(data) {
    const container = document.getElementById('match-end-container');
    const title = document.getElementById('match-end-title');
    
    if (data.winner === 'me') {
        title.textContent = 'VICTOIRE !';
        title.style.color = 'var(--success)';
    } else {
        title.textContent = 'DÉFAITE';
        title.style.color = 'var(--error)';
    }
    
    document.getElementById('final-score-chasseur').textContent = data.finalScore.chasseur;
    document.getElementById('final-score-cible').textContent = data.finalScore.cible;
    
    container.classList.remove('hidden');
}

function hideMatchEnd() {
    document.getElementById('match-end-container').classList.add('hidden');
}

/* ═══════════════════════════════════════════════════════════════
   EVENT LISTENERS
   ═══════════════════════════════════════════════════════════════ */

function initEventListeners() {
    debugLog('Initializing event listeners');
    
    // Close button
    if (Elements.closeBtn) {
        Elements.closeBtn.addEventListener('click', closeInterface);
    }
    
    // Tabs
    Elements.tabs.forEach(tab => {
        tab.addEventListener('click', () => switchTab(tab.dataset.tab));
    });
    
    // Mode cards
    Elements.modeCards.forEach(card => {
        card.addEventListener('click', () => {
            if (!card.classList.contains('disabled')) {
                const mode = card.dataset.mode;
                startMatchmaking(mode);
            }
        });
    });
    
    // Escape key
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && AppState.isOpen) {
            closeInterface();
        }
    });
    
    // Disable right click
    document.addEventListener('contextmenu', (e) => e.preventDefault());
}

/* ═══════════════════════════════════════════════════════════════
   MESSAGE HANDLER
   ═══════════════════════════════════════════════════════════════ */

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;
    
    debugLog(`Message received: ${data.action}`);
    
    switch (data.action) {
        case 'open':
            openInterface();
            break;
        case 'close':
            closeInterface();
            break;
        case 'showNotification':
            showNotification(data.data.message, data.data.duration, data.data.type);
            break;
        case 'showCountdown':
            showCountdown(data.data.number);
            break;
        case 'hideCountdown':
            hideCountdown();
            break;
        case 'showVehicleLock':
            showVehicleLock(data.data.duration);
            break;
        case 'hideVehicleLock':
            hideVehicleLock();
            break;
        case 'showTimer':
            showTimer(data.data);
            break;
        case 'updateTimer':
            // Timer mise à jour géré par l'interval
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
            if (data.data && data.data.myStats) {
                updateMyStatsDisplay(data.data.myStats);
            }
            if (data.data && data.data.leaderboard) {
                updateLeaderboardDisplay(data.data.leaderboard);
            }
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
    debugLog('═══════════════════════════════════════');
    debugLog('Scharman NUI V4.0 - Professional UI');
    debugLog('═══════════════════════════════════════');
    
    // Cache des éléments DOM
    Elements.app = document.getElementById('app');
    Elements.closeBtn = document.getElementById('closeBtn');
    Elements.tabs = Array.from(document.querySelectorAll('.app-tab'));
    Elements.sections = Array.from(document.querySelectorAll('.content-section'));
    Elements.modeCards = Array.from(document.querySelectorAll('.mode-card, .mode-card-main'));
    Elements.notificationContainer = document.getElementById('notification-container');
    
    // Validation
    if (!Elements.app || !Elements.notificationContainer) {
        debugLog('ERROR: Required elements missing!', 'error');
        return;
    }
    
    // Initialisation
    initEventListeners();
    Elements.app.classList.add('hidden');
    
    debugLog('Scharman NUI V4.0 - Ready!');
}

// Démarrage
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}