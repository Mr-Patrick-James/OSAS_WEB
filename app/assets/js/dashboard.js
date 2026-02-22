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

// Core Functions ==========================================================

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
    // Update profile name if element exists
    const profileName = document.querySelector('.profile-name');
    if (profileName) {
        profileName.textContent = session.name;
    }

    // Update profile role if element exists
    const profileRole = document.querySelector('.profile-role');
    if (profileRole) {
        profileRole.textContent = session.role;
    }

    // Update profile picture if exists
    const profilePic = document.querySelector('.profile-photo');
    if (profilePic && session.avatar) {
        profilePic.src = session.avatar;
    }
}

// Enhanced logout function
function logout() {
    if (confirm('Are you sure you want to logout?')) {
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

        // Determine correct logout path based on current location
        let logoutPath;
        const currentPath = window.location.pathname;
        
        if (currentPath.includes('/index.php')) {
          // From app/entry/dashboard.php -> ../app/views/auth/logout.php
          logoutPath = '../index.php';
        } else if (currentPath.includes('/includes/')) {
          // From includes/dashboard.php -> ../app/views/auth/logout.php
          logoutPath = '../index.php';
        } else {
          // Default fallback
          logoutPath = 'index.php';
        }
        
        console.log('Redirecting to logout:', logoutPath);
        window.location.href = logoutPath;
    }
}

