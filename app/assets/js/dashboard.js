// DOM Elements
const allSideMenu = document.querySelectorAll('#sidebar .side-menu.top li a, .top-nav .nav-menu .nav-link');
const menuBar = document.querySelector('.sidebar-toggle-logo') || document.querySelector('#sidebar .sidebar-close-icon') || document.querySelector('#sidebar .sidebar-menu-toggle') || document.querySelector('#content nav .bx.bx-menu');
const sidebar = document.getElementById('sidebar');
const sidebarCloseIcon = document.querySelector('#sidebar .sidebar-close-icon');
const searchButton = document.querySelector('#content nav form .form-input button');
const searchButtonIcon = document.querySelector('#content nav form .form-input button .bx');
const searchForm = document.querySelector('#content nav form');
const switchMode = document.getElementById('switch-mode');
const mainContent = document.getElementById('main-content');

// Global state
window.darkMode = true;

// Load default content (dashboard)
document.addEventListener('DOMContentLoaded', function () {
    console.log('🚀 Dashboard Framework initializing...');

    // Check if user is authenticated
    checkAuthentication();

    // Initialize theme from localStorage or system preference
    initializeTheme();

    // Sync theme toggle states
    syncThemeToggles();

    // Load default dashboard content
    loadContent('admin_page/dashcontent');



    // Set dashboard as active by default
    const dashboardLink = document.querySelector('[data-page="admin_page/dashcontent"]');
    if (dashboardLink) {
        dashboardLink.parentElement.classList.add('active');
    }

    // Initialize service worker for PWA
    initializeServiceWorker();

    // Initialize core event listeners
    initializeEventListeners();

    console.log('✅ Dashboard Framework initialized successfully');
});

// Sync theme toggle states
function syncThemeToggles() {
    const topNavToggle = document.getElementById('switch-mode-top');
    const oldToggle = document.getElementById('switch-mode');
    
    // Check current theme state
    const isDarkMode = document.body.classList.contains('dark');
    
    // Sync both toggles
    if (topNavToggle) {
        topNavToggle.checked = isDarkMode;
    }
    if (oldToggle) {
        oldToggle.checked = isDarkMode;
    }
}

/**
 * Update active navigation item based on the current page
 */
function updateActiveNavItem(page) {
    if (!allSideMenu) return;
    
    allSideMenu.forEach(item => {
        const itemPage = item.getAttribute('data-page');
        const li = item.parentElement;
        
        if (itemPage === page) {
            li.classList.add('active');
        } else {
            li.classList.remove('active');
        }
    });
}

// Core Functions ==========================================================

// Privilege Check Helper
function isMainAdmin() {
    const sessionStr = localStorage.getItem('userSession');
    if (!sessionStr) {
        console.log('❌ No userSession found in localStorage');
        return false;
    }
    try {
        const session = JSON.parse(sessionStr);
        // Debug: Log the session to help identify the user
        console.log('🔍 Checking privileges for session user:', session);
        
        // Check both session.username (from new login.js) and session.name (as fallback)
        const mainAdmins = ['admin_demo', 'adminOsas@colegio.edu', 'adminOsas'];
        
        // If session.username is available, check it
        if (session.username && mainAdmins.includes(session.username)) {
            return true;
        }
        
        // If session.name is available and matches, check it (as a fallback)
        if (session.name && mainAdmins.includes(session.name)) {
            return true;
        }
        
        console.log('⚠️ User is not recognized as a Main Admin');
        return false;
    } catch (e) {
        console.error('❌ Error parsing session in isMainAdmin:', e);
        return false;
    }
}

// Path Resolution Helper
function getProjectRoot() {
    const path = window.location.pathname;
    // Fallback: assume first segment is project name
    const parts = path.split('/');
    if (parts.length > 1 && parts[1]) {
        // Check if parts[1] is a common directory like 'app' or 'public'
        // If so, we might be at root
        if (parts[1] === 'app' || parts[1] === 'public' || parts[1] === 'api') {
            return '';
        }
        return '/' + parts[1];
    }
    return '';
}

function resolvePath(relativePath) {
    const root = getProjectRoot();
    
    // If path is already absolute (starts with http or /), return it
    if (relativePath.startsWith('http') || relativePath.startsWith('/')) {
        return relativePath;
    }
    
    // Remove leading ./ or ../
    relativePath = relativePath.replace(/^(\.\/|\.\.\/)+/, '');
    
    // Handle specific directories
    if (relativePath.startsWith('public/')) {
        return root + '/' + relativePath;
    }
    
    // If path starts with assets/, assume app/assets/
    if (relativePath.startsWith('assets/')) {
        return root + '/app/' + relativePath;
    }
    
    // Default fallback
    return root + '/' + relativePath;
}

// Initialize service worker for PWA
function initializeServiceWorker() {
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('../sw.js')
            .then(registration => {
                console.log('✅ Service Worker registered:', registration);
            })
            .catch(error => {
                console.log('❌ Service Worker registration failed:', error);
            });
    }
}

// Enhanced authentication check
function checkAuthentication() {
    // Check if PHP session is valid (cookies exist)
    const hasCookies = document.cookie.includes('user_id') && document.cookie.includes('role');
    
    if (hasCookies) {
        console.log('✅ PHP session cookies found, authentication valid');
        // Try to get localStorage session for UI updates
        const userSession = localStorage.getItem('userSession');
        if (userSession) {
            try {
                const session = JSON.parse(userSession);
                updateUserInfo(session);
                console.log('✅ Admin authenticated:', session.name, 'Role:', session.role);
            } catch (error) {
                console.warn('⚠️ Could not parse localStorage session, but cookies are valid');
            }
        }
        return; // Don't redirect if cookies exist
    }

    // Fallback to localStorage check
    const userSession = localStorage.getItem('userSession');

    if (!userSession) {
        console.log('❌ No user session found, redirecting to login...');
        window.location.href = '../index.php';
        return;
    }

    try {
        const session = JSON.parse(userSession);

        // Check session expiration
        if (session.expires && new Date() > new Date(session.expires)) {
            console.log('❌ Session expired, redirecting to login...');
            localStorage.removeItem('userSession');
            window.location.href = '../index.php';
            return;
        }

        // Check if user role is correct for this dashboard
        if (session.role !== 'admin') {
            console.log(`❌ Invalid role: ${session.role}, redirecting...`);
            if (session.role === 'user') {
                window.location.href = '../includes/user_dashboard.php';
            } else {
                window.location.href = '../index.php';
            }
            return;
        }

        // Update user info in the interface
        updateUserInfo(session);

        console.log('✅ Admin authenticated:', session.name, 'Role:', session.role);

    } catch (error) {
        console.error('❌ Error parsing user session:', error);
        localStorage.removeItem('userSession');
        window.location.href = '../index.php';
    }
}

// Enhanced user info update
function updateUserInfo(session) {
    // Update profile name if element exists (Top Nav and Sidebar)
    const profileNames = document.querySelectorAll('.profile-name, .user-name, .nav-user-menu .user-name');
    profileNames.forEach(el => {
        el.textContent = session.name || session.full_name || 'Admin';
    });

    // Update profile role if element exists
    const profileRoles = document.querySelectorAll('.profile-role, .user-role');
    profileRoles.forEach(el => {
        el.textContent = session.role;
    });

    // Update profile picture if exists
    const profilePics = document.querySelectorAll('.profile-photo, .user-avatar img');
    if (session.avatar || session.profile_picture) {
        const avatarPath = resolvePath(session.avatar || session.profile_picture);
        profilePics.forEach(img => {
            img.src = avatarPath;
        });
    }
}

// Enhanced logout function
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
    console.log('👋 User logging out...');

    // Clear all client-side storage
    localStorage.removeItem('userSession');
    sessionStorage.removeItem('userSession');

        // Delete all authentication cookies on client side
        document.cookie = 'user_id=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
        document.cookie = 'username=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
        document.cookie = 'role=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
        document.cookie = 'student_id=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';
        document.cookie = 'student_id_code=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;';

        // Call server-side logout to clear session/cookies, then redirect to login
        fetch('/OSAS_WEB/api/logout.php', { method: 'POST', credentials: 'include' })
            .finally(() => { window.location.href = '/OSAS_WEB/login_page.php'; });
}

