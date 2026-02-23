<?php
require_once __DIR__ . '/../core/Model.php';

class ViolationModel extends Model {
    protected $table = 'violations';
    protected $primaryKey = 'id';

    /**
     * Get all violations with student info
     */
    public function getAllWithStudentInfo($filter = 'all', $search = '', $studentId = '', $dateFrom = '', $dateTo = '', $isArchived = 0, $specificId = null) {
        // Check if violations table exists
        $tableCheck = @$this->conn->query("SHOW TABLES LIKE 'violations'");
        if ($tableCheck === false || $tableCheck->num_rows === 0) {
            throw new Exception('Violations table does not exist. Please run the database setup SQL file: database/osas.sql');
        }

        // Auto-fix: Check if is_archived column exists, if not add it
        $columnCheck = @$this->conn->query("SHOW COLUMNS FROM violations LIKE 'is_archived'");
        if ($columnCheck === false || $columnCheck->num_rows === 0) {
            @$this->conn->query("ALTER TABLE violations ADD COLUMN is_archived TINYINT(1) DEFAULT 0");
            @$this->conn->query("ALTER TABLE violations ADD INDEX idx_is_archived (is_archived)");
        }
        
        // First, check if there are any violations at all (without JOIN)
        $countQuery = "SELECT COUNT(*) as total FROM violations WHERE is_archived = ?";
        $stmtCount = $this->conn->prepare($countQuery);
        $stmtCount->bind_param("i", $isArchived);
        $stmtCount->execute();
        $countResult = $stmtCount->get_result();
        
        $totalCount = 0;
        if ($countResult) {
            $countRow = $countResult->fetch_assoc();
            $totalCount = (int)$countRow['total'];
        }
        
        error_log("ViolationsModel: Total violations in database (archived=$isArchived): $totalCount");
        
        // If no violations exist, return empty array immediately
        if ($totalCount === 0) {
            error_log("ViolationsModel: No violations found in database, returning empty array");
            return [];
        }
        
        // Use LEFT JOIN so we get violations even if student doesn't exist
        // Fix collation mismatch by using BINARY comparison (case-sensitive but works with any collation)
        // Also join with departments table to get department names
        $query = "SELECT 
                    v.*, 
                    vt.name as violation_type_name,
                    vl.name as violation_level_name,
                    s.student_id as student_id_no,
                    s.first_name, 
                    s.middle_name, 
                    s.last_name, 
                    s.email, 
                    s.contact_number, 
                    s.avatar,
                    s.department as student_dept,
                    s.section_id as student_section,
                    s.yearlevel as student_yearlevel,
                    s.department as student_dept_code,
                    COALESCE(d.department_name, s.department) as department_name,
                    COALESCE(sec.section_name, 'N/A') as section_name,
                    COALESCE(sec.section_code, 'N/A') as section_code
                  FROM violations v
                  LEFT JOIN violation_types vt ON v.violation_type_id = vt.id
                  LEFT JOIN violation_levels vl ON v.violation_level_id = vl.id
                  LEFT JOIN students s ON BINARY v.student_id = BINARY s.student_id
                  LEFT JOIN departments d ON s.department = d.department_code
                  LEFT JOIN sections sec ON s.section_id = sec.id
                  WHERE v.is_archived = ?";
        
        $params = [$isArchived];
        $types = "i";

        if (!empty($studentId)) {
            // If it's a numeric ID, allow filtering by students.id as well.
            // Otherwise, only filter by the student_id string to avoid MySQL coercion issues
            // (e.g. "2024-001" being treated as 2024).
            if (ctype_digit((string)$studentId)) {
                $query .= " AND (BINARY v.student_id = BINARY ? OR BINARY s.student_id = BINARY ? OR s.id = ?)";
                $params[] = $studentId;
                $params[] = $studentId;
                $params[] = (int)$studentId;
                $types .= "ssi";
            } else {
                $query .= " AND (BINARY v.student_id = BINARY ? OR BINARY s.student_id = BINARY ?)";
                $params[] = $studentId;
                $params[] = $studentId;
                $types .= "ss";
            }
        }

        if ($filter === 'resolved') {
            $query .= " AND v.status = 'resolved'";
        } elseif ($filter === 'pending') {
            $query .= " AND v.status IN ('warning', 'permitted')";
        } elseif ($filter === 'disciplinary') {
            $query .= " AND v.status = 'disciplinary'";
        }

        if (!empty($search)) {
            $query .= " AND (v.case_id LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR v.student_id LIKE ? OR vt.name LIKE ?)";
            $searchTerm = "%$search%";
            $searchParams = array_fill(0, 5, $searchTerm);
            $params = array_merge($params, $searchParams);
            $types .= "sssss";
        }

        if (!empty($dateFrom)) {
            $query .= " AND v.violation_date >= ?";
            $params[] = $dateFrom;
            $types .= "s";
        }

        if (!empty($dateTo)) {
            $query .= " AND v.violation_date <= ?";
            $params[] = $dateTo;
            $types .= "s";
        }

        if (!empty($specificId)) {
            $query .= " AND v.id = ?";
            $params[] = $specificId;
            $types .= "i";
        }

        $query .= " ORDER BY v.created_at DESC";

        try {
            // Debug: Log the query (remove in production)
            error_log("Violations Query: " . $query);
            error_log("Query params: " . print_r($params, true));
            
            $stmt = $this->conn->prepare($query);
            if (!$stmt) {
                $error = $this->conn->error;
                error_log("Prepare failed: " . $error);
                error_log("Query was: " . $query);
                throw new Exception('Prepare failed: ' . $error);
            }
            
            if (!empty($params) && !empty($types)) {
                if (!$stmt->bind_param($types, ...$params)) {
                    $error = $stmt->error;
                    error_log("Bind param failed: " . $error);
                    throw new Exception('Bind param failed: ' . $error);
                }
            }
            
            if (!$stmt->execute()) {
                $error = $stmt->error;
                error_log("Execute failed: " . $error);
                throw new Exception('Execute failed: ' . $error);
            }
            
            $result = $stmt->get_result();
            
            // Check if result is valid
            if ($result === false) {
                $error = $this->conn->error;
                error_log("Failed to get result: " . $error);
                throw new Exception('Failed to get result: ' . $error);
            }
            
            // Debug: Log row count
            $rowCount = $result ? $result->num_rows : 0;
            error_log("Violations query returned $rowCount rows");
            
        } catch (Exception $e) {
            if (isset($stmt)) {
                $stmt->close();
            }
            error_log("Violations query error: " . $e->getMessage());
            throw new Exception('Database query error: ' . $e->getMessage());
        }

        $violations = [];
        
        // Check if result is valid and has rows
        if ($result === false) {
            error_log("ViolationsModel: Result is false, query may have failed");
            $stmt->close();
            return [];
        }
        
        if ($result && $result->num_rows > 0) {
            error_log("ViolationsModel: Processing " . $result->num_rows . " rows");
            while ($row = $result->fetch_assoc()) {
                $firstName = $row['first_name'] ?? '';
                $middleName = $row['middle_name'] ?? '';
                $lastName = $row['last_name'] ?? '';
                $fullName = trim($firstName . ' ' . ($middleName ? $middleName . ' ' : '') . $lastName);
                
                // If no student name from JOIN, use student_id as fallback
                if (empty($fullName)) {
                    $fullName = 'Student ' . ($row['student_id'] ?? 'Unknown');
                }

                $avatar = $row['avatar'] ?? '';
                if (empty($avatar)) {
                    $avatar = 'https://ui-avatars.com/api/?name=' . urlencode($fullName) . '&background=ffd700&color=333&size=80';
                }

                $violationTypeLabel = $row['violation_type_name'] ?? 'Unknown Type';
                $violationLevelLabel = $row['violation_level_name'] ?? 'Unknown Level';

                $statusLabels = [
                    'permitted' => 'Permitted',
                    'warning' => 'Warning',
                    'disciplinary' => 'Disciplinary',
                    'resolved' => 'Resolved'
                ];
                $statusLabel = $statusLabels[$row['status']] ?? ucfirst($row['status']);

                $locationLabels = [
                    'gate_1' => 'Main Gate 1',
                    'gate_2' => 'Gate 2',
                    'classroom' => 'Classroom',
                    'library' => 'Library',
                    'cafeteria' => 'Cafeteria',
                    'gym' => 'Gymnasium',
                    'others' => 'Others'
                ];
                $locationLabel = $locationLabels[$row['location']] ?? ucfirst(str_replace('_', ' ', $row['location']));

                $violationDateTime = '';
                if ($row['violation_date'] && $row['violation_time']) {
                    $dateTime = new DateTime($row['violation_date'] . ' ' . $row['violation_time']);
                    $violationDateTime = $dateTime->format('M d, Y • h:i A');
                }

                $violations[] = [
                    'id' => (int)$row['id'],
                    'caseId' => $row['case_id'] ?? '',
                    'studentId' => $row['student_id'] ?? '',
                    'studentName' => $fullName,
                    'studentImage' => $avatar,
                    'studentDept' => $row['department_name'] ?? $row['student_dept'] ?? 'N/A',
                    'studentSection' => $row['section_code'] ?? $row['section_name'] ?? 'N/A',
                    'studentYearlevel' => $row['student_yearlevel'] ?? 'N/A',
                    'studentContact' => $row['contact_number'] ?? 'N/A',
                    'violationType' => $row['violation_type_id'] ?? '',
                    'violationTypeLabel' => $violationTypeLabel,
                    'violationLevel' => $row['violation_level_id'] ?? '',
                    'violationLevelLabel' => $violationLevelLabel,
                    'department' => $row['department_name'] ?? $row['student_dept'] ?? 'N/A',
                    'department_code' => $row['student_dept_code'] ?? $row['student_dept'] ?? 'N/A',
                    'section' => $row['section_code'] ?? $row['section_name'] ?? 'N/A',
                    'dateReported' => $row['violation_date'] ?? '',
                    'violationTime' => $row['violation_time'] ?? '',
                    'dateTime' => $violationDateTime,
                    'location' => $row['location'] ?? '',
                    'locationLabel' => $locationLabel,
                    'reportedBy' => $row['reported_by'] ?? '',
                    'status' => $row['status'] ?? 'warning',
                    'statusLabel' => $statusLabel,
                    'notes' => $row['notes'] ?? '',
                    'attachments' => !empty($row['attachments']) ? json_decode($row['attachments'], true) : [],
                    'created_at' => $row['created_at'] ?? '',
                    'updated_at' => $row['updated_at'] ?? ''
                ];
            }
        }

        if (isset($stmt)) {
            $stmt->close();
        }
        
        // Log final count
        error_log("ViolationsModel: Returning " . count($violations) . " violations");
        
        // If no violations returned but query succeeded, log a warning
        if (count($violations) === 0 && $totalCount > 0) {
            error_log("WARNING: ViolationsModel query returned 0 rows but database has $totalCount violations. Check if JOIN is working or if filters are too restrictive.");
        } elseif (count($violations) === 0 && $totalCount === 0) {
            error_log("INFO: No violations in database (count is 0)");
        }
        
        return $violations;
    }

