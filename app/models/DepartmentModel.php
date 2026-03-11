<?php
require_once __DIR__ . '/../core/Model.php';

class DepartmentModel extends Model {
    protected $table = 'departments';
    protected $primaryKey = 'id';

    /**
     * Get all departments with filters and pagination
     */
    public function getAllWithFilters($filter = 'all', $search = '', $page = null, $limit = null) {
        $query = "SELECT d.*, 
                         COUNT(DISTINCT s.id) as student_count
                  FROM departments d
                  LEFT JOIN students s ON d.department_code = s.department AND s.status != 'archived'
                  WHERE 1=1";
        $params = [];
        $types = "";

        if ($filter === 'active') {
            $query .= " AND d.status = 'active'";
        } elseif ($filter === 'archived') {
            $query .= " AND d.status = 'archived'";
        }

        if (!empty($search)) {
            $query .= " AND (d.department_name LIKE ? OR d.department_code LIKE ?)";
            $searchTerm = "%$search%";
            $params = [$searchTerm, $searchTerm];
            $types = "ss";
        }

        $query .= " GROUP BY d.id ORDER BY d.department_name ASC";

        if ($limit !== null && $page !== null) {
            $offset = ($page - 1) * $limit;
            $query .= " LIMIT ?, ?";
            $params[] = $offset;
            $params[] = $limit;
            $types .= "ii";
        }

        $stmt = $this->conn->prepare($query);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();

        $departments = [];
        while ($row = $result->fetch_assoc()) {
            $departments[] = [
                'id' => (int)$row['id'],
                'department_id' => (int)$row['id'],
                'name' => $row['department_name'] ?? '',
                'code' => $row['department_code'] ?? '',
                'hod' => $row['head_of_department'] ?? 'N/A',
                'student_count' => (int)($row['student_count'] ?? 0),
                'date' => isset($row['created_at']) ? date('M d, Y', strtotime($row['created_at'])) : date('M d, Y'),
                'status' => $row['status'] ?? 'active',
                'description' => $row['description'] ?? ''
            ];
        }

        $stmt->close();
        return $departments;
    }

    /**
     * Get total count with filters
     */
    public function getCountWithFilters($filter = 'all', $search = '') {
        $query = "SELECT COUNT(*) as count FROM departments d WHERE 1=1";
        $params = [];
        $types = "";

        if ($filter === 'active') {
            $query .= " AND d.status = 'active'";
        } elseif ($filter === 'archived') {
            $query .= " AND d.status = 'archived'";
        }

        if (!empty($search)) {
            $query .= " AND (d.department_name LIKE ? OR d.department_code LIKE ?)";
            $searchTerm = "%$search%";
            $params = [$searchTerm, $searchTerm];
            $types = "ss";
        }

        $stmt = $this->conn->prepare($query);
        if (!empty($params)) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $stmt->close();

        return (int)$row['count'];
    }

    /**
     * Get departments for dropdown
     */
    public function getForDropdown() {
        $query = "SELECT id, department_name as name, department_code as code 
                  FROM departments 
                  WHERE status = 'active' 
                  ORDER BY department_name ASC";
        
        $stmt = $this->conn->prepare($query);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $departments = [];
        while ($row = $result->fetch_assoc()) {
            $departments[] = [
                'id' => (int)$row['id'],
                'name' => $row['name'],
                'code' => $row['code']
            ];
        }
        
        $stmt->close();
        return $departments;
    }

    /**
     * Check if department code exists among active departments
     */
    public function codeExists($code, $excludeId = null) {
        // Only check for departments that are NOT archived
        $query = "SELECT id FROM departments WHERE department_code = ? AND status != 'archived'";
        if ($excludeId) {
            $query .= " AND id != ?";
            $result = $this->query($query, [$code, $excludeId]);
        } else {
            $result = $this->query($query, [$code]);
        }
        return count($result) > 0;
    }

    /**
     * Archive department
     */
    public function archive($id) {
        return $this->update($id, ['status' => 'archived', 'updated_at' => date('Y-m-d H:i:s')]);
    }

    /**
     * Restore department
     */
    public function restore($id) {
        return $this->update($id, ['status' => 'active', 'updated_at' => date('Y-m-d H:i:s')]);
    }

    /**
     * Get statistics
     */
    public function getStats() {
        $stats = [];
        $stats['total'] = $this->query("SELECT COUNT(*) as count FROM departments")[0]['count'];
        $stats['active'] = $this->query("SELECT COUNT(*) as count FROM departments WHERE status = 'active'")[0]['count'];
        $stats['archived'] = $this->query("SELECT COUNT(*) as count FROM departments WHERE status = 'archived'")[0]['count'];
        return $stats;
    }
}

