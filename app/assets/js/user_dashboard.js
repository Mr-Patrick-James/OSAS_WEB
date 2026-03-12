// ===============================
// USER DASHBOARD SCRIPT (FULL FIX)
// ===============================

// DOM Elements
const allSideMenu = document.querySelectorAll('#sidebar .side-menu.top li a');
const menuBar = document.querySelector('.sidebar-toggle-logo') || document.querySelector('#sidebar .sidebar-close-icon') || document.querySelector('#sidebar .sidebar-menu-toggle') || document.querySelector('#content nav .bx.bx-menu');
const sidebar = document.getElementById('sidebar');
const sidebarCloseIcon = document.querySelector('#sidebar .sidebar-close-icon');
const searchButton = document.querySelector('#content nav form .form-input button');
const searchButtonIcon = document.querySelector('#content nav form .form-input button .bx');
const searchForm = document.querySelector('#content nav form');
const switchMode = document.getElementById('switch-mode');
const mainContent = document.getElementById('main-content');

// ===============================
// USER DROPDOWN FUNCTIONALITY
// ===============================
function initializeUserDropdown() {
  const userAvatar = document.querySelector('.nav-user-menu .user-avatar');
  const userDropdown = document.querySelector('.nav-user-menu .user-dropdown');
  
  if (userAvatar && userDropdown) {
    userAvatar.addEventListener('click', function(e) {
      e.stopPropagation();
      userDropdown.classList.toggle('show');
    });
    
    // Close dropdown when clicking outside
    document.addEventListener('click', function(e) {
      if (!e.target.closest('.nav-user-menu')) {
        userDropdown.classList.remove('show');
      }
    });
    
    console.log('✅ User dropdown initialized');
  }

  // Use event delegation for all settings links (topnav, sidebar, and dynamic dashboard content)
  document.addEventListener('click', function(e) {
    const settingsLink = e.target.closest('.settings-link');
    if (settingsLink) {
      e.preventDefault();
      openUserSettingsModal();
      if (userDropdown) {
        userDropdown.classList.remove('show');
      }
    }
  });
}

// ===============================
// NOTIFICATION DROPDOWN
// ===============================
function initializeNotifications() {
  const notifBtn = document.getElementById('notificationBtn');
  const notifDropdown = document.getElementById('notificationDropdown');
  const notifList = document.getElementById('notificationList');
  const notifBadge = document.querySelector('.notification-badge');
  const markAllReadBtn = document.getElementById('markAllRead');

  if (!notifBtn || !notifDropdown) return;

  // Toggle dropdown
  notifBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    notifDropdown.classList.toggle('show');
    
    // If opening, load notifications
    if (notifDropdown.classList.contains('show')) {
      loadNotifications();
    }
  });

  // Close when clicking outside
  document.addEventListener('click', function(e) {
    if (!e.target.closest('.nav-notifications')) {
      notifDropdown.classList.remove('show');
    }
  });

  // Mark all as read
  if (markAllReadBtn) {
    markAllReadBtn.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      markAllNotificationsAsRead();
    });
  }

  // Handle "View all violations" link
  const viewAllLink = notifDropdown.querySelector('.view-all');
  if (viewAllLink) {
    viewAllLink.addEventListener('click', function(e) {
      e.preventDefault();
      const page = this.getAttribute('data-page');
      if (page) {
        if (typeof window.loadContent === 'function') {
          window.loadContent(page);
        } else {
          window.location.href = page;
        }
        notifDropdown.classList.remove('show');
      }
    });
  }

  async function loadNotifications() {
    // Show loading state if empty
    if (notifList.innerHTML.includes('no-notifications')) {
      notifList.innerHTML = '<div style="text-align:center; padding:20px;"><div class="loading-spinner"></div></div>';
    }

    try {
      // Get violations from the global state or fetch them
      let violations = [];
      if (window.userDashboardData && window.userDashboardData.violations && window.userDashboardData.violations.length > 0) {
        violations = window.userDashboardData.violations;
      } else {
        const apiBase = (function() {
          const pathParts = window.location.pathname.split('/').filter(p => p);
          if (pathParts.length > 0 && pathParts[0] === 'OSAS_WEB') return '/OSAS_WEB/api/';
          return '/api/';
        })();
        const res = await fetch(apiBase + 'violations.php');
        const data = await res.json();
        violations = data.data || data.violations || [];
      }

      const readNotifs = JSON.parse(localStorage.getItem('read_notifications') || '[]');
      const seenNotifs = JSON.parse(localStorage.getItem('seen_notifications') || '[]');
      
      // Sort by date descending
      violations.sort((a, b) => {
        const dateA = new Date((a.created_at || a.violation_date).replace(' ', 'T'));
        const dateB = new Date((b.created_at || b.violation_date).replace(' ', 'T'));
        return dateB - dateA;
      });

      // Limit to most recent 5 violations
      const recentViolations = violations.slice(0, 5);

      if (recentViolations.length === 0) {
        notifList.innerHTML = `
          <div class="no-notifications">
            <i class='bx bx-bell-off'></i>
            <p>No new notifications</p>
          </div>`;
        if (notifBadge) notifBadge.textContent = '0';
        return;
      }

      // Count only the LATEST violation as new if it hasn't been seen
      const latestViolation = recentViolations[0];
      const unseenCount = (!seenNotifs.includes(String(latestViolation.id)) && latestViolation.is_read != 1) ? 1 : 0;
      if (notifBadge) notifBadge.textContent = unseenCount;

      notifList.innerHTML = recentViolations.map(v => {
        const isUnread = !readNotifs.includes(String(v.id)) && v.is_read != 1;
        const isLatest = v.id === latestViolation.id;
        const type = v.violation_type_name || v.violationTypeLabel || v.violation_type || 'Violation';
        
        // Ensure date is parsed correctly by handling MySQL format (YYYY-MM-DD HH:MM:SS)
        let dateStr = v.created_at || v.violation_date;
        if (v.violation_date && v.violation_time && !v.created_at) {
          dateStr = `${v.violation_date} ${v.violation_time}`;
        }
        
        // Replace space with T for ISO format to ensure consistent cross-browser parsing
        const date = new Date(dateStr.replace(' ', 'T'));
        const timeAgo = formatTimeAgo(date);
        
        return `
          <div class="notification-item ${isUnread ? 'unread' : ''}" data-id="${v.id}">
            <div class="notif-icon">
              <i class='bx bxs-error-circle'></i>
            </div>
            <div class="notif-info">
              <span class="notif-title">${isLatest ? 'New Violation Recorded' : 'Previous Violation'}</span>
              <span class="notif-desc">${type} reported on ${date.toLocaleDateString()}</span>
              <span class="notif-time">${timeAgo}</span>
            </div>
          </div>
        `;
      }).join('');

      // Add click listeners to items
      notifList.querySelectorAll('.notification-item').forEach(item => {
        item.addEventListener('click', function() {
          const id = this.dataset.id;
          markNotificationAsRead(id);
          markNotificationAsSeen(id);
          
          // Close dropdown
          notifDropdown.classList.remove('show');
          
          // Open violation details modal
          if (typeof window.viewViolationDetails === 'function') {
            window.viewViolationDetails(id);
          } else {
            console.error('viewViolationDetails function not found');
          }
        });
      });

      // Mark the latest as "seen" once the dropdown is opened
      if (notifDropdown.classList.contains('show')) {
        markNotificationAsSeen(latestViolation.id);
      }

    } catch (error) {
      console.error('Error loading notifications:', error);
      notifList.innerHTML = '<div style="text-align:center; padding:20px; color:red;">Error loading notifications</div>';
    }
  }

  async function markNotificationAsRead(id) {
    const readNotifs = JSON.parse(localStorage.getItem('read_notifications') || '[]');
    if (!readNotifs.includes(String(id))) {
      readNotifs.push(String(id));
      localStorage.setItem('read_notifications', JSON.stringify(readNotifs));
    }
    
    // Persist to database
    try {
      const apiBase = (function() {
        const pathParts = window.location.pathname.split('/').filter(p => p);
        if (pathParts.length > 0 && pathParts[0] === 'OSAS_WEB') return '/OSAS_WEB/api/';
        return '/api/';
      })();
      await fetch(`${apiBase}violations.php?action=mark_as_read&id=${id}`);
    } catch (e) {
      console.error('Failed to persist read status:', e);
    }

    const item = notifList.querySelector(`.notification-item[data-id="${id}"]`);
    if (item) item.classList.remove('unread');
    
    updateBadgeCount();
  }

  function markNotificationAsSeen(id) {
    const seenNotifs = JSON.parse(localStorage.getItem('seen_notifications') || '[]');
    if (!seenNotifs.includes(String(id))) {
      seenNotifs.push(String(id));
      localStorage.setItem('seen_notifications', JSON.stringify(seenNotifs));
      updateBadgeCount();
    }
  }

  async function markAllNotificationsAsRead() {
    const items = notifList.querySelectorAll('.notification-item.unread');
    if (items.length === 0) return;

    const readNotifs = JSON.parse(localStorage.getItem('read_notifications') || '[]');
    const seenNotifs = JSON.parse(localStorage.getItem('seen_notifications') || '[]');

    items.forEach(item => {
      const id = item.dataset.id;
      if (!readNotifs.includes(String(id))) readNotifs.push(String(id));
      if (!seenNotifs.includes(String(id))) seenNotifs.push(String(id));
      item.classList.remove('unread');
    });

    localStorage.setItem('read_notifications', JSON.stringify(readNotifs));
    localStorage.setItem('seen_notifications', JSON.stringify(seenNotifs));
    
    // Persist to database
    try {
      const apiBase = (function() {
        const pathParts = window.location.pathname.split('/').filter(p => p);
        if (pathParts.length > 0 && pathParts[0] === 'OSAS_WEB') return '/OSAS_WEB/api/';
        return '/api/';
      })();
      await fetch(`${apiBase}violations.php?action=mark_all_read`);
      showNotification('All notifications marked as read', 'success');
    } catch (e) {
      console.error('Failed to persist mark all as read:', e);
    }

    updateBadgeCount();
  }

  function updateBadgeCount() {
    const seenNotifs = JSON.parse(localStorage.getItem('seen_notifications') || '[]');
    const items = notifList.querySelectorAll('.notification-item');
    if (items.length === 0) return;
    
    const latestItem = items[0];
    const latestId = latestItem.dataset.id;
    const isUnread = latestItem.classList.contains('unread');
    const isSeen = seenNotifs.includes(String(latestId));
    
    if (notifBadge) {
      // Badge should show if latest is both unread AND unseen
      notifBadge.textContent = (isUnread && !isSeen) ? '1' : '0';
    }
  }

  function formatTimeAgo(date) {
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMs < 0) return 'Just now';
    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  }
  
  // Initial check for notifications
  setTimeout(loadNotifications, 1000);
}

