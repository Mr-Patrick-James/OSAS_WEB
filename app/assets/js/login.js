// Dark/Light Mode Functionality
let darkMode = false;

function toggleTheme() {
    darkMode = !darkMode;
    updateTheme();
    localStorage.setItem('theme', darkMode ? 'dark' : 'light');
    console.log('Theme toggled to:', darkMode ? 'dark' : 'light');
}

function updateTheme() {
    // Toggle dark-mode class on body
    document.body.classList.toggle('dark-mode', darkMode);

    // Update theme toggle icon
    const themeToggle = document.querySelector('.theme-toggle i');
    if (themeToggle) {
        if (darkMode) {
            themeToggle.classList.remove('fa-sun');
            themeToggle.classList.add('fa-moon');
        } else {
            themeToggle.classList.remove('fa-moon');
            themeToggle.classList.add('fa-sun');
        }
    }

    // Update theme-color meta tag for PWA
    updateThemeColor();
}

function updateThemeColor() {
    const themeColorMeta = document.querySelector('meta[name="theme-color"]');
    if (themeColorMeta) {
        themeColorMeta.setAttribute('content', darkMode ? '#0F0F0F' : '#D4AF37');
    }
}

// Check for saved theme preference or system preference
function checkSavedTheme() {
    const savedTheme = localStorage.getItem('theme');
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

    if (savedTheme) {
        darkMode = savedTheme === 'dark';
    } else {
        darkMode = false;
    }

    updateTheme();
}

// Password visibility toggle
function togglePasswordVisibility() {
    const passwordInput = document.getElementById('password');
    const toggleButton = document.querySelector('.toggle-password i');

    if (passwordInput && toggleButton) {
        if (passwordInput.type === 'password') {
            passwordInput.type = 'text';
            toggleButton.classList.remove('fa-eye');
            toggleButton.classList.add('fa-eye-slash');
        } else {
            passwordInput.type = 'password';
            toggleButton.classList.remove('fa-eye-slash');
            toggleButton.classList.add('fa-eye');
        }
    }
}

/**
 * Modern Alert/Confirm Modal System
 */
