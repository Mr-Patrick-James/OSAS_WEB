<?php
require_once __DIR__ . '/../core/Model.php';

class StudentModel extends Model {
    protected $table = 'students';
    protected $primaryKey = 'id';

    /**
     * Get all students with filters and search
     */
    public function getAllWithDetails($filter = 'all', $search = '', $page = null, $limit = null) {
        // Check if sections and departments tables exist
        $sectionsExist = $this->tableExists('sections');
        $deptExist = $this->tableExists('departments');
        
        // Build query with JOINs
        if ($sectionsExist && $deptExist) {
            $query = "SELECT s.id, s.student_id, s.first_name, s.middle_name, s.last_name, 
                             s.email, s.contact_number, s.address, s.department, s.section_id, s.yearlevel,
                             s.avatar, s.status, s.created_at, s.updated_at,
                             COALESCE(sec.section_name, 'N/A') as section_name, 
                             COALESCE(sec.section_code, 'N/A') as section_code, 
                             COALESCE(d.department_name, s.department) as department_name
                      FROM students s
                      LEFT JOIN sections sec ON s.section_id = sec.id
                      LEFT JOIN departments d ON s.department = d.department_code
                      WHERE 1=1";
        } elseif ($sectionsExist) {
            $query = "SELECT s.id, s.student_id, s.first_name, s.middle_name, s.last_name, 
                             s.email, s.contact_number, s.address, s.department, s.section_id, s.yearlevel,
                             s.avatar, s.status, s.created_at, s.updated_at,
                             COALESCE(sec.section_name, 'N/A') as section_name, 
                             COALESCE(sec.section_code, 'N/A') as section_code, 
                             s.department as department_name
                      FROM students s
                      LEFT JOIN sections sec ON s.section_id = sec.id
                      WHERE 1=1";
        } else {
            $query = "SELECT s.id, s.student_id, s.first_name, s.middle_name, s.last_name, 
                             s.email, s.contact_number, s.address, s.department, s.section_id, s.yearlevel,
                             s.avatar, s.status, s.created_at, s.updated_at,
                             'N/A' as section_name, 
                             'N/A' as section_code, 
                             s.department as department_name
                      FROM students s
                      WHERE 1=1";
        }
        
        $params = [];
        $types = "";
        
        // Add status filter
        if ($filter === 'active') {
            $query .= " AND s.status = 'active'";
        } elseif ($filter === 'inactive') {
            $query .= " AND s.status = 'inactive'";
        } elseif ($filter === 'graduating') {
            $query .= " AND s.status = 'graduating'";
        } elseif ($filter === 'archived') {
            $query .= " AND s.status = 'archived'";
        } else {
            $query .= " AND s.status != 'archived'";
        }
        
        // Add search
        if (!empty($search)) {
            if ($sectionsExist && $deptExist) {
                $query .= " AND (s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ? OR s.student_id LIKE ? OR s.email LIKE ? OR s.department LIKE ? OR d.department_name LIKE ? OR sec.section_code LIKE ? OR sec.section_name LIKE ?)";
                $searchTerm = "%$search%";
                $params = array_fill(0, 9, $searchTerm);
                $types = "sssssssss";
            } elseif ($sectionsExist) {
                $query .= " AND (s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ? OR s.student_id LIKE ? OR s.email LIKE ? OR s.department LIKE ? OR sec.section_code LIKE ? OR sec.section_name LIKE ?)";
                $searchTerm = "%$search%";
                $params = array_fill(0, 8, $searchTerm);
                $types = "ssssssss";
            } else {
                $query .= " AND (s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ? OR s.student_id LIKE ? OR s.email LIKE ? OR s.department LIKE ?)";
                $searchTerm = "%$search%";
                $params = array_fill(0, 6, $searchTerm);
                $types = "ssssss";
            }
        }
        
        $query .= " ORDER BY s.created_at DESC";

        if (!is_null($page) && !is_null($limit)) {
            $offset = max(0, ($page - 1) * $limit);
            $query .= " LIMIT ? OFFSET ?";
            $params[] = (int)$limit;
            $params[] = (int)$offset;
            $types .= "ii";
        }
        
        $stmt = $this->conn->prepare($query);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        
        $students = [];
        while ($row = $result->fetch_assoc()) {
            $firstName = $row['first_name'] ?? '';
            $middleName = $row['middle_name'] ?? '';
            $lastName = $row['last_name'] ?? '';
            $fullName = trim($firstName . ' ' . ($middleName ? $middleName . ' ' : '') . $lastName);
            
            $avatar = $row['avatar'] ?? '';
            if (empty($avatar) || trim($avatar) === '') {
                $avatar = 'https://ui-avatars.com/api/?name=' . urlencode($fullName) . '&background=ffd700&color=333&size=40';
            } else {
                if (!filter_var($avatar, FILTER_VALIDATE_URL) && strpos($avatar, 'data:') !== 0) {
                    // Normalize avatar paths to use app/assets/
                    if (strpos($avatar, 'app/assets/img/students/') === false && strpos($avatar, 'assets/img/students/') === false) {
                        if (strpos($avatar, '../app/assets/img/students/') === 0 || strpos($avatar, '../assets/img/students/') === 0) {
                            // Remove ../ prefix and normalize to app/assets/
                            $avatar = 'app/' . ltrim(substr($avatar, 3), '/');
                            if (strpos($avatar, 'app/assets/') === false) {
                                $avatar = str_replace('assets/', 'app/assets/', $avatar);
                            }
                        } else {
                            // Assume it's just a filename, prepend the path
                            $avatar = 'app/assets/img/students/' . basename($avatar);
                        }
                    } elseif (strpos($avatar, 'assets/img/students/') !== false && strpos($avatar, 'app/assets/') === false) {
                        // Normalize old assets/ paths to app/assets/
                        $avatar = str_replace('assets/', 'app/assets/', $avatar);
                    }
                }
            }
            
            $students[] = [
                'id' => $row['id'] ?? 0,
                'studentId' => $row['student_id'] ?? '',
                'firstName' => $firstName,
                'middleName' => $middleName,
                'lastName' => $lastName,
                'email' => $row['email'] ?? '',
                'contact' => $row['contact_number'] ?: 'N/A',
                'address' => $row['address'] ?: '',
                'department' => $row['department_name'] ?? ($row['department'] ?? 'N/A'),
                'section' => $row['section_code'] ?? 'N/A',
                'section_id' => $row['section_id'] ?? null,
                'yearlevel' => $row['yearlevel'] ?? 'N/A',
                'status' => $row['status'] ?? 'active',
                'avatar' => $avatar,
                'date' => isset($row['created_at']) ? date('M d, Y', strtotime($row['created_at'])) : date('M d, Y')
            ];
        }
        
        $stmt->close();
        return $students;
    }