// ===============================
// LOGOUT FUNCTION
// ===============================
window.logout = function() {
  if (confirm('Are you sure you want to logout?')) {
    // Clear session and cookies
    fetch('../api/logout.php', {
      method: 'POST',
      credentials: 'include'
    })
    .then(() => {
      // Clear local storage
      localStorage.clear();
      // Redirect to login page
      window.location.href = '../index.php';
    })
    .catch(error => {
      console.error('Logout error:', error);
      // Redirect anyway
      window.location.href = '../index.php';
    });
  }
};

// ===============================
// PAGE INITIALIZATION
// ===============================
document.addEventListener('DOMContentLoaded', function () {
  console.log("🚀 Initializing user dashboard...");

  const session = checkAuthentication();

  if (!session) return; // Redirected if not authenticated
  
  // Initialize user dropdown
  initializeUserDropdown();

  // Initialize notifications
  initializeNotifications();

  // Initialize theme state if theme.js is available
  if (typeof initializeTheme === 'function') {
    initializeTheme();
  } else {
    // Fallback: Initialize dark mode state
    const savedTheme = localStorage.getItem('theme');
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    window.darkMode = savedTheme ? savedTheme === 'dark' : false;
    
    // Sync body class and switch
    if (window.darkMode) {
      document.body.classList.add('dark');
    } else {
      document.body.classList.remove('dark');
    }
    
    if (switchMode) {
      switchMode.checked = window.darkMode;
    }
  }
  
  // Store switchMode globally for theme.js
  window.switchMode = switchMode;

  // Load default page
  const defaultPage = 'user-page/user_dashcontent';
  loadContent(defaultPage);

  // Highlight active menu
  const dashboardLink = document.querySelector(`[data-page="${defaultPage}"]`);
  if (dashboardLink) {
    allSideMenu.forEach(i => i.parentElement.classList.remove('active'));
    dashboardLink.parentElement.classList.add('active');
  }
});

// ===============================
// AUTHENTICATION HANDLING
// ===============================
function checkAuthentication() {
  console.log('🔍 Checking authentication...');

  // Check if PHP session is valid (cookies exist) - this is the primary check
  const hasCookies = document.cookie.includes('user_id') && document.cookie.includes('role');
  
  if (hasCookies) {
    console.log('✅ PHP session cookies found, authentication valid');
    // Try to get localStorage session for UI updates
    const storedSession = localStorage.getItem('userSession');
    if (storedSession) {
      try {
        const session = JSON.parse(storedSession);
        updateUserInfo(session);
        console.log('✅ Authenticated as:', session.name, '| Role:', session.role);
        return session;
      } catch (error) {
        console.warn('⚠️ Could not parse localStorage session, but cookies are valid');
      }
    }
    return { role: 'user' }; // Return minimal session object
  }

  // Fallback to localStorage check (only if cookies don't exist)
  let storedSession = localStorage.getItem('userSession') || sessionStorage.getItem('userSession');

  if (!storedSession) {
    console.warn('❌ No session found. Redirecting to login.');
    redirectToLogin();
    return null;
  }

  let session;
  try {
    session = JSON.parse(storedSession);
  } catch (err) {
    console.error('❌ Invalid session format. Clearing...');
    localStorage.removeItem('userSession');
    sessionStorage.removeItem('userSession');
    redirectToLogin();
    return null;
  }

  const now = new Date().getTime();
  if (session.expires && now > session.expires) {
    console.warn('⚠️ Session expired. Clearing storage.');
    localStorage.removeItem('userSession');
    sessionStorage.removeItem('userSession');
    redirectToLogin();
    return null;
  }

  // Role check
  if (session.role !== 'user') {
    console.warn('⚠️ Unauthorized role detected:', session.role);
    if (session.role === 'admin') {
      window.location.href = '../includes/dashboard.php';
    } else {
      redirectToLogin();
    }
    return null;
  }

  updateUserInfo(session);
  console.log('✅ Authenticated as:', session.name, '| Role:', session.role);
  return session;
}

function redirectToLogin() {
  window.location.href = '../index.php';
}

// ===============================
// USER INFO
// ===============================
function updateUserInfo(session) {
  const profileName = document.querySelector('.profile-name');
  const studentId = document.querySelector('.student-id');

  if (profileName) profileName.textContent = session.name || 'Unknown User';
  if (studentId && session.studentId) studentId.textContent = `ID: ${session.studentId}`;
}

// ===============================
// LOGOUT FUNCTION
// ===============================
window.logout = function(e) {
  if (e) e.preventDefault();
  if (typeof openLogoutModal === 'function') {
      openLogoutModal();
  } else if (typeof window.openLogoutModal === 'function') {
      window.openLogoutModal();
  } else {
      // Fallback to confirm if modal fails
      if (confirm('Are you sure you want to logout?')) {
          executeLogout();
      }
  }
}

window.executeLogout = function() {
    console.log('👋 Logging out...');
    
    try {
      // Clear all client-side storage first
      localStorage.removeItem('userSession');
      sessionStorage.removeItem('userSession');
      
      // Delete all authentication cookies on client side
      deleteCookie('user_id');
      deleteCookie('username');
      deleteCookie('role');
      deleteCookie('student_id');
      deleteCookie('student_id_code');
      deleteCookie('userSession');
      
      // Direct redirect to logout script
      console.log('Redirecting to logout script...');
      
      // Determine correct logout path based on current location
      let logoutPath;
      const currentPath = window.location.pathname;
      
      if (currentPath.includes('/index.php')) {
        // From app/entry/user_dashboard.php -> ../app/views/auth/logout.php
        logoutPath = '../index.php';
      } else if (currentPath.includes('/includes/')) {
        // From includes/user_dashboard.php -> ../app/views/auth/logout.php
        logoutPath = '../index.php';
      } else {
        // Default fallback - go to root and then to logout
        logoutPath = '../index.php';
      }
      
      console.log('Logout path:', logoutPath);
      window.location.href = logoutPath;
      
    } catch (error) {
      console.error('Logout error:', error);
      // Fallback: direct redirect to login page
      window.location.href = 'index.php?direct=true';
    }
}

// ===============================
// COOKIE HELPERS
// ===============================
function getCookie(name) {
  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);
  if (parts.length === 2) return parts.pop().split(';').shift();
  return null;
}

function deleteCookie(name) {
  // Delete cookie with multiple path options to ensure it's removed
  document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
  document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/OSAS_WEB/;';
  document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/OSAS_WEB/app/entry/;';
}

/**
 * Modern Alert/Confirm Modal System
 */
window.showModernAlert = function({ 
  title = 'Are you sure?', 
  message = '', 
  icon = 'warning', 
  confirmText = 'Confirm', 
  cancelText = 'Cancel',
  showCancel = true
}) {
  return new Promise((resolve) => {
    let modal = document.getElementById('modernAlertModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'modernAlertModal';
      modal.className = 'modern-alert';
      document.body.appendChild(modal);
    }

    const iconMap = {
      warning: 'bx-error',
      danger: 'bx-trash',
      success: 'bx-check-circle',
      info: 'bx-info-circle',
      loading: 'bx-loader-alt bx-spin'
    };

    const iconClass = iconMap[icon] || iconMap.warning;
    const isDanger = icon === 'danger';

    modal.innerHTML = `
      <div class="modern-alert-content">
        <div class="modern-alert-icon ${icon}">
          <i class='bx ${iconClass}'></i>
        </div>
        <h2>${title}</h2>
        <p>${message}</p>
        <div class="modern-alert-actions">
          ${showCancel ? `<button class="modern-alert-btn cancel" id="modernAlertCancel">${cancelText}</button>` : ''}
          <button class="modern-alert-btn confirm ${isDanger ? 'danger' : ''}" id="modernAlertConfirm">${confirmText}</button>
        </div>
      </div>
    `;

    setTimeout(() => modal.classList.add('active'), 10);
    document.body.style.overflow = 'hidden';

    const cleanup = (result) => {
      modal.classList.remove('active');
      setTimeout(() => {
        document.body.style.overflow = '';
        resolve(result);
      }, 300);
    };

    if (showCancel) {
      document.getElementById('modernAlertCancel').onclick = () => cleanup(false);
    }
    document.getElementById('modernAlertConfirm').onclick = () => cleanup(true);
    
    modal.onclick = (e) => {
      if (e.target === modal && showCancel) cleanup(false);
    };
  });
};

/**
 * Modern Toast Notification System
 */
window.showNotification = function(message, type = 'info', title = null) {
  let container = document.querySelector('.toast-container');
  if (!container) {
    container = document.createElement('div');
    container.className = 'toast-container';
    document.body.appendChild(container);
  }

  const toast = document.createElement('div');
  toast.className = `toast-notification toast-${type}`;
  
  const icon = {
    success: 'bx-check-circle',
    error: 'bx-error-circle',
    warning: 'bx-error',
    info: 'bx-info-circle'
  }[type] || 'bx-info-circle';

  const defaultTitle = {
    success: 'Success',
    error: 'Error',
    warning: 'Warning',
    info: 'Information'
  }[type] || 'Notice';

  toast.innerHTML = `
    <div class="toast-icon">
      <i class='bx ${icon}'></i>
    </div>
    <div class="toast-content">
      <span class="toast-title">${title || defaultTitle}</span>
      <span class="toast-message">${message}</span>
    </div>
    <div class="toast-close">
      <i class='bx bx-x'></i>
    </div>
    <div class="toast-progress">
      <div class="toast-progress-bar"></div>
    </div>
  `;

  container.appendChild(toast);

  // Animate progress bar
  const progressBar = toast.querySelector('.toast-progress-bar');
  progressBar.style.transition = 'transform 4s linear';
  
  // Show toast
  setTimeout(() => {
    toast.classList.add('show');
    progressBar.style.transform = 'scaleX(0)';
  }, 100);

  // Auto remove
  const timeout = setTimeout(() => {
    removeToast(toast);
  }, 4000);

  // Close button
  toast.querySelector('.toast-close').onclick = () => {
    clearTimeout(timeout);
    removeToast(toast);
  };
};

// Global Form Validation Interceptor
document.addEventListener('invalid', (function() {
  return function(e) {
    // Prevent the browser from showing default error bubbles
    e.preventDefault();
    
    // Show custom modern notification instead
    const fieldName = e.target.getAttribute('placeholder') || e.target.getAttribute('name') || 'This field';
    const message = e.target.validationMessage || 'Please fill out this field.';
    
    if (typeof showNotification === 'function') {
      showNotification(`${message} (${fieldName})`, 'warning', 'Validation Error');
    }
  };
})(), true);