// Enhanced content loading with error handling and loading states
function loadContent(page) {
    // Update active navigation item
    updateActiveNavItem(page);

    // Show loading state
    mainContent.innerHTML = `
    <div class="loading-state">
      <div class="spinner"></div>
      <p>Loading ${page.replace('admin_page/', '').replace(/_/g, ' ')}...</p>
    </div>
  `;

    // Add loading styles if not exists
    if (!document.querySelector('#loading-styles')) {
        const styles = document.createElement('style');
        styles.id = 'loading-styles';
        styles.textContent = `
      .loading-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 50px;
        text-align: center;
      }
      .spinner {
        border: 4px solid #f3f3f3;
        border-top: 4px solid #ffb84fff;
        border-radius: 50%;
        width: 50px;
        height: 50px;
        animation: spin 1s linear infinite;
        margin-bottom: 20px;
      }
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
    `;
        document.head.appendChild(styles);
    }

    const xhr = new XMLHttpRequest();
    // Load from app/views/loader.php instead of pages/
    xhr.open('GET', `../app/views/loader.php?view=${page}`, true);
    xhr.timeout = 10000; // 10 second timeout

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
                            const existingScript = document.querySelector(`script[src="${src}"]`);
                            if (existingScript) {
                                console.log('Script already loaded:', src);
                                resolve();
                                return;
                            }
                            const newScript = document.createElement('script');
                            newScript.src = src;
                            newScript.onload = () => {
                                console.log('Script loaded successfully:', src);
                                resolve();
                            };
                            newScript.onerror = (error) => {
                                console.error('Failed to load script:', src, error);
                                reject(error);
                            };
                            document.body.appendChild(newScript);
                        } else {
                            // Inline script
                            const newScript = document.createElement('script');
                            newScript.textContent = script.textContent;
                            document.body.appendChild(newScript);
                            console.log('Inline script executed');
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
                };
                
                loadScriptsSequentially();
            } else {
                mainContent.innerHTML = response;
            }

            // Ensure PWA theme is applied to new content
            updateThemeColor();

            // Initialize module JS
            initializeModule(page);

            // Initialize dashboard data if dashboard page is loaded
            if (page === 'admin_page/dashcontent') {
                // Reset data loaded flag for new content
                if (typeof window !== 'undefined') {
                    window.dashboardDataLoaded = false;
                }
                
                // Wait a bit longer for content to be fully rendered
                setTimeout(() => {
                    if (typeof initDashboardData === 'function') {
                        console.log('🔄 Calling initDashboardData for dashcontent...');
                        // Reset the init flag to allow re-initialization
                        if (window.initDashboardDataAttempted !== undefined) {
                            window.initDashboardDataAttempted = false;
                        }
                        initDashboardData();
                    } else if (window.dashboardDataInstance) {
                        console.log('🔄 Using existing dashboardDataInstance...');
                        window.dashboardDataInstance.loadAllData().catch(error => {
                            console.error('❌ Error loading dashboard data:', error);
                        });
                    } else {
                        console.warn('⚠️ initDashboardData function not found, trying to create instance...');
                        // Try to create instance if it doesn't exist
                        if (typeof DashboardData !== 'undefined') {
                            window.dashboardDataInstance = new DashboardData();
                            setTimeout(() => {
                                window.dashboardDataInstance.loadAllData().catch(error => {
                                    console.error('❌ Error loading dashboard data:', error);
                                });
                            }, 500);
                        }
                    }
                }, 600);
            }

            console.log(`✅ ${page} loaded successfully`);

        } else if (this.status === 404) {
            mainContent.innerHTML = `
        <div class="error-state">
          <h2>Page not found</h2>
          <p>The requested page could not be found.</p>
          <button onclick="loadContent('admin_page/dashcontent')" class="btn-primary">
            Return to Dashboard
          </button>
        </div>
      `;
        }
    };

    xhr.onerror = function () {
        mainContent.innerHTML = `
      <div class="error-state">
        <h2>Error loading page</h2>
        <p>Please check your internet connection and try again.</p>
        <button onclick="loadContent('admin_page/dashcontent')" class="btn-primary">
          Return to Dashboard
        </button>
      </div>
    `;
    };

    xhr.ontimeout = function () {
        mainContent.innerHTML = `
      <div class="error-state">
        <h2>Request timeout</h2>
        <p>The page took too long to load. Please try again.</p>
        <button onclick="loadContent('admin_page/dashcontent')" class="btn-primary">
          Return to Dashboard
        </button>
      </div>
    `;
    };

    xhr.send();
}

// Module initializer function
// Module initializer function - UPDATED VERSION
function initializeModule(page) {
    // Always initialize modals for every page
    if (typeof initializeModals === 'function') {
        initializeModals();
    }

    // Initialize module-specific code
    const moduleMap = {
        'dashcontent': 'initDashboardModule',
        'department': 'initDepartmentModule',
        'students': 'initStudentsModule',
        'sections': 'initSectionsModule',
        'violations': 'initViolationsModule',  // This should match your violations.js function name
        'reports': 'initReportsModule',
        'users': 'initUsersModule',
        'settings': 'initSettingsModule',
        'announcements': 'initAnnouncementModule'
    };

    const moduleName = page.toLowerCase().replace('admin_page/', '');
    const initFunctionName = moduleMap[moduleName];

    console.log(`🛠 Attempting to initialize: ${moduleName}`);
    console.log(`🔍 Looking for function: ${initFunctionName}`);

    // Check if function exists in global scope
    if (initFunctionName && typeof window[initFunctionName] === 'function') {
        console.log(`✅ Found ${initFunctionName}, initializing...`);
        try {
            window[initFunctionName]();
        } catch (error) {
            console.error(`❌ Error initializing ${moduleName}:`, error);
        }
    } else {
        console.warn(`⚠️ ${initFunctionName} not found for ${moduleName}`);
        loadModuleScript(moduleName);
    }
}

let settingsModalOverlay = null;
let settingsModalInitialized = false;

function initializeModals() {
    if (!settingsModalInitialized) {
        createSettingsModal();
        settingsModalInitialized = true;
    }
}