    /**
     * Count active students
     */
    public function countActive() {
        $query = "SELECT COUNT(*) as count FROM students WHERE status != 'archived' OR status IS NULL";
        $result = $this->conn->query($query);
        if ($result) {
            $row = $result->fetch_assoc();
            return (int)$row['count'];
        }
        return 0;
    }

    public function getCountWithFilters($filter = 'all', $search = '') {
        $sectionsExist = $this->tableExists('sections');
        $deptExist = $this->tableExists('departments');

        if ($sectionsExist && $deptExist) {
            $query = "SELECT COUNT(DISTINCT s.id) as total
                      FROM students s
                      LEFT JOIN sections sec ON s.section_id = sec.id
                      LEFT JOIN departments d ON s.department = d.department_code
                      WHERE 1=1";
        } elseif ($sectionsExist) {
            $query = "SELECT COUNT(DISTINCT s.id) as total
                      FROM students s
                      LEFT JOIN sections sec ON s.section_id = sec.id
                      WHERE 1=1";
        } else {
            $query = "SELECT COUNT(*) as total
                      FROM students s
                      WHERE 1=1";
        }

        $params = [];
        $types = "";

        if ($filter === 'active') {
            $query .= " AND s.status = 'active'";
        } elseif ($filter === 'inactive') {
            $query .= " AND s.status = 'inactive'";
        } elseif ($filter === 'graduating') {
            $query .= " AND s.status = 'graduating'";
        } elseif ($filter === 'archived') {
            $query .= " AND s.status = 'archived'";
        } else {
            $query .= " AND s.status != 'archived'";
        }

        if (!empty($search)) {
            if ($sectionsExist && $deptExist) {
                $query .= " AND (s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ? OR s.student_id LIKE ? OR s.email LIKE ? OR s.department LIKE ? OR d.department_name LIKE ? OR sec.section_code LIKE ? OR sec.section_name LIKE ?)";
                $searchTerm = "%$search%";
                $params = array_fill(0, 9, $searchTerm);
                $types = "sssssssss";
            } elseif ($sectionsExist) {
                $query .= " AND (s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ? OR s.student_id LIKE ? OR s.email LIKE ? OR s.department LIKE ? OR sec.section_code LIKE ? OR sec.section_name LIKE ?)";
                $searchTerm = "%$search%";
                $params = array_fill(0, 8, $searchTerm);
                $types = "ssssssss";
            } else {
                $query .= " AND (s.first_name LIKE ? OR s.last_name LIKE ? OR s.middle_name LIKE ? OR s.student_id LIKE ? OR s.email LIKE ? OR s.department LIKE ?)";
                $searchTerm = "%$search%";
                $params = array_fill(0, 6, $searchTerm);
                $types = "ssssss";
            }
        }

        $stmt = $this->conn->prepare($query);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $stmt->close();
        return (int)($row['total'] ?? 0);
    }

