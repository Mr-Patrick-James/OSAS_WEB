/**
 * Admin Notifications System
 * - Real-time badge count via cheap poll_counts endpoint (every 10 s)
 * - Full notification list loaded on modal open
 * - Reacts immediately when violation.js realtime poll detects a new violation
 */

(function () {
    'use strict';

    // ── Config ────────────────────────────────────────────────────────────────
    const POLL_MS        = 10000;  // badge poll interval (10 s)
    const SNAP_KEY       = 'admin_notif_snap';   // sessionStorage key

    // Resolve API base path relative to any page depth
    function apiBase() {
        const p = location.pathname.split('/').filter(Boolean);
        const d = ['app', 'api', 'includes', 'assets', 'public'];
        return ((!p.length || d.includes(p[0])) ? '' : '/' + p[0]) + '/api/';
    }

    // ── Snapshot helpers ──────────────────────────────────────────────────────
    function loadSnap() {
        try { return JSON.parse(sessionStorage.getItem(SNAP_KEY) || '{}'); } catch (_) { return {}; }
    }
    function saveSnap(s) {
        try { sessionStorage.setItem(SNAP_KEY, JSON.stringify(s)); } catch (_) {}
    }

    // ── Badge element helpers ─────────────────────────────────────────────────
    function setBadge(count) {
        const badge = document.getElementById('notifBadge');
        if (!badge) return;
        const n = Math.max(0, count);
        badge.textContent  = n > 99 ? '99+' : String(n);
        badge.style.display = n > 0 ? 'flex' : 'none';
        // Pulse animation on increment
        badge.classList.remove('badge-pulse');
        if (n > 0) {
            void badge.offsetWidth; // reflow to restart animation
            badge.classList.add('badge-pulse');
        }
    }

    // ── Core: fetch lightweight counts from server ────────────────────────────
    async function fetchCounts() {
        const base = apiBase();
        const res = await fetch(base + 'violations.php?action=poll_counts&t=' + Date.now(), {
            credentials: 'same-origin',
            cache: 'no-store'
        });
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return await res.json();
    }

    // ── Badge update ──────────────────────────────────────────────────────────
    async function updateBadge() {
        try {
            const data = await fetchCounts();
            if (data.status !== 'success') return;

            // Badge = unresolved violations + pending slip requests
            // This is purely server-driven — no client-side seen/unseen tracking
            const total = (data.unresolved_count || 0) + (data.slip_count || 0);

            setBadge(total);

            // If modal is open, keep its list fresh
            const modal = document.getElementById('notifModal');
            if (modal && modal.classList.contains('show')) {
                _fetchAndRenderList();
            }
        } catch (err) {
            console.warn('[admin_notifications] badge update:', err.message);
        }
    }

    // Expose so realtimeAlerts.js + violation.js can trigger immediately
    window.updateNotificationCount = updateBadge;

    // Also expose a function that refreshes the dropdown list content
    window.refreshNotificationDropdown = function () {
        const modal = document.getElementById('notifModal');
        if (modal && modal.classList.contains('show')) {
            _fetchAndRenderList();
        }
    };

    // ── Full notification list ────────────────────────────────────────────────
    async function _fetchAndRenderList() {
        const notifList = document.getElementById('notifList');
        if (!notifList) return;

        notifList.innerHTML = '<div class="notif-loading"><i class="bx bx-loader-alt bx-spin"></i> Loading…</div>';

        const base = apiBase();

        try {
            const [disciplinaryRes, slipRes, recentRes] = await Promise.all([
                fetch(base + 'violations.php?filter=disciplinary', { credentials: 'same-origin' })
                    .then(r => r.json()).catch(() => ({ status: 'error' })),
                fetch(base + 'violations.php?action=get_pending_slip_requests', { credentials: 'same-origin' })
                    .then(r => r.json()).catch(() => ({ status: 'error' })),
                fetch(base + 'violations.php?action=get_recent&limit=10', { credentials: 'same-origin' })
                    .then(r => r.json()).catch(() => ({ status: 'error' }))
            ]);

            const notifications = [];

            // ── Pending slip requests ─────────────────────────────────────────
            if (slipRes.status === 'success' && Array.isArray(slipRes.data)) {
                slipRes.data.filter(r => r.status === 'pending').forEach(req => {
                    const name = [req.first_name, req.last_name].filter(Boolean).join(' ') || 'Unknown Student';
                    notifications.push({
                        type:      'slip_request',
                        name,
                        desc:      'Requested an entrance slip',
                        date:      req.request_date || req.created_at || '',
                        studentId: req.student_id_code || req.student_id || '',
                        avatar:    req.avatar || '',
                        id:        req.id
                    });
                });
            }

            // ── Disciplinary actions ──────────────────────────────────────────
            if (disciplinaryRes.status === 'success' && Array.isArray(disciplinaryRes.data)) {
                disciplinaryRes.data.forEach(v => {
                    const studentName = (v.studentName
                        || [v.first_name, v.middle_name, v.last_name].filter(Boolean).join(' ')
                        || 'Unknown Student').trim();
                    notifications.push({
                        type:      'disciplinary',
                        name:      studentName,
                        desc:      'Has pending disciplinary action',
                        date:      v.dateReported || v.violation_date || '',
                        studentId: v.studentId || v.student_id || '',
                        avatar:    v.studentImage || v.avatar || '',
                        id:        v.id
                    });
                });
            }

            // ── Recent violations (own + others) ─────────────────────────────
            if (recentRes.status === 'success' && Array.isArray(recentRes.data)) {
                const disciplinaryIds = new Set(
                    disciplinaryRes.status === 'success' && Array.isArray(disciplinaryRes.data)
                        ? disciplinaryRes.data.map(v => String(v.id))
                        : []
                );

                // Detect current user's name from cookie for "You recorded" labelling
                const currentName = decodeURIComponent(
                    (document.cookie.split(';').find(c => c.trim().startsWith('full_name=')) || '').split('=').slice(1).join('=').trim()
                );

                recentRes.data.forEach(v => {
                    if (disciplinaryIds.has(String(v.id))) return; // avoid dup with disciplinary section
                    const studentName = (v.studentName
                        || [v.first_name, v.middle_name, v.last_name].filter(Boolean).join(' ')
                        || 'Unknown Student').trim();
                    const recorder  = v.reported_by || v.recorded_by || v.created_by || '';
                    const isOwn     = currentName && recorder && currentName === recorder;
                    const desc      = isOwn
                        ? 'You recorded this violation'
                        : ('Recorded by ' + (recorder || 'staff'));
                    notifications.push({
                        type:          isOwn ? 'own_violation' : 'recent_violation',
                        name:          studentName,
                        desc,
                        violationType: v.violation_type_name || v.violation_type || '',
                        date:          v.dateReported || v.violation_date || v.created_at || '',
                        studentId:     v.studentId || v.student_id || '',
                        avatar:        v.studentImage || v.avatar || '',
                        id:            v.id
                    });
                });
            }

            if (notifications.length === 0) {
                notifList.innerHTML = '<div class="notif-empty"><i class="bx bx-bell-off"></i><p>No notifications at this time.</p></div>';
            } else {
                _renderItems(notifications);
            }

        } catch (err) {
            console.error('[admin_notifications] fetchList:', err);
            notifList.innerHTML = '<div class="notif-empty">Failed to load notifications.</div>';
        }
    }

    // ── Render notification items ─────────────────────────────────────────────
    function _renderItems(notifications) {
        const notifList = document.getElementById('notifList');
        if (!notifList) return;
        notifList.innerHTML = '';

        notifications.forEach(notif => {
            const initials  = _getInitials(notif.name);
            const avatarHtml = notif.avatar && notif.avatar.trim()
                ? `<img src="${_resolveAvatar(notif.avatar)}" alt="${notif.name}" class="notif-avatar"
                       onerror="this.style.display='none';this.nextElementSibling.style.display='flex'">
                   <span class="notif-avatar-initials" style="display:none">${initials}</span>`
                : `<span class="notif-avatar-initials">${initials}</span>`;

            let actionBtn = '';
            let badgeHtml = '';

            if (notif.type === 'slip_request') {
                actionBtn = `<button class="notif-manage-btn slip" onclick="manageSlipRequest('${notif.id}')">Review</button>`;
                badgeHtml = '<span class="notif-badge-tag slip"><i class="bx bx-file"></i> Slip</span>';
            } else if (notif.type === 'disciplinary') {
                actionBtn = `<button class="notif-manage-btn" onclick="manageViolation('${notif.studentId}')">Manage</button>`;
                badgeHtml = '<span class="notif-badge-tag disciplinary"><i class="bx bx-shield-x"></i> Disciplinary</span>';
            } else if (notif.type === 'own_violation') {
                actionBtn = `<button class="notif-manage-btn" onclick="manageViolation('${notif.studentId}')">View</button>`;
                badgeHtml = '<span class="notif-badge-tag own-violation"><i class="bx bx-user-check"></i> You</span>';
            } else if (notif.type === 'recent_violation') {
                actionBtn = `<button class="notif-manage-btn" onclick="manageViolation('${notif.studentId}')">View</button>`;
                badgeHtml = '<span class="notif-badge-tag recent-violation"><i class="bx bx-error-circle"></i> New</span>';
            }

            const descText = (notif.type === 'recent_violation' || notif.type === 'own_violation') && notif.violationType
                ? `${notif.desc} — <em>${notif.violationType}</em> ${badgeHtml}`
                : `${notif.desc} ${badgeHtml}`;

            const item = document.createElement('div');
            item.className = `notif-item notif-${notif.type}`;
            item.style.cursor = 'pointer';
            item.innerHTML = `
                <div class="notif-avatar-wrap">${avatarHtml}</div>
                <div class="notif-info">
                    <span class="notif-name">${notif.name}</span>
                    <span class="notif-desc">${descText}</span>
                    <span class="notif-time">${_formatDate(notif.date)}</span>
                </div>
                ${actionBtn}
            `;

            item.addEventListener('click', function (e) {
                if (e.target.closest('.notif-manage-btn')) return;
                if (notif.type === 'slip_request') manageSlipRequest(notif.id);
                else manageViolation(notif.studentId);
            });

            notifList.appendChild(item);
        });

        // View-all link
        const viewAll = document.createElement('a');
        viewAll.className = 'notif-view-all';
        viewAll.href = '#';
        viewAll.innerHTML = 'View All Violations <i class="bx bx-right-arrow-alt"></i>';
        viewAll.onclick = function (e) {
            e.preventDefault();
            if (typeof loadContent === 'function') loadContent('admin_page/Violations');
            const modal = document.getElementById('notifModal');
            if (modal) modal.classList.remove('show');
        };
        notifList.appendChild(viewAll);
    }

    // ── Utilities ─────────────────────────────────────────────────────────────
    function _getInitials(name) {
        const parts = (name || 'S').trim().split(/\s+/);
        return parts.length > 1
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : (parts[0][0] || 'S').toUpperCase();
    }

    function _resolveAvatar(path) {
        if (!path || !path.trim()) return '';
        if (/^https?:\/\//i.test(path) || path.startsWith('data:')) return path;
        if (path.startsWith('/') || path.startsWith('../')) return path;
        return '../app/assets/img/students/' + path;
    }

    function _formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        if (isNaN(d)) return dateStr;
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    // ── Global action helpers (called from inline onclick) ────────────────────
    window.manageViolation = function (studentId) {
        if (typeof loadContent === 'function') {
            loadContent('admin_page/Violations');
            setTimeout(() => {
                const input = document.getElementById('searchViolation');
                if (input) {
                    input.value = studentId;
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                }
            }, 500);
        } else {
            window.location.href = 'dashboard.php?page=Violations&search=' + studentId;
        }
        const modal = document.getElementById('notifModal');
        if (modal) modal.classList.remove('show');
    };

    window.manageSlipRequest = function (requestId) {
        if (typeof loadContent === 'function') {
            loadContent('admin_page/Violations');
            setTimeout(() => {
                const slipTab = document.querySelector('[data-view="requests"]');
                if (slipTab) slipTab.click();
            }, 600);
        } else {
            window.location.href = 'dashboard.php?page=Violations&view=requests';
        }
        const modal = document.getElementById('notifModal');
        if (modal) modal.classList.remove('show');
    };

    // ── Initialization ────────────────────────────────────────────────────────
    function init() {
        const role = (document.cookie.split(';').find(c => c.trim().startsWith('role=')) || '').split('=')[1]?.trim();

        const notifBadge = document.getElementById('notifBadge');
        const notifBtn   = document.getElementById('notifBtn');
        const notifModal = document.getElementById('notifModal');
        const closeBtn   = document.querySelector('.notif-close-btn');

        if (role !== 'admin') {
            // Non-admins: hide badge, show info toast on click
            if (notifBadge) notifBadge.style.display = 'none';
            if (notifBtn) {
                notifBtn.addEventListener('click', function (e) {
                    e.stopPropagation();
                    if (typeof showNotification === 'function') {
                        showNotification('Only administrators can receive system notifications.', 'info', 'Notifications Restricted');
                    }
                });
            }
            return;
        }

        if (!notifBtn || !notifModal) return;

        // ── Badge pulse style ──────────────────────────────────────────────
        if (!document.getElementById('notif-pulse-style')) {
            const style = document.createElement('style');
            style.id = 'notif-pulse-style';
            style.textContent = `
                @keyframes notifBadgePulse {
                    0%   { transform: scale(1); }
                    30%  { transform: scale(1.45); }
                    60%  { transform: scale(0.9); }
                    100% { transform: scale(1); }
                }
                .badge-pulse { animation: notifBadgePulse .45s ease; }
            `;
            document.head.appendChild(style);
        }

        // ── Toggle modal ───────────────────────────────────────────────────
        notifBtn.addEventListener('click', function (e) {
            e.stopPropagation();
            notifModal.classList.toggle('show');
            if (notifModal.classList.contains('show')) {
                _fetchAndRenderList();
            }
        });

        if (closeBtn) {
            closeBtn.addEventListener('click', function () {
                notifModal.classList.remove('show');
            });
        }

        document.addEventListener('click', function (e) {
            if (!notifModal.contains(e.target) && !notifBtn.contains(e.target)) {
                notifModal.classList.remove('show');
            }
        });

        // ── Start real-time badge polling ──────────────────────────────────
        updateBadge(); // immediate first call
        setInterval(updateBadge, POLL_MS);

        // Re-poll when tab becomes visible again
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') updateBadge();
        });
    }

    // Boot when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
