<?php
require_once __DIR__ . '/../core/Controller.php';
require_once __DIR__ . '/../models/UserModel.php';
require_once __DIR__ . '/../core/Logger.php';

class AuthController extends Controller {
    private $model;

    public function __construct() {
        ob_start();
        header('Content-Type: application/json');
        
        // Only start session if not already started
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
        
        try {
            $this->model = new UserModel();
        } catch (Exception $e) {
            error_log('AuthController constructor error: ' . $e->getMessage());
            $this->error('System initialization failed. Please try again.');
        }
    }

    public function login() {
        try {
            if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
                $this->error('Invalid request method');
                return;
            }

            $username = trim($this->getPost('username', ''));
            $password = trim($this->getPost('password', ''));
            $remember = isset($_POST['rememberMe']) && $_POST['rememberMe'] === 'true';

            if (empty($username) || empty($password)) {
                $this->error('Please fill in all fields.');
                return;
            }

            // Log login attempt for debugging
            error_log("Login attempt for username: " . $username);

            $user = $this->model->authenticate($username, $password);

            if ($user) {
                $studentId = null;
                $studentIdCode = null;
                
                if ($user['role'] === 'user') {
                    // Get student_id directly from users table (it's stored there!)
                    if (!empty($user['student_id'])) {
                        $studentIdCode = $user['student_id'];
                        // Try to get the database ID from students table if it exists
                        try {
                            require_once __DIR__ . '/../models/StudentModel.php';
                            $studentModel = new StudentModel();
                            $student = $studentModel->query(
                                "SELECT id FROM students WHERE student_id = ? LIMIT 1",
                                [$studentIdCode]
                            );
                            if (!empty($student)) {
                                $studentId = $student[0]['id'];
                            }
                        } catch (Exception $e) {
                            error_log("Error fetching student database ID: " . $e->getMessage());
                        }
                    }
                }
                
                $_SESSION['user_id'] = $user['id'];
                $_SESSION['username'] = $user['username'];
                $_SESSION['full_name'] = $user['full_name'] ?: $user['username'];
                $_SESSION['role'] = $user['role'];
                if ($studentIdCode) {
                    $_SESSION['student_id_code'] = $studentIdCode;
                    if ($studentId) {
                        $_SESSION['student_id'] = $studentId;
                    }
                }

                $expiryTime = time() + ($remember ? 30*24*60*60 : 6*60*60);

                setcookie("user_id", $user['id'], $expiryTime, "/", "", false, false);
                setcookie("username", $user['username'], $expiryTime, "/", "", false, false);
                setcookie("role", $user['role'], $expiryTime, "/", "", false, false);
                setcookie("full_name", $user['full_name'] ?: ($user['username'] ?: 'Admin'), $expiryTime, "/", "", false, false);
                if ($studentIdCode) {
                    setcookie("student_id_code", $studentIdCode, $expiryTime, "/", "", false, false);
                    if ($studentId) {
                        setcookie("student_id", $studentId, $expiryTime, "/", "", false, false);
                    }
                }

                $responseData = [
                    'role' => $user['role'],
                    'name' => $user['full_name'] ?: $user['username'],
                    'username' => $user['username'],
                    'studentId' => $studentId,
                    'studentIdCode' => $studentIdCode,
                    'expires' => $expiryTime
                ];
                
                error_log("Login successful for username: " . $username . ", role: " . $user['role']);
                
                // Log the login event
                Logger::log('Login', "User logged in: {$user['username']} (Role: {$user['role']})");

                $this->success('Login successful', $responseData);
            } else {
                error_log("Login failed for username: " . $username . " - invalid credentials");
                
                // Get the user record to check why it failed
                $userCheck = $this->model->query("SELECT is_active FROM users WHERE username = ? OR email = ? LIMIT 1", [$username, $username]);
                
                if (empty($userCheck)) {
                    $this->error('The email or username you entered doesn\'t exist.');
                } else if ($userCheck[0]['is_active'] == 0) {
                    $this->error('Your account is currently inactive. Please contact the administrator.');
                } else {
                    $this->error('Invalid password. Please try again.');
                }
            }
        } catch (Exception $e) {
            error_log("Login method exception: " . $e->getMessage());
            $this->error('Login failed. Please try again.');
        }
    }

    public function logout() {
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
        
        // Log logout before destroying session
        if (isset($_SESSION['user_id'])) {
            Logger::log('Logout', "User logged out: {$_SESSION['username']}");
        }

        session_destroy();
        setcookie("user_id", "", time() - 3600, "/");
        setcookie("username", "", time() - 3600, "/");
        setcookie("role", "", time() - 3600, "/");
        setcookie("full_name", "", time() - 3600, "/");
        
        $this->success('Logged out successfully');
    }

    public function check() {
        session_start();
        if (isset($_SESSION['user_id'])) {
            $this->success('User is authenticated', [
                'user_id' => $_SESSION['user_id'],
                'username' => $_SESSION['username'],
                'role' => $_SESSION['role']
            ]);
        } else {
            $this->error('User is not authenticated', '', 401);
        }
    }
}