    /**
     * Get statistics
     */
    public function getStats() {
        $stats = [];
        $stats['total'] = $this->query("SELECT COUNT(*) as count FROM students")[0]['count'];
        $stats['active'] = $this->query("SELECT COUNT(*) as count FROM students WHERE status = 'active'")[0]['count'];
        $stats['inactive'] = $this->query("SELECT COUNT(*) as count FROM students WHERE status = 'inactive'")[0]['count'];
        $stats['graduating'] = $this->query("SELECT COUNT(*) as count FROM students WHERE status = 'graduating'")[0]['count'];
        $stats['archived'] = $this->query("SELECT COUNT(*) as count FROM students WHERE status = 'archived'")[0]['count'];
        return $stats;
    }

    /**
     * Get student by student_id (the actual student ID string)
     */
    public function getByStudentId($studentId) {
        // Check if table exists
        $tableCheck = @$this->conn->query("SHOW TABLES LIKE '{$this->table}'");
        if ($tableCheck === false || $tableCheck->num_rows === 0) {
            return null;
        }

        // Check if sections and departments tables exist
        $sectionsExist = $this->tableExists('sections');
        $deptExist = $this->tableExists('departments');
        
        // Build query with JOINs
        if ($sectionsExist && $deptExist) {
            $query = "SELECT s.*, 
                             COALESCE(sec.section_name, 'N/A') as section_name, 
                             COALESCE(sec.section_code, 'N/A') as section_code, 
                             COALESCE(d.department_name, s.department) as department_name
                      FROM students s
                      LEFT JOIN sections sec ON s.section_id = sec.id
                      LEFT JOIN departments d ON s.department = d.department_code
                      WHERE s.student_id = ? AND s.status != 'archived'";
        } elseif ($sectionsExist) {
            $query = "SELECT s.*, 
                             COALESCE(sec.section_name, 'N/A') as section_name, 
                             COALESCE(sec.section_code, 'N/A') as section_code, 
                             s.department as department_name
                      FROM students s
                      LEFT JOIN sections sec ON s.section_id = sec.id
                      WHERE s.student_id = ? AND s.status != 'archived'";
        } else {
            $query = "SELECT s.*, 
                             'N/A' as section_name, 
                             'N/A' as section_code, 
                             s.department as department_name
                      FROM students s
                      WHERE s.student_id = ? AND s.status != 'archived'";
        }

        try {
            $stmt = $this->conn->prepare($query);
            if ($stmt) {
                $stmt->bind_param("s", $studentId);
                $stmt->execute();
                $result = $stmt->get_result();
                
                if ($result->num_rows > 0) {
                    $row = $result->fetch_assoc();
                    
                    // Format the data similar to getAllWithDetails
                    $firstName = trim($row['first_name'] ?? '');
                    $middleName = trim($row['middle_name'] ?? '');
                    $lastName = trim($row['last_name'] ?? '');
                    
                    $avatar = $row['avatar'] ?? null;
                    if ($avatar && !empty($avatar) && trim($avatar) !== '') {
                        // If avatar is already a full path (contains app/assets or assets), use it as is
                        if (strpos($avatar, 'app/assets/img/students/') !== false || 
                            strpos($avatar, 'assets/img/students/') !== false) {
                            // Already has full path, use as is
                            if (strpos($avatar, 'app/assets/') === false && strpos($avatar, 'assets/') !== false) {
                                // Normalize to app/assets/
                                $avatar = str_replace('assets/', 'app/assets/', $avatar);
                            }
                        } elseif (!filter_var($avatar, FILTER_VALIDATE_URL) && !str_starts_with($avatar, '/')) {
                            // If it's just a filename, prepend the path
                            $avatar = 'app/assets/img/students/' . basename($avatar);
                        }
                    } else {
                        $avatar = 'app/assets/img/default.png';
                    }
                    
                    return [
                        'id' => $row['id'] ?? 0,
                        'student_id' => $row['student_id'] ?? '',
                        'studentId' => $row['student_id'] ?? '',
                        'first_name' => $firstName,
                        'firstName' => $firstName,
                        'middle_name' => $middleName,
                        'middleName' => $middleName,
                        'last_name' => $lastName,
                        'lastName' => $lastName,
                        'email' => $row['email'] ?? '',
                        'contact_number' => $row['contact_number'] ?? null,
                        'contact' => $row['contact_number'] ?? null,
                        'phone' => $row['contact_number'] ?? null,
                        'address' => $row['address'] ?? '',
                        'department' => $row['department_name'] ?? ($row['department'] ?? 'N/A'),
                        'department_name' => $row['department_name'] ?? ($row['department'] ?? 'N/A'),
                        'section' => $row['section_code'] ?? 'N/A',
                        'section_code' => $row['section_code'] ?? 'N/A',
                        'section_name' => $row['section_name'] ?? 'N/A',
                        'section_id' => $row['section_id'] ?? null,
                        'status' => $row['status'] ?? 'active',
                        'avatar' => $avatar,
                        'date_of_birth' => $row['date_of_birth'] ?? null,
                        'dateOfBirth' => $row['date_of_birth'] ?? null,
                        'dob' => $row['date_of_birth'] ?? null,
                        'gender' => $row['gender'] ?? null,
                        'year_level' => $row['year_level'] ?? null,
                        'yearLevel' => $row['year_level'] ?? null,
                        'year' => $row['year_level'] ?? null,
                        'yearlevel' => $row['yearlevel'] ?? null,
                        'created_at' => $row['created_at'] ?? null,
                        'createdAt' => $row['created_at'] ?? null,
                        'enrollment_date' => $row['created_at'] ?? null,
                        'enrollmentDate' => $row['created_at'] ?? null
                    ];
                }
                $stmt->close();
            }
            return null;
        } catch (Exception $e) {
            error_log("StudentModel::getByStudentId error: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Check if student_id exists
     */
    public function studentIdExists($studentId, $excludeId = null) {
        $query = "SELECT id FROM students WHERE student_id = ?";
        if ($excludeId) {
            $query .= " AND id != ?";
            $result = $this->query($query, [$studentId, $excludeId]);
        } else {
            $result = $this->query($query, [$studentId]);
        }
        return count($result) > 0;
    }

    /**
     * Check if email exists
     */
    public function emailExists($email, $excludeId = null) {
        $query = "SELECT id FROM students WHERE email = ?";
        if ($excludeId) {
            $query .= " AND id != ?";
            $result = $this->query($query, [$email, $excludeId]);
        } else {
            $result = $this->query($query, [$email]);
        }
        return count($result) > 0;
    }

    /**
     * Archive student
     */
    public function archive($id) {
        return $this->update($id, ['status' => 'archived', 'updated_at' => date('Y-m-d H:i:s')]);
    }

    /**
     * Restore student
     */
    public function restore($id) {
        return $this->update($id, ['status' => 'active', 'updated_at' => date('Y-m-d H:i:s')]);
    }

    /**
     * Check if table exists
     */
    private function tableExists($tableName) {
        $result = $this->conn->query("SHOW TABLES LIKE '$tableName'");
        return $result && $result->num_rows > 0;
    }
}

