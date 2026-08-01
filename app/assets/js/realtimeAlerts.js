/**
 * Real-time in-app alerts (no permission needed).
 * Polls announcements + violations; updates bell badge; shows system notification if already allowed.
 */
(function () {
    'use strict';

    const POLL_MS        = 5000;  // 5s — fast enough to feel real-time
    const ANNOUNCE_MS   = 45000; // 45s for announcements (less critical)
    const STORAGE_KEY    = 'eosas_last_alert_snapshot';

    function apiBase() {
        const p = location.pathname.split('/').filter(Boolean);
        const d = ['app', 'api', 'includes', 'assets', 'public'];
        return ((!p.length || d.includes(p[0])) ? '' : '/' + p[0]) + '/api/';
    }

    function loadSnapshot() {
        try {
            return JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
        } catch (e) {
            return {};
        }
    }

    function saveSnapshot(s) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
    }

    function updateBadge(count) {
        const badge = document.querySelector('.notification-badge');
        if (badge) badge.textContent = count > 9 ? '9+' : String(count);
    }

    function notifyUser(title, body, tag) {
        if (typeof window.showSystemAlert === 'function' && Notification.permission === 'granted') {
            window.showSystemAlert(title, body, tag);
        }
        if (typeof window.showNotification === 'function') {
            window.showNotification(body, 'info', title);
        } else if (typeof window.showInfo === 'function') {
            window.showInfo(title + ': ' + body);
        }
    }

    // Lightweight poll — only fetches latest_id + total_count, no heavy JOINs
    async function pollLatest() {
        const res = await fetch(apiBase() + 'violations.php?action=poll_latest&t=' + Date.now(), {
            credentials: 'same-origin',
            cache: 'no-store'
        });
        if (!res.ok) return null;
        const data = await res.json();
        return data.status === 'success' ? data : null;
    }

    // Full violations fetch — only used when we need badge counts or notification details
    async function fetchViolations() {
        const res = await fetch(apiBase() + 'violations.php', { credentials: 'same-origin' });
        const data = await res.json();
        return data.data || data.violations || [];
    }

    async function fetchAnnouncements() {
        const res = await fetch(apiBase() + 'announcements.php?action=active&limit=50', { credentials: 'same-origin' });
        const data = await res.json();
        const payload = data.data;
        if (Array.isArray(payload)) return payload;
        if (payload && Array.isArray(payload.announcements)) return payload.announcements;
        if (Array.isArray(data.announcements)) return data.announcements;
        return [];
    }

    async function checkForUpdates() {
        if (!navigator.onLine) return;

        try {
            // Use cheap poll_latest for violation change detection
            const pollData = await pollLatest();
            const snap     = loadSnapshot();
            const isFirst  = !snap.initialized;

            const incomingId    = Number(pollData?.latest_id    || 0);
            const incomingCount = Number(pollData?.total_count  ?? -1);

            // On first run, baseline and do a full fetch for badge counts
            if (isFirst) {
                const [violations, announcements] = await Promise.all([
                    fetchViolations(),
                    fetchAnnouncements()
                ]);
                violations.sort((a, b) => Number(b.id) - Number(a.id));
                announcements.sort((a, b) => Number(b.id) - Number(a.id));
                saveSnapshot({
                    initialized:        true,
                    lastViolationId:    incomingId,
                    lastViolationCount: incomingCount,
                    lastAnnouncementId: announcements[0]?.id
                });
                _updateBadgeFromViolations(violations);
                if (typeof window.updateNotificationCount === 'function') {
                    window.updateNotificationCount();
                }
                return;
            }

            let newCount       = 0;
            let somethingChanged = false;

            // Detect new violation (addition)
            const isNewViolation = incomingId > Number(snap.lastViolationId || 0);
            // Detect deleted violation (count dropped)
            const isDeleted = incomingCount >= 0 &&
                              snap.lastViolationCount >= 0 &&
                              incomingCount < snap.lastViolationCount;

            if (isNewViolation || isDeleted) {
                somethingChanged = true;
                snap.lastViolationId    = incomingId;
                snap.lastViolationCount = incomingCount;

                if (isNewViolation && pollData) {
                    // Notify about the new violation
                    const isAdmin = document.getElementById('notifBtn') && !document.getElementById('notificationBtn');
                    const currentName = (document.cookie.split(';').find(c => c.trim().startsWith('full_name=')) || '').split('=').slice(1).join('=').trim();
                    const recorder  = pollData.latest_reported_by || '';
                    const isOwnRecord = isAdmin && currentName && recorder && decodeURIComponent(currentName) === recorder;

                    if (!isOwnRecord) {
                        const violationType = pollData.latest_case_id ? 'Case ' + pollData.latest_case_id : 'Check violations tab';
                        notifyUser(
                            'New Violation Recorded',
                            (recorder ? 'By ' + recorder + ' — ' : '') + violationType,
                            'violation-' + incomingId
                        );
                        newCount++;
                    }
                }

                // Refresh violation-related UI (student violations page, userViolations)
                if (typeof window._reloadViolationsUI === 'function') {
                    window._reloadViolationsUI();
                }
                if (typeof window.refreshUserViolations === 'function') {
                    window.refreshUserViolations();
                }
            }

            // Check announcements separately (less frequent — only every ANNOUNCE_MS)
            const now = Date.now();
            if (!snap.lastAnnouncementCheck || now - snap.lastAnnouncementCheck > ANNOUNCE_MS) {
                snap.lastAnnouncementCheck = now;
                const announcements = await fetchAnnouncements();
                announcements.sort((a, b) => Number(b.id) - Number(a.id));
                const latestA = announcements[0];
                if (latestA && String(latestA.id) !== String(snap.lastAnnouncementId)) {
                    const isNewAnnouncement = !snap.lastAnnouncementId || Number(latestA.id) > Number(snap.lastAnnouncementId);
                    if (isNewAnnouncement) {
                        somethingChanged = true;
                        notifyUser(
                            'New Announcement',
                            latestA.title || 'New campus update posted',
                            'announcement-' + latestA.id
                        );
                        newCount++;
                        if (window.userDashboardData && typeof window.userDashboardData.loadAllData === 'function') {
                            window.userDashboardData.loadAllData();
                        }
                        if (window.refreshAnnouncements && typeof window.refreshAnnouncements === 'function') {
                            window.refreshAnnouncements();
                        }
                    }
                    snap.lastAnnouncementId = latestA.id;
                }
            }

            saveSnapshot(snap);

            if (somethingChanged && typeof window.updateNotificationCount === 'function') {
                window.updateNotificationCount();
            }

            if (typeof window.refreshNotificationBadge === 'function') {
                window.refreshNotificationBadge();
            } else if (newCount > 0) {
                // Only do a full fetch for badge update when something actually changed
                const violations = await fetchViolations();
                _updateBadgeFromViolations(violations, newCount);
            }

            // If dropdown is already open, refresh it silently
            const dropdown = document.getElementById('notificationDropdown');
            if (dropdown && dropdown.classList.contains('show')) {
                if (typeof window.refreshNotificationDropdown === 'function') {
                    window.refreshNotificationDropdown();
                }
            }

        } catch (e) {
            console.warn('Realtime alerts:', e);
        }
    }

    function _updateBadgeFromViolations(violations, extraNew = 0) {
        const seen = JSON.parse(localStorage.getItem('seen_notifications') || '[]');
        const read = JSON.parse(localStorage.getItem('read_notifications') || '[]');
        const unreadViolations = violations.filter(v =>
            !read.includes('v-' + v.id) &&
            !seen.includes('v-' + v.id) &&
            v.is_read != 1
        ).length;
        updateBadge(unreadViolations + extraNew);
    }

    function startRealtimeAlerts() {
        // Works on both student dashboard (notificationBtn) and admin dashboard (notifBtn)
        if (!document.getElementById('notificationBtn') && !document.getElementById('notifBtn')) return;
        checkForUpdates();
        setInterval(checkForUpdates, POLL_MS);
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') checkForUpdates();
        });
    }

    window.startRealtimeAlerts = startRealtimeAlerts;
    window.checkForUpdates = checkForUpdates;

    document.addEventListener('DOMContentLoaded', () => {
        setTimeout(startRealtimeAlerts, 3000);
    });
})();

    function apiBase() {
        const p = location.pathname.split('/').filter(Boolean);
        const d = ['app', 'api', 'includes', 'assets', 'public'];
        return ((!p.length || d.includes(p[0])) ? '' : '/' + p[0]) + '/api/';
    }

    function loadSnapshot() {
        try {
            return JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
        } catch (e) {
            return {};
        }
    }

    function saveSnapshot(s) {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
    }

    function updateBadge(count) {
        const badge = document.querySelector('.notification-badge');
        if (badge) badge.textContent = count > 9 ? '9+' : String(count);
    }

    function notifyUser(title, body, tag) {
        if (typeof window.showSystemAlert === 'function' && Notification.permission === 'granted') {
            window.showSystemAlert(title, body, tag);
        }
        if (typeof window.showNotification === 'function') {
            window.showNotification(body, 'info', title);
        } else if (typeof window.showInfo === 'function') {
            window.showInfo(title + ': ' + body);
        }
    }

    async function fetchViolations() {
        const res = await fetch(apiBase() + 'violations.php', { credentials: 'same-origin' });
        const data = await res.json();
        return data.data || data.violations || [];
    }

    async function fetchAnnouncements() {
        const res = await fetch(apiBase() + 'announcements.php?action=active&limit=50', { credentials: 'same-origin' });
        const data = await res.json();
        const payload = data.data;
        if (Array.isArray(payload)) return payload;
        if (payload && Array.isArray(payload.announcements)) return payload.announcements;
        if (Array.isArray(data.announcements)) return data.announcements;
        return [];
    }

    async function checkForUpdates() {
        if (!navigator.onLine) return;

        try {
            const [violations, announcements] = await Promise.all([
                fetchViolations(),
                fetchAnnouncements()
            ]);

            violations.sort((a, b) => Number(b.id) - Number(a.id));
            announcements.sort((a, b) => Number(b.id) - Number(a.id));
            const latestV = violations[0];
            const latestA = announcements[0];
            const snap = loadSnapshot();
            const isFirst = !snap.initialized;

            if (isFirst) {
                saveSnapshot({
                    initialized: true,
                    lastViolationId: latestV?.id,
                    lastAnnouncementId: latestA?.id
                });
                // Initial badge count from unread violations
                _updateBadgeFromViolations(violations);
                // Kick the admin badge too
                if (typeof window.updateNotificationCount === 'function') {
                    window.updateNotificationCount();
                }
                return;
            }

            let newCount = 0;
            let somethingChanged = false;

            if (latestV && String(latestV.id) !== String(snap.lastViolationId)) {
                const isNew = !snap.lastViolationId || Number(latestV.id) > Number(snap.lastViolationId);
                if (isNew) {
                    somethingChanged = true;
                    // For admins, always notify about new violations (no is_read filter needed)
                    // For students, only notify if unread
                    const isAdmin = document.getElementById('notifBtn') && !document.getElementById('notificationBtn');
                    // Don't notify admin about violations they recorded themselves
                    const currentName = (document.cookie.split(';').find(c => c.trim().startsWith('full_name=')) || '').split('=').slice(1).join('=').trim();
                    const recorder = latestV.reported_by || '';
                    const isOwnRecord = isAdmin && currentName && recorder && decodeURIComponent(currentName) === recorder;
                    if (!isOwnRecord && (isAdmin || latestV.is_read != 1)) {
                        const violationType = latestV.violation_type_name || latestV.violation_type || 'Check violations tab';
                        notifyUser(
                            'New Violation Recorded',
                            (recorder ? 'By ' + recorder + ' — ' : '') +
                            (latestV.case_id ? 'Case ' + latestV.case_id + ' — ' : '') +
                            violationType,
                            'violation-' + latestV.id
                        );
                        newCount++;
                    }
                }
                snap.lastViolationId = latestV.id;
            }

            if (latestA && String(latestA.id) !== String(snap.lastAnnouncementId)) {
            const isNew = !snap.lastAnnouncementId || Number(latestA.id) > Number(snap.lastAnnouncementId);
            if (isNew) {
                somethingChanged = true;
                notifyUser(
                    'New Announcement',
                    latestA.title || 'New campus update posted',
                    'announcement-' + latestA.id
                );
                newCount++;

                // Refresh user dashboard announcements
                if (window.userDashboardData && typeof window.userDashboardData.loadAllData === 'function') {
                    console.log('🔄 Refreshing user dashboard for new announcement');
                    window.userDashboardData.loadAllData();
                }

                // Refresh user announcements page if on it
                if (window.refreshAnnouncements && typeof window.refreshAnnouncements === 'function') {
                    console.log('🔄 Refreshing user announcements page');
                    window.refreshAnnouncements();
                }
            }
            snap.lastAnnouncementId = latestA.id;
        }

            saveSnapshot(snap);

            // Immediately refresh the admin badge whenever something changed
            if (somethingChanged && typeof window.updateNotificationCount === 'function') {
                window.updateNotificationCount();
            }

            // Always silently update the student badge count
            if (typeof window.refreshNotificationBadge === 'function') {
                window.refreshNotificationBadge();
            } else {
                _updateBadgeFromViolations(violations, newCount);
            }

            // If dropdown is already open, refresh it silently
            const dropdown = document.getElementById('notificationDropdown');
            if (dropdown && dropdown.classList.contains('show')) {
                if (typeof window.refreshNotificationDropdown === 'function') {
                    window.refreshNotificationDropdown();
                }
            }

        } catch (e) {
            console.warn('Realtime alerts:', e);
        }
    }

    function _updateBadgeFromViolations(violations, extraNew = 0) {
        const seen = JSON.parse(localStorage.getItem('seen_notifications') || '[]');
        const read = JSON.parse(localStorage.getItem('read_notifications') || '[]');
        const unreadViolations = violations.filter(v =>
            !read.includes('v-' + v.id) &&
            !seen.includes('v-' + v.id) &&
            v.is_read != 1
        ).length;
        updateBadge(unreadViolations + extraNew);
    }

    function startRealtimeAlerts() {
        // Works on both student dashboard (notificationBtn) and admin dashboard (notifBtn)
        if (!document.getElementById('notificationBtn') && !document.getElementById('notifBtn')) return;
        checkForUpdates();
        setInterval(checkForUpdates, POLL_MS); // poll every 20s
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') checkForUpdates();
        });
    }

    window.startRealtimeAlerts = startRealtimeAlerts;
    window.checkForUpdates = checkForUpdates;

    document.addEventListener('DOMContentLoaded', () => {
        setTimeout(startRealtimeAlerts, 3000);
    });
})();