    /**
     * Check if a monthly reset is needed and trigger it automatically
     */
    public function checkAndTriggerAutoArchive() {
        // Check if settings table exists
        $tableCheck = @$this->conn->query("SHOW TABLES LIKE 'settings'");
        if ($tableCheck === false || $tableCheck->num_rows === 0) {
            return false;
        }

        // Get last reset month from settings
        $query = "SELECT setting_value FROM settings WHERE setting_key = 'last_monthly_reset' LIMIT 1";
        $result = $this->conn->query($query);
        
        $lastResetMonth = '';
        if ($result && $row = $result->fetch_assoc()) {
            $lastResetMonth = $row['setting_value'];
        } else {
            // Setting doesn't exist, create it
            // Default to current month so we don't archive everything on the very first run 
            // unless the admin explicitly clicks the reset button
            $lastResetMonth = date('Y-m');
            $insertQuery = "INSERT INTO settings (setting_key, setting_value, setting_type, category, description) 
                           VALUES ('last_monthly_reset', ?, 'string', 'system', 'Last month when the violations were archived')";
            $stmt = $this->conn->prepare($insertQuery);
            $stmt->bind_param("s", $lastResetMonth);
            $stmt->execute();
            $stmt->close();
        }

        $currentMonth = date('Y-m');
        if ($lastResetMonth !== $currentMonth) {
            error_log("ViolationModel: Triggering automatic monthly reset for $currentMonth (last reset was $lastResetMonth)");
            
            try {
                // Trigger archive
                $this->archiveOldViolations();
                
                // Update last reset date
                $updateQuery = "UPDATE settings SET setting_value = ?, updated_at = NOW() WHERE setting_key = 'last_monthly_reset'";
                $stmt = $this->conn->prepare($updateQuery);
                $stmt->bind_param("s", $currentMonth);
                $stmt->execute();
                $stmt->close();
                
                return true;
            } catch (Exception $e) {
                error_log("ViolationModel: Automatic reset failed: " . $e->getMessage());
                return false;
            }
        }
        
        return false;
    }