function showModernAlert({ 
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
            warning: 'fa-exclamation-triangle',
            danger: 'fa-trash',
            success: 'fa-check-circle',
            info: 'fa-info-circle',
            loading: 'fa-spinner fa-spin'
        };

        const iconClass = iconMap[icon] || iconMap.warning;
        const isDanger = icon === 'danger';

        modal.innerHTML = `
            <div class="modern-alert-content">
                <div class="modern-alert-icon ${icon}">
                    <i class="fas ${iconClass}"></i>
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
}

// Modern Toast Notification System (Synced with Dashboard)
function showToast(message, type = 'info', title = null) {
    let container = document.querySelector('.toast-container');
    if (!container) {
        container = document.createElement('div');
        container.className = 'toast-container';
        document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `toast-notification toast-${type}`;
    
    const icon = {
        success: 'fa-check-circle',
        error: 'fa-exclamation-circle',
        warning: 'fa-exclamation-triangle',
        info: 'fa-info-circle'
    }[type] || 'fa-info-circle';

    const defaultTitle = {
        success: 'Success',
        error: 'Error',
        warning: 'Warning',
        info: 'Information'
    }[type] || 'Notice';

    toast.innerHTML = `
        <div class="toast-icon">
            <i class="fas ${icon}"></i>
        </div>
        <div class="toast-content">
            <span class="toast-title">${title || defaultTitle}</span>
            <span class="toast-message">${message}</span>
        </div>
        <div class="toast-close">
            <i class="fas fa-times"></i>
        </div>
        <div class="toast-progress">
            <div class="toast-progress-bar"></div>
        </div>
    `;

    container.appendChild(toast);

    // Animate progress bar
    const progressBar = toast.querySelector('.toast-progress-bar');
    progressBar.style.transition = 'transform 5s linear';
    
    // Show toast
    setTimeout(() => {
        toast.classList.add('show');
        progressBar.style.transform = 'scaleX(0)';
    }, 100);

    // Auto remove
    const timeout = setTimeout(() => {
        removeToast(toast);
    }, 5000);

    // Close button
    toast.querySelector('.toast-close').onclick = () => {
        clearTimeout(timeout);
        removeToast(toast);
    };
}

// Global Form Validation Interceptor (Synced with Dashboard)
document.addEventListener('invalid', (function() {
    return function(e) {
        // Prevent the browser from showing default error bubbles
        e.preventDefault();
        
        // Show custom modern notification instead
        const fieldName = e.target.getAttribute('placeholder') || e.target.getAttribute('name') || 'This field';
        const message = e.target.validationMessage || 'Please fill out this field.';
        
        showToast(`${message} (${fieldName})`, 'warning', 'Validation Error');
    };
})(), true);

function removeToast(toast) {
    toast.classList.remove('show');
    toast.style.transform = 'translateX(120%)';
    setTimeout(() => toast.remove(), 500);
}

// Form validation
function validateForm(username, password) {
    if (!username || !password) {
        showToast('Please fill in all fields.', 'error');
        return false;
    }

    if (username.length < 3) {
        showToast('Username must be at least 3 characters long.', 'error');
        return false;
    }

    if (password.length < 6) {
        showToast('Password must be at least 6 characters long.', 'error');
        return false;
    }

    return true;
}

// AJAX Login Handler
function handleLoginFormSubmit(e) {
    e.preventDefault();

    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value.trim();
    const loginButton = document.getElementById('loginButton');
    const rememberMe = document.getElementById('rememberMe')?.checked || false;

    if (!validateForm(username, password)) {
        return;
    }

    // Loading Animation
    loginButton.disabled = true;
    loginButton.innerHTML = `<div class="spinner"></div><span>Logging in...</span>`;

    fetch('./app/views/auth/login.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}&rememberMe=${rememberMe}`
    })
        .then(res => {
            if (!res.ok) {
                throw new Error('Network response was not ok');
            }
            return res.json();
        })
        .then(data => {
            loginButton.disabled = false;
            loginButton.innerHTML = `<span>Login</span>`;

            if (data.status === 'success') {
                showToast('Login successful! Redirecting...', 'success');

                const payload = data.data || data;

                const sessionData = {
                    username: payload.username || username,
                    name: payload.name,
                    full_name: payload.name, // Added full_name for compatibility
                    role: payload.role,
                    user_id: payload.user_id || payload.studentId,
                    studentId: payload.studentId,
                    studentIdCode: payload.studentIdCode,
                    expires: payload.expires * 1000,
                    theme: darkMode ? 'dark' : 'light'
                };

                localStorage.setItem('userSession', JSON.stringify(sessionData));
                
                if (payload.studentId) {
                    localStorage.setItem('student_id', payload.studentId);
                    if (payload.studentIdCode) {
                        localStorage.setItem('student_id_code', payload.studentIdCode);
                    }
                }

                setTimeout(() => {
                    if (payload.role === 'admin') {
                        window.location.href = './includes/dashboard.php';
                    } else {
                        window.location.href = './includes/user_dashboard.php';
                    }
                }, 1000);
            } else {
                showToast(data.message || 'Invalid credentials.', 'error');
            }
        })
        .catch(err => {
            console.error('Login error:', err);
            loginButton.disabled = false;
            loginButton.innerHTML = `<span>Login</span>`;
            showToast('Server error. Please try again later.', 'error');
        });
}

// Initialize application
function initApp() {
    console.log('Initializing app...');

    // Initialize theme
    checkSavedTheme();

    // Add event listeners
    const loginForm = document.getElementById('loginForm');
    const themeToggle = document.getElementById('themeToggle');
    const passwordToggle = document.getElementById('passwordToggle');

    console.log('Elements found:', {
        loginForm: !!loginForm,
        themeToggle: !!themeToggle,
        passwordToggle: !!passwordToggle
    });

    if (loginForm) {
        loginForm.addEventListener('submit', handleLoginFormSubmit);
        console.log('Login form event listener added');
    }

    if (themeToggle) {
        themeToggle.addEventListener('click', toggleTheme);
        console.log('Theme toggle event listener added');
    }

    if (passwordToggle) {
        passwordToggle.addEventListener('click', togglePasswordVisibility);
        console.log('Password toggle event listener added');
    }

    // Listen for system theme changes
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    mediaQuery.addEventListener('change', function (e) {
        // Only update if user hasn't explicitly set a preference
        if (!localStorage.getItem('theme')) {
            darkMode = e.matches;
            updateTheme();
        }
    });

    console.log('App initialization complete');
}

// Initialize when DOM is fully loaded
document.addEventListener('DOMContentLoaded', function () {
    console.log('DOM fully loaded');
    initApp();
});

// Also initialize if DOM is already loaded
if (document.readyState === 'interactive' || document.readyState === 'complete') {
    console.log('DOM already ready, initializing immediately');
    initApp();
}