function createSettingsModal() {
    if (settingsModalOverlay) {
        return;
    }

    const existing = document.getElementById('settingsModalOverlay');
    if (existing) {
        settingsModalOverlay = existing;
        attachSettingsModalEvents();
        return;
    }

    const overlay = document.createElement('div');
    overlay.id = 'settingsModalOverlay';
    overlay.className = 'settings-modal-overlay';
    const defaultAvatar = resolvePath('assets/img/default.png');
    const userAvatar = resolvePath('assets/img/user.jpg');
    
    // Check privileges
    const isMain = isMainAdmin();

    overlay.innerHTML = `
        <div class="settings-modal admin-settings-modal">
            <aside class="settings-sidebar">
                <div class="settings-sidebar-header">Settings</div>
                <div class="settings-sidebar-list">
                    <button type="button" class="settings-sidebar-item active" data-section="profile">
                        <i class='bx bx-id-card'></i>
                        <span>Profile</span>
                    </button>
                    <button type="button" class="settings-sidebar-item" data-section="admins">
                        <i class='bx bx-user-circle'></i>
                        <span>Admin accounts</span>
                    </button>
                    <button type="button" class="settings-sidebar-item" data-section="users">
                        <i class='bx bx-group'></i>
                        <span>User Accounts</span>
                    </button>
                    ${isMain ? `
                    <button type="button" class="settings-sidebar-item" data-section="archive">
                        <i class='bx bx-archive'></i>
                        <span>Archive</span>
                    </button>
                    <button type="button" class="settings-sidebar-item" data-section="export">
                        <i class='bx bx-data'></i>
                        <span>Export Database</span>
                    </button>
                    <button type="button" class="settings-sidebar-item" data-section="systemlogs">
                        <i class='bx bx-history'></i>
                        <span>System Logs</span>
                    </button>
                    ` : ''}
                </div>
            </aside>
            <div class="settings-content">
                <button type="button" class="settings-close-btn" id="settingsModalCloseBtn">
                    <i class='bx bx-x'></i>
                </button>

                <div class="settings-section active" data-section="profile">
                    <h3 class="settings-section-title">My Profile</h3>
                    <p class="settings-section-description">
                        Manage your account settings and profile information.
                    </p>
                    <div id="settingsProfileAlert" class="settings-alert"></div>
                    <form id="settingsProfileForm" enctype="multipart/form-data">
                        
                        <!-- Profile Header -->
                        <div class="settings-profile-header">
                            <div class="profile-upload-container">
                                <img id="profileImagePreview" class="profile-image-preview" src="${userAvatar}" onerror="this.src='${defaultAvatar}'" alt="Profile Picture">
                                <label for="profilePictureInput" class="profile-upload-button">
                                    <i class='bx bx-camera'></i>
                                </label>
                                <input type="file" id="profilePictureInput" name="profile_picture" accept="image/*" style="display: none;">
                            </div>
                            <div class="profile-info-text">
                                <h4 id="profileDisplayName">Administrator</h4>
                                <p>Manage your account details and security settings. Click the camera icon to update your profile photo.</p>
                            </div>
                        </div>

                        <div class="settings-grid">
                            <div class="settings-form-group">
                                <label class="settings-label" for="profileFullName">Full Name</label>
                                <input class="settings-input" type="text" id="profileFullName" name="full_name" placeholder="Your full name">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="profileUsername">Username</label>
                                <input class="settings-input" type="text" id="profileUsername" name="username" placeholder="Your username">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="profileCurrentPassword">Current Password</label>
                                <input class="settings-input" type="password" id="profileCurrentPassword" name="current_password" placeholder="Required only if changing password">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="profileNewPassword">New Password (Optional)</label>
                                <input class="settings-input" type="password" id="profileNewPassword" name="new_password" placeholder="Leave blank to keep current">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="profileConfirmPassword">Confirm New Password</label>
                                <input class="settings-input" type="password" id="profileConfirmPassword" name="confirm_password" placeholder="Confirm new password">
                            </div>
                        </div>
                        <div class="settings-actions">
                            <button type="submit" class="settings-btn settings-btn-primary" id="settingsProfileSubmit">
                                <span>Save Changes</span>
                            </button>
                        </div>
                    </form>
                </div>
                
                <div class="settings-section" data-section="admins">
                    <div class="settings-header-group">
                        <div class="settings-header-text">
                            <h3 class="settings-section-title">Admin accounts</h3>
                            <p class="settings-section-description">
                                ${isMain ? 'Create and manage administrators.' : 'View administrator accounts.'}
                            </p>
                        </div>
                        <div class="settings-table-controls">
                            <div class="settings-search-wrapper">
                                <i class='bx bx-search'></i>
                                <input type="text" id="adminSearch" class="settings-search-input" placeholder="Search admins...">
                            </div>
                        </div>
                    </div>
                    <div id="settingsAdminAlert" class="settings-alert"></div>
                    
                    ${isMain ? `
                    <form id="settingsAdminForm" class="settings-admin-create-form">
                        <div class="settings-grid">
                            <div class="settings-form-group">
                                <label class="settings-label" for="adminFullName">Full name</label>
                                <input class="settings-input" type="text" id="adminFullName" name="full_name" placeholder="Admin full name">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="adminEmail">Email</label>
                                <input class="settings-input" type="email" id="adminEmail" name="email" placeholder="admin@example.com">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="adminRole">Role</label>
                                <select class="settings-input" id="adminRole" name="role">
                                    <option value="admin">Admin</option>
                                    <option value="OSAS Staff">OSAS Staff</option>
                                    <option value="CSC Officer">CSC Officer</option>
                                    <option value="Faculty Member">Faculty Member</option>
                                    <option value="Student">Student</option>
                                </select>
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="adminUsername">Username</label>
                                <input class="settings-input" type="text" id="adminUsername" name="username" placeholder="Username for login">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="adminStudentId">ID or employee number (optional)</label>
                                <input class="settings-input" type="text" id="adminStudentId" name="student_id" placeholder="Optional ID">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="adminPassword">Password</label>
                                <input class="settings-input" type="password" id="adminPassword" name="password" placeholder="Password">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="adminPasswordConfirm">Confirm password</label>
                                <input class="settings-input" type="password" id="adminPasswordConfirm" name="confirm_password" placeholder="Confirm password">
                            </div>
                        </div>
                        <div class="settings-actions">
                            <button type="submit" class="settings-btn settings-btn-primary" id="settingsAdminSubmit">
                                <span>Create admin</span>
                            </button>
                        </div>
                    </form>
                    ` : ''}

                    <div class="settings-table-wrapper">
                        <table class="settings-table">
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Email</th>
                                    <th>Username</th>
                                    <th>ID</th>
                                    <th>Role</th>
                                    <th>Status</th>
                                    ${isMain ? '<th>Actions</th>' : ''}
                                </tr>
                            </thead>
                            <tbody id="settingsAdminTableBody">
                                <tr>
                                    <td colspan="${isMain ? 7 : 6}">
                                        <div class="settings-empty-state">Loading admins...</div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <div id="settingsAdminPagination" class="settings-pagination"></div>
                </div>

                <div class="settings-section" data-section="users">
                    <div class="settings-header-group">
                        <div class="settings-header-text">
                            <h3 class="settings-section-title">User Accounts</h3>
                            <p class="settings-section-description">
                                ${isMain ? 'View and manage registered users.' : 'View registered users.'}
                            </p>
                        </div>
                        <div class="settings-table-controls">
                            <div class="settings-search-wrapper">
                                <i class='bx bx-search'></i>
                                <input type="text" id="userSearch" class="settings-search-input" placeholder="Search users...">
                            </div>
                        </div>
                    </div>
                    <div class="settings-table-wrapper">
                        <table class="settings-table">
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Email</th>
                                    <th>Username</th>
                                    <th>Student ID</th>
                                    <th>Role</th>
                                    <th>Status</th>
                                    ${isMain ? '<th>Actions</th>' : ''}
                                </tr>
                            </thead>
                            <tbody id="settingsUserTableBody">
                                <tr>
                                    <td colspan="${isMain ? 7 : 6}">
                                        <div class="settings-empty-state">Loading users...</div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <div id="settingsUserPagination" class="settings-pagination"></div>
                </div>

                ${isMain ? `
                <div class="settings-section" data-section="archive">
                    <div class="settings-header-group">
                        <div class="settings-header-text">
                            <h3 class="settings-section-title">Archived Accounts</h3>
                            <p class="settings-section-description">Restore or view archived accounts.</p>
                        </div>
                        <div class="settings-table-controls">
                            <div class="settings-search-wrapper">
                                <i class='bx bx-search'></i>
                                <input type="text" id="archiveSearch" class="settings-search-input" placeholder="Search archive...">
                            </div>
                        </div>
                    </div>
                    <div class="settings-table-wrapper">
                        <table class="settings-table">
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Username</th>
                                    <th>Role</th>
                                    <th>Archived Date</th>
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody id="settingsArchiveTableBody">
                                <tr>
                                    <td colspan="5">
                                        <div class="settings-empty-state">Loading archived accounts...</div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <div id="settingsArchivePagination" class="settings-pagination"></div>
                </div>
                <div class="settings-section" data-section="export">
                    <h3 class="settings-section-title">Export Database</h3>
                    <p class="settings-section-description">
                        Download a complete backup of the database structure and data.
                    </p>
                    <div class="settings-actions">
                        <button type="button" class="settings-btn settings-btn-primary" onclick="window.location.href='../api/backup.php'">
                            <i class='bx bx-download'></i>
                            <span>Download SQL Backup</span>
                        </button>
                    </div>
                </div>

                <div class="settings-section" data-section="systemlogs">
                    <div class="settings-header-group">
                        <div class="settings-header-text">
                            <h3 class="settings-section-title">System Activity Logs</h3>
                            <p class="settings-section-description">
                                View recent administrator actions and session history.
                            </p>
                        </div>
                        <button type="button" class="settings-btn settings-btn-secondary" onclick="loadSettingsLogs()">
                            <i class='bx bx-refresh'></i>
                            <span>Refresh</span>
                        </button>
                    </div>
                    <div class="settings-table-wrapper" style="max-height: 400px; overflow-y: auto;">
                        <table class="settings-table">
                            <thead style="position: sticky; top: 0; background: var(--light); z-index: 1;">
                                <tr>
                                    <th>User</th>
                                    <th>Action</th>
                                    <th>Details</th>
                                    <th>Time</th>
                                </tr>
                            </thead>
                            <tbody id="settingsLogsTableBody">
                                <tr>
                                    <td colspan="4">
                                        <div class="settings-empty-state">Loading logs...</div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
                ` : ''}
            </div>
        </div>
    `;

    document.body.appendChild(overlay);
    settingsModalOverlay = overlay;
    attachSettingsModalEvents();
}

function attachSettingsModalEvents() {
    if (!settingsModalOverlay) {
        return;
    }

    const closeBtn = settingsModalOverlay.querySelector('#settingsModalCloseBtn');
    if (closeBtn) {
        closeBtn.addEventListener('click', function () {
            closeSettingsModal();
        });
    }

    settingsModalOverlay.addEventListener('click', function (event) {
        if (event.target === settingsModalOverlay) {
            closeSettingsModal();
        }
    });

    const sidebarItems = settingsModalOverlay.querySelectorAll('.settings-sidebar-item');
    sidebarItems.forEach(function (item) {
        item.addEventListener('click', function () {
            const section = this.getAttribute('data-section');
            setActiveSettingsSection(section);
        });
    });

    const form = document.getElementById('settingsAdminForm');
    if (form) {
        form.addEventListener('submit', function (event) {
            event.preventDefault();
            submitAdminForm();
        });
    }

    const profileForm = document.getElementById('settingsProfileForm');
    if (profileForm) {
        profileForm.addEventListener('submit', function (event) {
            event.preventDefault();
            submitProfileForm();
        });
    }

    // Search Events
    const setupTableControls = (inputId, stateKey, loadFn) => {
        const input = document.getElementById(inputId);
        let debounceTimeout;

        if (input) {
            input.addEventListener('input', (e) => {
                clearTimeout(debounceTimeout);
                debounceTimeout = setTimeout(() => {
                    settingsPagination[stateKey].search = e.target.value.toLowerCase();
                    settingsPagination[stateKey].currentPage = 1;
                    loadFn();
                }, 300);
            });
        }
    };

    setupTableControls('adminSearch', 'admins', loadAdminAccounts);
    setupTableControls('userSearch', 'users', loadUserAccounts);
    setupTableControls('archiveSearch', 'archive', loadArchivedAccounts);
}

// Pagination State
let settingsPagination = {
    admins: { currentPage: 1, itemsPerPage: 10, search: '' },
    users: { currentPage: 1, itemsPerPage: 10, search: '' },
    archive: { currentPage: 1, itemsPerPage: 10, search: '' }
};

function renderPagination(containerId, totalItems, itemsPerPage, currentPage, onPageChange) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const totalPages = Math.ceil(totalItems / itemsPerPage);
    if (totalPages <= 1) {
        container.innerHTML = '';
        return;
    }

    const startItem = (currentPage - 1) * itemsPerPage + 1;
    const endItem = Math.min(currentPage * itemsPerPage, totalItems);

    let html = `
        <div class="pagination-info">
            Showing ${startItem}-${endItem} of ${totalItems}
        </div>
        <div class="pagination-controls">
            <button class="pagination-btn" ${currentPage === 1 ? 'disabled' : ''} data-page="${currentPage - 1}">
                <i class='bx bx-chevron-left'></i>
            </button>
    `;

    // Show first page, current page, and last page with dots if needed
    for (let i = 1; i <= totalPages; i++) {
        if (i === 1 || i === totalPages || (i >= currentPage - 1 && i <= currentPage + 1)) {
            html += `
                <button class="pagination-btn ${i === currentPage ? 'active' : ''}" data-page="${i}">
                    ${i}
                </button>
            `;
        } else if (i === currentPage - 2 || i === currentPage + 2) {
            html += `<span class="pagination-dots">...</span>`;
        }
    }

    html += `
            <button class="pagination-btn" ${currentPage === totalPages ? 'disabled' : ''} data-page="${currentPage + 1}">
                <i class='bx bx-chevron-right'></i>
            </button>
        </div>
    `;

    container.innerHTML = html;

    // Add event listeners
    container.querySelectorAll('.pagination-btn:not(:disabled)').forEach(btn => {
        btn.addEventListener('click', () => {
            const page = parseInt(btn.getAttribute('data-page'));
            onPageChange(page);
        });
    });
}

