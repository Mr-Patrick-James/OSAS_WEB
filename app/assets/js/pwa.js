// ── Service Worker Registration ───────────────────────────────────────────────
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        const parts = window.location.pathname.split('/').filter(Boolean);
        const appDirs = ['app', 'api', 'includes', 'assets', 'public'];
        const root = (parts.length === 0 || appDirs.includes(parts[0])) ? '' : '/' + parts[0];

        navigator.serviceWorker.register(root + '/service-worker.js', { scope: root + '/' })
            .then(reg => {
                console.log('✅ SW registered, scope:', reg.scope);
                reg.update();

                // Detect new SW waiting — show update toast
                reg.addEventListener('updatefound', () => {
                    const newSW = reg.installing;
                    if (!newSW) return;
                    newSW.addEventListener('statechange', () => {
                        if (newSW.state === 'installed' && navigator.serviceWorker.controller) {
                            showUpdateToast(newSW);
                        }
                    });
                });

                // Listen for messages from SW (Background Sync trigger)
                navigator.serviceWorker.addEventListener('message', async (event) => {
                    if (event.data && event.data.type === 'SYNC_VIOLATIONS') {
                        // runGlobalSync works on any page; violation.js UI refresh
                        // is handled inside runGlobalSync when it's available
                        await runGlobalSync();
                    }
                });
            })
            .catch(err => console.warn('❌ SW registration failed:', err));
    });
}

function showUpdateToast(newSW) {
    // Disabled by request: Remove update available popup
    return;
}

window.applyUpdate = function() {
    // Listen for controller change BEFORE posting the skip message
    // so we never miss the event
    navigator.serviceWorker.addEventListener('controllerchange', () => {
        window.location.reload();
    });

    if (window._pendingSW) {
        window._pendingSW.postMessage({ type: 'SKIP_WAITING' });
    } else {
        // No pending SW tracked — just force a hard reload to pick up new assets
        window.location.reload(true);
    }
};

// ── Global offline sync — works on ANY page, no violation.js required ────────
let _syncInProgress = false;

async function runGlobalSync() {
    if (_syncInProgress || !navigator.onLine) return;
    if (!window.offlineDB) return;

    const queue = await window.offlineDB.getSyncQueue();
    const pending = queue.filter(i => i.status === 'pending');
    if (pending.length === 0) return;

    _syncInProgress = true;
    console.log(`🔄 [global] Syncing ${pending.length} offline violation(s)...`);

    // Resolve API base from current path (same logic as violation.js)
    const parts   = window.location.pathname.split('/').filter(Boolean);
    const appDirs = ['app', 'api', 'includes', 'assets', 'public'];
    const root    = (parts.length === 0 || appDirs.includes(parts[0])) ? '' : '/' + parts[0];
    const apiBase = root + '/api/';

    let synced = 0;
    let failed = 0;

    for (const item of pending) {
        try {
            if (item.action === 'POST_VIOLATION') {
                const formData = new FormData();
                for (const key in item.data) {
                    formData.append(key, item.data[key]);
                }

                const response = await fetch(apiBase + 'violations.php', {
                    method: 'POST',
                    credentials: 'include',
                    body: formData
                });

                const text = await response.text();
                let result;
                try { result = JSON.parse(text); } catch (e) { result = null; }

                if (response.ok && result && result.status === 'success') {
                    await window.offlineDB.removeFromQueue(item.tempId);

                    // Remove the matching TEMP-* entry from the violations cache
                    // so stale pending records don't linger when the page is closed
                    // before _reloadViolationsUI can run.
                    try {
                        const cached = await window.offlineDB.getViolations();
                        const studentId = item.data && item.data.studentId;
                        const cleaned = cached.filter(v => {
                            // Drop TEMP entries that belong to this queued item
                            if (!String(v.id || '').startsWith('TEMP-')) return true;
                            if (studentId && v.studentId !== studentId) return true;
                            return false; // remove this temp entry
                        });
                        if (cleaned.length !== cached.length) {
                            await window.offlineDB.saveViolations(cleaned);
                            console.log(`🧹 [global] Removed stale TEMP violation from IndexedDB cache`);
                        }
                    } catch (cleanErr) {
                        console.warn('⚠️ [global] Could not clean stale TEMP violation from cache:', cleanErr);
                    }

                    synced++;
                    console.log(`✅ [global] Synced item ${item.tempId}`);
                } else {
                    console.warn(`⚠️ [global] Sync failed for ${item.tempId}:`, result?.message || text);
                    failed++;
                }
            }
        } catch (err) {
            console.error(`❌ [global] Sync error for ${item.tempId}:`, err);
            failed++;
        }
    }

    _syncInProgress = false;

    // If violation.js is loaded (violations page), let it refresh the UI
    if (window.syncOfflineActions && synced > 0) {
        // UI already synced above — just trigger a reload of the violations list
        // without re-posting (queue items already removed)
        if (typeof window._reloadViolationsUI === 'function') {
            window._reloadViolationsUI();
        }
    }

    if (window.refreshOfflineBadge) window.refreshOfflineBadge();

    if (synced > 0 && failed === 0) {
        console.log(`✅ [global] All ${synced} violation(s) synced.`);
        if (typeof showNotification === 'function') {
            showNotification(
                `${synced} offline violation${synced > 1 ? 's' : ''} synced successfully.`,
                'success',
                'Sync Complete'
            );
        }
    } else if (synced > 0) {
        console.warn(`⚠️ [global] ${synced} synced, ${failed} failed.`);
        if (typeof showNotification === 'function') {
            showNotification(
                `${synced} synced, ${failed} failed. Check your connection and try again.`,
                'warning',
                'Partial Sync'
            );
        }
    }
}