    /**
     * Archive violations from previous months and reset student violation levels
     */
    public function archiveOldViolations() {
        // Start transaction
        $this->conn->begin_transaction();

        try {
            // 1. Mark violations from previous months as archived
            // A violation is "old" if its violation_date is before the first day of the current month
            $currentMonthStart = date('Y-m-01');
            
            $archiveQuery = "UPDATE violations SET is_archived = 1 WHERE violation_date < ? AND is_archived = 0";
            $stmt = $this->conn->prepare($archiveQuery);
            $stmt->bind_param("s", $currentMonthStart);
            $stmt->execute();
            $archivedCount = $stmt->affected_rows;
            $stmt->close();

            // 2. Reset student_violation_levels
            // We reset counts and levels for all students who had violations that were just archived
            // Or simply reset everyone if "reset every month" means a fresh start for all.
            // Usually, it means everyone starts fresh.
            $resetQuery = "UPDATE student_violation_levels SET 
                            current_level = 'permitted1',
                            permitted_count = 0,
                            warning_count = 0,
                            total_violations = 0,
                            status = 'active',
                            updated_at = CURRENT_TIMESTAMP";
            $this->conn->query($resetQuery);

            $this->conn->commit();
            return $archivedCount;
        } catch (Exception $e) {
            $this->conn->rollback();
            error_log("Error archiving violations: " . $e->getMessage());
            throw $e;
        }
    }

