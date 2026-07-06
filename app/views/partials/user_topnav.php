<?php
require_once __DIR__ . '/../../core/View.php';

$username = $_SESSION['username'] ?? 'User';
$role = $_SESSION['role'] ?? 'user';

// Use passed student data if available
$hasProfilePic = false;
$userImage = '';
if (isset($student) && $student) {
    // Construct full name
    $fullName = trim(($student['first_name'] ?? '') . ' ' . ($student['last_name'] ?? ''));
    if (!empty($fullName)) {
        $username = $fullName;
    }
    // Check for avatar (ignore generated ui-avatars URLs and default.png)
    if (!empty($student['avatar'])) {
        $avatar = $student['avatar'];
        $isGenerated = (strpos($avatar, 'ui-avatars.com') !== false);
        $isDefault = (strpos($avatar, 'default.png') !== false);
        if (!$isGenerated && !$isDefault) {
            if (filter_var($avatar, FILTER_VALIDATE_URL)) {
                $userImage = $avatar;
            } else {
                $userImage = View::asset($avatar);
            }
            $hasProfilePic = true;
        }
    }
}

// Also check session profile picture
if (!$hasProfilePic && isset($_SESSION['profile_picture']) && !empty($_SESSION['profile_picture'])) {
    $profilePic = $_SESSION['profile_picture'];
    if (strpos($profilePic, 'public/') === 0) {
        $userImage = View::url($profilePic) . '?t=' . time();
    } else {
        $userImage = View::asset($profilePic);
    }
    $hasProfilePic = true;
}

// Generate initials from the user's name (first letter of first & last name)
$nameParts = explode(' ', trim($username));
$initials = strtoupper(substr($nameParts[0], 0, 1));
if (count($nameParts) > 1) {
    $initials .= strtoupper(substr(end($nameParts), 0, 1));
}
?>
<!-- Mobile Sidebar Overlay -->
<div class="mobile-sidebar-overlay" id="mobileSidebarOverlay"></div>

<!-- Mobile Nav Sidebar -->
<aside class="mobile-nav-sidebar" id="mobileNavSidebar">
  <div class="mobile-sidebar-header">
    <div class="mobile-sidebar-brand">
      <img src="<?= View::asset('img/default.png') ?>" alt="E-OSAS" class="mobile-sidebar-logo">
      <span class="mobile-sidebar-title">E-OSAS</span>
    </div>
    <button class="mobile-sidebar-close" id="mobileSidebarClose" aria-label="Close sidebar">
      <i class='bx bx-x'></i>
    </button>
  </div>

  <!-- Mobile Sidebar — Profile Section (mobile only) -->
  <div class="mobile-sidebar-profile">
    <div class="msb-avatar-wrap">
      <?php if ($hasProfilePic): ?>
        <img src="<?= $userImage ?>" alt="Profile" class="msb-avatar-img"
             onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
        <span class="msb-avatar-initials" style="display:none;"><?= htmlspecialchars($initials) ?></span>
      <?php else: ?>
        <span class="msb-avatar-initials"><?= htmlspecialchars($initials) ?></span>
      <?php endif; ?>
    </div>
    <div class="msb-user-name"><?= htmlspecialchars($username) ?></div>
    <div class="msb-user-role"><?= htmlspecialchars(ucfirst($role)) ?></div>
  </div>

  <ul class="mobile-sidebar-menu" id="mobileSidebarMenu">
    <li class="mobile-sidebar-item active" data-page="user-page/user_dashcontent">
      <a href="#" data-page="user-page/user_dashcontent">
        <i class='bx bxs-dashboard'></i><span>My Dashboard</span>
      </a>
    </li>
    <li class="mobile-sidebar-item" data-page="user-page/my_violations">
      <a href="#" data-page="user-page/my_violations">
        <i class='bx bxs-shield-x'></i><span>My Violations</span>
      </a>
    </li>
    <li class="mobile-sidebar-item" data-page="user-page/announcements">
      <a href="#" data-page="user-page/announcements">
        <i class='bx bxs-megaphone'></i><span>Announcements</span>
      </a>
    </li>
    <div class="mobile-sidebar-divider"></div>
    <li class="mobile-sidebar-item">
      <a href="#" onclick="logout(); return false;">
        <i class='bx bx-log-out' style="color: #ef4444;"></i><span style="color: #ef4444;">Sign Out</span>
      </a>
    </li>
  </ul>
</aside>