function removeToast(toast) {
  toast.classList.remove('show');
  toast.style.transform = 'translateX(120%)';
  setTimeout(() => toast.remove(), 500);
}

// Global alias for compatibility
window.showSuccess = (msg) => showNotification(msg, 'success');
window.showError = (msg) => showNotification(msg, 'error');

// ===============================
// SIDEBAR HANDLING
// ===============================
allSideMenu.forEach(item => {
  // Skip chatbot buttons - they have their own handlers
  if (item.classList.contains('chatbot-sidebar-btn')) {
    return;
  }
  
  const li = item.parentElement;

  item.addEventListener('click', function (e) {
    e.preventDefault();
    const page = this.getAttribute('data-page');
    if (!page) return;

    allSideMenu.forEach(i => {
      if (!i.classList.contains('chatbot-sidebar-btn')) {
        i.parentElement.classList.remove('active');
      }
    });
    li.classList.add('active');

    loadContent(page);
  });
});

// ===============================
// TOP NAVIGATION HANDLING
// ===============================
const topNavLinks = document.querySelectorAll('.nav-menu .nav-link');
console.log('Found', topNavLinks.length, 'top nav links');

topNavLinks.forEach(link => {
  link.addEventListener('click', function (e) {
    e.preventDefault();
    const page = this.getAttribute('data-page');
    if (!page) return;

    console.log('Top nav clicked:', page);

    // Update active state
    topNavLinks.forEach(l => {
      l.parentElement.classList.remove('active');
    });
    this.parentElement.classList.add('active');

    // Also update sidebar active state if it exists
    allSideMenu.forEach(i => {
      if (!i.classList.contains('chatbot-sidebar-btn')) {
        i.parentElement.classList.remove('active');
      }
    });

    loadContent(page);
  });
});

// ===============================
// DYNAMIC CONTENT LOADER
// ===============================
function loadContent(page) {
  console.log(`📄 Loading page: ${page}`);

  const xhr = new XMLHttpRequest();
  // Load from app/views/loader.php instead of pages/
  xhr.open('GET', `../app/views/loader.php?view=${page}`, true);

  xhr.onload = function () {
    if (this.status === 200) {
      const response = this.responseText;
      console.log('Raw response received, length:', response.length);
      
      // Parse HTML properly using DOMParser (handles <head> and <body> tags)
      const parser = new DOMParser();
      const doc = parser.parseFromString(response, 'text/html');
      const headContent = doc.querySelector('head');
      const bodyContent = doc.querySelector('body');
      
      console.log('Head found:', !!headContent);
      console.log('Body found:', !!bodyContent);
      
      if (headContent || bodyContent) {
        // Extract all link tags (CSS) from head
        if (headContent) {
          const links = headContent.querySelectorAll('link[rel="stylesheet"]');
          console.log('Found', links.length, 'CSS link(s) in head');
          links.forEach((link, index) => {
            const href = link.getAttribute('href');
            console.log(`CSS ${index + 1}:`, href);
            
            // Use href as-is if it's already absolute (starts with / or http)
            // View::asset() returns absolute paths starting with /
            let absoluteHref = href;
            if (href && !href.startsWith('http') && !href.startsWith('/')) {
              // It's a relative path, make it absolute
              const basePath = window.location.pathname.substring(0, window.location.pathname.lastIndexOf('/'));
              absoluteHref = basePath + '/' + href;
              console.log('Converted relative to absolute:', absoluteHref);
            } else if (href && href.startsWith('./')) {
              // Remove leading ./
              absoluteHref = href.substring(2);
              const basePath = window.location.pathname.substring(0, window.location.pathname.lastIndexOf('/'));
              absoluteHref = basePath + '/' + absoluteHref;
              console.log('Converted ./ to absolute:', absoluteHref);
            } else if (href && href.startsWith('/')) {
              // Already absolute path - use as-is
              console.log('Using absolute path as-is:', absoluteHref);
            }
            
            // Check if this CSS is already loaded
            const existingLink = document.querySelector(`link[href="${href}"], link[href="${absoluteHref}"]`);
            if (!existingLink) {
              const newLink = document.createElement('link');
              newLink.rel = 'stylesheet';
              newLink.href = absoluteHref;
              newLink.onload = () => console.log('✓ CSS loaded successfully:', absoluteHref);
              newLink.onerror = (e) => {
                console.error('✗ CSS failed to load:', absoluteHref);
                console.error('Error details:', e);
              };
              document.head.appendChild(newLink);
              console.log('→ Injecting CSS:', absoluteHref);
            } else {
              console.log('→ CSS already loaded:', href);
            }
          });
        } else {
          console.warn('No head element found in loaded content');
        }
        
        // Extract all script tags from both head and body
        const allScripts = [];
        if (headContent) {
          headContent.querySelectorAll('script').forEach(script => {
            allScripts.push(script);
          });
        }
        if (bodyContent) {
          bodyContent.querySelectorAll('script').forEach(script => {
            allScripts.push(script);
          });
        }
        
        // Extract content from body or main tag (without scripts)
        if (bodyContent) {
          // Clone body content and remove scripts
          const bodyClone = bodyContent.cloneNode(true);
          bodyClone.querySelectorAll('script').forEach(script => script.remove());
          mainContent.innerHTML = bodyClone.innerHTML;
        } else {
          // If no body tag, try to get main content
          const mainTag = tempDiv.querySelector('main');
          if (mainTag) {
            const mainClone = mainTag.cloneNode(true);
            mainClone.querySelectorAll('script').forEach(script => script.remove());
            mainContent.innerHTML = mainClone.outerHTML;
          } else {
            mainContent.innerHTML = response;
          }
        }
        
        // Load and execute scripts
        const loadScript = (script) => {
          return new Promise((resolve, reject) => {
            if (script.src) {
              // External script
              const src = script.getAttribute('src');
              // Check if script is already loaded
              if (document.querySelector(`script[src="${src}"]`)) {
                resolve();
                return;
              }
              const newScript = document.createElement('script');
              newScript.src = src;
              newScript.onload = resolve;
              newScript.onerror = reject;
              document.body.appendChild(newScript);
            } else {
              // Inline script
              const newScript = document.createElement('script');
              newScript.textContent = script.textContent;
              document.body.appendChild(newScript);
              resolve();
            }
          });
        };
        
        // Load scripts sequentially
        const loadScriptsSequentially = async () => {
          console.log(`Loading ${allScripts.length} script(s)...`);
          for (const script of allScripts) {
            try {
              await loadScript(script);
            } catch (error) {
              console.warn('Failed to load script:', script.src || 'inline', error);
            }
          }
          console.log('All scripts loaded');
          
          // Dispatch custom event for page-specific initializations
          window.dispatchEvent(new Event('pageContentLoaded'));
          
          // Initialize modules after scripts are loaded
          if (page.toLowerCase().includes('user_dashcontent') || page.toLowerCase().includes('dashcontent')) {
            // Ensure userViolations.js is loaded for download modal
            const vScript = document.createElement('script');
            vScript.src = '../app/assets/js/userViolations.js';
            try {
                await loadScript(vScript);
                console.log('✅ User violations script loaded for dashboard');
            } catch (e) {
                console.warn('⚠️ Failed to pre-load user violations script', e);
            }

            setTimeout(() => {
              console.log('🔄 Initializing dashboard page...');
              if (typeof initializeUserDashboard === 'function') initializeUserDashboard();
              if (typeof initializeAnnouncements === 'function') initializeAnnouncements();
              
              // Re-initialize theme toggle for dynamically loaded content
              const switchMode = document.getElementById('switch-mode');
              if (switchMode && !switchMode.hasAttribute('data-listener-attached')) {
                switchMode.setAttribute('data-listener-attached', 'true');
                window.switchMode = switchMode;
                switchMode.addEventListener('change', function () {
                  if (typeof toggleTheme === 'function') {
                    toggleTheme();
                  } else {
                    window.darkMode = this.checked;
                    if (this.checked) {
                      document.body.classList.add('dark');
                    } else {
                      document.body.classList.remove('dark');
                    }
                    localStorage.setItem('theme', this.checked ? 'dark' : 'light');
                    document.dispatchEvent(new CustomEvent('themeChanged', { 
                      detail: { darkMode: this.checked } 
                    }));
                  }
                });
                console.log('✅ Theme toggle re-initialized');
              }
              
              // Load dashboard data
              const loadData = () => {
                if (typeof window.userDashboardData !== 'undefined' && window.userDashboardData) {
                  console.log('🔄 Loading user dashboard data...');
                  window.userDashboardData.loadAllData().catch(error => {
                    console.error('❌ Error loading dashboard data:', error);
                  });
                } else if (typeof userDashboardData !== 'undefined' && userDashboardData) {
                  console.log('🔄 Loading user dashboard data (fallback)...');
                  userDashboardData.loadAllData().catch(error => {
                    console.error('❌ Error loading dashboard data:', error);
                  });
                } else {
                  // Create new instance if it doesn't exist
                  if (typeof UserDashboardData !== 'undefined') {
                    window.userDashboardData = new UserDashboardData();
                    window.userDashboardData.loadAllData().catch(error => {
                      console.error('❌ Error loading dashboard data:', error);
                    });
                  } else {
                    console.warn('⚠️ userDashboardData not available, retrying in 500ms...');
                    setTimeout(loadData, 500);
                  }
                }
              };
              
              loadData();
              
              // Load sidebar profile
              if (typeof updateSidebarProfile === 'function') {
                updateSidebarProfile();
              } else {
                // Load sidebar profile from API
                loadSidebarProfile();
              }
            }, 100);
          }

          if (page.toLowerCase().includes('my_violations')) {
            setTimeout(() => {
              console.log('🔄 Attempting to initialize violations page...');
              console.log('window.initUserViolations exists?', typeof window.initUserViolations);
              
              if (typeof window.initUserViolations === 'function') {
                console.log('✅ Calling window.initUserViolations()');
                window.initUserViolations();
              } else if (typeof initUserViolations === 'function') {
                console.log('✅ Calling initUserViolations()');
                initUserViolations();
              } else if (typeof window.initializeUserViolations === 'function') {
                console.log('✅ Calling window.initializeUserViolations()');
                window.initializeUserViolations();
              } else if (typeof initViolationsModule === 'function') {
                console.log('✅ Calling initViolationsModule()');
                initViolationsModule();
              } else {
                console.error('❌ User violations init function not found');
                console.log('Available window functions:', Object.keys(window).filter(k => k.includes('violation') || k.includes('Violation')));
              }
            }, 500);
          }

          if (page.toLowerCase().includes('announcements') && !page.toLowerCase().includes('user_dashcontent')) {
            setTimeout(() => {
              if (typeof window.initAnnouncementsModule === 'function') {
                window.initAnnouncementsModule();
              } else if (typeof window.initializeUserAnnouncements === 'function') {
                window.initializeUserAnnouncements();
              } else if (typeof initAnnouncementsModule === 'function') {
                initAnnouncementsModule();
              } else {
                console.warn('⚠️ User announcements init function not found');
              }
            }, 300);
          }
        };
        
        loadScriptsSequentially();
      } else {
        mainContent.innerHTML = response;
        
        // Fallback: Initialize modules even if structure is different
        if (page.toLowerCase().includes('user_dashcontent')) {
          loadScript('../app/assets/js/userViolations.js', () => {
              console.log('✅ User violations script loaded (fallback)');
          });
          
          setTimeout(() => {
            console.log('🔄 Initializing dashboard page...');
            if (typeof initializeUserDashboard === 'function') initializeUserDashboard();
            if (typeof initializeAnnouncements === 'function') initializeAnnouncements();
            
            const loadData = () => {
              if (typeof window.userDashboardData !== 'undefined' && window.userDashboardData) {
                console.log('🔄 Loading user dashboard data...');
                window.userDashboardData.loadAllData().catch(error => {
                  console.error('❌ Error loading dashboard data:', error);
                });
              } else if (typeof userDashboardData !== 'undefined' && userDashboardData) {
                console.log('🔄 Loading user dashboard data (fallback)...');
                userDashboardData.loadAllData().catch(error => {
                  console.error('❌ Error loading dashboard data:', error);
                });
              } else {
                console.warn('⚠️ userDashboardData not available, retrying in 500ms...');
                setTimeout(loadData, 500);
              }
            };
            
            loadData();
          }, 500);
        }

        if (page.toLowerCase().includes('my_violations')) {
          loadScript('../app/assets/js/userViolations.js', () => {
            console.log('✅ User violations script loaded');
            setTimeout(() => {
              if (typeof window.initUserViolations === 'function') {
                window.initUserViolations();
              } else if (typeof window.initializeUserViolations === 'function') {
                window.initializeUserViolations();
              } else {
                console.warn('⚠️ User violations init function not found');
              }
            }, 300);
          });
        }

        if (page.toLowerCase().includes('announcements') && !page.toLowerCase().includes('user_dashcontent')) {
          loadScript('../app/assets/js/userAnnouncements.js', () => {
            console.log('✅ User announcements script loaded');
            setTimeout(() => {
              if (typeof window.initAnnouncementsModule === 'function') {
                window.initAnnouncementsModule();
              } else if (typeof window.initializeUserAnnouncements === 'function') {
                window.initializeUserAnnouncements();
              } else {
                console.warn('⚠️ User announcements init function not found');
              }
            }, 300);
          });
        }
      }
    } else if (this.status === 404) {
      mainContent.innerHTML = '<h2 style="color:red; padding:20px;">Page not found.</h2>';
    }
  };

  xhr.onerror = function () {
    mainContent.innerHTML = '<h2 style="color:red; padding:20px;">Error loading page.</h2>';
  };

  xhr.send();
}