// Drag-to-scroll functionality for settings tables and mobile sidebar (Mouse + Touch)
function enableDragScroll(selector) {
    const elements = document.querySelectorAll(selector);
    
    elements.forEach(slider => {
        let isDown = false;
        let startX;
        let scrollLeft;

        // MOUSE EVENTS
        slider.addEventListener('mousedown', (e) => {
            isDown = true;
            slider.classList.add('active');
            startX = e.pageX - slider.offsetLeft;
            scrollLeft = slider.scrollLeft;
        });

        slider.addEventListener('mouseleave', () => {
            isDown = false;
            slider.classList.remove('active');
        });

        slider.addEventListener('mouseup', () => {
            isDown = false;
            slider.classList.remove('active');
        });

        slider.addEventListener('mousemove', (e) => {
            if (!isDown) return;
            e.preventDefault();
            const x = e.pageX - slider.offsetLeft;
            const walk = (x - startX) * 2; 
            slider.scrollLeft = scrollLeft - walk;
        });

        // TOUCH EVENTS (MOBILE SLIDING)
        slider.addEventListener('touchstart', (e) => {
            isDown = true;
            startX = e.touches[0].pageX - slider.offsetLeft;
            scrollLeft = slider.scrollLeft;
        }, { passive: true });

        slider.addEventListener('touchend', () => {
            isDown = false;
        }, { passive: true });

        slider.addEventListener('touchmove', (e) => {
            if (!isDown) return;
            const x = e.touches[0].pageX - slider.offsetLeft;
            const walk = (x - startX) * 2;
            slider.scrollLeft = scrollLeft - walk;
        }, { passive: false }); 
    });
}

function openSettingsModal(initialSection) {
    createSettingsModal();
    if (!settingsModalOverlay) {
        return;
    }
    
    // Validate section access
    const isMain = isMainAdmin();
    let targetSection = initialSection || (isMain ? 'admins' : 'profile');
    
    // If not main admin, only allow 'profile'
    if (!isMain && targetSection !== 'profile') {
        targetSection = 'profile';
    }
    
    settingsModalOverlay.classList.add('active');
    document.body.classList.add('settings-modal-open');
    setActiveSettingsSection(targetSection);
    
    // Enable drag scroll on modal load
    setTimeout(() => {
        enableDragScroll('.settings-table-wrapper, .settings-sidebar-list');
    }, 100);
}

function closeSettingsModal() {
    if (!settingsModalOverlay) {
        return;
    }
    settingsModalOverlay.classList.remove('active');
    document.body.classList.remove('settings-modal-open');
}

function setActiveSettingsSection(section) {
    if (!settingsModalOverlay) {
        return;
    }

    const sidebarItems = settingsModalOverlay.querySelectorAll('.settings-sidebar-item');
    const sections = settingsModalOverlay.querySelectorAll('.settings-section');

    sidebarItems.forEach(function (item) {
        const target = item.getAttribute('data-section');
        if (target === section) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });

    sections.forEach(function (node) {
        const target = node.getAttribute('data-section');
        if (target === section) {
            node.classList.add('active');
        } else {
            node.classList.remove('active');
        }
    });

    if (section === 'admins') {
        loadAdminAccounts();
    } else if (section === 'profile') {
        loadUserProfile();
    } else if (section === 'users') {
        loadUserAccounts();
    } else if (section === 'archive') {
        loadArchivedAccounts();
    } else if (section === 'systemlogs') {
        loadSettingsLogs();
    }
}

async function loadSettingsLogs() {
    const tableBody = document.getElementById('settingsLogsTableBody');
    if (!tableBody) return;

    tableBody.innerHTML = '<tr><td colspan="4"><div class="settings-empty-state"><i class="bx bx-loader-alt bx-spin"></i> Fetching logs...</div></td></tr>';

    try {
        const response = await fetch('../api/system_logs.php?limit=20');
        const payload = await response.json();

        if (payload.status === 'success') {
            const logs = payload.data.logs;
            if (logs.length === 0) {
                tableBody.innerHTML = '<tr><td colspan="4"><div class="settings-empty-state">No activity logs found.</div></td></tr>';
                return;
            }

            tableBody.innerHTML = logs.map(log => {
                const date = new Date(log.created_at);
                const timeStr = date.toLocaleString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });

                return `
                    <tr>
                        <td style="font-weight: 600;">${log.username}</td>
                        <td>${log.action}</td>
                        <td style="max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${log.details || ''}">${log.details || 'N/A'}</td>
                        <td style="font-size: 11px; color: var(--dark-grey);">${timeStr}</td>
                    </tr>
                `;
            }).join('');
        } else {
            tableBody.innerHTML = `<tr><td colspan="4"><div class="settings-empty-state text-danger">${payload.message}</div></td></tr>`;
        }
    } catch (error) {
        console.error('Error loading settings logs:', error);
        tableBody.innerHTML = '<tr><td colspan="4"><div class="settings-empty-state text-danger">Network error.</div></td></tr>';
    }
}

async function loadUserProfile() {
    const usernameInput = document.getElementById('profileUsername');
    const fullNameInput = document.getElementById('profileFullName');
    const profileImagePreview = document.getElementById('profileImagePreview');
    const profilePictureInput = document.getElementById('profilePictureInput');
    const profileDisplayName = document.getElementById('profileDisplayName');
    
    if (!usernameInput) return;

    // Clear password fields
    document.getElementById('profileCurrentPassword').value = '';
    document.getElementById('profileNewPassword').value = '';
    document.getElementById('profileConfirmPassword').value = '';
    
    // Setup file input listener for preview
    if (profilePictureInput && profileImagePreview) {
        profilePictureInput.onchange = function(e) {
            const file = e.target.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    profileImagePreview.src = e.target.result;
                }
                reader.readAsDataURL(file);
            }
        };
    }
    
    try {
        const response = await fetch('../api/users.php?action=profile');
        const data = await response.json();
        
        if (data.status === 'success') {
            usernameInput.value = data.data.profile.username;
            if (fullNameInput) {
                fullNameInput.value = data.data.profile.full_name || '';
            }
            
            // Update display name
            if (profileDisplayName) {
                profileDisplayName.textContent = data.data.profile.full_name || data.data.profile.username || 'Administrator';
            }
            
            // Update profile image preview if exists
            if (data.data.profile.profile_picture && profileImagePreview) {
                const fullPath = resolvePath(data.data.profile.profile_picture);
                // Add timestamp to prevent caching issues
                profileImagePreview.src = fullPath + '?t=' + new Date().getTime();
            } else if (profileImagePreview) {
                 // Set default if no profile picture
                 profileImagePreview.src = resolvePath('assets/img/user.jpg');
            }
        }
    } catch (error) {
        console.error('Error loading profile:', error);
    }
}

async function submitProfileForm() {
    const form = document.getElementById('settingsProfileForm');
    const alertBox = document.getElementById('settingsProfileAlert');
    const submitBtn = document.getElementById('settingsProfileSubmit');
    
    if (!form || !alertBox) return;
    
    alertBox.className = 'settings-alert';
    alertBox.textContent = '';
    
    // Basic validation
    const currentPassword = document.getElementById('profileCurrentPassword').value;
    const newPassword = document.getElementById('profileNewPassword').value;
    const confirmPassword = document.getElementById('profileConfirmPassword').value;
    
    if (!currentPassword && newPassword) {
        alertBox.className = 'settings-alert error';
        alertBox.textContent = 'Current password is required to change password.';
        return;
    }
    
    if (newPassword && newPassword !== confirmPassword) {
        alertBox.className = 'settings-alert error';
        alertBox.textContent = 'New passwords do not match.';
        return;
    }
    
    try {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span>Saving...</span>';
        
        const formData = new FormData(form);
        
        const response = await fetch('../api/users.php?action=updateProfile', {
            method: 'POST',
            body: formData
        });

        const text = await response.text();
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            console.error('Invalid JSON response:', text);
            throw new Error('Server returned invalid response');
        }
        
        if (data.status === 'success') {
            alertBox.className = 'settings-alert success';
            alertBox.textContent = 'Profile updated successfully.';
            // Clear password fields
            document.getElementById('profileCurrentPassword').value = '';
            document.getElementById('profileNewPassword').value = '';
            document.getElementById('profileConfirmPassword').value = '';
            
            // Update the username input if it was changed
            if (data.data && data.data.username) {
                 document.getElementById('profileUsername').value = data.data.username;
                 
                 // Update display name header in modal
                 const profileDisplayName = document.getElementById('profileDisplayName');
                 if (profileDisplayName) {
                     profileDisplayName.textContent = data.data.full_name || data.data.username;
                 }

                 // Update the top navigation username if present
                 const navUsername = document.querySelector('.nav-user-menu .user-name');
                 if (navUsername) {
                     navUsername.textContent = data.data.full_name || data.data.username;
                 }
            }
            
            // Update profile picture if changed
            if (data.data && data.data.profile_picture) {
                const profilePics = document.querySelectorAll('.profile-photo, .user-avatar img, .nav-profile-photo');
                const fullPath = resolvePath(data.data.profile_picture);
                
                profilePics.forEach(img => {
                    // Add timestamp to bust cache
                    img.src = fullPath + '?t=' + new Date().getTime();
                });
                
                // Also update preview
                const preview = document.getElementById('profileImagePreview');
                if (preview) {
                    preview.src = fullPath + '?t=' + new Date().getTime();
                }
            }
        } else {
            alertBox.className = 'settings-alert error';
            alertBox.textContent = data.message || 'Failed to update profile.';
        }
    } catch (error) {
        console.error('Error updating profile:', error);
        alertBox.className = 'settings-alert error';
        alertBox.textContent = 'An error occurred while updating profile. ' + error.message;
    } finally {
        submitBtn.disabled = false;
        submitBtn.innerHTML = '<span>Save Changes</span>';
    }
}