    /**
     * Generate case ID
     */
    public function generateCaseId() {
        $year = date('Y');
        $result = $this->query("SELECT COUNT(*) as count FROM violations WHERE YEAR(created_at) = ?", [$year]);
        $count = ($result[0]['count'] ?? 0) + 1;
        return sprintf('VIOL-%d-%03d', $year, $count);
    }

    /**
     * Check for duplicate violation with time tolerance
     */
    public function checkDuplicate($studentId, $violationTypeId, $violationLevelId, $violationDate, $violationTime, $location) {
        $query = "SELECT id FROM violations 
                  WHERE student_id = ? 
                  AND violation_type_id = ? 
                  AND violation_level_id = ?
                  AND violation_date = ? 
                  AND violation_time = ? 
                  AND location = ? 
                  AND deleted_at IS NULL";
        
        $result = $this->query($query, [$studentId, $violationTypeId, $violationLevelId, $violationDate, $violationTime, $location]);
        return !empty($result) ? $result[0]['id'] : false;
    }

    /**
     * Check for duplicate violation submission (exact match or created recently)
     */
    public function checkDuplicateSubmission($studentId, $violationTypeId, $violationLevelId, $violationDate, $violationTime, $location) {
        // 1. Check for exact match (same details)
        // We check for records created recently (last 10 seconds) with same details to catch double-clicks
        // OR simply check if such a violation exists at all. 
        // Given "only one", we assume strict uniqueness for (student, type, date, time).
        
        $query = "SELECT id FROM violations 
                  WHERE student_id = ? 
                  AND violation_type_id = ? 
                  AND violation_level_id = ?
                  AND violation_date = ? 
                  AND violation_time = ? 
                  AND location = ? 
                  AND deleted_at IS NULL";
        
        $result = $this->query($query, [$studentId, $violationTypeId, $violationLevelId, $violationDate, $violationTime, $location]);
        
        if (!empty($result)) {
            return $result[0]['id'];
        }

        // 2. Check for "same violation, different timestamp" if needed (e.g. submitted 1 second apart but with different input time?)
        // If the user inputs the time manually, it will be the same.
        // If the system auto-generates time, it might differ.
        // Assuming user inputs time or system sets it once in frontend.
        
        return false;
    }

