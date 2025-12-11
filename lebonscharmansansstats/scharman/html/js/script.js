/* ═══════════════════════════════════════════════════════════════
   SCHARMAN V4.0 - SCRIPT NUI
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
    timerRole: ''
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
    timerMessage: null
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
        default:
            showNotification('❌ Mode non reconnu', 2000, 'error');
            break;
    }
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
    
    // Escape key
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && AppState.isOpen) {
            debugLog('ESC pressed', 'info');
            closeInterface();
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
    
    // Validate required elements
    if (!Elements.app || !Elements.closeBtn || !Elements.notificationContainer) {
        debugLog('ERROR: Required elements missing!', 'error');
        return;
    }
    
    // Initialize
    initEventListeners();
    Elements.app.classList.add('hidden');
    
    debugLog('═══════════════════════════════════════', 'info');
    debugLog('Scharman NUI V4.0 - Ready!', 'success');
    debugLog('- Timer system: OK', 'success');
    debugLog('- Countdown: OK', 'success');
    debugLog('- Scoreboard: OK', 'success');
    debugLog('═══════════════════════════════════════', 'info');
}

// Start
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}