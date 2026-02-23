<?php
require_once __DIR__ . '/../../core/View.php';
// Get user profile image or default
$userImage = View::asset('img/default.png');
if (file_exists(__DIR__ . '/../../assets/img/user.jpg')) {
    $userImage = View::asset('img/user.jpg');
}

$username = $_SESSION['username'] ?? 'User';
$role = $_SESSION['role'] ?? 'user';

// Use passed student data if available
if (isset($student) && $student) {
    // Construct full name
    $fullName = trim(($student['first_name'] ?? '') . ' ' . ($student['last_name'] ?? ''));
    if (!empty($fullName)) {
        $username = $fullName;
    }
    
    // Set avatar
    if (!empty($student['avatar'])) {
        // If avatar is a URL, use it directly
        if (filter_var($student['avatar'], FILTER_VALIDATE_URL)) {
            $userImage = $student['avatar'];
        } else {
            // Use View::asset to resolve the path
            // The StudentModel returns paths starting with app/assets/..., which View::asset handles
            $userImage = View::asset($student['avatar']);
        }
    }
}
?>
<!-- TOP NAVIGATION -->
<nav class="top-nav">
  <!-- Logo Section -->
  <div class="nav-brand">
    <img src="<?= View::asset('img/default.png') ?>" alt="Osas Logo" class="nav-logo">
    <span class="nav-title" title="Office of Student Affairs and Services">E-Osas</span>
    <span class="nav-title-compact" title="Office of Student Affairs and Services">OSAS</span>
  </div>

  <!-- Navigation Menu -->
  <ul class="nav-menu">
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

  <!-- User Section -->
  <div class="nav-user">
    <!-- Search -->
    <div class="nav-search">
      <form action="#" class="search-form">
        <div class="search-input-wrapper">
          <i class='bx bx-search'></i>
          <input type="search" placeholder="Search..." class="search-input">
        </div>
      </form>
    </div>
    
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
      <button class="notification-btn">
        <i class='bx bx-bell'></i>
        <span class="notification-badge"><?= isset($notificationCount) ? $notificationCount : '1' ?></span>
      </button>
    </div>

    <!-- User Menu -->
    <div class="nav-user-menu">
      <div class="user-avatar">
        <img src="<?= $userImage ?>" alt="User Avatar">
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
  </div>
</nav>
<!-- TOP NAVIGATION -->
