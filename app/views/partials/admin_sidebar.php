<?php
require_once __DIR__ . '/../../core/View.php';
// Get user profile image or default
$userImage = View::asset('img/user.jpg');
if (!file_exists(__DIR__ . '/../../assets/img/user.jpg')) {
    $userImage = View::asset('img/default.png');
}
$username = $_SESSION['full_name'] ?? ($_SESSION['username'] ?? 'Admin');
$role = $_SESSION['role'] ?? 'admin';

// Only admin and OSAS Staff can access these restricted pages
$canAccessRestricted = in_array($role, ['admin', 'OSAS Staff']);

// Announcements are accessible to all staff roles
$canAccessAnnouncements = in_array($role, ['admin', 'OSAS Staff', 'CSC Officer', 'Officer', 'Faculty Member']);
?>
<!-- SIDEBAR -->
<section id="sidebar">
  <!-- Sidebar Header with Logo -->
  <div class="sidebar-header">
    <div class="sidebar-logo-section">
      <img src="<?= View::asset('img/default.png') ?>" alt="Osas Logo" class="sidebar-logo sidebar-toggle-logo" style="cursor: pointer;">
      <span class="sidebar-title">E-Osas</span>
      <i class='bx bx-chevron-left sidebar-close-icon'></i>
    </div>
    <div class="sidebar-search-section">
      <form action="#" class="sidebar-search-form">
        <div class="sidebar-form-input">
          <i class='bx bx-search'></i>
          <input type="search" placeholder="Search..." class="sidebar-search-input">
        </div>
      </form>
    </div>
  </div>

  <ul class="side-menu top">
    <li class="active">
      <a href="#" data-page="admin_page/dashcontent">
        <i class='bx bxs-dashboard'></i>
        <span class="text">Dashboard</span>
      </a>
    </li>
    <li<?= !$canAccessRestricted ? ' class="nav-restricted"' : '' ?>>
      <?php if ($canAccessRestricted): ?>
        <a href="#" data-page="admin_page/Department">
          <i class='bx bxs-building'></i>
          <span class="text">Department</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-disabled" title="Access restricted to Admin and OSAS Staff only" onclick="return false;">
          <i class='bx bxs-building'></i>
          <span class="text">Department</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
    <li<?= !$canAccessRestricted ? ' class="nav-restricted"' : '' ?>>
      <?php if ($canAccessRestricted): ?>
        <a href="#" data-page="admin_page/Sections">
          <i class='bx bxs-layer'></i>
          <span class="text">Sections</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-disabled" title="Access restricted to Admin and OSAS Staff only" onclick="return false;">
          <i class='bx bxs-layer'></i>
          <span class="text">Sections</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
    <li<?= !$canAccessRestricted ? ' class="nav-restricted"' : '' ?>>
      <?php if ($canAccessRestricted): ?>
        <a href="#" data-page="admin_page/Students">
          <i class='bx bxs-group'></i>
          <span class="text">Students</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-disabled" title="Access restricted to Admin and OSAS Staff only" onclick="return false;">
          <i class='bx bxs-group'></i>
          <span class="text">Students</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
    <li>
      <a href="#" data-page="admin_page/Violations">
        <i class='bx bxs-shield-x'></i>
        <span class="text">Violations</span>
      </a>
    </li>
    <li<?= !$canAccessRestricted ? ' class="nav-restricted"' : '' ?>>
      <?php if ($canAccessRestricted): ?>
        <a href="#" data-page="admin_page/Reports">
          <i class='bx bxs-file'></i>
          <span class="text">Reports</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-disabled" title="Access restricted to Admin and OSAS Staff only" onclick="return false;">
          <i class='bx bxs-file'></i>
          <span class="text">Reports</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
    <li<?= !$canAccessAnnouncements ? ' class="nav-restricted"' : '' ?>>
      <?php if ($canAccessAnnouncements): ?>
        <a href="#" data-page="admin_page/Announcements">
          <i class='bx bxs-megaphone'></i>
          <span class="text">Announcements</span>
        </a>
      <?php else: ?>
        <a href="#" class="nav-disabled" title="Access restricted" onclick="return false;">
          <i class='bx bxs-megaphone'></i>
          <span class="text">Announcements</span>
          <i class='bx bxs-lock-alt nav-lock-icon'></i>
        </a>
      <?php endif; ?>
    </li>
  </ul>
  <!-- Logout Fixed at Bottom -->
  <div class="sidebar-logout">
    <a href="#" class="logout" onclick="logout()">
      <i class='bx bx-log-out'></i>
      <span class="text">Logout</span>
    </a>
  </div>
</section>
<!-- SIDEBAR -->