    /**
     * Check for duplicate violation within time window (for near-simultaneous submissions)
     */
    public function checkDuplicateInTimeWindow($studentId, $violationTypeId, $violationLevelId, $violationDate, $violationTime, $location, $timeWindowMinutes = 5) {
        // Check exact match first
        $exactMatch = $this->checkDuplicate($studentId, $violationTypeId, $violationLevelId, $violationDate, $violationTime, $location);
        if ($exactMatch) {
            return $exactMatch;
        }

        // Check for violations within time window
        // Use CAST(? AS TIME) to handle various time formats safely
        $query = "SELECT id, violation_time FROM violations 
                  WHERE student_id = ? 
                  AND violation_type_id = ? 
                  AND violation_level_id = ?
                  AND violation_date = ? 
                  AND location = ? 
                  AND deleted_at IS NULL
                  AND ABS(TIMESTAMPDIFF(MINUTE, CAST(? AS TIME), violation_time)) <= ?";
        
        $result = $this->query($query, [$studentId, $violationTypeId, $violationLevelId, $violationDate, $location, $violationTime, $timeWindowMinutes]);
        return !empty($result) ? $result[0]['id'] : false;
    }

    /**
     * Check if case ID already exists
     */
    public function caseIdExists($caseId) {
        $query = "SELECT id FROM violations WHERE case_id = ?";
        $result = $this->query($query, [$caseId]);
        return !empty($result);
    }

    /**
     * Get all violation types
     */
    public function getViolationTypes() {
        return $this->query("SELECT * FROM violation_types ORDER BY name ASC");
    }

    /**
     * Get violation levels by type
     */
    public function getViolationLevels($typeId) {
        // This method relies on the base Model::query method which returns an array
        // We need to implement query() in Model.php or use prepare/execute here
        // Since Model.php as I read earlier didn't have query(), I should implement it properly using prepare
        
        $query = "SELECT * FROM violation_levels WHERE violation_type_id = ? ORDER BY level_order ASC";
        $stmt = $this->conn->prepare($query);
        $stmt->bind_param("i", $typeId);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $levels = [];
        while ($row = $result->fetch_assoc()) {
            $levels[] = $row;
        }
        $stmt->close();
        return $levels;
    }


    /**
     * Count total violations
     */
    public function countViolations($studentId = null) {
        $query = "SELECT COUNT(*) as count FROM violations v";
        $params = [];
        $types = "";
        
        if ($studentId) {
            $query .= " WHERE BINARY v.student_id = BINARY ?";
            $params[] = $studentId;
            $types = "s";
        }
        
        if (!empty($params)) {
            $stmt = $this->conn->prepare($query);
            $stmt->bind_param($types, ...$params);
            $stmt->execute();
            $result = $stmt->get_result();
            $row = $result->fetch_assoc();
            $stmt->close();
            return (int)$row['count'];
        } else {
            $result = $this->conn->query($query);
            if ($result) {
                $row = $result->fetch_assoc();
                return (int)$row['count'];
            }
        }
        return 0;
    }

    /**
     * Count unique violators
     */
    public function countViolators($studentId = null) {
        if ($studentId) {
            return $this->countViolations($studentId) > 0 ? 1 : 0;
        }
        
        $query = "SELECT COUNT(DISTINCT student_id) as count FROM violations WHERE student_id IS NOT NULL AND student_id != ''";
        $result = $this->conn->query($query);
        if ($result) {
            $row = $result->fetch_assoc();
            return (int)$row['count'];
        }
        return 0;
    }

    /**
     * Count penalties (disciplinary actions)
     */
    public function countPenalties($studentId = null) {
        $query = "SELECT COUNT(*) as count FROM violations v WHERE v.status = 'disciplinary'";
        $params = [];
        $types = "";
        
        if ($studentId) {
            $query .= " AND BINARY v.student_id = BINARY ?";
            $params[] = $studentId;
            $types = "s";
        }
        
        if (!empty($params)) {
            $stmt = $this->conn->prepare($query);
            $stmt->bind_param($types, ...$params);
            $stmt->execute();
            $result = $stmt->get_result();
            $row = $result->fetch_assoc();
            $stmt->close();
            return (int)$row['count'];
        } else {
            $result = $this->conn->query($query);
            if ($result) {
                $row = $result->fetch_assoc();
                return (int)$row['count'];
            }
        }
        return 0;
    }