// Expose globally so violation.js and SW messages can call it
window.runGlobalSync = runGlobalSync;

// ── Register Background Sync when coming back online ─────────────────────────
async function registerBackgroundSync() {
    // Always run the sync immediately — no waiting for SW or SyncManager
    await runGlobalSync();

    // Also register SW background sync as a belt-and-suspenders fallback
    if (!('serviceWorker' in navigator) || !('SyncManager' in window)) return;
    try {
        const reg = await navigator.serviceWorker.ready;
        await reg.sync.register('sync-violations');
        console.log('✅ Background sync tag registered');
    } catch (e) {
        console.warn('Background sync registration failed (non-critical):', e);
    }
}

// ── PWA Install Prompt ────────────────────────────────────────────────────────
let deferredPrompt;

window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    const btn = document.getElementById('installPWA');
    if (btn) btn.style.display = 'block';
});

document.addEventListener('click', async (e) => {
    if (!e.target.closest('#installPWA')) return;
    if (!deferredPrompt) return;
    const btn = document.getElementById('installPWA');
    if (btn) btn.style.display = 'none';
    deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    deferredPrompt = null;
});

window.addEventListener('appinstalled', () => {
    console.log('✅ PWA installed');
    deferredPrompt = null;
    localStorage.setItem('eosas_pwa_installed', '1');
    localStorage.removeItem('eosas_guest_push_prompted');
    localStorage.removeItem('eosas_student_push_prompted');
    localStorage.removeItem('eosas_install_prompted');

    setTimeout(() => {
        if (typeof window.initGuestPush === 'function') window.initGuestPush();
        if (typeof window.initPushNotifications === 'function') window.initPushNotifications();
    }, 500);
});

// ── Online / Offline Status ───────────────────────────────────────────────────
let _offlineTimer = null;