async function loadAdminAccounts() {
    const tableBody = document.getElementById('settingsAdminTableBody');
    if (!tableBody) {
        return;
    }

    tableBody.innerHTML = `
        <tr>
            <td colspan="5">
                <div class="settings-empty-state">Loading admins...</div>
            </td>
        </tr>
    `;

    const apiPath = '../api/users.php?action=admins&t=' + new Date().getTime();

    try {
        console.log('🔄 Loading admin accounts...');
        const response = await fetch(apiPath, { 
            credentials: 'same-origin',
            cache: 'no-store',
            headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });
        const text = await response.text();
        let payload;

        try {
            payload = JSON.parse(text);
        } catch (error) {
            console.error('Failed to parse admins response', error);
            console.error('Response text:', text);
            // Show partial response for debugging
            const debugText = text.substring(0, 200).replace(/</g, '&lt;').replace(/>/g, '&gt;');
            tableBody.innerHTML = `
                <tr>
                    <td colspan="7">
                        <div class="settings-empty-state">
                            Unable to load admins.<br>
                            <small class="text-muted">Error: ${error.message}</small><br>
                            <small class="text-muted">Response: ${debugText}...</small>
                        </div>
                    </td>
                </tr>
            `;
            return;
        }

        if (payload.status !== 'success') {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="5">
                        <div class="settings-empty-state">${payload.message || 'Unable to load admins.'}</div>
                    </td>
                </tr>
            `;
            return;
        }

        const admins = Array.isArray(payload.data.admins) ? payload.data.admins : [];

        // Apply Search
        const { search, currentPage, itemsPerPage } = settingsPagination.admins;
        const filteredAdmins = admins.filter(admin => {
            const name = (admin.full_name || '').toLowerCase();
            const username = (admin.username || '').toLowerCase();
            const email = (admin.email || '').toLowerCase();
            
            return !search || name.includes(search) || username.includes(search) || email.includes(search);
        });

        if (filteredAdmins.length === 0) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="7">
                        <div class="settings-empty-state">No matching admin accounts found.</div>
                    </td>
                </tr>
            `;
            const paginationContainer = document.getElementById('settingsAdminPagination');
            if (paginationContainer) paginationContainer.innerHTML = '';
            return;
        }

        // Pagination Logic
        const startIndex = (currentPage - 1) * itemsPerPage;
        const paginatedAdmins = filteredAdmins.slice(startIndex, startIndex + itemsPerPage);
        
        const isMain = isMainAdmin();

        const rows = paginatedAdmins.map(function (admin) {
            const name = admin.full_name || admin.username || '';
            const email = admin.email || '';
            const username = admin.username || '';
            const studentId = admin.student_id || '';
            const role = admin.role || 'Admin';
            const active = admin.is_active !== undefined ? admin.is_active : true;
            const statusClass = active ? 'settings-status-badge' : 'settings-status-badge inactive';
            const statusLabel = active ? 'Active' : 'Inactive';
            const id = admin.id;

            return `
                <tr>
                    <td>${name}</td>
                    <td>${email}</td>
                    <td>${username}</td>
                    <td>${studentId}</td>
                    <td>${role}</td>
                    <td>
                        <span class="${statusClass}">${statusLabel}</span>
                    </td>
                    ${isMain ? `
                    <td>
                        <button type="button" class="settings-action-btn delete" onclick="deleteAdmin(${id}, '${username}')" title="Archive User">
                            <i class='bx bx-archive-in'></i>
                        </button>
                    </td>
                    ` : ''}
                </tr>
            `;
        }).join('');

        tableBody.innerHTML = rows;

        // Render Pagination
        renderPagination('settingsAdminPagination', admins.length, itemsPerPage, currentPage, (page) => {
            settingsPagination.admins.currentPage = page;
            loadAdminAccounts();
        });

        // Re-enable drag scroll for the new content (Mouse + Touch)
        enableDragScroll('.settings-table-wrapper');
    } catch (error) {
        console.error('Error loading admins', error);
        tableBody.innerHTML = `
            <tr>
                <td colspan="${isMainAdmin() ? 7 : 6}">
                    <div class="settings-empty-state">Network error while loading admins.</div>
                </td>
            </tr>
        `;
    }
}

async function submitAdminForm() {
    const form = document.getElementById('settingsAdminForm');
    const submitButton = document.getElementById('settingsAdminSubmit');
    const alertBox = document.getElementById('settingsAdminAlert');

    if (!form || !submitButton || !alertBox) {
        return;
    }

    alertBox.className = 'settings-alert';
    alertBox.textContent = '';

    const formData = new FormData(form);

    try {
        submitButton.disabled = true;

        const response = await fetch('../api/users.php?action=addAdmin', {
            method: 'POST',
            body: formData,
            credentials: 'same-origin'
        });

        const text = await response.text();
        console.log('Create Admin Response:', text); // Debug response

        if (!response.ok) {
            throw new Error(`Server returned status ${response.status}: ${text}`);
        }

        let payload;
        try {
            payload = JSON.parse(text);
        } catch (error) {
            console.error('Failed to parse create admin response', error);
            console.error('Response text:', text);
            alertBox.className = 'settings-alert error';
            alertBox.textContent = 'Server returned an invalid response.';
            return;
        }

        if (payload.status === 'success') {
            alertBox.className = 'settings-alert success';
            alertBox.textContent = payload.message || 'Admin account created.';
            form.reset();
            
            // Reload list
            loadAdminAccounts();
            
            if (typeof showNotification === 'function') {
                showNotification('The admin account has been created.', 'success');
            }
        } else {
            alertBox.className = 'settings-alert error';
            alertBox.textContent = payload.message || 'Failed to create admin.';
        }
    } catch (error) {
        console.error('Error creating admin:', error);
        
        // Avoid showing "Maximum call stack size exceeded" as network error
        if (error.message && error.message.includes('Maximum call stack size exceeded')) {
            console.error('Stack overflow detected. Please check recursive calls.');
            // This is likely a false positive in the UI flow, suppress alert if operation succeeded
            return;
        }

        alertBox.className = 'settings-alert error';
        alertBox.textContent = 'Network error: ' + (error.message || 'Unknown error');
    } finally {
        submitButton.disabled = false;
    }
}

async function deleteAdmin(id, username) {
    if (!confirm(`Are you sure you want to archive the user "${username}"? They will be safely stored and hidden from the active list.`)) {
        return;
    }

    try {
        const response = await fetch('../api/users.php?action=deleteAdmin', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: `id=${id}`
        });

        const text = await response.text();
        console.log('Archive Admin Response:', text); // Debug response

        if (!response.ok) {
            throw new Error(`Server returned status ${response.status}: ${text}`);
        }

        let payload;
        try {
            payload = JSON.parse(text);
        } catch (e) {
            console.error('Invalid JSON:', text);
            alert('Server error: Invalid JSON response');
            return;
        }

        if (payload.status === 'success') {
            if (typeof showNotification === 'function') {
                showNotification(`User "${username}" has been archived.`, 'success');
            } else {
                alert(`User "${username}" has been archived.`);
            }
            // Reload list with safety timeout
            setTimeout(() => {
                if (typeof loadAdminAccounts === 'function') {
                    console.log('🔄 Triggering admin list reload after archive...');
                    // Force a clear first to show something is happening
                    const tableBody = document.getElementById('settingsAdminTableBody');
                    if (tableBody) {
                         tableBody.innerHTML = `
                            <tr>
                                <td colspan="7">
                                    <div class="settings-empty-state">Refreshing list...</div>
                                </td>
                            </tr>
                        `;
                    }
                    loadAdminAccounts().catch(e => console.error('Error reloading admins:', e));
                } else {
                    console.error('❌ loadAdminAccounts function not found!');
                }
            }, 500);
        } else {
            alert(payload.message || 'Failed to archive user.');
        }
    } catch (error) {
        console.error('Error archiving user:', error);
        // Avoid showing "Maximum call stack size exceeded" as network error
        if (error.message.includes('Maximum call stack size exceeded')) {
            console.error('Stack overflow detected. Please check recursive calls.');
            // This is likely a false positive in the UI flow, suppress alert if operation succeeded
            return;
        }
        alert('Network error: ' + (error.message || 'Unknown error'));
    }
}