    /**
     * Get recent violations
     */
    public function getRecent($limit = 10, $studentId = null) {
        $query = "
            SELECT v.id,
                   v.case_id,
                   v.student_id,
                   vt.name as violation_type,
                   vl.name as violation_level,
                   v.violation_date,
                   v.violation_time,
                   v.status,
                   v.location,
                   v.reported_by,
                   v.notes,
                   v.created_at,
                   v.updated_at,
                   s.first_name, 
                   s.last_name, 
                   s.avatar,
                   s.department
            FROM violations v
            LEFT JOIN students s ON BINARY v.student_id = BINARY s.student_id
            LEFT JOIN violation_types vt ON v.violation_type_id = vt.id
            LEFT JOIN violation_levels vl ON v.violation_level_id = vl.id
        ";
        
        $params = [];
        $types = "";
        
        if ($studentId) {
            $query .= " WHERE BINARY v.student_id = BINARY ?";
            $params[] = $studentId;
            $types = "s";
        }
        
        $query .= " ORDER BY v.created_at DESC LIMIT ?";
        $params[] = $limit;
        $types .= "i";
        
        $stmt = $this->conn->prepare($query);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $data = [];
        while ($row = $result->fetch_assoc()) {
            // Normalize avatar
            $firstName = $row['first_name'] ?? '';
            $middleName = ''; // Not in query but needed for normalization
            $lastName = $row['last_name'] ?? '';
            $fullName = trim($firstName . ' ' . $lastName);
            
            $avatar = $row['avatar'] ?? '';
            if (empty($avatar) || trim($avatar) === '') {
                $avatar = 'https://ui-avatars.com/api/?name=' . urlencode($fullName) . '&background=ffd700&color=333&size=40';
            } else {
                if (!filter_var($avatar, FILTER_VALIDATE_URL) && strpos($avatar, 'data:') !== 0) {
                    if (strpos($avatar, 'app/assets/img/students/') === false && strpos($avatar, 'assets/img/students/') === false) {
                         if (strpos($avatar, '../app/assets/img/students/') === 0 || strpos($avatar, '../assets/img/students/') === 0) {
                             $avatar = 'app/' . ltrim(substr($avatar, 3), '/');
                             if (strpos($avatar, 'app/assets/') === false) {
                                 $avatar = str_replace('assets/', 'app/assets/', $avatar);
                             }
                         } else {
                             $avatar = 'app/assets/img/students/' . basename($avatar);
                         }
                    } elseif (strpos($avatar, 'assets/img/students/') !== false && strpos($avatar, 'app/assets/') === false) {
                        $avatar = str_replace('assets/', 'app/assets/', $avatar);
                    }
                }
            }
            $row['avatar'] = $avatar;
            
            $data[] = $row;
        }
        $stmt->close();
        return $data;
    }

    /**
     * Get top violators
     */
    public function getTopViolators($limit = 5, $studentId = null) {
        $query = "
            SELECT 
                v.student_id,
                s.first_name,
                s.last_name,
                s.avatar,
                COUNT(*) as violation_count
            FROM violations v
            LEFT JOIN students s ON BINARY v.student_id = BINARY s.student_id
        ";
        
        $params = [];
        $types = "";
        
        if ($studentId) {
            $query .= " WHERE BINARY v.student_id = BINARY ?";
            $params[] = $studentId;
            $types = "s";
        }
        
        $query .= " GROUP BY v.student_id, s.first_name, s.last_name, s.avatar ORDER BY violation_count DESC LIMIT ?";
        $params[] = $limit;
        $types .= "i";
        
        $stmt = $this->conn->prepare($query);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
        
        $data = [];
        while ($row = $result->fetch_assoc()) {
            $data[] = $row;
        }
        $stmt->close();
        return $data;
    }
}