function showNetworkToast(isOnline) {
    if (_offlineTimer) { clearTimeout(_offlineTimer); _offlineTimer = null; }

    let toast = document.getElementById('network-status-bar');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'network-status-bar';
        toast.style.cssText = `
            position:fixed;bottom:72px;left:50%;transform:translateX(-50%) translateY(20px);
            z-index:999999;display:none;align-items:center;gap:10px;
            padding:10px 16px 10px 14px;border-radius:12px;
            font-size:12px;font-weight:600;letter-spacing:0.01em;white-space:nowrap;
            box-shadow:0 4px 24px rgba(0,0,0,0.22);
            opacity:0;transition:opacity 0.25s ease,transform 0.25s ease;
            max-width:calc(100vw - 32px);
        `;
        document.body.appendChild(toast);
    }

    const show = () => {
        toast.style.display = 'flex';
        requestAnimationFrame(() => {
            toast.style.opacity = '1';
            toast.style.transform = 'translateX(-50%) translateY(0)';
        });
    };
    const hide = (delay = 0) => {
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateX(-50%) translateY(20px)';
            setTimeout(() => { toast.style.display = 'none'; }, 280);
        }, delay);
    };

    if (isOnline) {
        toast.style.background = '#064e3b';
        toast.style.color = '#6ee7b7';
        toast.style.border = '1px solid rgba(110,231,183,0.2)';
        toast.innerHTML = `
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/>
                <path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/>
            </svg>
            <span>Back online</span>`;
        show();
        registerBackgroundSync();
        hide(3000);
    } else {
        // 4-second delay to avoid false positives on slow connections
        _offlineTimer = setTimeout(() => {
            if (navigator.onLine) return;
            toast.style.background = '#1c1917';
            toast.style.color = '#fca5a5';
            toast.style.border = '1px solid rgba(252,165,165,0.15)';
            toast.innerHTML = `
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="1" y1="1" x2="23" y2="23"/>
                    <path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"/><path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"/>
                    <path d="M10.71 5.05A16 16 0 0 1 22.56 9"/><path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"/>
                    <path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><circle cx="12" cy="20" r="1" fill="currentColor"/>
                </svg>
                <span>Offline mode &nbsp;·&nbsp; Cached data</span>
                <button onclick="document.getElementById('network-status-bar').style.display='none'" style="
                    background:rgba(255,255,255,0.08);border:none;color:inherit;
                    width:20px;height:20px;border-radius:50%;display:flex;align-items:center;
                    justify-content:center;cursor:pointer;font-size:13px;margin-left:4px;flex-shrink:0;">✕</button>`;
            show();
        }, 4000);
    }
}

window.addEventListener('online',  () => showNetworkToast(true));
window.addEventListener('offline', () => showNetworkToast(false));

window.addEventListener('DOMContentLoaded', () => {
    if (window.refreshOfflineBadge) window.refreshOfflineBadge();
    if (!navigator.onLine) setTimeout(() => showNetworkToast(false), 1000);
    // Warm API cache silently 3s after dashboard loads
    if (navigator.onLine && window.location.pathname.includes('dashboard')) {
        setTimeout(warmAPICache, 3000);
    }

    // Periodic sync check: every 30s when online, check for pending items
    setInterval(async () => {
        if (navigator.onLine && window.offlineDB) {
            const count = await window.offlineDB.getPendingCount();
            if (count > 0) {
                console.log(`⏰ [periodic] Found ${count} pending item(s), triggering sync...`);
                await runGlobalSync();
            }
        }
    }, 30000); // 30 seconds

    // Also run sync immediately on page load if online and pending items exist
    if (navigator.onLine && window.offlineDB) {
        setTimeout(async () => {
            const count = await window.offlineDB.getPendingCount();
            if (count > 0) {
                console.log(`🚀 [startup] Found ${count} pending item(s), syncing now...`);
                await runGlobalSync();
            }
        }, 2000); // 2 seconds after page load
    }
});

// ── Pre-warm API cache ────────────────────────────────────────────────────────
async function warmAPICache() {
    if (!navigator.onLine) return;
    const p = window.location.pathname.split('/').filter(Boolean);
    const d = ['app','api','includes','assets','public'];
    const root = (p.length === 0 || d.includes(p[0])) ? '' : '/' + p[0];
    const api  = root + '/api/';
    const endpoints = [
        api + 'violations.php?limit=all',
        api + 'students.php?action=get&filter=active&page=1&limit=1000',
        api + 'students.php?action=stats',
        api + 'violations.php?action=types',
        api + 'departments.php?action=get&filter=active',
        api + 'sections.php?action=get&filter=active',
        api + 'announcements.php?action=active',
        api + 'dashboard_stats.php'
    ];
    await Promise.allSettled(endpoints.map(url => fetch(url).catch(() => {})));
    console.log('✅ API cache warmed for offline use');
}
window.warmAPICache = warmAPICache;