// NEW FUNCTION: Load module script dynamically
function loadModuleScript(moduleName) {
    const moduleScripts = {
        'department': '../app/assets/js/department.js',
        'sections': '../app/assets/js/section.js',
        'students': '../app/assets/js/student.js',
        'violations': '../app/assets/js/violation.js',
        'reports': '../app/assets/js/reports.js',
        'users': '../app/assets/js/users.js'
    };

    const scriptPath = moduleScripts[moduleName];
    
    if (scriptPath && !document.querySelector(`script[src^="${scriptPath}"]`)) {
        console.log(`📥 Loading ${moduleName} module script: ${scriptPath}`);
        
        const script = document.createElement('script');
        script.src = scriptPath + '?v=' + new Date().getTime();
        script.onload = function() {
            console.log(`✅ ${moduleName} script loaded`);
            
            // Try to initialize again after script loads
            const initFunctionName = `init${moduleName.charAt(0).toUpperCase() + moduleName.slice(1)}Module`;
            if (typeof window[initFunctionName] === 'function') {
                console.log(`⚡ Initializing ${moduleName} module...`);
                window[initFunctionName]();
            }
        };
        script.onerror = function() {
            console.error(`❌ Failed to load script: ${scriptPath}`);
        };
        document.body.appendChild(script);
    }
}

