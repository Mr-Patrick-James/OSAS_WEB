/**
 * Push: announcements = guest (no login, after install).
 *         violations = student only (after login, scope full).
 */
(function () {
    'use strict';

    const STYLE_ID = 'eosas-push-styles';

    /** True when opened from home-screen installed app (not a browser tab). */
    function isInstalledPWA() {
        if (navigator.standalone === true) return true;
        const modes = ['standalone', 'fullscreen', 'minimal-ui', 'window-controls-overlay'];
        for (let i = 0; i < modes.length; i++) {
            if (window.matchMedia('(display-mode: ' + modes[i] + ')').matches) return true;
        }
        // Some Android PWAs still report "browser" — treat as installed if not in a normal tab
        if (localStorage.getItem('eosas_pwa_installed') === '1'
            && !window.matchMedia('(display-mode: browser)').matches) {
            return true;
        }
        return false;
    }

    /** Request OS permission in the same user gesture (required on mobile). */
    async function requestNotificationPermission() {
        if (!('Notification' in window)) return 'unsupported';
        if (Notification.permission === 'granted') return 'granted';
        if (Notification.permission === 'denied') return 'denied';
        try {
            return await Notification.requestPermission();
        } catch (e) {
            console.warn('requestPermission:', e);
            return Notification.permission;
        }
    }

    async function subscribeAfterPermission(scope) {
        const sub = await getOrCreateSubscription();
        await saveSubscription(sub, scope);
        return true;
    }

    function projectRoot() {
        const p = location.pathname.split('/').filter(Boolean);
        const dirs = ['app', 'api', 'includes', 'assets', 'public'];
        return (!p.length || dirs.includes(p[0])) ? '' : '/' + p[0];
    }

    function apiBase() {
        return projectRoot() + '/api/';
    }

    function isStudentApp() {
        return document.body.dataset.eosasPush === 'student'
            || /user_dashboard\.php/i.test(location.pathname);
    }

    function isGuestApp() {
        return document.body.dataset.eosasPush === 'guest'
            || (!isStudentApp() && (location.pathname === '/' || /index\.php$/i.test(location.pathname)));
    }

    function injectStyles() {
        if (document.getElementById(STYLE_ID)) return;
        const s = document.createElement('style');
        s.id = STYLE_ID;
        s.textContent = `
          #eosas-push-overlay{position:fixed;inset:0;z-index:2147483646;background:rgba(0,0,0,.65);display:flex;align-items:center;justify-content:center;padding:16px}
          #eosas-push-modal{max-width:360px;width:100%;background:#1e293b;color:#fff;border-radius:16px;padding:20px;box-shadow:0 12px 40px rgba(0,0,0,.45)}
          #eosas-push-modal h3{margin:0 0 8px;font-size:18px}
          #eosas-push-modal p{margin:0 0 16px;font-size:14px;line-height:1.45;color:#cbd5e1}
          #eosas-push-modal .eosas-push-btns{display:flex;flex-direction:column;gap:10px}
          #eosas-push-modal button{min-height:48px;font-size:16px;border-radius:10px;border:none;touch-action:manipulation;cursor:pointer}
          #eosas-push-enable{background:#D4AF37;color:#111;font-weight:700}
          #eosas-push-later{background:transparent;color:#94a3b8;border:1px solid #475569}
        `;
        document.head.appendChild(s);
    }

    function toast(msg, ok) {
        const t = document.createElement('div');
        t.style.cssText = 'position:fixed;top:16px;left:50%;transform:translateX(-50%);z-index:2147483647;padding:12px 16px;border-radius:10px;color:#fff;font-size:13px;max-width:90vw;text-align:center;background:' + (ok ? '#16a34a' : '#dc2626');
        t.textContent = msg;
        document.body.appendChild(t);
        setTimeout(() => t.remove(), 5000);
    }

    function b64ToUint8(s) {
        const pad = '='.repeat((4 - (s.length % 4)) % 4);
        const b = (s + pad).replace(/-/g, '+').replace(/_/g, '/');
        const r = atob(b);
        const a = new Uint8Array(r.length);
        for (let i = 0; i < r.length; i++) a[i] = r.charCodeAt(i);
        return a;
    }

    async function getOrCreateSubscription() {
        const vkRes = await fetch(apiBase() + 'push.php?action=vapid-key', { credentials: 'same-origin' });
        const vk = await vkRes.json();
        if (!vkRes.ok || vk.status !== 'success') throw new Error(vk.message || 'Push not configured');

        const reg = await navigator.serviceWorker.ready;
        let sub = await reg.pushManager.getSubscription();
        if (!sub) {
            sub = await reg.pushManager.subscribe({
                userVisibleOnly: true,
                applicationServerKey: b64ToUint8(vk.data.publicKey)
            });
        }
        return sub;
    }

    async function saveSubscription(sub, scope) {
        const payload = Object.assign(sub.toJSON(), { scope });
        const res = await fetch(apiBase() + 'push.php?action=subscribe', {
            method: 'POST',
            credentials: 'same-origin',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (!res.ok || data.status !== 'success') throw new Error(data.message || 'Subscribe failed');
    }

    async function subscribeWithScope(scope) {
        if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
            toast('Use Chrome and install the app for alerts.', false);
            return false;
        }
        const perm = await requestNotificationPermission();
        if (perm !== 'granted') {
            toast('Tap Allow on the next screen, or enable in phone Settings.', false);
            return false;
        }
        return subscribeAfterPermission(scope);
    }

    async function upgradePushToStudent() {
        if (Notification.permission !== 'granted') return false;
        try {
            const reg = await navigator.serviceWorker.ready;
            const sub = await reg.pushManager.getSubscription();
            if (!sub) return subscribeWithScope('full');

            const res = await fetch(apiBase() + 'push.php?action=upgrade', {
                method: 'POST',
                credentials: 'same-origin',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(sub.toJSON())
            });
            const data = await res.json();
            if (res.ok && data.status === 'success') return true;
            return subscribeWithScope('full');
        } catch (e) {
            console.warn('Push upgrade:', e);
            return false;
        }
    }

    function showInstallFirstModal() {
        // Disabled by request: Remove install first popup
        return;
    }

    function showEnableModal() {
        // Show on both installed PWA and regular desktop browsers
        if (document.getElementById('eosas-push-overlay')) return;
        injectStyles();

        const overlay = document.createElement('div');
        overlay.id = 'eosas-push-overlay';
        const modal = document.createElement('div');
        modal.id = 'eosas-push-modal';

        const title = document.createElement('h3');
        title.textContent = '🔔 Stay updated';
        const desc = document.createElement('p');
        const isDesktop = !isInstalledPWA();
        desc.innerHTML = isDesktop
            ? 'Enable <strong>browser notifications</strong> to receive violation alerts and important updates instantly. Click Enable, then <strong>Allow</strong> when your browser asks.'
            : 'Turn on <strong>notifications</strong> to receive campus announcements, violation alerts, and important updates. Tap Enable, then <strong>Allow</strong>.';

        const btns = document.createElement('div');
        btns.className = 'eosas-push-btns';
        const yes = document.createElement('button');
        yes.id = 'eosas-push-enable';
        yes.textContent = 'Enable notifications';
        const no = document.createElement('button');
        no.id = 'eosas-push-later';
        no.textContent = 'Not now';

        const run = async (e) => {
            if (e) { e.preventDefault(); e.stopPropagation(); }
            yes.disabled = true;
            yes.textContent = 'Please wait…';
            try {
                if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
                    // Fallback: try basic Notification API without push subscription
                    const perm = await requestNotificationPermission();
                    if (perm === 'granted') {
                        toast('Browser notifications enabled!', true);
                        overlay.remove();
                    } else {
                        toast('Please allow notifications in your browser settings.', false);
                    }
                    return;
                }
                const perm = await requestNotificationPermission();
                if (perm !== 'granted') {
                    toast('Click Allow on the browser prompt to enable notifications.', false);
                    return;
                }
                await subscribeAfterPermission('full');
                toast('Notifications enabled — you\'ll receive all alerts.', true);
                overlay.remove();
                if (typeof window.showLatestAnnouncementNotifications === 'function') {
                    await window.showLatestAnnouncementNotifications(true);
                }
            } catch (err) {
                toast(err.message || 'Failed', false);
            }
            yes.disabled = false;
            yes.textContent = 'Enable notifications';
        };

        yes.addEventListener('click', run, { passive: false });
        yes.addEventListener('touchend', run, { passive: false });
        no.addEventListener('click', (e) => {
            e.preventDefault();
            overlay.remove();
        });

        btns.append(yes, no);
        modal.append(title, desc, btns);
        overlay.appendChild(modal);
        document.body.appendChild(overlay);
    }

    async function syncGuestSubscription() {
        if (Notification.permission !== 'granted') return;
        try {
            const sub = await getOrCreateSubscription();
            await saveSubscription(sub, 'full');
        } catch (e) {
            console.warn('Guest push sync:', e);
        }
    }

    async function syncStudentSubscription() {
        if (Notification.permission !== 'granted') return;
        await syncGuestSubscription();
        await upgradePushToStudent();
    }

    async function initGuestPush() {
        if (!isGuestApp() || !('Notification' in window)) return;

        if (!isInstalledPWA()) return;

        if (Notification.permission === 'granted') {
            await syncGuestSubscription();
            if (typeof window.startGuestAnnouncementWatcher === 'function') {
                window.startGuestAnnouncementWatcher();
            }
            return;
        }
        setTimeout(() => showEnableModal(), 800);
    }

    async function initStudentPush() {
        if (!isStudentApp() || !('Notification' in window)) return;
        if (!('serviceWorker' in navigator) || !('PushManager' in window)) return;

        const pushPage = new URLSearchParams(location.search).get('push_page');
        if (pushPage && typeof window.loadContent === 'function') {
            setTimeout(() => window.loadContent(pushPage), 800);
        }

        navigator.serviceWorker.addEventListener('message', (e) => {
            if (e.data?.type === 'PUSH_NAVIGATE' && e.data.page && typeof window.loadContent === 'function') {
                window.loadContent(e.data.page);
            }
        });

        if (!isInstalledPWA()) return;

        if (Notification.permission === 'granted') {
            await syncStudentSubscription();
            return;
        }
        setTimeout(() => showEnableModal(), 800);
    }

    function isAdminApp() {
        return /dashboard\.php/i.test(location.pathname) && !isStudentApp();
    }

    /** Returns true if the push prompt was recently dismissed (within 24h) */
    function wasPushRecentlyDismissed() {
        const ts = parseInt(localStorage.getItem('eosas_push_dismissed') || '0');
        return ts && (Date.now() - ts) < 24 * 60 * 60 * 1000;
    }

    async function initAdminPush() {
        if (!isAdminApp() || !('Notification' in window)) return;
        if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
            // No push support — still try basic Notification permission on desktop
            if (Notification.permission === 'default') {
                setTimeout(() => showEnableModal(), 1500);
            }
            return;
        }

        if (Notification.permission === 'granted') {
            // Already granted — sync subscription silently
            try {
                const sub = await getOrCreateSubscription();
                await saveSubscription(sub, 'full');
            } catch (e) {
                console.warn('Admin push sync:', e);
            }
            return;
        }

        // Not yet granted — show prompt every time (desktop or PWA)
        if (Notification.permission !== 'denied') {
            setTimeout(() => showEnableModal(), 1500);
        }
    }

    function maybePromptForPush() {
        if (isStudentApp()) initStudentPush();
        else if (isAdminApp()) initAdminPush();
        else if (isGuestApp()) initGuestPush();
    }

    window.isInstalledPWA = isInstalledPWA;
    window.subscribeToPush = () => {
        if (!isInstalledPWA()) { showInstallFirstModal(); return Promise.resolve(false); }
        return subscribeWithScope('full');
    };
    window.upgradePushToStudent = upgradePushToStudent;
    window.showPushEnableModal = () => showEnableModal();
    window.initPushNotifications = initStudentPush;
    window.initGuestPush = initGuestPush;

    function boot() {
        maybePromptForPush();
    }

    document.readyState === 'loading' ? document.addEventListener('DOMContentLoaded', boot) : boot();

    window.addEventListener('pageshow', () => { setTimeout(maybePromptForPush, 400); });
    document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') setTimeout(maybePromptForPush, 400);
    });
})();