// Load script dynamically
function loadScript(src, callback) {
  // Check if script already loaded
  const existingScript = document.querySelector(`script[src="${src}"]`);
  if (existingScript) {
    if (callback) callback();
    return;
  }

  const script = document.createElement('script');
  script.src = src;
  script.onload = callback;
  script.onerror = function() {
    console.error(`❌ Failed to load script: ${src}`);
  };
  document.head.appendChild(script);
}

// Announcements functionality
function toggleAnnouncements() {
  const content = document.getElementById('announcementsContent');
  const toggle = document.querySelector('.announcement-toggle');

  if (content && toggle) {
    content.classList.toggle('collapsed');
    toggle.classList.toggle('rotated');
  }
}

// Initialize announcements
function initializeAnnouncements() {
  // Add click events to read more buttons
  const readMoreButtons = document.querySelectorAll('.btn-read-more');
  readMoreButtons.forEach(button => {
    button.addEventListener('click', function (e) {
      e.stopPropagation();
      // Here you can add functionality to show full announcement details
      console.log('Read more clicked for announcement');
    });
  });

  // Auto-collapse announcements after 5 seconds (optional)
  setTimeout(() => {
    const content = document.getElementById('announcementsContent');
    const toggle = document.querySelector('.announcement-toggle');
    if (content && !content.classList.contains('collapsed')) {
      content.classList.add('collapsed');
      toggle.classList.add('rotated');
    }
  }, 5000);
}

// Enhanced announcement functions
function markAsRead(button) {
  const announcementItem = button.closest('.announcement-item');
  announcementItem.classList.remove('unread');
  button.style.display = 'none';

  // Update announcement count
  updateAnnouncementCount();

  // Show success message
  showNotification('Announcement marked as read', 'success');
}

function markAllAsRead() {
  const unreadItems = document.querySelectorAll('.announcement-item.unread');
  unreadItems.forEach(item => {
    item.classList.remove('unread');
    const markButton = item.querySelector('.btn-mark-read');
    if (markButton) {
      markButton.style.display = 'none';
    }
  });

  updateAnnouncementCount();
  showNotification('All announcements marked as read', 'success');
}

function updateAnnouncementCount() {
  const unreadCount = document.querySelectorAll('.announcement-item.unread').length;
  const countElement = document.querySelector('.announcement-count');
  if (countElement) {
    if (unreadCount > 0) {
      countElement.textContent = `${unreadCount} New`;
      countElement.style.display = 'inline-block';
    } else {
      countElement.style.display = 'none';
    }
  }
}

function openAnnouncement(id) {
  // Here you can implement opening full announcement details
  console.log(`Opening announcement ${id}`);
  showNotification('Opening announcement details...', 'info');
}

function viewAllAnnouncements() {
  // Here you can implement viewing all announcements
  console.log('Viewing all announcements');
  showNotification('Opening all announcements...', 'info');
}

function getUserProjectRoot() {
  const parts = window.location.pathname.split('/').filter(p => p);
  if (parts.length > 0) {
    const first = parts[0];
    if (first === 'app' || first === 'public' || first === 'includes' || first === 'api') {
      return '';
    }
    return '/' + first;
  }
  return '';
}

function getUserApiBasePath() {
  const root = getUserProjectRoot();
  if (root) return root + '/api/';
  return '/api/';
}

function resolveUserPath(relativePath) {
  if (!relativePath) return relativePath;
  if (relativePath.startsWith('http') || relativePath.startsWith('/')) return relativePath;
  const root = getUserProjectRoot();
  const cleanPath = relativePath.replace(/^(\.\/|\.\.\/)+/, '');
  if (cleanPath.startsWith('public/')) return root + '/' + cleanPath;
  if (cleanPath.startsWith('assets/')) return root + '/app/' + cleanPath;
  return root + '/' + cleanPath;
}