// Initialize all event listeners
function initializeEventListeners() {
    // Enhanced navigation functionality (works with both sidebar and top nav)
    allSideMenu.forEach(item => {
        // Skip chatbot buttons - they have their own handlers
        if (item.classList.contains('chatbot-sidebar-btn')) {
            return;
        }
        
        const li = item.parentElement;

        item.addEventListener('click', function (e) {
            e.preventDefault();
            const page = this.getAttribute('data-page');
            
            // Only process items with data-page attribute
            if (!page) return;

            // Update active menu item
            updateActiveNavItem(page);

            // Close sidebar on mobile after selection (only if sidebar exists)
            if (window.innerWidth < 768 && sidebar) {
                sidebar.classList.add('hide');
            }

            // Load the corresponding content
            loadContent(page);
        });
    });

    // Universal Search Functionality
    const topNavSearch = document.querySelector('.nav-search .search-input');
    const searchSuggestions = document.getElementById('searchSuggestions');
    
    if (topNavSearch && searchSuggestions) {
        let searchTimeout;
        
        // Google-style focus behavior
        topNavSearch.addEventListener('focus', function() {
            const val = this.value.trim().toLowerCase();
            if (val === '') {
                renderRecentSearches();
            } else if (val.length >= 2) {
                searchSuggestions.classList.add('active');
            }
        });

        topNavSearch.addEventListener('input', function(e) {
            const searchTerm = e.target.value.trim().toLowerCase();
            
            clearTimeout(searchTimeout);
            
            if (searchTerm.length === 0) {
                renderRecentSearches();
                return;
            }

            if (searchTerm.length < 2) {
                searchSuggestions.classList.remove('active');
                return;
            }
            
            searchTimeout = setTimeout(async () => {
                const results = await performUniversalSearch(searchTerm);
                renderSearchSuggestions(results, searchTerm);
            }, 300);
        });
        
        // Close suggestions when clicking outside
        document.addEventListener('click', function(e) {
            if (!topNavSearch.contains(e.target) && !searchSuggestions.contains(e.target)) {
                searchSuggestions.classList.remove('active');
            }
        });
    }

    /**
     * Google-style: Render Recent Searches from LocalStorage
     */
    function renderRecentSearches() {
        const lastSearches = JSON.parse(localStorage.getItem('lastSearches') || '[]');
        if (lastSearches.length === 0) {
            searchSuggestions.classList.remove('active');
            return;
        }

        let html = `
            <div class="suggestion-group">
                <div class="suggestion-group-title">Recent Searches</div>
                ${lastSearches.map(term => `
                    <div class="suggestion-item recent-search" onclick="applyRecentSearch('${term}')">
                        <div class="suggestion-icon"><i class='bx bx-history'></i></div>
                        <div class="suggestion-info">
                            <span class="suggestion-name">${term}</span>
                        </div>
                        <div class="suggestion-remove" onclick="removeRecentSearch(event, '${term}')">
                            <i class='bx bx-x'></i>
                        </div>
                    </div>
                `).join('')}
            </div>
        `;
        searchSuggestions.innerHTML = html;
        searchSuggestions.classList.add('active');
    }

    window.applyRecentSearch = function(term) {
        topNavSearch.value = term;
        topNavSearch.dispatchEvent(new Event('input'));
        topNavSearch.focus();
    };

    window.removeRecentSearch = function(e, term) {
        e.stopPropagation();
        let lastSearches = JSON.parse(localStorage.getItem('lastSearches') || '[]');
        lastSearches = lastSearches.filter(t => t !== term);
        localStorage.setItem('lastSearches', JSON.stringify(lastSearches));
        renderRecentSearches();
    };

    function saveToRecentSearches(term) {
        if (!term || term.length < 2) return;
        let lastSearches = JSON.parse(localStorage.getItem('lastSearches') || '[]');
        // Remove if already exists to move to top
        lastSearches = lastSearches.filter(t => t.toLowerCase() !== term.toLowerCase());
        lastSearches.unshift(term);
        lastSearches = lastSearches.slice(0, 5); // Keep top 5
        localStorage.setItem('lastSearches', JSON.stringify(lastSearches));
    }

    /**
     * Perform Universal Search across different modules
     */
    async function performUniversalSearch(query) {
        const results = {
            students: [],
            violations: [],
            departments: [],
            sections: []
        };
        
        try {
            const apiBase = typeof getAPIBasePath === 'function' ? getAPIBasePath() : '../api/';
            
            // Parallel fetching for performance
            // Fix: Pass action=get explicitly to ensure correct routing
            const [studentsRes, violationsRes, deptsRes, sectionsRes] = await Promise.all([
                fetch(`${apiBase}students.php?action=get&search=${encodeURIComponent(query)}&limit=5`),
                fetch(`${apiBase}violations.php?action=get&search=${encodeURIComponent(query)}&limit=5`),
                fetch(`${apiBase}departments.php?action=get&search=${encodeURIComponent(query)}&limit=3`),
                fetch(`${apiBase}sections.php?action=get&search=${encodeURIComponent(query)}&limit=3`)
            ]);

            if (studentsRes.ok) {
                const data = await studentsRes.json();
                // Correctly extract nested student array from data.data.students
                if (data.data && Array.isArray(data.data.students)) {
                    results.students = data.data.students;
                } else if (Array.isArray(data.data)) {
                    results.students = data.data;
                } else {
                    results.students = [];
                }
            }
            
            if (violationsRes.ok) {
                const data = await violationsRes.json();
                // Violations API returns data array directly or in data.violations
                if (Array.isArray(data.data)) {
                    results.violations = data.data;
                } else if (Array.isArray(data.violations)) {
                    results.violations = data.violations;
                } else {
                    results.violations = [];
                }
            }
            
            if (deptsRes.ok) {
                const data = await deptsRes.json();
                // Extract from data.data.departments or data.data
                if (data.data && Array.isArray(data.data.departments)) {
                    results.departments = data.data.departments;
                } else if (Array.isArray(data.data)) {
                    results.departments = data.data;
                } else {
                    results.departments = [];
                }
            }
            
            if (sectionsRes.ok) {
                const data = await sectionsRes.json();
                // Extract from data.data.sections or data.data
                if (data.data && Array.isArray(data.data.sections)) {
                    results.sections = data.data.sections;
                } else if (Array.isArray(data.data)) {
                    results.sections = data.data;
                } else {
                    results.sections = [];
                }
            }
            
        } catch (error) {
            console.error('❌ Universal search failed:', error);
        }
        
        return results;
    }

    /**
     * Render Search Suggestions Dropdown
     */
    function renderSearchSuggestions(results, query) {
        const totalResults = (results.students || []).length + (results.violations || []).length + 
                            (results.departments || []).length + (results.sections || []).length;
                            
        if (totalResults === 0) {
            searchSuggestions.innerHTML = `<div class="no-suggestions">No results found for "${query}"</div>`;
        } else {
            let html = '';
            
            // Students Section - Modern approach with specific action
            if (results.students && results.students.length > 0) {
                html += `
                    <div class="suggestion-group">
                        <div class="suggestion-group-title">Students</div>
                        ${results.students.map(s => {
                            // Robust name detection (handles snake_case and camelCase)
                            const firstName = s.first_name || s.firstName || '';
                            const lastName = s.last_name || s.lastName || '';
                            const fullName = `${firstName} ${lastName}`.trim();
                            const studentId = s.student_id || s.studentId || '';
                            const deptName = s.department_name || s.departmentName || s.department || '';
                            
                            return `
                            <div class="suggestion-item" onclick="navigateToStudent('${studentId}', '${fullName}')">
                                <div class="suggestion-icon"><i class='bx bxs-user-detail'></i></div>
                                <div class="suggestion-info">
                                    <span class="suggestion-name">${fullName || 'Unknown Student'}</span>
                                    <span class="suggestion-meta">${studentId} • ${deptName} • View Records</span>
                                </div>
                            </div>
                        `}).join('')}
                    </div>
                `;
            }
            
            // Violations Section - Only show if it matches specifically (not just general student search)
            if (results.violations && results.violations.length > 0) {
                // Filter violations to avoid showing generic results if the query is a name
                const filteredViolations = results.violations.filter(v => 
                    (v.case_id && v.case_id.toLowerCase().includes(query)) || 
                    (v.violation_type_name && v.violation_type_name.toLowerCase().includes(query))
                );

                if (filteredViolations.length > 0) {
                    html += `
                        <div class="suggestion-group">
                            <div class="suggestion-group-title">Violations & Cases</div>
                            ${filteredViolations.map(v => {
                                const studentName = `${v.first_name || ''} ${v.last_name || ''}`.trim();
                                return `
                                <div class="suggestion-item" onclick="navigateToModule('admin_page/Violations', '${v.case_id || v.id}')">
                                    <div class="suggestion-icon"><i class='bx bxs-shield-x'></i></div>
                                    <div class="suggestion-info">
                                        <span class="suggestion-name">${v.violation_type_name || v.violation_type || 'Violation'}</span>
                                        <span class="suggestion-meta">${studentName || 'Student'} • Case: ${v.case_id || v.id}</span>
                                    </div>
                                </div>
                            `}).join('')}
                        </div>
                    `;
                }
            }
            
            // Departments Section
            if (results.departments && results.departments.length > 0) {
                html += `
                    <div class="suggestion-group">
                        <div class="suggestion-group-title">Departments</div>
                        ${results.departments.map(d => {
                            const name = d.department_name || d.name || '';
                            const code = d.department_code || d.code || '';
                            const count = d.student_count || d.studentCount || 0;
                            return `
                            <div class="suggestion-item" onclick="navigateToModule('admin_page/Department', '${code}')">
                                <div class="suggestion-icon"><i class='bx bxs-building'></i></div>
                                <div class="suggestion-info">
                                    <span class="suggestion-name">${name}</span>
                                    <span class="suggestion-meta">${code} • ${count} Students</span>
                                </div>
                            </div>
                        `}).join('')}
                    </div>
                `;
            }

            // Sections Section
            if (results.sections && results.sections.length > 0) {
                html += `
                    <div class="suggestion-group">
                        <div class="suggestion-group-title">Sections</div>
                        ${results.sections.map(s => {
                            const name = s.section_name || s.name || '';
                            const code = s.section_code || s.code || '';
                            const dept = s.department_name || s.department || '';
                            const count = s.student_count || s.studentCount || 0;
                            return `
                            <div class="suggestion-item" onclick="navigateToModule('admin_page/Sections', '${code || name}')">
                                <div class="suggestion-icon"><i class='bx bxs-layer'></i></div>
                                <div class="suggestion-info">
                                    <span class="suggestion-name">${name}</span>
                                    <span class="suggestion-meta">${dept} • ${count} Students</span>
                                </div>
                            </div>
                        `}).join('')}
                    </div>
                `;
            }
            
            searchSuggestions.innerHTML = html || `<div class="no-suggestions">No specific results found for "${query}"</div>`;
        }
        
        searchSuggestions.classList.add('active');
    }

    /**
     * Modernized Student Navigation: Direct to Violations
     */
    window.navigateToStudent = function(studentId, fullName) {
        saveToRecentSearches(fullName);
        // Direct jump to violations page with the student ID
        navigateToModule('admin_page/Violations', studentId);
    };

    /**
     * Global navigation helper for search results
     */
    window.navigateToModule = function(page, searchTerm) {
        console.log(`🚀 Routing: ${page} with query: "${searchTerm}"`);
        saveToRecentSearches(searchTerm);
        
        searchSuggestions.classList.remove('active');
        
        // Update top nav search input to reflect the current search
        if (topNavSearch) {
            topNavSearch.value = searchTerm;
        }
        
        // Update active navigation item
        updateActiveNavItem(page);
        
        if (typeof loadContent === 'function') {
            loadContent(page);
            
            // Precise target search injection across all page types
            setTimeout(() => {
                const moduleSearch = document.querySelector('#studentSearch, #violationSearch, #departmentSearch, #sectionSearch, #userSearch, #announcementSearch, .Violations-search-box input');
                if (moduleSearch) {
                    moduleSearch.value = searchTerm;
                    moduleSearch.dispatchEvent(new Event('input'));
                    moduleSearch.focus();
                }
            }, 600);
        }
    };

    // Dark mode toggle functionality (top navigation)
    const topNavThemeToggle = document.getElementById('switch-mode-top');
    if (topNavThemeToggle) {
        topNavThemeToggle.addEventListener('change', function () {
            toggleTheme();
            // Sync with any other theme toggles
            const oldThemeToggle = document.getElementById('switch-mode');
            if (oldThemeToggle) {
                oldThemeToggle.checked = this.checked;
            }
        });
    }

    // Notification button functionality
    const notificationBtn = document.querySelector('.notification-btn');
    if (notificationBtn) {
        notificationBtn.addEventListener('click', function() {
            console.log('Notifications clicked');
            // Show notifications panel
        });
    }

    // User dropdown functionality
    const userAvatar = document.querySelector('.user-avatar');
    const userDropdown = document.querySelector('.user-dropdown');
    
    if (userAvatar && userDropdown) {
        // Toggle dropdown on avatar click
        userAvatar.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            
            // Close all other dropdowns first
            document.querySelectorAll('.user-dropdown').forEach(d => {
                if (d !== userDropdown) {
                    d.classList.remove('show');
                }
            });
            
            // Toggle this dropdown
            userDropdown.classList.toggle('show');
        });

        // Close dropdown when clicking on items
        const dropdownItems = userDropdown.querySelectorAll('.dropdown-item');
        dropdownItems.forEach(item => {
            item.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                
                if (item.classList.contains('logout')) {
                    logout();
                }
                
                userDropdown.classList.remove('show');
            });
        });

        // Close dropdown when clicking outside
        document.addEventListener('click', function(e) {
            if (!e.target.closest('.nav-user-menu')) {
                userDropdown.classList.remove('show');
            }
        });

        // Close dropdown when pressing Escape
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                userDropdown.classList.remove('show');
            }
        });
    }

    // Toggle sidebar with animation - Logo click
    const logoToggle = document.querySelector('.sidebar-toggle-logo');
    if (logoToggle) {
        logoToggle.addEventListener('click', function (e) {
            e.stopPropagation();
            sidebar.classList.toggle('hide');
            // Save sidebar state
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
    if (searchButton) {
        searchButton.addEventListener('click', function (e) {
            if (window.innerWidth < 576) {
                e.preventDefault();
                searchForm.classList.toggle('show');
                searchButtonIcon.classList.toggle('bx-x', searchForm.classList.contains('show'));
                searchButtonIcon.classList.toggle('bx-search', !searchForm.classList.contains('show'));
            }
        });
    }

    // Theme switcher: dark mode (compatible with login.js)
    if (switchMode) {
        switchMode.addEventListener('change', function () {
            toggleTheme();
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
    document.addEventListener('themeChanged', function() {
        setTimeout(() => {
            if (typeof updateEyeCareButtonState === 'function') {
                updateEyeCareButtonState();
            }
        }, 100);
    });

    const settingsTriggers = document.querySelectorAll('.nav-settings, .user-dropdown .settings-link');
    if (settingsTriggers.length > 0) {
        settingsTriggers.forEach(function (trigger) {
            trigger.addEventListener('click', function (e) {
                e.preventDefault();
                openSettingsModal('admins');
            });
        });
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', function (e) {
        // Ctrl/Cmd + D to toggle dark mode
        if ((e.ctrlKey || e.metaKey) && e.key === 'd') {
            e.preventDefault();
            toggleTheme();
        }

        // Ctrl/Cmd + M to toggle sidebar
        if ((e.ctrlKey || e.metaKey) && e.key === 'm') {
            e.preventDefault();
            if (menuBar) menuBar.click();
        }

        // Escape to close search on mobile
        if (e.key === 'Escape' && searchForm && searchForm.classList.contains('show')) {
            searchForm.classList.remove('show');
            if (searchButtonIcon) {
                searchButtonIcon.classList.replace('bx-x', 'bx-search');
            }
        }
    });
}

// Enhanced responsive adjustments
function handleResponsiveAdjustments() {
    // Sidebar behavior
    if (window.innerWidth < 768 && sidebar) {
        sidebar.classList.add('hide');
    } else if (window.innerWidth >= 768 && sidebar) {
        // Restore sidebar state on larger screens
        const sidebarHidden = localStorage.getItem('sidebarHidden') === 'true';
        if (!sidebarHidden) {
            sidebar.classList.remove('hide');
        }
    }

    // Search form behavior
    if (window.innerWidth > 576 && searchButtonIcon) {
        searchButtonIcon.classList.replace('bx-x', 'bx-search');
        if (searchForm) {
            searchForm.classList.remove('show');
        }
    }
}

// Initial responsive adjustments
handleResponsiveAdjustments();

// Responsive adjustments on resize with debounce
let resizeTimeout;
window.addEventListener('resize', function () {
    clearTimeout(resizeTimeout);
    resizeTimeout = setTimeout(handleResponsiveAdjustments, 250);
});

console.log('🎯 Dashboard Framework loaded successfully!');

async function loadUserAccounts() {
    const tableBody = document.getElementById('settingsUserTableBody');
    if (!tableBody) {
        return;
    }

    tableBody.innerHTML = `
        <tr>
            <td colspan="6">
                <div class="settings-empty-state">Loading users...</div>
            </td>
        </tr>
    `;

    const apiPath = '../api/users.php?action=users&t=' + new Date().getTime();

    try {
        console.log('🔄 Loading user accounts...');
        const response = await fetch(apiPath, { 
            credentials: 'same-origin',
            cache: 'no-store',
            headers: {
                'Cache-Control': 'no-cache',
                'Pragma': 'no-cache'
            }
        });
        const text = await response.text();
        let payload;

        try {
            payload = JSON.parse(text);
        } catch (error) {
            console.error('Failed to parse users response', error);
            console.error('Response text:', text);
            tableBody.innerHTML = `
                <tr>
                    <td colspan="6">
                        <div class="settings-empty-state">
                            Unable to load users.<br>
                            <small class="text-muted">Error: ${error.message}</small>
                        </div>
                    </td>
                </tr>
            `;
            return;
        }

        if (payload.status !== 'success') {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="6">
                        <div class="settings-empty-state">${payload.message || 'Unable to load users.'}</div>
                    </td>
                </tr>
            `;
            return;
        }

        const users = Array.isArray(payload.data.users) ? payload.data.users : [];

        // Apply Search
        const { search, currentPage, itemsPerPage } = settingsPagination.users;
        const filteredUsers = users.filter(user => {
            const name = (user.full_name || '').toLowerCase();
            const username = (user.username || '').toLowerCase();
            const email = (user.email || '').toLowerCase();
            
            return !search || name.includes(search) || username.includes(search) || email.includes(search);
        });

        if (filteredUsers.length === 0) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="7">
                        <div class="settings-empty-state">No matching user accounts found.</div>
                    </td>
                </tr>
            `;
            const paginationContainer = document.getElementById('settingsUserPagination');
            if (paginationContainer) paginationContainer.innerHTML = '';
            return;
        }

        // Pagination Logic
        const startIndex = (currentPage - 1) * itemsPerPage;
        const paginatedUsers = filteredUsers.slice(startIndex, startIndex + itemsPerPage);
        
        const isMain = isMainAdmin();

        const rows = paginatedUsers.map(function (user) {
            const name = user.full_name || user.username || '';
            const email = user.email || '';
            const username = user.username || '';
            const studentId = user.student_id || '';
            const role = user.role || 'User';
            const active = user.is_active !== undefined ? user.is_active : true;
            const statusClass = active ? 'settings-status-badge' : 'settings-status-badge inactive';
            const statusLabel = active ? 'Active' : 'Inactive';

            return `
                <tr>
                    <td>${name}</td>
                    <td>${email}</td>
                    <td>${username}</td>
                    <td>${studentId}</td>
                    <td>${role}</td>
                    <td>
                        <span class="${statusClass}">${statusLabel}</span>
                    </td>
                    ${isMain ? `
                    <td>
                        <button type="button" class="settings-action-btn secondary" onclick="toggleUserActive('${user.id}', ${active ? 0 : 1})" title="${active ? 'Deactivate' : 'Activate'}">
                            <i class='bx ${active ? 'bx-user-x' : 'bx-user-check'}'></i>
                        </button>
                        <button type="button" class="settings-action-btn" onclick="resetUserPassword('${user.id}', '${username}')" title="Reset Password">
                            <i class='bx bx-reset'></i>
                        </button>
                        <button type="button" class="settings-action-btn delete" onclick="deleteUser('${user.id}', '${username}')" title="Archive User">
                            <i class='bx bx-archive-in'></i>
                        </button>
                    </td>
                    ` : ''}
                </tr>
            `;
        }).join('');

        tableBody.innerHTML = rows;

        // Render Pagination
        renderPagination('settingsUserPagination', users.length, itemsPerPage, currentPage, (page) => {
            settingsPagination.users.currentPage = page;
            loadUserAccounts();
        });

        // Re-enable drag scroll for the new content (Mouse + Touch)
        enableDragScroll('.settings-table-wrapper');
    } catch (error) {
        console.error('Error loading users', error);
        tableBody.innerHTML = `
            <tr>
                <td colspan="${isMainAdmin() ? 7 : 6}">
                    <div class="settings-empty-state">Network error while loading users.</div>
                </td>
            </tr>
        `;
    }
}

async function resetUserPassword(id, username) {
    const confirmed = await showModernAlert({
        title: 'Reset Password',
        message: `Reset password for "${username}" to default?`,
        icon: 'warning',
        confirmText: 'Yes, Reset'
    });
    
    if (!confirmed) return;

    try {
        const response = await fetch('../api/users.php?action=resetPassword', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `id=${id}`
        });
        const text = await response.text();
        let payload;
        try { payload = JSON.parse(text); } catch (e) { alert('Server error'); return; }
        if (payload.status === 'success') {
            if (typeof showNotification === 'function') showNotification('Password reset', 'success');
        } else {
            alert(payload.message || 'Failed to reset');
        }
    } catch (e) {
        alert('Network error');
    }
}

async function loadArchivedAccounts() {
    const tableBody = document.getElementById('settingsArchiveTableBody');
    if (!tableBody) return;

    tableBody.innerHTML = `<tr><td colspan="5"><div class="settings-empty-state">Loading archived accounts...</div></td></tr>`;

    try {
        const response = await fetch('../api/users.php?action=archived');
        const data = await response.json();

        if (data.status === 'success') {
            const archived = data.data.archived || [];
            
            // Apply Search
            const { search, currentPage, itemsPerPage } = settingsPagination.archive;
            const filteredArchived = archived.filter(user => {
                const name = (user.full_name || '').toLowerCase();
                const username = (user.username || '').toLowerCase();
                
                return !search || name.includes(search) || username.includes(search);
            });

            if (filteredArchived.length === 0) {
                tableBody.innerHTML = `<tr><td colspan="5"><div class="settings-empty-state">No matching archived accounts found.</div></td></tr>`;
                const paginationContainer = document.getElementById('settingsArchivePagination');
                if (paginationContainer) paginationContainer.innerHTML = '';
                return;
            }

            // Pagination Logic
            const startIndex = (currentPage - 1) * itemsPerPage;
            const paginatedArchived = filteredArchived.slice(startIndex, startIndex + itemsPerPage);

            tableBody.innerHTML = paginatedArchived.map(user => {
                const date = user.deleted_at ? new Date(user.deleted_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'N/A';
                return `
                    <tr>
                        <td>${user.full_name || user.username}</td>
                        <td>${user.username}</td>
                        <td>${user.role}</td>
                        <td>${date}</td>
                        <td>
                            <button type="button" class="settings-action-btn" onclick="restoreUser(${user.id}, '${user.username}')" title="Restore User">
                                <i class='bx bx-undo'></i>
                            </button>
                        </td>
                    </tr>
                `;
            }).join('');
            
            // Render Pagination
            renderPagination('settingsArchivePagination', archived.length, itemsPerPage, currentPage, (page) => {
                settingsPagination.archive.currentPage = page;
                loadArchivedAccounts();
            });

            // Re-enable drag scroll for the new content (Mouse + Touch)
            enableDragScroll('.settings-table-wrapper');
        } else {
            tableBody.innerHTML = `<tr><td colspan="5"><div class="settings-empty-state">${data.message || 'Failed to load archived accounts.'}</div></td></tr>`;
        }
    } catch (error) {
        console.error('Error loading archived accounts:', error);
        tableBody.innerHTML = `<tr><td colspan="5"><div class="settings-empty-state">Network error while loading archived accounts.</div></td></tr>`;
    }
}

async function restoreUser(id, username) {
    const confirmed = await showModernAlert({
        title: 'Restore User',
        message: `Restore account for "${username}"?`,
        icon: 'info',
        confirmText: 'Yes, Restore'
    });

    if (!confirmed) {
        return;
    }

    try {
        const response = await fetch('../api/users.php?action=restoreUser', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `id=${id}`
        });

        const data = await response.json();
        if (data.status === 'success') {
            if (typeof showNotification === 'function') {
                showNotification(`User "${username}" has been restored.`, 'success');
            }
            loadArchivedAccounts();
        } else {
            alert(data.message || 'Failed to restore user.');
        }
    } catch (error) {
        console.error('Error restoring user:', error);
        alert('Network error');
    }
}

async function toggleUserActive(id, isActive) {
    try {
        const response = await fetch('../api/users.php?action=updateStatus', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `id=${id}&is_active=${isActive}`
        });
        const text = await response.text();
        let payload;
        try { payload = JSON.parse(text); } catch (e) { alert('Server error'); return; }
        if (payload.status === 'success') {
            loadUserAccounts();
        } else {
            alert(payload.message || 'Failed to update');
        }
    } catch (e) {
        alert('Network error');
    }
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
window.showWarning = (msg) => showNotification(msg, 'warning');
window.showInfo = (msg) => showNotification(msg, 'info');

async function deleteUser(id, username) {
    const confirmed = await showModernAlert({
        title: 'Archive User',
        message: `Archive user "${username}"? This will safely store their account data but remove them from the active list.`,
        icon: 'warning',
        confirmText: 'Yes, Archive'
    });

    if (!confirmed) {
        return;
    }
    try {
        const response = await fetch('../api/users.php?action=deleteUser', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `id=${id}`
        });
        const text = await response.text();
        let payload;
        try { payload = JSON.parse(text); } catch (e) { alert('Server error'); return; }
        if (payload.status === 'success') {
            if (typeof showNotification === 'function') {
                showNotification(`User "${username}" has been archived.`, 'success');
            }
            loadUserAccounts();
        } else {
            alert(payload.message || 'Failed to archive');
        }
    } catch (e) {
        alert('Network error');
    }
}
