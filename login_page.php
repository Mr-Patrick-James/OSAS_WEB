<?php
session_start();

// Check if user wants to see login page (bypass auto-redirect)
$forceLogin = isset($_GET['force_login']) && $_GET['force_login'] === 'true';

// Restore session from cookies if not forcing login
if (!$forceLogin && isset($_COOKIE['user_id']) && isset($_COOKIE['role'])) {
    $_SESSION['user_id'] = $_COOKIE['user_id'];
    $_SESSION['username'] = $_COOKIE['username'] ?? '';
    $_SESSION['role'] = $_COOKIE['role'];
    
    if ($_SESSION['role'] === 'admin') {
        header('Location: includes/dashboard.php');
        exit;
    } elseif ($_SESSION['role'] === 'user') {
        header('Location: includes/user_dashboard.php');
        exit;
    }
}

// Also check session (fallback)
if (!$forceLogin && isset($_SESSION['user_id']) && isset($_SESSION['role'])) {
    if ($_SESSION['role'] === 'admin') {
        header('Location: includes/dashboard.php');
        exit;
    } elseif ($_SESSION['role'] === 'user') {
        header('Location: includes/user_dashboard.php');
        exit;
    }
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OSAS | Login</title>
    <link rel="manifest" href="manifest.json">
    <meta name="theme-color" content="#D4AF37">
    <link rel="apple-touch-icon" href="app/assets/img/default.png">
    <meta name="apple-mobile-web-app-capable" content="yes">

    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <link rel="stylesheet" href="./app/assets/styles/login.css">
    <style>
        
        /* Error toast styles */
        .error-toast {
            position: fixed;
            top: 20px;
            right: 20px;
            background: #ff4444;
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
            z-index: 10000;
            display: flex;
            align-items: center;
            gap: 10px;
            min-width: 300px;
            animation: slideInRight 0.3s ease;
        }

        .error-toast i {
            font-size: 1.2rem;
        }

        .error-toast button {
            background: none;
            border: none;
            color: white;
            cursor: pointer;
            font-size: 1.1rem;
            padding: 0;
            margin-left: auto;
        }

        .error-toast button:hover {
            opacity: 0.8;
        }

        @keyframes slideInRight {
            from {
                transform: translateX(100%);
                opacity: 0;
            }

            to {
                transform: translateX(0);
                opacity: 1;
            }
        }

        /* Loading spinner */
        .loading-spinner {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid #ffffff;
            border-radius: 50%;
            border-top-color: transparent;
            animation: spin 1s ease-in-out infinite;
        }

        @keyframes spin {
            to {
                transform: rotate(360deg);
            }
        }

        /* Background animation for light mode */
        @keyframes backgroundShift {

            0%,
            100% {
                background-position: 0% 50%;
            }

            50% {
                background-position: 100% 50%;
            }
        }



        /* 🔹 Toast Notification Styles */
        .toast {
            position: fixed;
            top: -60px;
            right: 20px;
            background: #222;
            color: white;
            padding: 12px 18px;
            border-radius: 8px;
            box-shadow: 0 4px 10px rgba(0, 0, 0, 0.2);
            display: flex;
            align-items: center;
            gap: 10px;
            opacity: 0;
            transform: translateY(-10px);
            transition: all 0.4s ease;
            z-index: 9999;
            font-size: 0.95rem;
        }

        .toast.show {
            top: 20px;
            opacity: 1;
            transform: translateY(0);
        }

        .toast i {
            font-size: 1.2rem;
        }

        .toast.success {
            background: linear-gradient(135deg, #4CAF50, #2E7D32);
        }

        .toast.error {
            background: linear-gradient(135deg, #E53935, #B71C1C);
        }

        /* 🔹 Spinner on Login Button */
        .spinner {
            border: 3px solid rgba(255, 255, 255, 0.3);
            border-top: 3px solid #fff;
            border-radius: 50%;
            width: 18px;
            height: 18px;
            margin-right: 8px;
            animation: spin 0.8s linear infinite;
            display: inline-block;
            vertical-align: middle;
        }

        @keyframes spin {
            from {
                transform: rotate(0deg);
            }

            to {
                transform: rotate(360deg);
            }
        }

        .login-button {
            display: flex;
            justify-content: center;
            align-items: center;
            gap: 8px;
        }

        .login-button:disabled {
            opacity: 0.7;
            cursor: not-allowed;
        }
    </style>
</head>

<body>
    <div class="login-container">
        <div class="login-card">
            <div class="gold-border"></div>

            <div class="theme-toggle" id="themeToggle">
                <i class="fas fa-sun"></i>
            </div>

            <div class="login-header">
                <div class="logo">
                    <img src="./app/assets/img/default.png" alt="Logo" width="55" height="55">
                </div>
                <h2>Welcome Back</h2>
                <p>Please enter your credentials to login</p>
            </div>

            <?php if (!empty($error)): ?>
                <div class="error-toast">
                    <i class="fas fa-exclamation-circle"></i>
                    <span><?= htmlspecialchars($error) ?></span>
                    <button onclick="this.parentElement.remove()">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
            <?php endif; ?>

            <?php if ($forceLogin && (isset($_SESSION['user_id']) || isset($_COOKIE['user_id']))): ?>
                <div class="info-toast" style="position: fixed; top: 20px; right: 20px; background: #2196F3; color: white; padding: 15px 20px; border-radius: 8px; box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2); z-index: 10000; display: flex; align-items: center; gap: 10px; min-width: 300px;">
                    <i class="fas fa-info-circle"></i>
                    <div style="flex: 1;">
                        <strong>You are currently logged in</strong><br>
                        <small>If you want to login with a different account, please logout first.</small>
                    </div>
                    <button onclick="this.parentElement.remove()" style="background: none; border: none; color: white; cursor: pointer; font-size: 1.1rem; padding: 0; margin-left: auto;">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div style="text-align: center; margin-bottom: 20px;">
                    <a href="app/views/auth/logout.php" style="color: #2196F3; text-decoration: none; font-weight: 500;">
                        <i class="fas fa-sign-out-alt"></i> Click here to logout
                    </a>
                </div>
            <?php endif; ?>

            <form id="loginForm">
                <div class="form-row">
                    <div class="form-group">
                        <label for="username">Username or Email</label>
                        <input id="username" name="username" type="text" placeholder="Enter your username or email" required>
                    </div>

                    <div class="form-group">
                        <label for="password">Password</label>
                        <div class="password-input-wrapper">
                            <input id="password" name="password" type="password" placeholder="Enter your password" required>
                            <button type="button" class="toggle-password" id="passwordToggle">
                                <i class="fas fa-eye"></i>
                            </button>
                        </div>
                    </div>
                </div>

                <div class="form-options">
                    <label class="remember-me">
                        <input type="checkbox" id="rememberMe">
                        <span class="checkmark"></span>
                        Remember me
                    </label>
                    <a href="#" class="forgot-password" id="forgotPasswordBtn">Forgot password?</a>
                </div>

                <button type="submit" class="login-button" id="loginButton">
                    <span>Login</span>
                </button>
            </form>

            <div class="login-footer">
                <p>Use the email provided by the admin and the default password to login.</p>
            </div>
        </div>
    </div>

    <!-- Forgot Password Modal -->
    <div id="forgotPasswordModal" class="modal-overlay">
        <div class="modal-content">
            <div class="modal-header">
                <div class="modal-icon">
                    <i class="fas fa-key"></i>
                </div>
                <h2>Reset Password</h2>
                <button class="close-modal" id="closeForgotModal">&times;</button>
            </div>
            <div class="modal-body">
                <div class="info-box">
                    <i class="fas fa-info-circle"></i>
                    <p>You need to go to <strong>admin</strong> and request to reset the password.</p>
                </div>
            </div>
            <div class="modal-footer">
                <button class="modal-btn-primary" id="gotItBtn">Got it</button>
            </div>
        </div>
    </div>

    <style>
        /* Forgot Password Modal Styles */
        .modal-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.6);
            backdrop-filter: blur(5px);
            display: none;
            justify-content: center;
            align-items: center;
            z-index: 10000;
            opacity: 0;
            transition: opacity 0.3s ease;
        }

        .modal-overlay.show {
            display: flex;
            opacity: 1;
        }

        .modal-content {
            background: var(--bg-card, #ffffff);
            width: 90%;
            max-width: 400px;
            padding: 30px;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
            transform: translateY(20px);
            transition: transform 0.3s ease;
            text-align: center;
            position: relative;
        }

        .modal-overlay.show .modal-content {
            transform: translateY(0);
        }

        .modal-header {
            margin-bottom: 20px;
        }

        .modal-icon {
            width: 60px;
            height: 60px;
            background: rgba(212, 175, 55, 0.1);
            color: #D4AF37;
            font-size: 24px;
            border-radius: 50%;
            display: flex;
            justify-content: center;
            align-items: center;
            margin: 0 auto 15px;
        }

        .modal-header h2 {
            font-size: 1.5rem;
            color: var(--text-primary, #333);
            margin: 0;
        }

        .close-modal {
            position: absolute;
            top: 15px;
            right: 20px;
            background: none;
            border: none;
            font-size: 24px;
            color: #999;
            cursor: pointer;
            transition: color 0.2s;
        }

        .close-modal:hover {
            color: #666;
        }

        .modal-body {
            margin-bottom: 25px;
        }

        .info-box {
            background: rgba(212, 175, 55, 0.05);
            border-left: 4px solid #D4AF37;
            padding: 15px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            gap: 12px;
            text-align: left;
        }

        .info-box i {
            color: #D4AF37;
            font-size: 1.2rem;
        }

        .info-box p {
            margin: 0;
            color: var(--text-secondary, #666);
            font-size: 0.95rem;
            line-height: 1.5;
        }

        .modal-btn-primary {
            background: #D4AF37;
            color: white;
            border: none;
            padding: 12px 30px;
            border-radius: 10px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
            width: 100%;
        }

        .modal-btn-primary:hover {
            background: #b8962d;
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(212, 175, 55, 0.3);
        }

        /* Dark mode overrides */
        body.dark-mode .modal-content {
            background: #1e1e1e;
            color: #e0e0e0;
        }

        body.dark-mode .modal-header h2 {
            color: #e0e0e0;
        }

        body.dark-mode .info-box {
            background: rgba(212, 175, 55, 0.1);
        }

        body.dark-mode .info-box p {
            color: #ccc;
        }
    </style>

    <button id="installPWA" class="pwa-install-btn">
        Install App
    </button>

    <script src="service-worker.js"></script>
    <script src="app/assets/js/pwa.js"></script>
    <script src="app/assets/js/session.js"></script>
    <script src="app/assets/js/login.js"></script>

</body>

</html>
s"></script>
    <script src="app/assets/js/pwa.js"></script>
    <script src="app/assets/js/session.js"></script>
    <script src="app/assets/js/login.js"></script>

</body>

</html>
