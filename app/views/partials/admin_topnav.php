<?php
require_once __DIR__ . '/../../core/View.php';

$username = $_SESSION['full_name'] ?? $_SESSION['username'] ?? 'Admin';
$role     = $_SESSION['role'] ?? 'admin';

// Only admin and OSAS Staff can access these restricted pages
$canAccessRestricted = in_array($role, ['admin', 'OSAS Staff']);

// Announcements are accessible to all staff roles
$canAccessAnnouncements = in_array($role, ['admin', 'OSAS Staff', 'CSC Officer', 'Officer', 'Faculty Member']);

// Generate initials from the user's name (first letter of first & last name)
$nameParts = explode(' ', trim($username));
$initials = strtoupper(substr($nameParts[0], 0, 1));
if (count($nameParts) > 1) {
    $initials .= strtoupper(substr(end($nameParts), 0, 1));
}

// Check if user has a profile picture
$hasProfilePic = false;
$userImage = '';
if (isset($_SESSION['profile_picture']) && !empty($_SESSION['profile_picture'])) {
    $profilePic = $_SESSION['profile_picture'];
    if (strpos($profilePic, 'public/') === 0) {
        $userImage = View::url($profilePic) . '?t=' . time();
    } else {
        $userImage = View::asset($profilePic);
    }
    $hasProfilePic = true;
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
             onerror="this.outerHTML='<span class=\'msb-avatar-initials\'><?= htmlspecialchars($initials) ?></span>';">
      <?php else: ?>
        <span class="msb-avatar-initials"><?= htmlspecialchars($initials) ?></span>
      <?php endif; ?>
    </div>
    <div class="msb-user-name"><?= htmlspecialchars($username) ?></div>
    <div class="msb-user-role"><?= htmlspecialchars(ucfirst($role)) ?></div>
  </div>

  <ul class="mobile-sidebar-menu" id="mobileSidebarMenu">
    <li class="mobile-sidebar-item" data-page="admin_page/dashcontent">
      <a href="#" data-page="admin_page/dashcontent">
        <i class='bx bxs-dashboard'></i><span>Dashboard</span>
      </a>
    </li>
    <?php if ($canAccessRestricted): ?>
    <li class="mobile-sidebar-item" data-page="admin_page/Department">
      <a href="#" data-page="admin_page/Department">
        <i class='bx bxs-building'></i><span>Department</span>
      </a>
    </li>
    <li class="mobile-sidebar-item" data-page="admin_page/Sections">
      <a href="#" data-page="admin_page/Sections">
        <i class='bx bxs-layer'></i><span>Sections</span>
      </a>
    </li>
    <li class="mobile-sidebar-item" data-page="admin_page/Students">
      <a href="#" data-page="admin_page/Students">
        <i class='bx bxs-group'></i><span>Students</span>
      </a>
    </li>
    <?php else: ?>
    <li class="mobile-sidebar-item nav-restricted">
      <a href="#" class="nav-disabled" onclick="return false;" title="Restricted">
        <i class='bx bxs-building'></i><span>Department</span>
        <i class='bx bxs-lock-alt' style="margin-left:auto;font-size:0.85rem;opacity:0.5;"></i>
      </a>
    </li>
    <li class="mobile-sidebar-item nav-restricted">
      <a href="#" class="nav-disabled" onclick="return false;" title="Restricted">
        <i class='bx bxs-layer'></i><span>Sections</span>
        <i class='bx bxs-lock-alt' style="margin-left:auto;font-size:0.85rem;opacity:0.5;"></i>
      </a>
    </li>
    <li class="mobile-sidebar-item nav-restricted">
      <a href="#" class="nav-disabled" onclick="return false;" title="Restricted">
        <i class='bx bxs-group'></i><span>Students</span>
        <i class='bx bxs-lock-alt' style="margin-left:auto;font-size:0.85rem;opacity:0.5;"></i>
      </a>
    </li>
    <?php endif; ?>
    <li class="mobile-sidebar-item" data-page="admin_page/Violations">
      <a href="#" data-page="admin_page/Violations">
        <i class='bx bxs-shield-x'></i><span>Violations</span>
      </a>
    </li>
    <?php if ($canAccessRestricted): ?>
    <li class="mobile-sidebar-item" data-page="admin_page/Reports">
      <a href="#" data-page="admin_page/Reports">
        <i class='bx bxs-file'></i><span>Reports</span>
      </a>
    </li>
    <?php else: ?>
    <li class="mobile-sidebar-item nav-restricted">
      <a href="#" class="nav-disabled" onclick="return false;" title="Restricted">
        <i class='bx bxs-file'></i><span>Reports</span>
        <i class='bx bxs-lock-alt' style="margin-left:auto;font-size:0.85rem;opacity:0.5;"></i>
      </a>
    </li>
    <?php endif; ?>
    <?php if ($canAccessAnnouncements): ?>
    <li class="mobile-sidebar-item" data-page="admin_page/Announcements">
      <a href="#" data-page="admin_page/Announcements">
        <i class='bx bxs-megaphone'></i><span>Announcements</span>
      </a>
    </li>
    <?php else: ?>
    <li class="mobile-sidebar-item nav-restricted">
      <a href="#" class="nav-disabled" onclick="return false;" title="Restricted">
        <i class='bx bxs-megaphone'></i><span>Announcements</span>
        <i class='bx bxs-lock-alt' style="margin-left:auto;font-size:0.85rem;opacity:0.5;"></i>
      </a>
    </li>
    <?php endif; ?>
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

  <!-- Brand — click to toggle mobile sidebar -->
  <div class="nav-brand" id="mobileMenuToggle" role="button" aria-label="Open navigation menu">
    <i class='bx bx-menu mobile-menu-icon'></i>
    <img src="<?= View::asset('img/default.png') ?>" alt="E-OSAS" class="nav-logo">
    <span class="nav-title">E-OSAS</span>
  </div>

  <!-- Nav links -->
  <ul class="nav-menu">
    <li class="nav-item">
      <a href="#" data-page="admin_page/dashcontent" class="nav-link" title="Dashboard">
        <i class='bx bxs-dashboard'></i><span>Dashboard</span>
      </a>
    </li>
    <li class="nav-item<?= !$canAccessRestricted ? ' nav-restricted' : '' ?>">
      <?php if ($canAccessRestricted): ?>
        <a href="#" data-page="admin_page/Department" class="nav-link" title="Department">
          <i class='bx bxs-building'></i><span>Department</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-link nav-disabled" title="Access restricted to Admin and OSAS Staff only" onclick="return false;">
          <i class='bx bxs-building'></i><span>Department</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
    <li class="nav-item<?= !$canAccessRestricted ? ' nav-restricted' : '' ?>">
      <?php if ($canAccessRestricted): ?>
        <a href="#" data-page="admin_page/Sections" class="nav-link" title="Sections">
          <i class='bx bxs-layer'></i><span>Sections</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-link nav-disabled" title="Access restricted to Admin and OSAS Staff only" onclick="return false;">
          <i class='bx bxs-layer'></i><span>Sections</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
    <li class="nav-item<?= !$canAccessRestricted ? ' nav-restricted' : '' ?>">
      <?php if ($canAccessRestricted): ?>
        <a href="#" data-page="admin_page/Students" class="nav-link" title="Students">
          <i class='bx bxs-group'></i><span>Students</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-link nav-disabled" title="Access restricted to Admin and OSAS Staff only" onclick="return false;">
          <i class='bx bxs-group'></i><span>Students</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
    <li class="nav-item">
      <a href="#" data-page="admin_page/Violations" class="nav-link" title="Violations">
        <i class='bx bxs-shield-x'></i><span>Violations</span>
      </a>
    </li>
    <li class="nav-item<?= !$canAccessRestricted ? ' nav-restricted' : '' ?>">
      <?php if ($canAccessRestricted): ?>
        <a href="#" data-page="admin_page/Reports" class="nav-link" title="Reports">
          <i class='bx bxs-file'></i><span>Reports</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-link nav-disabled" title="Access restricted to Admin and OSAS Staff only" onclick="return false;">
          <i class='bx bxs-file'></i><span>Reports</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
    <li class="nav-item<?= !$canAccessAnnouncements ? ' nav-restricted' : '' ?>">
      <?php if ($canAccessAnnouncements): ?>
        <a href="#" data-page="admin_page/Announcements" class="nav-link" title="Announcements">
          <i class='bx bxs-megaphone'></i><span>Announcements</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-link nav-disabled" title="Access restricted" onclick="return false;">
          <i class='bx bxs-megaphone'></i><span>Announcements</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
  </ul>

  <!-- Right controls -->
  <div class="nav-user">

    <!-- Dark-mode pill toggle -->
    <label class="tn-theme-pill" title="Toggle Dark Mode">
      <input type="checkbox" id="switch-mode-top" hidden>
      <span class="tn-pill-track">
        <span class="tn-pill-thumb"></span>
        <i class='bx bx-sun  tn-icon tn-sun'></i>
        <i class='bx bx-moon tn-icon tn-moon'></i>
      </span>
    </label>

    <!-- Notification bell -->
    <div class="nav-notifications">
      <button class="notification-btn" id="notifBtn" aria-label="Notifications">
        <i class='bx bx-bell'></i>
        <span class="notification-badge" id="notifBadge">0</span>
      </button>
      <div id="notifModal" class="notif-modal">
        <div class="notif-modal-content">
          <div class="notif-modal-header">
            <h3><i class='bx bxs-bell-ring'></i> Notifications</h3>
            <button class="notif-close-btn" aria-label="Close">&times;</button>
          </div>
          <div class="notif-modal-body" id="notifList">
            <div class="notif-loading">Loading notifications...</div>
          </div>
          <div class="notif-modal-footer">
            <button class="notif-view-all" onclick="loadContent('admin_page/Violations')">
              View All Violations <i class='bx bx-right-arrow-alt'></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- User profile pill -->
    <div class="tn-user-pill" id="tnUserPill">
      <span class="tn-avatar-ring">
        <?php if ($hasProfilePic): ?>
          <img src="<?= $userImage ?>" alt="Avatar" class="tn-avatar-img"
               onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
          <span class="tn-avatar-initials" style="display:none;"><?= htmlspecialchars($initials) ?></span>
        <?php else: ?>
          <span class="tn-avatar-initials"><?= htmlspecialchars($initials) ?></span>
        <?php endif; ?>
      </span>
      <span class="tn-user-name"><?= htmlspecialchars($username) ?></span>
      <i class='bx bx-chevron-down tn-chevron'></i>
      <div class="tn-user-dropdown" id="tnUserDropdown">
        <div class="tn-dropdown-header">
          <?php if ($hasProfilePic): ?>
            <img src="<?= $userImage ?>" alt="Avatar" class="tn-dropdown-avatar"
                 onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
            <span class="tn-dropdown-avatar-initials" style="display:none;"><?= htmlspecialchars($initials) ?></span>
          <?php else: ?>
            <span class="tn-dropdown-avatar-initials"><?= htmlspecialchars($initials) ?></span>
          <?php endif; ?>
          <div class="tn-dropdown-info">
            <span class="tn-dropdown-name"><?= htmlspecialchars($username) ?></span>
            <span class="tn-dropdown-role"><?= ucfirst($role) ?></span>
          </div>
        </div>
        <div class="tn-dropdown-divider"></div>
        <a href="#" class="tn-dropdown-item settings-link">
          <i class='bx bxs-cog'></i> Settings
        </a>
        <div class="tn-dropdown-divider"></div>
        <a href="#" class="tn-dropdown-item tn-logout" onclick="logout()">
          <i class='bx bx-log-out'></i> Sign Out
        </a>
      </div>
    </div>

    <!-- Mobile-only profile avatar button (top-right on mobile) -->
    <div class="mobile-profile-btn" id="mobileProfileBtn" role="button" aria-label="Profile menu">
      <div class="mpb-ring">
        <?php if ($hasProfilePic): ?>
          <img src="<?= $userImage ?>" alt="Profile" class="mpb-img"
               onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
          <span class="mpb-initials" style="display:none;"><?= htmlspecialchars($initials) ?></span>
        <?php else: ?>
          <span class="mpb-initials"><?= htmlspecialchars($initials) ?></span>
        <?php endif; ?>
      </div>

      <!-- Mini dropdown -->
      <div class="mpb-dropdown" id="mobileProfileDropdown">
        <div class="mpb-dropdown-header">
          <div class="mpb-hd-ring">
            <?php if ($hasProfilePic): ?>
              <img src="<?= $userImage ?>" alt="Profile" class="mpb-hd-img"
                   onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
              <span class="mpb-hd-initials" style="display:none;"><?= htmlspecialchars($initials) ?></span>
            <?php else: ?>
              <span class="mpb-hd-initials"><?= htmlspecialchars($initials) ?></span>
            <?php endif; ?>
          </div>
          <div class="mpb-hd-info">
            <div class="mpb-hd-name"><?= htmlspecialchars($username) ?></div>
            <div class="mpb-hd-role"><?= htmlspecialchars(ucfirst($role)) ?></div>
          </div>
        </div>
        <div class="mpb-dropdown-divider"></div>
        <a href="#" class="mpb-dropdown-item settings-link">
          <i class='bx bxs-cog'></i> Settings
        </a>
        <div class="mpb-dropdown-divider"></div>
        <a href="#" class="mpb-dropdown-item mpb-logout" onclick="logout(); return false;">
          <i class='bx bx-log-out'></i> Sign Out
        </a>
      </div>
    </div>

  </div>
</nav>
<!-- /TOP NAVIGATION -->

<script>
(function () {
  /* ── Mobile Profile Button Dropdown ── */
  var mobileProfileBtn = document.getElementById('mobileProfileBtn');
  if (mobileProfileBtn) {
    mobileProfileBtn.addEventListener('click', function(e) {
      if (e.target.closest('.mpb-dropdown')) return; // let dropdown items bubble normally
      e.stopPropagation();
      mobileProfileBtn.classList.toggle('open');
    });
    document.addEventListener('click', function() {
      mobileProfileBtn.classList.remove('open');
    });
  }

  /* ── User pill dropdown ── */
  var pill     = document.getElementById('tnUserPill');
  var dropdown = document.getElementById('tnUserDropdown');
  if (pill && dropdown) {
    pill.addEventListener('click', function (e) {
      if (e.target.closest('.tn-user-dropdown')) return; // let dropdown items bubble normally
      e.stopPropagation();
      dropdown.classList.toggle('show');
      pill.classList.toggle('open');
    });
    document.addEventListener('click', function () {
      dropdown.classList.remove('show');
      pill.classList.remove('open');
    });
  }

  /* ── Mobile Sidebar Toggle ── */
  var toggle  = document.getElementById('mobileMenuToggle');
  var sidebar = document.getElementById('mobileNavSidebar');
  var overlay = document.getElementById('mobileSidebarOverlay');
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

  /* Close sidebar when a nav link is clicked and load the page */
  var sidebarLinks = document.querySelectorAll('#mobileSidebarMenu a[data-page]');
  sidebarLinks.forEach(function(link) {
    link.addEventListener('click', function(e) {
      e.preventDefault();
      var page = this.getAttribute('data-page');
      closeSidebar();
      /* Sync active state */
      document.querySelectorAll('#mobileSidebarMenu .mobile-sidebar-item').forEach(function(item) {
        item.classList.remove('active');
      });
      this.closest('.mobile-sidebar-item').classList.add('active');
      /* Navigate — loadContent is defined in dashboard.js */
      if (page && typeof loadContent === 'function') {
        loadContent(page);
      }
    });
  });

  /* Sync mobile sidebar active state with desktop nav */
  document.addEventListener('pageChanged', function(e) {
    var page = e.detail && e.detail.page;
    if (!page) return;
    document.querySelectorAll('#mobileSidebarMenu .mobile-sidebar-item').forEach(function(item) {
      var itemPage = item.getAttribute('data-page');
      item.classList.toggle('active', itemPage === page);
    });
  });
})();
</script>