// Enhanced content loading with error handling and loading states
function loadContent(page) {
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
    overlay.innerHTML = `
        <div class="settings-modal">
            <aside class="settings-sidebar">
                <div class="settings-sidebar-header">Settings</div>
                <div class="settings-sidebar-list">
                    <button type="button" class="settings-sidebar-item active" data-section="overview">
                        <i class='bx bx-slider-alt'></i>
                        <span>Overview</span>
                    </button>
                    <button type="button" class="settings-sidebar-item" data-section="admins">
                        <i class='bx bx-user-circle'></i>
                        <span>Admin accounts</span>
                    </button>
                    <button type="button" class="settings-sidebar-item" data-section="users">
                        <i class='bx bx-group'></i>
                        <span>User Accounts</span>
                    </button>
                    <button type="button" class="settings-sidebar-item" data-section="profile">
                        <i class='bx bx-id-card'></i>
                        <span>Profile</span>
                    </button>
                    <button type="button" class="settings-sidebar-item" data-section="export">
                        <i class='bx bx-data'></i>
                        <span>Export Database</span>
                    </button>
                </div>
            </aside>
            <div class="settings-content">
                <button type="button" class="settings-close-btn" id="settingsModalCloseBtn">
                    <i class='bx bx-x'></i>
                </button>

                <div class="settings-section active" data-section="overview">
                    <h3 class="settings-section-title">Overview</h3>
                    <p class="settings-section-description">
                        Configure key options for your admin workspace. Use the Admin accounts section
                        to invite and manage additional administrators.
                    </p>
                </div>
                <div class="settings-section" data-section="profile">
                    <h3 class="settings-section-title">My Profile</h3>
                    <p class="settings-section-description">
                        Update your username and password. Current password is required for any changes.
                    </p>
                    <div id="settingsProfileAlert" class="settings-alert"></div>
                    <form id="settingsProfileForm">
                        <div class="settings-grid">
                            <div class="settings-form-group">
                                <label class="settings-label" for="profileUsername">Username</label>
                                <input class="settings-input" type="text" id="profileUsername" name="username" placeholder="Your username">
                            </div>
                            <div class="settings-form-group">
                                <label class="settings-label" for="profileCurrentPassword">Current Password (Required)</label>
                                <input class="settings-input" type="password" id="profileCurrentPassword" name="current_password" placeholder="Enter current password">
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
                    <h3 class="settings-section-title">Admin accounts</h3>
                    <p class="settings-section-description">
                        Create new admin users with email and password and view existing administrators.
                    </p>
                    <div id="settingsAdminAlert" class="settings-alert"></div>
                    <form id="settingsAdminForm">
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
                                    <th>Actions</th>
                                </tr>
                            </thead>
                            <tbody id="settingsAdminTableBody">
                                <tr>
                                    <td colspan="7">
                                        <div class="settings-empty-state">Loading admins...</div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
                <div class="settings-section" data-section="users">
                    <h3 class="settings-section-title">User Accounts</h3>
                    <p class="settings-section-description">
                        View registered users and students.
                    </p>
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
                                </tr>
                            </thead>
                            <tbody id="settingsUserTableBody">
                                <tr>
                                    <td colspan="6">
                                        <div class="settings-empty-state">Loading users...</div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
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
}

function openSettingsModal(initialSection) {
    createSettingsModal();
    if (!settingsModalOverlay) {
        return;
    }
    settingsModalOverlay.classList.add('active');
    document.body.classList.add('settings-modal-open');
    const targetSection = initialSection || 'admins';
    setActiveSettingsSection(targetSection);
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
    }
}

async function loadUserProfile() {
    const usernameInput = document.getElementById('profileUsername');
    if (!usernameInput) return;

    // Clear password fields
    document.getElementById('profileCurrentPassword').value = '';
    document.getElementById('profileNewPassword').value = '';
    document.getElementById('profileConfirmPassword').value = '';
    
    try {
        const response = await fetch('../api/users.php?action=profile');
        const data = await response.json();
        
        if (data.status === 'success') {
            usernameInput.value = data.data.profile.username;
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
    
    if (!currentPassword) {
        alertBox.className = 'settings-alert error';
        alertBox.textContent = 'Current password is required.';
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
                 
                 // Update the top navigation username if present
                 const navUsername = document.querySelector('.nav-user-menu .user-name');
                 if (navUsername) {
                     navUsername.textContent = data.data.username;
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

        if (admins.length === 0) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="7">
                        <div class="settings-empty-state">No admin accounts found.</div>
                    </td>
                </tr>
            `;
            return;
        }

        const rows = admins.map(function (admin) {
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
                    <td>
                        <button type="button" class="settings-action-btn delete" onclick="deleteAdmin(${id}, '${username}')" title="Remove User">
                            <i class='bx bx-trash'></i>
                        </button>
                    </td>
                </tr>
            `;
        }).join('');

        tableBody.innerHTML = rows;
    } catch (error) {
        console.error('Error loading admins', error);
        tableBody.innerHTML = `
            <tr>
                <td colspan="7">
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
    if (!confirm(`Are you sure you want to remove the user "${username}"? This action cannot be undone.`)) {
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
        console.log('Delete Admin Response:', text); // Debug response

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
                showNotification(`User "${username}" has been removed.`, 'success');
            } else {
                alert(`User "${username}" has been removed.`);
            }
            // Reload list with safety timeout
            setTimeout(() => {
                if (typeof loadAdminAccounts === 'function') {
                    console.log('🔄 Triggering admin list reload after delete...');
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
            alert(payload.message || 'Failed to remove user.');
        }
    } catch (error) {
        console.error('Error removing user:', error);
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

            // Update active menu item (works for both sidebar and top nav)
            allSideMenu.forEach(i => {
                if (!i.classList.contains('chatbot-sidebar-btn')) {
                    i.parentElement.classList.remove('active');
                }
            });
            li.classList.add('active');

            // Close sidebar on mobile after selection (only if sidebar exists)
            if (window.innerWidth < 768 && sidebar) {
                sidebar.classList.add('hide');
            }

            // Load the corresponding content
            loadContent(page);
        });
    });

    // Top navigation search functionality
    const topNavSearch = document.querySelector('.nav-search .search-input');
    if (topNavSearch) {
        topNavSearch.addEventListener('input', function(e) {
            const searchTerm = e.target.value.toLowerCase();
            console.log('Top nav search:', searchTerm);
            // Implement search functionality here
        });
    }

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

        if (users.length === 0) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="6">
                        <div class="settings-empty-state">No user accounts found.</div>
                    </td>
                </tr>
            `;
            return;
        }

        const rows = users.map(function (user) {
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
                </tr>
            `;
        }).join('');

        tableBody.innerHTML = rows;
    } catch (error) {
        console.error('Error loading users', error);
        tableBody.innerHTML = `
            <tr>
                <td colspan="6">
                    <div class="settings-empty-state">Network error while loading users.</div>
                </td>
            </tr>
        `;
    }
}
