<?php
require_once __DIR__ . '/../core/Model.php';

class UserModel extends Model {
    protected $table = 'users';
    protected $primaryKey = 'id';

    /**
     * Authenticate user
     */
    public function authenticate($username, $password) {
        try {
            error_log("UserModel: Authenticating user: " . $username);
            
            // Updated query to match actual table structure (no status, no email_verified_at)
            $query = "SELECT * FROM users WHERE (username = ? OR email = ?) AND is_active = 1 LIMIT 1";
            error_log("UserModel: Executing query: " . $query);
            
            $result = $this->query($query, [$username, $username]);
            error_log("UserModel: Query returned " . count($result) . " results");
            
            if (count($result) === 1) {
                $user = $result[0];
                error_log("UserModel: Found user, verifying password");
                
                if (password_verify($password, $user['password'])) {
                    error_log("UserModel: Password verified successfully");
                    return $user;
                } else {
                    error_log("UserModel: Password verification failed");
                }
            } else {
                error_log("UserModel: No user found or multiple users returned");
            }
            
            return null;
        } catch (Exception $e) {
            error_log("UserModel authenticate error: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Check if username exists
     */
    public function usernameExists($username, $excludeId = null) {
        $query = "SELECT id FROM users WHERE username = ?";
        if ($excludeId) {
            $query .= " AND id != ?";
            $result = $this->query($query, [$username, $excludeId]);
        } else {
            $result = $this->query($query, [$username]);
        }
        return count($result) > 0;
    }

    /**
     * Check if email exists
     */
    public function emailExists($email, $excludeId = null) {
        $query = "SELECT id FROM users WHERE email = ?";
        if ($excludeId) {
            $query .= " AND id != ?";
            $result = $this->query($query, [$email, $excludeId]);
        } else {
            $result = $this->query($query, [$email]);
        }
        return count($result) > 0;
    }

    /**
     * Create user with hashed password
     */
    public function create($data) {
        if (isset($data['password'])) {
            $data['password'] = password_hash($data['password'], PASSWORD_DEFAULT);
        }
        return parent::create($data);
    }

    /**
     * Update user with optional password hashing
     */
    public function update($id, $data) {
        if (isset($data['password'])) {
            $data['password'] = password_hash($data['password'], PASSWORD_DEFAULT);
        }
        return parent::update($id, $data);
    }

    public function getAdmins() {
        $query = "SELECT id, username, email, full_name, student_id, role, is_active, created_at, updated_at FROM {$this->table} WHERE role != 'user' ORDER BY created_at DESC";
        return $this->query($query);
    }

    public function getUsers() {
        $query = "SELECT id, username, email, full_name, student_id, role, is_active, created_at, updated_at FROM {$this->table} WHERE role = 'user' ORDER BY created_at DESC";
        return $this->query($query);
    }
}