function createUserSettingsModal() {
  let overlay = document.getElementById('userSettingsModalOverlay');
  if (overlay) return overlay;

  overlay = document.createElement('div');
  overlay.id = 'userSettingsModalOverlay';
  overlay.className = 'settings-modal-overlay';

  const defaultAvatar = resolveUserPath('assets/img/default.png');

  overlay.innerHTML = `
    <div class="settings-modal user-settings-modal">
      <aside class="settings-sidebar">
        <div class="settings-sidebar-header">Settings</div>
        <div class="settings-sidebar-list">
          <button type="button" class="settings-sidebar-item active" data-section="profile">
            <i class='bx bx-id-card'></i>
            <span>Profile</span>
          </button>
          <button type="button" class="settings-sidebar-item" data-section="preferences">
            <i class='bx bx-cog'></i>
            <span>Preferences</span>
          </button>
        </div>
      </aside>
      <div class="settings-content">
        <button type="button" class="settings-close-btn" id="userSettingsCloseBtn">
          <i class='bx bx-x'></i>
        </button>
        <div class="settings-section active" data-section="profile">
          <h2 class="settings-title">My Profile</h2>
          <div id="userSettingsProfileAlert" class="settings-alert"></div>
          <form id="userSettingsProfileForm" enctype="multipart/form-data">
            <div class="settings-profile-header">
              <div class="profile-upload-container">
                <img id="userProfileImagePreview" class="profile-image-preview" src="${defaultAvatar}" alt="Profile Picture">
                <label for="userProfilePictureInput" class="profile-upload-button">
                  <i class='bx bx-camera'></i>
                </label>
                <input type="file" id="userProfilePictureInput" name="profile_picture" accept="image/*" style="display: none;">
              </div>
              <div class="profile-info-text">
                <h4 id="userProfileDisplayName">User</h4>
                <p>Update your account details and password.</p>
              </div>
            </div>
            <div class="settings-grid">
              <div class="settings-form-group">
                <label class="settings-label" for="userProfileUsername">Username</label>
                <input class="settings-input" type="text" id="userProfileUsername" name="username" placeholder="Your username">
              </div>
              <div class="settings-form-group">
                <label class="settings-label" for="userProfileFullName">Full Name</label>
                <input class="settings-input" type="text" id="userProfileFullName" name="full_name" placeholder="Full name" readonly>
              </div>
              <div class="settings-form-group">
                <label class="settings-label" for="userProfileEmail">Email</label>
                <input class="settings-input" type="email" id="userProfileEmail" name="email" placeholder="Email" readonly>
              </div>
              <div class="settings-form-group">
                <label class="settings-label" for="userProfileCurrentPassword">Current Password</label>
                <input class="settings-input" type="password" id="userProfileCurrentPassword" name="current_password" placeholder="Required only if changing password">
              </div>
              <div class="settings-form-group">
                <label class="settings-label" for="userProfileNewPassword">New Password</label>
                <input class="settings-input" type="password" id="userProfileNewPassword" name="new_password" placeholder="Leave blank to keep current">
              </div>
              <div class="settings-form-group">
                <label class="settings-label" for="userProfileConfirmPassword">Confirm New Password</label>
                <input class="settings-input" type="password" id="userProfileConfirmPassword" name="confirm_password" placeholder="Confirm new password">
              </div>
            </div>
            <div class="settings-actions">
              <button type="submit" class="settings-btn settings-btn-primary" id="userSettingsProfileSubmit">
                <span>Save Changes</span>
              </button>
            </div>
          </form>
        </div>
        <div class="settings-section" data-section="preferences">
          <h2 class="settings-title">Preferences</h2>
          <div id="userSettingsPreferencesAlert" class="settings-alert"></div>
          <form id="userSettingsPreferencesForm">
            <div class="settings-grid">
              <div class="settings-form-group">
                <label class="settings-label" for="userSettingDarkMode">Dark Mode</label>
                <input type="checkbox" id="userSettingDarkMode">
              </div>
              <div class="settings-form-group">
                <label class="settings-label" for="userSettingEyeCare">Eye Care Filter</label>
                <input type="checkbox" id="userSettingEyeCare">
              </div>
              <div class="settings-form-group">
                <label class="settings-label" for="userSettingNotifications">Notifications</label>
                <input type="checkbox" id="userSettingNotifications">
              </div>
            </div>
            <div class="settings-actions">
              <button type="button" class="settings-btn settings-btn-secondary" id="userSettingsResetBtn">Reset</button>
              <button type="submit" class="settings-btn settings-btn-primary" id="userSettingsPreferencesSubmit">
                <span>Save Preferences</span>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(overlay);
  return overlay;
}

function openUserSettingsModal() {
  const overlay = createUserSettingsModal();
  overlay.style.display = 'flex';
  requestAnimationFrame(() => {
    overlay.classList.add('active');
  });
  initializeSettings();
  loadUserSettingsProfile();
  initializeSettingsPreferences();
}

function closeUserSettingsModal() {
  const overlay = document.getElementById('userSettingsModalOverlay');
  if (!overlay) return;
  overlay.classList.remove('active');
  setTimeout(() => {
    overlay.style.display = 'none';
  }, 200);
}

function showSettingsTab(tabName) {
  const panels = document.querySelectorAll('#userSettingsModalOverlay .settings-section');
  panels.forEach(panel => {
    const panelSection = panel.getAttribute('data-section');
    if (panelSection === tabName) {
      panel.classList.add('active');
    } else {
      panel.classList.remove('active');
    }
  });

  const tabs = document.querySelectorAll('#userSettingsModalOverlay .settings-sidebar-item');
  tabs.forEach(tab => {
    const tabKey = tab.getAttribute('data-section');
    if (tabKey === tabName) {
      tab.classList.add('active');
    } else {
      tab.classList.remove('active');
    }
  });
}

function setSettingsAlert(element, type, message) {
  if (!element) return;
  element.className = `settings-alert ${type}`;
  element.textContent = message;
}

function initializeSettings() {
  const overlay = document.getElementById('userSettingsModalOverlay');
  if (!overlay) return;

  const closeBtn = overlay.querySelector('#userSettingsCloseBtn');
  if (closeBtn && !closeBtn.dataset.listenerAttached) {
    closeBtn.dataset.listenerAttached = 'true';
    closeBtn.addEventListener('click', function () {
      closeUserSettingsModal();
    });
  }

  overlay.addEventListener('click', function (event) {
    if (event.target === overlay) {
      closeUserSettingsModal();
    }
  });

  const sidebarItems = overlay.querySelectorAll('.settings-sidebar-item');
  sidebarItems.forEach(item => {
    if (item.dataset.listenerAttached) return;
    item.dataset.listenerAttached = 'true';
    item.addEventListener('click', function () {
      const section = this.getAttribute('data-section');
      if (section) showSettingsTab(section);
    });
  });

  showSettingsTab('profile');

  const profileForm = overlay.querySelector('#userSettingsProfileForm');
  if (profileForm && !profileForm.dataset.listenerAttached) {
    profileForm.dataset.listenerAttached = 'true';
    profileForm.addEventListener('submit', function (event) {
      event.preventDefault();
      submitUserSettingsProfile();
    });
  }

  const preferencesForm = overlay.querySelector('#userSettingsPreferencesForm');
  if (preferencesForm && !preferencesForm.dataset.listenerAttached) {
    preferencesForm.dataset.listenerAttached = 'true';
    preferencesForm.addEventListener('submit', function (event) {
      event.preventDefault();
      saveSettings();
    });
  }

  const resetBtn = overlay.querySelector('#userSettingsResetBtn');
  if (resetBtn && !resetBtn.dataset.listenerAttached) {
    resetBtn.dataset.listenerAttached = 'true';
    resetBtn.addEventListener('click', resetSettings);
  }
}

async function loadUserSettingsProfile() {
  const usernameInput = document.getElementById('userProfileUsername');
  const fullNameInput = document.getElementById('userProfileFullName');
  const emailInput = document.getElementById('userProfileEmail');
  const profileImagePreview = document.getElementById('userProfileImagePreview');
  const profilePictureInput = document.getElementById('userProfilePictureInput');
  const displayName = document.getElementById('userProfileDisplayName');

  if (usernameInput) usernameInput.value = '';
  if (fullNameInput) fullNameInput.value = '';
  if (emailInput) emailInput.value = '';

  const currentPassword = document.getElementById('userProfileCurrentPassword');
  const newPassword = document.getElementById('userProfileNewPassword');
  const confirmPassword = document.getElementById('userProfileConfirmPassword');
  if (currentPassword) currentPassword.value = '';
  if (newPassword) newPassword.value = '';
  if (confirmPassword) confirmPassword.value = '';

  if (profilePictureInput && profileImagePreview) {
    profilePictureInput.onchange = function (e) {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = function (ev) {
          profileImagePreview.src = ev.target.result;
        };
        reader.readAsDataURL(file);
      }
    };
  }

  try {
    const response = await fetch(getUserApiBasePath() + 'users.php?action=profile');
    const data = await response.json();
    if (data.status === 'success') {
      const profile = data.data.profile || {};
      if (usernameInput) usernameInput.value = profile.username || '';
      if (fullNameInput) fullNameInput.value = profile.full_name || '';
      if (emailInput) emailInput.value = profile.email || '';
      if (displayName) displayName.textContent = profile.full_name || profile.username || 'User';

      if (profile.profile_picture && profileImagePreview) {
        const fullPath = resolveUserPath(profile.profile_picture);
        profileImagePreview.src = fullPath + '?t=' + new Date().getTime();
      } else if (profileImagePreview) {
        profileImagePreview.src = resolveUserPath('assets/img/default.png');
      }
    }
  } catch (error) {
    console.error('Error loading profile:', error);
  }
}

async function submitUserSettingsProfile() {
  const form = document.getElementById('userSettingsProfileForm');
  const alertBox = document.getElementById('userSettingsProfileAlert');
  const submitBtn = document.getElementById('userSettingsProfileSubmit');

  if (!form) return;
  if (alertBox) {
    alertBox.className = 'settings-alert';
    alertBox.textContent = '';
  }

  const currentPassword = document.getElementById('userProfileCurrentPassword')?.value || '';
  const newPassword = document.getElementById('userProfileNewPassword')?.value || '';
  const confirmPassword = document.getElementById('userProfileConfirmPassword')?.value || '';

  if (!currentPassword && newPassword) {
    setSettingsAlert(alertBox, 'error', 'Current password is required to change password.');
    return;
  }

  if (newPassword && newPassword !== confirmPassword) {
    setSettingsAlert(alertBox, 'error', 'New passwords do not match.');
    return;
  }

  try {
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.innerHTML = '<span>Saving...</span>';
    }

    const formData = new FormData(form);
    const response = await fetch(getUserApiBasePath() + 'users.php?action=updateProfile', {
      method: 'POST',
      body: formData
    });

    const text = await response.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch (err) {
      data = { status: 'error', message: 'Unexpected response from server.' };
    }

    if (data.status === 'success') {
      setSettingsAlert(alertBox, 'success', data.message || 'Profile updated successfully.');
      const profilePicture = data.data?.profile_picture || null;
      const username = data.data?.username || null;
      if (username) {
        const displayName = document.getElementById('userProfileDisplayName');
        if (displayName) displayName.textContent = username;
      }

      if (profilePicture) {
        const fullPath = resolveUserPath(profilePicture) + '?t=' + new Date().getTime();
        const preview = document.getElementById('userProfileImagePreview');
        if (preview) preview.src = fullPath;
        const topnavAvatar = document.querySelector('.nav-user-menu .user-avatar img');
        if (topnavAvatar) topnavAvatar.src = fullPath;
        const sidebarAvatar = document.getElementById('sidebarProfileImage');
        if (sidebarAvatar) sidebarAvatar.src = fullPath;
      }

      const currentPasswordField = document.getElementById('userProfileCurrentPassword');
      const newPasswordField = document.getElementById('userProfileNewPassword');
      const confirmPasswordField = document.getElementById('userProfileConfirmPassword');
      if (currentPasswordField) currentPasswordField.value = '';
      if (newPasswordField) newPasswordField.value = '';
      if (confirmPasswordField) confirmPasswordField.value = '';
    } else {
      setSettingsAlert(alertBox, 'error', data.message || 'Failed to update profile.');
    }
  } catch (error) {
    setSettingsAlert(alertBox, 'error', 'Error updating profile.');
  } finally {
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.innerHTML = '<span>Save Changes</span>';
    }
  }
}

function initializeSettingsPreferences() {
  const darkModeToggle = document.getElementById('userSettingDarkMode');
  const eyeCareToggle = document.getElementById('userSettingEyeCare');
  const notificationsToggle = document.getElementById('userSettingNotifications');

  if (darkModeToggle) {
    const savedTheme = localStorage.getItem('theme');
    darkModeToggle.checked = savedTheme ? savedTheme === 'dark' : !!window.darkMode;
    if (!darkModeToggle.dataset.listenerAttached) {
      darkModeToggle.dataset.listenerAttached = 'true';
      darkModeToggle.addEventListener('change', function () {
        window.darkMode = this.checked;
        if (typeof updateTheme === 'function') {
          updateTheme();
          if (typeof updateThemeColor === 'function') updateThemeColor();
        } else {
          document.body.classList.toggle('dark', window.darkMode);
          document.body.classList.toggle('dark-mode', window.darkMode);
        }
        localStorage.setItem('theme', window.darkMode ? 'dark' : 'light');
        document.dispatchEvent(new CustomEvent('themeChanged', { detail: { darkMode: window.darkMode } }));
      });
    }
  }

  if (eyeCareToggle) {
    const savedEyeCare = localStorage.getItem('eyeCareEnabled');
    const isDark = window.darkMode || document.body.classList.contains('dark');
    eyeCareToggle.checked = savedEyeCare === 'true' && !isDark;
    if (!eyeCareToggle.dataset.listenerAttached) {
      eyeCareToggle.dataset.listenerAttached = 'true';
      eyeCareToggle.addEventListener('change', function () {
        const isDark = window.darkMode || document.body.classList.contains('dark');
        if (this.checked && isDark) {
          this.checked = false;
          localStorage.setItem('eyeCareEnabled', 'false');
          showNotification('Eye Care is only available in light mode', 'info');
          return;
        }
        if (this.checked) {
          if (typeof enableEyeCare === 'function') {
            enableEyeCare();
          } else {
            localStorage.setItem('eyeCareEnabled', 'true');
          }
        } else {
          if (typeof disableEyeCare === 'function') {
            disableEyeCare();
          } else {
            localStorage.setItem('eyeCareEnabled', 'false');
          }
        }
      });
    }
  }

  if (notificationsToggle) {
    const savedNotifications = localStorage.getItem('userNotificationsEnabled');
    notificationsToggle.checked = savedNotifications === null ? true : savedNotifications === 'true';
    if (!notificationsToggle.dataset.listenerAttached) {
      notificationsToggle.dataset.listenerAttached = 'true';
      notificationsToggle.addEventListener('change', function () {
        localStorage.setItem('userNotificationsEnabled', this.checked ? 'true' : 'false');
      });
    }
  }
}

function saveSettings() {
  const alertBox = document.getElementById('userSettingsPreferencesAlert');
  setSettingsAlert(alertBox, 'success', 'Preferences saved successfully.');
  showNotification('Preferences saved successfully!', 'success');
}

function resetSettings() {
  if (!confirm('Reset preferences to default?')) {
    return;
  }

  localStorage.removeItem('theme');
  localStorage.removeItem('eyeCareEnabled');
  localStorage.removeItem('userNotificationsEnabled');

  if (typeof initializeTheme === 'function') {
    initializeTheme();
  } else {
    window.darkMode = false;
    document.body.classList.remove('dark');
    document.body.classList.remove('dark-mode');
  }

  if (typeof disableEyeCare === 'function') {
    disableEyeCare();
  }

  initializeSettingsPreferences();
  const alertBox = document.getElementById('userSettingsPreferencesAlert');
  setSettingsAlert(alertBox, 'success', 'Preferences reset to default.');
  showNotification('Preferences reset to default', 'info');
}

// Notification system
function showNotification(message, type = 'info') {
  // Create notification element
  const notification = document.createElement('div');
  notification.className = `notification-toast notification-${type}`;
  notification.innerHTML = `
    <div class="notification-content">
      <i class='bx ${getNotificationIcon(type)}'></i>
      <span>${message}</span>
    </div>
    <button class="notification-close" onclick="this.parentElement.remove()">
      <i class='bx bx-x'></i>
    </button>
  `;

  // Add to body
  document.body.appendChild(notification);

  // Auto remove after 3 seconds
  setTimeout(() => {
    if (notification.parentElement) {
      notification.remove();
    }
  }, 3000);
}

function getNotificationIcon(type) {
  const icons = {
    success: 'bx-check-circle',
    error: 'bx-error-circle',
    warning: 'bx-error',
    info: 'bx-info-circle'
  };
  return icons[type] || icons.info;
}

// Initialize user dashboard
function initializeUserDashboard() {
  // Add event listeners for violation details buttons
  const viewDetailsButtons = document.querySelectorAll('.btn-view-details');
  viewDetailsButtons.forEach(button => {
    button.addEventListener('click', function () {
      showViolationDetails(this);
    });
  });

  if (typeof window.ensureDownloadModal !== 'function') {
      window.ensureDownloadModal = function() {
          let modal = document.getElementById('DownloadFormatModal');
          if (!modal) {
              modal = document.createElement('div');
              modal.id = 'DownloadFormatModal';
              modal.className = 'download-modal';
              modal.style.display = 'none';
              modal.innerHTML = '' +
                  '<div class="download-modal-overlay"></div>' +
                  '<div class="download-modal-container">' +
                  '  <div class="download-modal-header">' +
                  '    <h3>Select Download Format</h3>' +
                  '    <button class="close-btn"><i class="bx bx-x"></i></button>' +
                  '  </div>' +
                  '  <div class="download-modal-body">' +
                  '    <p>Please choose your preferred file format:</p>' +
                  '    <div class="download-options">' +
                  '      <button class="download-option" data-format="csv">' +
                  '        <i class="bx bxs-file-txt" style="color:#28a745;"></i>' +
                  '        <span>CSV</span>' +
                  '        <small>Spreadsheet compatible</small>' +
                  '      </button>' +
                  '      <button class="download-option" data-format="pdf">' +
                  '        <i class="bx bxs-file-pdf" style="color:#dc3545;"></i>' +
                  '        <span>PDF</span>' +
                  '        <small>Portable Document Format</small>' +
                  '      </button>' +
                  '      <button class="download-option" data-format="docx">' +
                  '        <i class="bx bxs-file-doc" style="color:#007bff;"></i>' +
                  '        <span>DOCX</span>' +
                  '        <small>Microsoft Word</small>' +
                  '      </button>' +
                  '    </div>' +
                  '  </div>' +
                  '</div>';
              document.body.appendChild(modal);
              const overlay = modal.querySelector('.download-modal-overlay');
              const closeBtn = modal.querySelector('.close-btn');
              const options = modal.querySelectorAll('.download-option');
              if (overlay) overlay.addEventListener('click', () => { if (typeof window.closeDownloadModal === 'function') window.closeDownloadModal(); });
              if (closeBtn) closeBtn.addEventListener('click', () => { if (typeof window.closeDownloadModal === 'function') window.closeDownloadModal(); });
              options.forEach(btn => btn.addEventListener('click', () => {
                  const fmt = btn.getAttribute('data-format');
                  if (typeof window.confirmDownload === 'function') {
                      window.confirmDownload(fmt);
                  }
              }));
          }
          if (typeof window.openDownloadModal !== 'function') {
              window.openDownloadModal = function() {
                  const m = document.getElementById('DownloadFormatModal');
                  if (m) {
                      m.style.display = 'flex';
                      setTimeout(() => m.classList.add('active'), 10);
                  }
              };
          }
          if (typeof window.closeDownloadModal !== 'function') {
              window.closeDownloadModal = function() {
                  const m = document.getElementById('DownloadFormatModal');
                  if (m) {
                      m.classList.remove('active');
                      setTimeout(() => m.style.display = 'none', 300);
                  }
              };
          }
          if (typeof window.confirmDownload !== 'function') {
              window.confirmDownload = function(format) {
                  if (typeof window.closeDownloadModal === 'function') window.closeDownloadModal();
                  setTimeout(() => {
                      if (window.downloadContext === 'dashboard') {
                          if (typeof window.downloadDashboardReport === 'function') {
                              window.downloadDashboardReport(format);
                          }
                      } else if (window.downloadContext === 'violations') {
                          if (typeof window.downloadCSV === 'function' || typeof window.downloadPDF === 'function' || typeof window.downloadDOCX === 'function') {
                              if (format === 'csv' && typeof downloadCSV === 'function' && window.userViolations) downloadCSV(window.userViolations, 'my_violations');
                              else if (format === 'pdf' && typeof downloadPDF === 'function' && window.userViolations) downloadPDF(window.userViolations, 'My Violation Report', 'my_violations');
                              else if (format === 'docx' && typeof downloadDOCX === 'function' && window.userViolations) downloadDOCX(window.userViolations, 'My Violation Report', 'my_violations');
                          }
                      }
                  }, 300);
              };
          }
      };
  }
  if (typeof window.ensureDownloadModal === 'function') {
      window.ensureDownloadModal();
  }

  // Dashboard Download Report
  const btnDashDownload = document.getElementById('btnDashDownloadReport');
  if (btnDashDownload) {
      console.log('✅ Found dashboard download button, attaching listener');
      // Remove old listeners to prevent duplicates if function runs multiple times
      const newBtn = btnDashDownload.cloneNode(true);
      btnDashDownload.parentNode.replaceChild(newBtn, btnDashDownload);
      
      newBtn.addEventListener('click', function(e) {
          e.preventDefault();
          console.log('🖱️ Dashboard download clicked');
          if (typeof window.ensureDownloadModal === 'function') {
              window.ensureDownloadModal();
          }
          
          if (window.userDashboardData && window.userDashboardData.violations) {
              // Trigger the modal
              if (typeof window.openDownloadModal === 'function') {
                  window.downloadContext = 'dashboard'; 
                  window.openDownloadModal();
              } else {
                  console.warn('Download modal functions not found, attempting to load script...');
                  loadScript('../app/assets/js/userViolations.js', () => {
                      if (typeof window.openDownloadModal === 'function') {
                          window.downloadContext = 'dashboard'; 
                          window.openDownloadModal();
                      } else {
                          console.error('Failed to load download functionality');
                          alert('Download functionality unavailable. Please refresh the page.');
                      }
                  });
              }
          } else {
              alert('Dashboard data is loading or empty. Please try again in a moment.');
          }
      });
  } else {
      console.warn('⚠️ Dashboard download button not found');
  }

  // Update violation counts and status (Safe call)
  if (typeof updateViolationStats === 'function') {
    try {
        updateViolationStats();
    } catch (e) {
        console.warn('Error updating violation stats:', e);
    }
  } else if (typeof window.updateViolationStats === 'function') {
      try {
        window.updateViolationStats();
      } catch (e) {
          console.warn('Error updating violation stats (window):', e);
      }
  } else {
      console.log('ℹ️ updateViolationStats function not available');
  }

  console.log('⚡ User dashboard initialized');
}

// Make this globally available so confirmDownload can call it
window.downloadDashboardReport = function(format) {
    const violations = window.userDashboardData.violations;
    if (!violations || violations.length === 0) {
        alert('No violations to download.');
        return;
    }

    const fmt = format.toLowerCase().trim();
    if (fmt === 'csv') {
        downloadCSV(violations, 'dashboard_report');
    } else if (fmt === 'pdf') {
        downloadPDF(violations, 'My Dashboard Report', 'dashboard_report');
    } else if (fmt === 'docx') {
        downloadDOCX(violations, 'My Dashboard Report', 'dashboard_report');
    }
};

if (typeof window.ensureDownloadModal !== 'function') {
    window.ensureDownloadModal = function() {
        let modal = document.getElementById('DownloadFormatModal');
        if (!modal) {
            modal = document.createElement('div');
            modal.id = 'DownloadFormatModal';
            modal.className = 'download-modal';
            modal.style.display = 'none';
            modal.innerHTML = '' +
                '<div class="download-modal-overlay"></div>' +
                '<div class="download-modal-container">' +
                '  <div class="download-modal-header">' +
                '    <h3>Select Download Format</h3>' +
                '    <button class="close-btn"><i class="bx bx-x"></i></button>' +
                '  </div>' +
                '  <div class="download-modal-body">' +
                '    <p>Please choose your preferred file format:</p>' +
                '    <div class="download-options">' +
                '      <button class="download-option" data-format="csv">' +
                '        <i class="bx bxs-file-txt" style="color:#28a745;"></i>' +
                '        <span>CSV</span>' +
                '        <small>Spreadsheet compatible</small>' +
                '      </button>' +
                '      <button class="download-option" data-format="pdf">' +
                '        <i class="bx bxs-file-pdf" style="color:#dc3545;"></i>' +
                '        <span>PDF</span>' +
                '        <small>Portable Document Format</small>' +
                '      </button>' +
                '      <button class="download-option" data-format="docx">' +
                '        <i class="bx bxs-file-doc" style="color:#007bff;"></i>' +
                '        <span>DOCX</span>' +
                '        <small>Microsoft Word</small>' +
                '      </button>' +
                '    </div>' +
                '  </div>' +
                '</div>';
            document.body.appendChild(modal);
            const overlay = modal.querySelector('.download-modal-overlay');
            const closeBtn = modal.querySelector('.close-btn');
            const options = modal.querySelectorAll('.download-option');
            if (overlay) overlay.addEventListener('click', () => { if (typeof window.closeDownloadModal === 'function') window.closeDownloadModal(); });
            if (closeBtn) closeBtn.addEventListener('click', () => { if (typeof window.closeDownloadModal === 'function') window.closeDownloadModal(); });
            options.forEach(btn => btn.addEventListener('click', () => {
                const fmt = btn.getAttribute('data-format');
                if (typeof window.confirmDownload === 'function') {
                    window.confirmDownload(fmt);
                }
            }));
        }
        if (typeof window.openDownloadModal !== 'function') {
            window.openDownloadModal = function() {
                const m = document.getElementById('DownloadFormatModal');
                if (m) {
                    m.style.display = 'flex';
                    setTimeout(() => m.classList.add('active'), 10);
                }
            };
        }
        if (typeof window.closeDownloadModal !== 'function') {
            window.closeDownloadModal = function() {
                const m = document.getElementById('DownloadFormatModal');
                if (m) {
                    m.classList.remove('active');
                    setTimeout(() => m.style.display = 'none', 300);
                }
            };
        }
        if (typeof window.confirmDownload !== 'function') {
            window.confirmDownload = function(format) {
                if (typeof window.closeDownloadModal === 'function') window.closeDownloadModal();
                setTimeout(() => {
                    if (window.downloadContext === 'dashboard') {
                        if (typeof window.downloadDashboardReport === 'function') {
                            window.downloadDashboardReport(format);
                        }
                    } else if (window.downloadContext === 'violations') {
                        if (format === 'csv' && typeof downloadCSV === 'function' && window.userViolations) downloadCSV(window.userViolations, 'my_violations');
                        else if (format === 'pdf' && typeof downloadPDF === 'function' && window.userViolations) downloadPDF(window.userViolations, 'My Violation Report', 'my_violations');
                        else if (format === 'docx' && typeof downloadDOCX === 'function' && window.userViolations) downloadDOCX(window.userViolations, 'My Violation Report', 'my_violations');
                    }
                }, 300);
            };
        }
    };
}

if (typeof document !== 'undefined' && !window.__dashDownloadDelegated) {
    document.addEventListener('click', function(e) {
        const btn = e.target && e.target.closest ? e.target.closest('#btnDashDownloadReport') : null;
        if (btn) {
            e.preventDefault();
            if (typeof window.ensureDownloadModal === 'function') {
                window.ensureDownloadModal();
            }
            window.downloadContext = 'dashboard';
            if (typeof window.openDownloadModal === 'function') {
                window.openDownloadModal();
            } else if (typeof window.downloadDashboardReport === 'function') {
                window.downloadDashboardReport('pdf');
            }
        }
    });
    window.__dashDownloadDelegated = true;
}

function downloadDashboardReport_OLD(violations) {
    if (!violations || violations.length === 0) {
        alert('No violations to download.');
        return;
    }

    // Ask user for format
    const format = prompt("Enter download format: csv, pdf, or docx", "pdf");
    if (!format) return;
    
    const fmt = format.toLowerCase().trim();
    if (fmt === 'csv') {
        downloadCSV(violations, 'dashboard_report');
    } else if (fmt === 'pdf') {
        downloadPDF(violations, 'My Dashboard Report', 'dashboard_report');
    } else if (fmt === 'docx') {
        downloadDOCX(violations, 'My Dashboard Report', 'dashboard_report');
    } else {
        alert('Invalid format. Please choose csv, pdf, or docx.');
    }
}

function downloadCSV(data, filenamePrefix) {
    const lines = [];
    const now = new Date();
    
    // Header Info
    lines.push('My Dashboard Report');
    lines.push('Generated,' + csvEscape(now.toLocaleString()));
    lines.push('');
    
    // Stats Summary
    if (window.userDashboardData && window.userDashboardData.stats) {
        const s = window.userDashboardData.stats;
        lines.push('Summary Stats');
        lines.push(['Active Violations', s.activeViolations || 0].map(csvEscape).join(','));
        lines.push(['Total Violations', data.length].map(csvEscape).join(','));
        lines.push('');
    }

    // Column Headers
    lines.push(['Case ID', 'Violation Type', 'Status', 'Date Reported'].map(csvEscape).join(','));

    // Data Rows
    data.forEach(v => {
        const type = v.violationType || v.violation_type || 'Unknown';
        const date = v.violationDate || v.violation_date || v.dateReported || v.created_at;
        const status = v.status || 'Unknown';
        
        lines.push([
            v.case_id || v.id,
            type,
            status,
            date
        ].map(csvEscape).join(','));
    });

    const csvContent = lines.join('\r\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const fileName = filenamePrefix + '_' + now.toISOString().slice(0, 10) + '.csv';
    
    if (typeof saveAs === 'function') {
        saveAs(blob, fileName);
    } else {
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }
}

async function downloadPDF(data, title, filenamePrefix) {
    if (!window.jspdf) {
        alert('PDF library not loaded. Please refresh the page.');
        return;
    }
    
    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();
    const now = new Date();

    // Title
    doc.setFontSize(18);
    doc.text(title, 14, 22);
    
    doc.setFontSize(11);
    doc.setTextColor(100);
    doc.text(`Generated on: ${now.toLocaleString()}`, 14, 30);

    // Stats Summary
    let startY = 40;
    if (window.userDashboardData && window.userDashboardData.stats) {
        const s = window.userDashboardData.stats;
        doc.setFontSize(12);
        doc.setTextColor(0);
        doc.text(`Active Violations: ${s.activeViolations || 0}`, 14, startY);
        doc.text(`Total Violations: ${data.length}`, 100, startY);
        startY += 15;
    }

    // Table Data
    const tableBody = data.map(v => [
        v.case_id || v.id,
        v.violationType || v.violation_type || 'Unknown',
        v.status || 'Unknown',
        v.violationDate || v.violation_date || v.dateReported || v.created_at
    ]);

    doc.autoTable({
        head: [['Case ID', 'Violation Type', 'Status', 'Date Reported']],
        body: tableBody,
        startY: startY,
        theme: 'grid',
        styles: { fontSize: 10, cellPadding: 3 },
        headStyles: { fillColor: [255, 193, 7], textColor: 50, fontStyle: 'bold' }
    });

    doc.save(`${filenamePrefix}_${now.toISOString().slice(0, 10)}.pdf`);
}

function downloadDOCX(data, title, filenamePrefix) {
    if (!window.docx) {
        alert('DOCX library not loaded. Please refresh the page.');
        return;
    }

    const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, HeadingLevel } = window.docx;
    const now = new Date();

    // Stats
    let statsParagraph = new Paragraph({});
    if (window.userDashboardData && window.userDashboardData.stats) {
        const s = window.userDashboardData.stats;
        statsParagraph = new Paragraph({
            children: [
                new TextRun({ text: `Active Violations: ${s.activeViolations || 0}`, bold: true }),
                new TextRun({ text: `\tTotal Violations: ${data.length}`, bold: true }),
            ],
            spacing: { after: 200 },
        });
    }

    // Table Header
    const tableHeader = new TableRow({
        children: [
            new TableCell({ children: [new Paragraph({ text: "Case ID", bold: true })] }),
            new TableCell({ children: [new Paragraph({ text: "Violation Type", bold: true })] }),
            new TableCell({ children: [new Paragraph({ text: "Status", bold: true })] }),
            new TableCell({ children: [new Paragraph({ text: "Date Reported", bold: true })] }),
        ],
    });

    // Table Rows
    const tableRows = data.map(v => {
        return new TableRow({
            children: [
                new TableCell({ children: [new Paragraph(String(v.case_id || v.id))] }),
                new TableCell({ children: [new Paragraph(v.violationType || v.violation_type || 'Unknown')] }),
                new TableCell({ children: [new Paragraph(v.status || 'Unknown')] }),
                new TableCell({ children: [new Paragraph(v.violationDate || v.violation_date || v.dateReported || v.created_at)] }),
            ],
        });
    });

    const doc = new Document({
        sections: [{
            properties: {},
            children: [
                new Paragraph({
                    text: title,
                    heading: HeadingLevel.HEADING_1,
                    spacing: { after: 200 },
                }),
                new Paragraph({
                    children: [
                        new TextRun({
                            text: `Generated on: ${now.toLocaleString()}`,
                            italics: true,
                            color: "666666",
                        }),
                    ],
                    spacing: { after: 400 },
                }),
                statsParagraph,
                new Table({
                    rows: [tableHeader, ...tableRows],
                    width: {
                        size: 100,
                        type: WidthType.PERCENTAGE,
                    },
                }),
            ],
        }],
    });

    Packer.toBlob(doc).then(blob => {
        saveAs(blob, `${filenamePrefix}_${now.toISOString().slice(0, 10)}.docx`);
    });
}

function csvEscape(value) {
    if (value === null || value === undefined) return '';
    const str = String(value);
    if (/[",\n]/.test(str)) {
        return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
}

// Show violation details
function showViolationDetails(button) {
  const row = button.closest('tr');
  const violationType = row.querySelector('.violation-info span').textContent;
  const date = row.querySelector('td:first-child').textContent;

  showNotification(`Viewing details for ${violationType} on ${date}`, 'info');
  // Here you can implement a modal or detailed view
}

// Update violation statistics
function updateViolationStats() {
  // This would typically fetch data from an API
  // For now, we'll use mock data
  const stats = {
    activeViolations: 0,
    totalViolations: 3,
    status: 'Good',
    daysClean: 7
  };

  // Update the stats display
  const activeViolations = document.querySelector('.box-info li:nth-child(1) h3');
  const totalViolations = document.querySelector('.box-info li:nth-child(2) h3');
  const status = document.querySelector('.box-info li:nth-child(3) h3');
  const daysClean = document.querySelector('.box-info li:nth-child(4) h3');

  if (activeViolations) activeViolations.textContent = stats.activeViolations;
  if (totalViolations) totalViolations.textContent = stats.totalViolations;
  if (status) status.textContent = stats.status;
  if (daysClean) daysClean.textContent = stats.daysClean;
}

// Chart initialization function
function initializeCharts() {
  // Check if Chart.js is available
  if (typeof Chart === 'undefined') {
    console.warn('Chart.js is not loaded');
    return;
  }

  // Violation Types Pie Chart
  const violationTypesCtx = document.getElementById('violationTypesChart');
  if (violationTypesCtx) {
    new Chart(violationTypesCtx, {
      type: 'pie',
      data: {
        labels: ['Academic Dishonesty', 'Disruptive Behavior', 'Dress Code', 'Late Attendance', 'Other'],
        datasets: [{
          data: [25, 20, 15, 30, 10],
          backgroundColor: [
            '#FFD700',
            '#FFCE26',
            '#FD7238',
            '#DB504A',
            '#AAAAAA'
          ],
          borderWidth: 2,
          borderColor: '#ffffff'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              padding: 20,
              usePointStyle: true,
              font: {
                size: 12
              }
            }
          }
        }
      }
    });
  }

  // Department Violations Bar Chart
  const departmentViolationsCtx = document.getElementById('departmentViolationsChart');
  if (departmentViolationsCtx) {
    new Chart(departmentViolationsCtx, {
      type: 'bar',
      data: {
        labels: ['Engineering', 'Business', 'Education', 'Arts', 'Science'],
        datasets: [{
          label: 'Violations',
          data: [45, 32, 28, 19, 15],
          backgroundColor: [
            '#FFD700',
            '#FFCE26',
            '#FD7238',
            '#DB504A',
            '#AAAAAA'
          ],
          borderRadius: 8,
          borderSkipped: false,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(0,0,0,0.1)'
            }
          },
          x: {
            grid: {
              display: false
            }
          }
        }
      }
    });
  }

  // Monthly Trends Line Chart
  const monthlyTrendsCtx = document.getElementById('monthlyTrendsChart');
  if (monthlyTrendsCtx) {
    new Chart(monthlyTrendsCtx, {
      type: 'line',
      data: {
        labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
        datasets: [{
          label: 'Violations',
          data: [12, 19, 15, 25, 22, 30, 28, 35, 32, 28, 24, 20],
          borderColor: '#FFD700',
          backgroundColor: 'rgba(255, 215, 0, 0.1)',
          tension: 0.4,
          fill: true,
          borderWidth: 3,
          pointBackgroundColor: '#FFD700',
          pointBorderColor: '#ffffff',
          pointBorderWidth: 2,
          pointRadius: 6,
          pointHoverRadius: 8
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(0,0,0,0.1)'
            }
          },
          x: {
            grid: {
              color: 'rgba(0,0,0,0.1)'
            }
          }
        }
      }
    });
  }
}

// Toggle sidebar - Logo click
const logoToggle = document.querySelector('.sidebar-toggle-logo');
if (logoToggle) {
  logoToggle.addEventListener('click', function (e) {
    e.stopPropagation();
    sidebar.classList.toggle('hide');
    localStorage.setItem('sidebarHidden', sidebar.classList.contains('hide'));
  });
}

// Toggle sidebar with close icon
const closeIcon = document.querySelector('#sidebar .sidebar-close-icon');
if (closeIcon) {
  closeIcon.addEventListener('click', function (e) {
    e.stopPropagation();
    sidebar.classList.add('hide');
    localStorage.setItem('sidebarHidden', true);
  });
}

// Search button functionality for mobile
searchButton.addEventListener('click', function (e) {
  if (window.innerWidth < 576) {
    e.preventDefault();
    searchForm.classList.toggle('show');
    searchButtonIcon.classList.toggle('bx-x', searchForm.classList.contains('show'));
    searchButtonIcon.classList.toggle('bx-search', !searchForm.classList.contains('show'));
  }
});

// Theme switcher: dark mode
if (switchMode) {
  // Store globally for theme.js
  window.switchMode = switchMode;
  
  switchMode.addEventListener('change', function () {
    // Use theme.js toggleTheme if available, otherwise use local implementation
    if (typeof toggleTheme === 'function') {
      toggleTheme();
    } else {
      window.darkMode = this.checked;
      if (this.checked) {
        document.body.classList.add('dark');
      } else {
        document.body.classList.remove('dark');
      }
      localStorage.setItem('theme', this.checked ? 'dark' : 'light');
      
      // Dispatch theme change event
      document.dispatchEvent(new CustomEvent('themeChanged', { 
        detail: { darkMode: this.checked } 
      }));
    }
  });
}

// Eye Care toggle - only active in light mode
// Initialize after a short delay to ensure eyeCare.js is loaded
const initEyeCareToggle = () => {
  const eyeCareToggle = document.getElementById('eye-care-toggle');
  const eyeCareLabel = document.querySelector('label[for="eye-care-toggle"]');
  
  if (eyeCareToggle && typeof toggleEyeCare === 'function') {
    // Add change event listener
    eyeCareToggle.addEventListener('change', function () {
      toggleEyeCare();
    });
    console.log('✅ Eye Care toggle initialized');
  } else if (eyeCareToggle) {
    // Retry if toggleEyeCare function not yet available
    setTimeout(initEyeCareToggle, 100);
  }
  
  // Also add click handler to label for better compatibility
  if (eyeCareLabel) {
    eyeCareLabel.style.cursor = 'pointer';
    eyeCareLabel.addEventListener('click', function (e) {
      // Let the label naturally toggle the checkbox via 'for' attribute
      // Then manually trigger the toggle function
      setTimeout(() => {
        if (typeof toggleEyeCare === 'function') {
          toggleEyeCare();
        }
      }, 10);
    });
  }
};

// Initialize after page load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initEyeCareToggle);
} else {
  setTimeout(initEyeCareToggle, 100);
}

// Update eye care button state on theme change
document.addEventListener('themeChanged', function(e) {
  setTimeout(() => {
    if (typeof updateEyeCareButtonState === 'function') {
      updateEyeCareButtonState();
    }
  }, 100);
});

// Settings icon in navbar (for user dashboard, show alert since no settings page)
const navSettings = document.querySelector('.nav-settings');
if (navSettings) {
  navSettings.addEventListener('click', function (e) {
    e.preventDefault();
    openUserSettingsModal();
  });
}

// Logout button event listener (backup to onclick)
const logoutButton = document.querySelector('.sidebar-logout a.logout');
if (logoutButton) {
  logoutButton.addEventListener('click', function (e) {
    e.preventDefault();
    console.log('Logout button clicked via event listener');
    logout();
  });
  console.log('✅ Logout button event listener attached');
} else {
  console.log('❌ Logout button not found');
}

// Responsive adjustments on load
if (window.innerWidth < 768) {
  sidebar.classList.add('hide');
}
if (window.innerWidth > 576) {
  searchButtonIcon.classList.replace('bx-x', 'bx-search');
  searchForm.classList.remove('show');
}

// Responsive adjustments on resize
window.addEventListener('resize', function () {
  if (this.innerWidth > 576) {
    searchButtonIcon.classList.replace('bx-x', 'bx-search');
    searchForm.classList.remove('show');
  }
});

// Load sidebar profile from database
function loadSidebarProfile() {
  const sidebarUsername = document.getElementById('sidebarUsername');
  const sidebarProfileImage = document.getElementById('sidebarProfileImage');
  
  if (!sidebarUsername && !sidebarProfileImage) return;
  
  // Get student_id_code from cookies or window.STUDENT_ID
  const cookies = document.cookie.split(';').reduce((acc, cookie) => {
    const [key, value] = cookie.trim().split('=');
    acc[key] = value;
    return acc;
  }, {});
  
  const studentIdCode = window.STUDENT_ID || cookies.student_id_code;
  if (!studentIdCode) {
    console.warn('⚠️ Student ID not found for sidebar profile');
    return;
  }
  
  // Get student data from API
  const apiBase = (function() {
    const pathParts = window.location.pathname.split('/').filter(p => p);
    if (pathParts.length > 0) return '/' + pathParts[0] + '/api/';
    return '/api/';
  })();
  
  fetch(apiBase + 'students.php')
    .then(response => response.json())
    .then(data => {
      const students = data.data || data.students || [];
      // Find student by student_id (the actual student ID string like "2023-0195")
      const student = students.find(s => {
        const sId = s.student_id || s.studentId || '';
        return sId && sId.toString() === studentIdCode.toString();
      });
      
      if (student) {
        // Update username
        if (sidebarUsername) {
          const firstName = student.first_name || student.firstName || '';
          const lastName = student.last_name || student.lastName || '';
          const fullName = `${firstName} ${lastName}`.trim() || 'Student';
          sidebarUsername.textContent = fullName;
          
          // Also update topnav username
          const topnavUsername = document.querySelector('.nav-user-menu .user-name');
          if (topnavUsername) {
            topnavUsername.textContent = fullName;
          }
        }
        
        // Update profile image
        if (sidebarProfileImage) {
          if (student.avatar && student.avatar.trim() !== '') {
            let avatarUrl = student.avatar;
            if (!avatarUrl.startsWith('http') && !avatarUrl.startsWith('/')) {
              avatarUrl = '../app/assets/img/students/' + avatarUrl;
            }
            sidebarProfileImage.src = avatarUrl;
            sidebarProfileImage.onerror = function() {
              this.src = '../app/assets/img/default.png';
            };
            
            // Also update topnav avatar
            const topnavAvatar = document.querySelector('.nav-user-menu .user-avatar img');
            if (topnavAvatar) {
              topnavAvatar.src = avatarUrl;
              topnavAvatar.onerror = function() {
                this.src = '../app/assets/img/default.png';
              };
            }
          } else {
            sidebarProfileImage.src = '../app/assets/img/default.png';
            
            // Also update topnav avatar
            const topnavAvatar = document.querySelector('.nav-user-menu .user-avatar img');
            if (topnavAvatar) {
              topnavAvatar.src = '../app/assets/img/default.png';
            }
          }
        }
      } else {
        console.warn('⚠️ Student not found for student_id:', studentIdCode);
      }
    })
    .catch(error => {
      console.error('Error loading sidebar profile:', error);
    });
}

// Load sidebar profile on page load
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', loadSidebarProfile);
} else {
  setTimeout(loadSidebarProfile, 100);
}
