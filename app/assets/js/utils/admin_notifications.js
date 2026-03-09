/**
 * Admin Notifications System
 * Handles disciplinary action notifications in the top navigation bar
 */

document.addEventListener('DOMContentLoaded', function() {
    initAdminNotifications();
});

function initAdminNotifications() {
    const notifBtn = document.getElementById('notifBtn');
    const notifBadge = document.getElementById('notifBadge');
    const notifModal = document.getElementById('notifModal');
    const notifList = document.getElementById('notifList');
    const closeBtn = document.querySelector('.notif-close-btn');

    if (!notifBtn || !notifBadge || !notifModal) return;

    // Initial count fetch
    updateNotificationCount();

    // Refresh count every 30 seconds
    setInterval(updateNotificationCount, 30000);

    // Toggle modal
    notifBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        notifModal.classList.toggle('show');
        if (notifModal.classList.contains('show')) {
            fetchNotifications();
        }
    });

    // Close modal on close button click
    if (closeBtn) {
        closeBtn.addEventListener('click', function() {
            notifModal.classList.remove('show');
        });
    }

    // Close modal when clicking outside
    document.addEventListener('click', function(e) {
        if (!notifModal.contains(e.target) && !notifBtn.contains(e.target)) {
            notifModal.classList.remove('show');
        }
    });
}

async function updateNotificationCount() {
    try {
        const response = await fetch('../api/violations.php?filter=disciplinary');
        const data = await response.json();
        
        if (data.status === 'success') {
            const count = data.count || 0;
            const notifBadge = document.getElementById('notifBadge');
            if (notifBadge) {
                notifBadge.textContent = count;
                notifBadge.style.display = count > 0 ? 'block' : 'none';
            }
        }
    } catch (error) {
        console.error('Error fetching notification count:', error);
    }
}

async function fetchNotifications() {
    const notifList = document.getElementById('notifList');
    if (!notifList) return;

    notifList.innerHTML = '<div class="notif-loading">Loading notifications...</div>';

    try {
        const response = await fetch('../api/violations.php?filter=disciplinary');
        const data = await response.json();
        
        if (data.status === 'success' && data.data && data.data.length > 0) {
            renderNotifications(data.data);
        } else {
            notifList.innerHTML = '<div class="notif-empty">No disciplinary actions found.</div>';
        }
    } catch (error) {
        console.error('Error fetching notifications:', error);
        notifList.innerHTML = '<div class="notif-empty">Failed to load notifications.</div>';
    }
}

function renderNotifications(violations) {
    const notifList = document.getElementById('notifList');
    if (!notifList) return;

    notifList.innerHTML = '';

    violations.forEach(violation => {
        const studentName = `${violation.first_name} ${violation.last_name}`;
        const avatar = violation.avatar ? `../app/assets/img/students/${violation.avatar}` : 'https://ui-avatars.com/api/?name=' + encodeURIComponent(studentName) + '&background=ffd700&color=333';
        
        const item = document.createElement('div');
        item.className = 'notif-item';
        item.innerHTML = `
            <img src="${avatar}" alt="${studentName}" class="notif-avatar" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(studentName)}&background=ffd700&color=333'">
            <div class="notif-info">
                <span class="notif-name">${studentName}</span>
                <span class="notif-desc">Has pending disciplinary action</span>
                <span class="notif-time">${formatDate(violation.violation_date)}</span>
            </div>
            <button class="notif-manage-btn" onclick="manageViolation('${violation.student_id}')">Manage</button>
        `;
        notifList.appendChild(item);
    });
}

function formatDate(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function manageViolation(studentId) {
    // Redirect to violations page and potentially filter by student
    if (typeof loadContent === 'function') {
        loadContent('admin_page/Violations');
        
        // Give it a small delay to allow the page to load, then search
        setTimeout(() => {
            const searchInput = document.getElementById('searchViolation');
            if (searchInput) {
                searchInput.value = studentId;
                // Trigger input event to fire the search logic in violation.js
                searchInput.dispatchEvent(new Event('input', { bubbles: true }));
            }
        }, 500);
    } else {
        window.location.href = 'dashboard.php?page=Violations&search=' + studentId;
    }
    
    // Close modal
    const notifModal = document.getElementById('notifModal');
    if (notifModal) notifModal.classList.remove('show');
}