<!-- TOP NAVIGATION -->
<nav class="top-nav">
  <!-- Logo Section — click to open mobile sidebar -->
  <div class="nav-brand" id="mobileMenuToggle" role="button" aria-label="Open navigation menu">
    <img src="<?= View::asset('img/default.png') ?>" alt="Osas Logo" class="nav-logo">
    <span class="nav-title" title="Office of Student Affairs and Services">E-Osas</span>
    <span class="nav-title-compact" title="Office of Student Affairs and Services">OSAS</span>
  </div>

  <!-- Desktop Navigation Menu (centre) -->
  <ul class="nav-menu nav-menu--desktop">
    <li class="nav-item active">
      <a href="#" data-page="user-page/user_dashcontent" class="nav-link">
        <i class='bx bxs-dashboard'></i>
        <span>My Dashboard</span>
      </a>
    </li>
    <li class="nav-item">
      <a href="#" data-page="user-page/my_violations" class="nav-link">
        <i class='bx bxs-shield-x'></i>
        <span>My Violations</span>
      </a>
    </li>
    <li class="nav-item">
      <a href="#" data-page="user-page/announcements" class="nav-link">
        <i class='bx bxs-megaphone'></i>
        <span>Announcements</span>
      </a>
    </li>
  </ul>

  <!-- User Section (right) -->
  <div class="nav-user">
    <!-- Dark Mode Toggle -->
    <div class="nav-theme-toggle">
      <label class="theme-switch">
        <input type="checkbox" id="switch-mode">
        <span class="slider">
          <i class='bx bx-sun sun-icon'></i>
          <i class='bx bx-moon moon-icon'></i>
        </span>
      </label>
    </div>

    <!-- Notifications -->
    <div class="nav-notifications">
      <button class="notification-btn" id="notificationBtn">
        <i class='bx bx-bell'></i>
        <span class="notification-badge">0</span>
      </button>
      
      <!-- Notification Dropdown -->
      <div class="notification-dropdown" id="notificationDropdown">
        <div class="notif-header">
          <h3>Notifications</h3>
          <a href="#" id="markAllRead">Mark all as read</a>
        </div>
        <p style="padding:8px 12px;margin:0;font-size:12px;border-bottom:1px solid rgba(0,0,0,.08);">
          <a href="#" id="enablePhoneAlerts" style="color:#D4AF37;font-weight:600;">Enable alerts (in app)</a>
        </p>
        <div class="notif-list" id="notificationList">
          <div class="no-notifications">
            <i class='bx bx-bell-off'></i>
            <p>No new notifications</p>
          </div>
        </div>
        <div class="notif-footer">
          <a href="#" class="view-all" data-page="user-page/my_violations">View all violations</a>
        </div>
      </div>
    </div>

    <!-- User Menu -->
    <div class="nav-user-menu">
      <div class="user-avatar">
        <span class="user-avatar-ring">
          <?php if ($hasProfilePic): ?>
            <img src="<?= $userImage ?>" alt="User Avatar" class="user-avatar-img"
                 onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
            <span class="user-avatar-initials" style="display:none;"><?= htmlspecialchars($initials) ?></span>
          <?php else: ?>
            <span class="user-avatar-initials"><?= htmlspecialchars($initials) ?></span>
          <?php endif; ?>
        </span>
        <span class="user-name"><?= htmlspecialchars($username) ?></span>
        <i class='bx bx-chevron-down'></i>
      </div>
      
      <!-- Dropdown Menu -->
      <div class="user-dropdown">
        <a href="#" class="dropdown-item settings-item settings-link">
          <i class='bx bx-cog'></i>
          <span>Settings</span>
        </a>
        <div class="dropdown-divider"></div>
        <a href="#" class="dropdown-item logout" onclick="logout()">
          <i class='bx bx-log-out'></i>
          <span>Logout</span>
        </a>
      </div>
    </div>
    <!-- Mobile-only settings gear button -->
    <button class="mobile-topnav-settings-btn settings-link" id="mobileTopnavSettingsBtn" aria-label="Settings" title="Settings">
      <i class='bx bxs-cog'></i>
    </button>

  </div>
</nav>
<!-- /TOP NAVIGATION -->

<script>
(function() {
  /* ── User avatar dropdown ── */
  var avatar = document.querySelector('.user-avatar');
  var dropdown = document.querySelector('.user-dropdown');
  if (avatar && dropdown) {
    avatar.addEventListener('click', function(e) {
      e.stopPropagation();
      dropdown.classList.toggle('show');
    });
    document.addEventListener('click', function() {
      dropdown.classList.remove('show');
    });
  }

  /* ── Mobile Sidebar Toggle ── */
  var toggle   = document.getElementById('mobileMenuToggle');
  var sidebar  = document.getElementById('mobileNavSidebar');
  var overlay  = document.getElementById('mobileSidebarOverlay');
  var closeBtn = document.getElementById('mobileSidebarClose');

  function openSidebar() {
    sidebar.classList.add('open');
    overlay.classList.add('open');
    document.body.style.overflow = 'hidden';
  }

  function closeSidebar() {
    sidebar.classList.remove('open');
    overlay.classList.remove('open');
    document.body.style.overflow = '';
  }

  /* Only activate toggle on mobile (≤768px) */
  if (toggle) toggle.addEventListener('click', function() {
    if (window.innerWidth <= 768) openSidebar();
  });
  if (closeBtn) closeBtn.addEventListener('click', closeSidebar);
  if (overlay)  overlay.addEventListener('click',  closeSidebar);

  /* Close sidebar if screen is resized to desktop */
  window.addEventListener('resize', function() {
    if (window.innerWidth > 768) closeSidebar();
  });

  /* Close sidebar and update active when a link is tapped, then load the page */
  var sidebarLinks = document.querySelectorAll('#mobileSidebarMenu a[data-page]');
  sidebarLinks.forEach(function(link) {
    link.addEventListener('click', function(e) {
      e.preventDefault();
      var page = this.getAttribute('data-page');
      closeSidebar();
      document.querySelectorAll('#mobileSidebarMenu .mobile-sidebar-item').forEach(function(item) {
        item.classList.remove('active');
      });
      this.closest('.mobile-sidebar-item').classList.add('active');
      /* Navigate — loadContent is defined in user_dashboard.js */
      if (page && typeof loadContent === 'function') {
        loadContent(page);
      }
    });
  });

  /* Sync active state when page changes */
  document.addEventListener('pageChanged', function(e) {
    var page = e.detail && e.detail.page;
    if (!page) return;
    document.querySelectorAll('#mobileSidebarMenu .mobile-sidebar-item').forEach(function(item) {
      item.classList.toggle('active', item.getAttribute('data-page') === page);
    });
  });
})();
</script>
