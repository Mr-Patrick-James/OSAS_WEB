<?php
require_once __DIR__ . '/../core/Controller.php';
require_once __DIR__ . '/../models/UserModel.php';

class UserController extends Controller {
    private $model;

    public function __construct() {
        ob_start();
        header('Content-Type: application/json');
        @session_start();
        $this->model = new UserModel();
    }

    public function listAdmins() {
        try {
            $this->requireAdmin();
            $admins = $this->model->getAdmins();
            $formatted = array_map(function ($row) {
                return [
                    'id' => isset($row['id']) ? (int)$row['id'] : 0,
                    'username' => $row['username'] ?? '',
                    'email' => $row['email'] ?? '',
                    'full_name' => $row['full_name'] ?? '',
                    'student_id' => $row['student_id'] ?? '',
                    'role' => $row['role'] ?? 'Admin',
                    'is_active' => isset($row['is_active']) ? (bool)$row['is_active'] : true,
                    'created_at' => $row['created_at'] ?? null,
                    'updated_at' => $row['updated_at'] ?? null
                ];
            }, $admins);

            $this->success('Admins retrieved successfully', ['admins' => $formatted]);
        } catch (Exception $e) {
            $this->error('Failed to load admins: ' . $e->getMessage());
        }
    }

    public function listUsers() {
        try {
            $this->requireAdmin();
            $users = $this->model->getUsers();
            $formatted = array_map(function ($row) {
                return [
                    'id' => isset($row['id']) ? (int)$row['id'] : 0,
                    'username' => $row['username'] ?? '',
                    'email' => $row['email'] ?? '',
                    'full_name' => $row['full_name'] ?? '',
                    'student_id' => $row['student_id'] ?? '',
                    'role' => $row['role'] ?? 'User',
                    'is_active' => isset($row['is_active']) ? (bool)$row['is_active'] : true,
                    'created_at' => $row['created_at'] ?? null,
                    'updated_at' => $row['updated_at'] ?? null
                ];
            }, $users);

            $this->success('Users retrieved successfully', ['users' => $formatted]);
        } catch (Exception $e) {
            $this->error('Failed to load users: ' . $e->getMessage());
        }
    }

    public function createAdmin() {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        $this->requireAdmin();

        $username = $this->sanitize($this->getPost('username', ''));
        $email = $this->sanitize($this->getPost('email', ''));
        $fullName = $this->sanitize($this->getPost('full_name', ''));
        $role = $this->sanitize($this->getPost('role', 'admin'));
        $password = $this->getPost('password', '');
        $confirmPassword = $this->getPost('confirm_password', '');
        $studentId = $this->sanitize($this->getPost('student_id', ''));

        if ($username === '' || $email === '' || $fullName === '' || $password === '' || $confirmPassword === '') {
            $this->error('All required fields must be filled.');
        }

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error('Invalid email address.');
        }

        if ($password !== $confirmPassword) {
            $this->error('Passwords do not match.');
        }

        if ($this->model->usernameExists($username)) {
            $this->error('Username already exists.');
        }

        if ($this->model->emailExists($email)) {
            $this->error('Email already exists.');
        }

        try {
            $data = [
                'username' => $username,
                'email' => $email,
                'password' => $password,
                'role' => $role,
                'full_name' => $fullName,
                'student_id' => $studentId !== '' ? $studentId : null,
                'is_active' => 1
            ];

            $id = $this->model->create($data);
            $admin = $this->model->getById($id);

            if (!$admin) {
                $this->error('Admin account created but could not be loaded.');
            }

            $response = [
                'id' => isset($admin['id']) ? (int)$admin['id'] : 0,
                'username' => $admin['username'] ?? '',
                'email' => $admin['email'] ?? '',
                'full_name' => $admin['full_name'] ?? '',
                'student_id' => $admin['student_id'] ?? '',
                'role' => $admin['role'] ?? 'Admin',
                'is_active' => isset($admin['is_active']) ? (bool)$admin['is_active'] : true,
                'created_at' => $admin['created_at'] ?? null,
                'updated_at' => $admin['updated_at'] ?? null
            ];

            $this->success('Admin account created successfully', ['admin' => $response]);
        } catch (Exception $e) {
            $this->error('Failed to create admin: ' . $e->getMessage());
        }
    }

    public function deleteAdmin() {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        $this->requireAdmin();

        $id = isset($_POST['id']) ? (int)$_POST['id'] : 0;

        if ($id <= 0) {
            $this->error('Invalid user ID.');
        }

        // Prevent deleting yourself
        if (isset($_SESSION['user_id']) && $_SESSION['user_id'] == $id) {
            $this->error('You cannot delete your own account.');
        }

        try {
            // Check if user exists
            $user = $this->model->getById($id);
            if (!$user) {
                $this->error('User not found.');
            }

            // Perform deletion
            // Using generic delete from Model class
            if ($this->model->delete($id)) {
                $this->success('User deleted successfully.');
            } else {
                $this->error('Failed to delete user.');
            }
        } catch (Exception $e) {
            $this->error('Error deleting user: ' . $e->getMessage());
        }
    }

    public function updateProfile() {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        if (!isset($_SESSION['user_id'])) {
            $this->error('User not logged in.');
        }

        $userId = $_SESSION['user_id'];
        $username = $this->sanitize($this->getPost('username', ''));
        $currentPassword = $this->getPost('current_password', '');
        $newPassword = $this->getPost('new_password', '');
        $confirmPassword = $this->getPost('confirm_password', '');

        if ($username === '') {
            $this->error('Username is required.');
        }

        if ($currentPassword === '') {
            $this->error('Current password is required to save changes.');
        }

        try {
            $user = $this->model->getById($userId);
            if (!$user) {
                $this->error('User not found.');
            }

            // Verify current password
            if (!password_verify($currentPassword, $user['password'])) {
                $this->error('Incorrect current password.');
            }

            // Check if username is being changed and if it's already taken
            if ($username !== $user['username']) {
                if ($this->model->usernameExists($username, $userId)) {
                    $this->error('Username already exists.');
                }
            }

            $updateData = [
                'username' => $username,
                'updated_at' => date('Y-m-d H:i:s')
            ];

            // If new password is provided
            if ($newPassword !== '') {
                if ($newPassword !== $confirmPassword) {
                    $this->error('New passwords do not match.');
                }
                $updateData['password'] = $newPassword;
            }

            if ($this->model->update($userId, $updateData)) {
                // Update session if username changed
                $_SESSION['username'] = $username;
                $this->success('Profile updated successfully.', ['username' => $username]);
            } else {
                $this->error('Failed to update profile.');
            }
        } catch (Exception $e) {
            $this->error('Error updating profile: ' . $e->getMessage());
        }
    }

    public function getProfile() {
        if (!isset($_SESSION['user_id'])) {
            $this->error('User not logged in.');
        }

        try {
            $user = $this->model->getById($_SESSION['user_id']);
            if (!$user) {
                $this->error('User not found.');
            }

            $profile = [
                'username' => $user['username'],
                'full_name' => $user['full_name'] ?? '',
                'email' => $user['email'] ?? ''
            ];

            $this->success('Profile retrieved successfully', ['profile' => $profile]);
        } catch (Exception $e) {
            $this->error('Error retrieving profile: ' . $e->getMessage());
        }
    }
}

