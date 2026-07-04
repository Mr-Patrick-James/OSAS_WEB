<?php

require_once __DIR__ . '/../core/Controller.php';
require_once __DIR__ . '/../models/ViolationModel.php';
require_once __DIR__ . '/../models/StudentModel.php';
require_once __DIR__ . '/../models/ReportModel.php';

class ViolationController extends Controller
{
    private $model;
    private $studentModel;
    private $reportModel;

    public function __construct()
    {
        header('Content-Type: application/json');
        @session_start();

        $this->model = new ViolationModel();
        $this->studentModel = new StudentModel();
        $this->reportModel = new ReportModel();

        // Recovery Logic: If session is lost but cookies exist, restore student_id_code
        if (isset($_SESSION['role']) && $_SESSION['role'] === 'user' && !isset($_SESSION['student_id_code'])) {
            $studentIdFromCookie = $_COOKIE['student_id_code'] ?? null;
            if ($studentIdFromCookie) {
                $_SESSION['student_id_code'] = $studentIdFromCookie;
            } else {
                // Fallback: lookup by user_id if we have it
                $userId = $_SESSION['user_id'] ?? null;
                if ($userId) {
                    $userRes = $this->model->query("SELECT student_id FROM users WHERE id = ?", [$userId]);
                    if (!empty($userRes)) {
                        $_SESSION['student_id_code'] = $userRes[0]['student_id'];
                    }
                }
            }
        }

        // Automatically check and trigger monthly reset if needed
        $this->model->checkAndTriggerAutoArchive();
    }

    /**
     * GET /api/violations.php?student_id=123 (optional)
     * If student_id is provided, returns violations for that student
     * If role is 'user', automatically filters by their student_id
     * If not provided and role is admin, returns all violations
     */
    public function index()
    {
        $action = $this->getGet('action', '');

        if ($action === 'types') {
            $this->get_types();
            return;
        }

        if ($action === 'create_type') {
            $this->create_type();
            return;
        }

        if ($action === 'update_type') {
            $this->update_type();
            return;
        }

        if ($action === 'delete_type') {
            $this->delete_type();
            return;
        }

        if ($action === 'create_level') {
            $this->create_level();
            return;
        }

        if ($action === 'update_level') {
            $this->update_level();
            return;
        }

        if ($action === 'delete_level') {
            $this->delete_level();
            return;
        }

        if ($action === 'restore_type') {
            $this->restore_type();
            return;
        }

        if ($action === 'restore_level') {
            $this->restore_level();
            return;
        }

        if ($action === 'get_statuses') {
            $this->get_statuses();
            return;
        }

        if ($action === 'create_status') {
            $this->create_status();
            return;
        }

        if ($action === 'update_status') {
            $this->update_status();
            return;
        }

        if ($action === 'delete_status') {
            $this->delete_status();
            return;
        }

        if ($action === 'restore_status') {
            $this->restore_status();
            return;
        }

        if ($action === 'get_slip_data') {
            $this->get_slip_data();
            return;
        }

        if ($action === 'generate_slip') {
            $this->generate_slip();
            return;
        }

        if ($action === 'get_slip_template') {
            $this->get_slip_template();
            return;
        }

        if ($action === 'request_slip') {
            $this->request_slip();
            return;
        }

        if ($action === 'approve_slip') {
            $this->approve_slip();
            return;
        }

        if ($action === 'deny_slip') {
            $this->deny_slip();
            return;
        }

        if ($action === 'slip_status') {
            $this->slip_status();
            return;
        }

        if ($action === 'my_slip_requests') {
            $this->my_slip_requests();
            return;
        }

        if ($action === 'get_pending_slip_requests') {
            $this->get_pending_slip_requests();
            return;
        }

        $studentId = $this->getGet('student_id', '');
        $filter    = $this->getGet('filter', 'all');
        $search    = $this->getGet('search', '');
        $dateFrom  = $this->getGet('date_from', '');
        $dateTo    = $this->getGet('date_to', '');
        $isArchived = (int)($this->getGet('is_archived') ?? $this->getGet('isArchived') ?? 0);

        if ($action === 'archive') {
            try {
                $res = $this->model->archivePreviousMonthViolations();
                if ($res) {
                    $this->json([
                        'status' => 'success',
                        'message' => "Successfully archived previous month's violations and reset all student violation levels."
                    ]);
                } else {
                    $this->error('Failed to perform archive reset.');
                }
                return;
            } catch (Exception $e) {
                $this->error('Failed to archive violations: ' . $e->getMessage());
                return;
            }
        }

        if ($action === 'mark_as_read') {
            $id = (int)$this->getGet('id', 0);
            if ($id === 0) {
                $this->error('Violation ID required');
            }
            
            $studentId = '';
            if (isset($_SESSION['role']) && $_SESSION['role'] === 'user') {
                $studentId = $_SESSION['student_id_code'] ?? '';
            }

            try {
                $this->model->markAsRead($id, $studentId);
                $this->json(['status' => 'success', 'message' => 'Notification marked as read']);
                return;
            } catch (Exception $e) {
                $this->error('Failed to mark as read: ' . $e->getMessage());
                return;
            }
        }

        if ($action === 'mark_all_read') {
            $studentId = '';
            if (isset($_SESSION['role']) && $_SESSION['role'] === 'user') {
                $studentId = $_SESSION['student_id_code'] ?? '';
            } else {
                $studentId = $this->getGet('student_id', '');
            }

            if (empty($studentId)) {
                $this->error('Student ID required');
            }

            try {
                $this->model->markAllAsRead($studentId);
                $this->json(['status' => 'success', 'message' => 'All notifications marked as read']);
                return;
            } catch (Exception $e) {
                $this->error('Failed to mark all as read: ' . $e->getMessage());
                return;
            }
        }

        // Role-based access control for fetching violations
        $reportedByFilter = '';
        $role = $_SESSION['role'] ?? '';

        if ($role === 'user') {
            // Regular students only see their own violations
            $studentId = $_SESSION['student_id_code'] ?? '';
            if (empty($studentId)) {
                $this->error('Student ID not found. Please login again.', '', 401);
            }
        } elseif (in_array($role, ['Officer', 'CSC Officer'])) {
            // Officers and CSC Officers only see violations they recorded
            $reportedByFilter = $_SESSION['full_name'] ?? $_SESSION['username'] ?? '';
        }
        // admin, OSAS Staff, Faculty Member → no filter, see all violations

        try {
            $violations = $this->model->getAllWithStudentInfo(
                $filter,
                $search,
                $studentId,
                $dateFrom,
                $dateTo,
                $isArchived,
                null,
                $reportedByFilter
            );

            $this->json([
                'status'  => 'success',
                'message' => count($violations) > 0
                    ? 'Violations retrieved successfully'
                    : 'No violations found',
                'violations' => $violations,  // Also include 'violations' key for compatibility
                'data'    => $violations,
                'count'   => count($violations)
            ]);

        } catch (Exception $e) {
            error_log('ViolationController@index: ' . $e->getMessage());
            error_log('Stack trace: ' . $e->getTraceAsString());
            $this->error('Failed to retrieve violations: ' . $e->getMessage());
        }
    }

    /**
     * POST /api/violations.php
     */
    public function create()
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        // Restore session from cookies if session expired (handles offline sync after reconnect)
        if (!isset($_SESSION['user_id']) && isset($_COOKIE['user_id']) && isset($_COOKIE['role'])) {
            $_SESSION['user_id'] = $_COOKIE['user_id'];
            $_SESSION['username'] = $_COOKIE['username'] ?? '';
            $_SESSION['role']    = $_COOKIE['role'];
        }

        if (!isset($_SESSION['user_id'])) {
            $this->error('Authentication required', 'Please login first', 401);
        }
        if (!in_array($_SESSION['role'] ?? '', ['admin', 'OSAS Staff', 'CSC Officer', 'Officer', 'Faculty Member'])) {
            $this->error('Access denied', 'Admin privileges required', 403);
        }

        // Handle both JSON and FormData
        $input = $_POST;
        if (empty($input)) {
            $jsonInput = json_decode(file_get_contents('php://input'), true);
            if ($jsonInput) $input = $jsonInput;
        }

        $studentId      = $this->sanitize($input['studentId'] ?? '');
        $violationType  = $this->sanitize($input['violationType'] ?? '');
        $violationLevel = $this->sanitize($input['violationLevel'] ?? '');
        $violationDate  = $this->sanitize($input['violationDate'] ?? '');
        $violationTime  = $this->sanitize($input['violationTime'] ?? '');
        $location       = $this->sanitize($input['location'] ?? '');
        $reportedBy     = $this->sanitize(($_SESSION['full_name'] ?? $_SESSION['username'] ?? '') ?: ($input['reportedBy'] ?? ''));
        $notes          = $this->sanitize($input['notes'] ?? '');

        // Auto-derive status from the level's default_status (not hardcoded 'warning')
        $levelData = $this->model->query("SELECT default_status FROM violation_levels WHERE id = ?", [$violationLevel]);
        $status = !empty($levelData) ? ($this->sanitize($levelData[0]['default_status'] ?? 'warning')) : 'warning';

        // RBAC: Only 'admin' role can record a violation as 'resolved'
        if ($status === 'resolved' && ($_SESSION['role'] ?? '') !== 'admin') {
            $this->error('Access denied', 'Only Administrators can record resolved violations.', 403);
        }

        // Handle attachments (File Upload)
        $attachmentPaths = [];
        if (!empty($_FILES['attachments'])) {
            $uploadDir = __DIR__ . '/../../app/assets/img/violations/';
            if (!is_dir($uploadDir)) {
                mkdir($uploadDir, 0777, true);
            }

            foreach ($_FILES['attachments']['tmp_name'] as $key => $tmpName) {
                if ($_FILES['attachments']['error'][$key] === UPLOAD_ERR_OK) {
                    $originalName = $_FILES['attachments']['name'][$key];
                    $extension = pathinfo($originalName, PATHINFO_EXTENSION);
                    $newFileName = 'viol_' . time() . '_' . uniqid() . '.' . $extension;
                    $destPath = $uploadDir . $newFileName;

                    if (move_uploaded_file($tmpName, $destPath)) {
                        $attachmentPaths[] = 'app/assets/img/violations/' . $newFileName;
                    }
                }
            }
        }

        if (
            empty($studentId) || empty($violationType) || empty($violationLevel) ||
            empty($violationDate) || empty($violationTime) ||
            empty($location) || empty($reportedBy)
        ) {
            $this->error('All required fields must be filled');
        }

        // Get student info
        $student = $this->studentModel->query(
            "SELECT s.*, COALESCE(d.department_name, s.department) AS department_name
             FROM students s
             LEFT JOIN departments d ON d.department_code = s.department
             WHERE s.student_id = ?",
            [$studentId]
        );

        if (!$student) {
            $this->error('Student not found');
        }

        try {
            // TEMPORARILY COMMENTED OUT: Check if student already has this violation type recorded on the same day
            /*
            $existingViolation = $this->model->checkStudentViolationByTypeAndDate(
                $studentId,
                $violationType,
                $violationDate
            );
            
            if ($existingViolation) {
                $this->error('This violation type has already been recorded for this student today by ' . $existingViolation['reported_by'], ['existing_id' => $existingViolation['id'], 'reported_by' => $existingViolation['reported_by']]);
                return;
            }
            */

            // Check for duplicate violation (Double Submission Check - same exact details)
            $existingId = $this->model->checkDuplicateSubmission(
               $studentId, 
               $violationType, 
               $violationLevel,
               $violationDate, 
               $violationTime, 
               $location
            );
            
            if ($existingId) {
                $this->error('This violation has already been recorded.', ['existing_id' => $existingId]);
                return;
            }

            // Generate unique case ID with retry mechanism
            $maxRetries = 3;
            $caseId = null;
            
            for ($attempt = 0; $attempt < $maxRetries; $attempt++) {
                $caseId = $this->model->generateCaseId();
                
                if (!$this->model->caseIdExists($caseId)) {
                    break; // Found unique case ID
                }
                
                if ($attempt === $maxRetries - 1) {
                    $this->error('Unable to generate unique case ID. Please try again.');
                    return;
                }
                
                // Wait a moment before retrying
                usleep(100000); // 0.1 seconds
            }

            $data = [
                'case_id'        => $caseId,
                'student_id'     => $studentId,
                'violation_type_id' => $violationType,
                'violation_level_id'=> $violationLevel,
                'department'     => $student[0]['department_name'] ?? 'N/A',
                'section'        => $student[0]['section_id'] ?? '',
                'violation_date' => $violationDate,
                'violation_time' => $violationTime,
                'location'       => $location,
                'reported_by'    => $reportedBy,
                'status'         => $status,
                'notes'          => $notes ?: null,
                'attachments'    => !empty($attachmentPaths) ? json_encode($attachmentPaths) : null,
                'created_at'     => date('Y-m-d H:i:s')
            ];

            $id = $this->model->create($data);

            // Update reports
            try {
                $this->reportModel->generateReportsFromViolations();
            } catch (Exception $e) {
                error_log("Failed to auto-update reports: " . $e->getMessage());
                // Don't fail the request, just log it
            }

            try {
                require_once __DIR__ . '/../services/PushNotificationService.php';
                
                // Get violation type, level, and sanction info
                $typeInfo = $this->model->query("SELECT name FROM violation_types WHERE id = ?", [$violationType]);
                $levelInfo = $this->model->query("SELECT name, sanction_name, sanction_description FROM violation_levels WHERE id = ?", [$violationLevel]);
                $typeName = $typeInfo[0]['name'] ?? 'Violation';
                $levelName = $levelInfo[0]['name'] ?? '';
                $sanctionName = $levelInfo[0]['sanction_name'] ?? null;
                $sanctionDescription = $levelInfo[0]['sanction_description'] ?? null;

                $studentFirstName = $student[0]['first_name'] ?? 'Student';

                // Use sanction if defined, otherwise fall back to level-name-based messages
                if ($sanctionName) {
                    $pushTitle = "{$sanctionName} — {$typeName}";
                    $pushBody = $sanctionDescription
                        ? "Hi {$studentFirstName}, you received \"{$sanctionName}\" for \"{$typeName}\" ({$levelName}). {$sanctionDescription}"
                        : "Hi {$studentFirstName}, a \"{$typeName}\" ({$levelName}) violation has been recorded. Sanction: {$sanctionName}.";
                } else {
                    $levelLower = strtolower($levelName);
                    if (strpos($levelLower, '1st') !== false) {
                        $pushTitle = 'Violation Notice';
                        $pushBody = "Hi {$studentFirstName}, you've been noted for \"{$typeName}\" ({$levelName}). Please follow the dress code policy.";
                    } elseif (strpos($levelLower, '2nd') !== false) {
                        $pushTitle = 'Violation Notice';
                        $pushBody = "Hi {$studentFirstName}, this is your 2nd offense for \"{$typeName}\". Please comply with the policy.";
                    } elseif (strpos($levelLower, '3rd') !== false) {
                        $pushTitle = 'Violation Notice';
                        $pushBody = "Hi {$studentFirstName}, 3rd offense for \"{$typeName}\". Please comply immediately.";
                    } elseif (strpos($levelLower, 'disciplinary') !== false) {
                        $pushTitle = 'Disciplinary Notice';
                        $pushBody = "Hi {$studentFirstName}, a disciplinary action has been recorded for \"{$typeName}\". Please report to the OSAS office.";
                    } else {
                        $pushTitle = 'Violation Notice';
                        $pushBody = "Hi {$studentFirstName}, a \"{$typeName}\" ({$levelName}) violation has been recorded. Please check your E-OSAS portal.";
                    }
                }
                
                (new PushNotificationService())->notifyStudent(
                    $studentId,
                    $pushTitle,
                    $pushBody,
                    ['type' => 'violation', 'id' => (int) $id, 'page' => 'user-page/my_violations', 'tag' => 'violation-' . $id]
                );
                
                // Notify head admin about the new violation (so they know who recorded it)
                $currentUserId = $_SESSION['user_id'] ?? null;
                $recordedBy = $_SESSION['full_name'] ?? $_SESSION['username'] ?? 'Staff';
                $studentFullName = trim(($student[0]['first_name'] ?? '') . ' ' . ($student[0]['last_name'] ?? ''));
                
                $adminTitle = 'New Violation Recorded';
                $adminBody = "{$recordedBy} recorded a \"{$typeName}\" ({$levelName}) violation for {$studentFullName} ({$studentId}).";
                
                (new PushNotificationService())->notifyAdmins(
                    $adminTitle,
                    $adminBody,
                    ['type' => 'admin_violation', 'id' => (int) $id, 'page' => 'violations', 'tag' => 'admin-violation-' . $id],
                    $currentUserId // exclude the admin who recorded it (they already know)
                );
            } catch (Throwable $e) {
                error_log('Violation push: ' . $e->getMessage());
            }

            $this->success('Violation recorded successfully', [
                'id'      => $id,
                'case_id' => $caseId
            ]);

        } catch (Exception $e) {
            // Check if it's a duplicate key error
            if (strpos($e->getMessage(), 'Duplicate entry') !== false) {
                $this->error('A violation with this case ID already exists. Please try again.');
            } else {
                $this->error('Failed to save violation: ' . $e->getMessage());
            }
        }
    }

    /**
     * PUT /api/violations.php?id=1
     */
    public function update()
    {
        $id = intval($this->getGet('id', 0));
        if ($id === 0) {
            $this->error('Violation ID required');
        }

        if (!isset($_SESSION['user_id'])) {
            $this->error('Authentication required', 'Please login first', 401);
        }
        if (($_SESSION['role'] ?? '') !== 'admin') {
            $this->error('Access denied', 'Only Administrators can edit violations.', 403);
        }

        $input = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $current = $this->model->getById($id);

        if (!$current) {
            $this->error('Violation not found');
        }

        $editorName  = $_SESSION['full_name'] ?? $_SESSION['username'] ?? 'Admin';
        $editedAt    = date('Y-m-d H:i:s');

        $newTypeId  = $this->sanitize($input['violationType']  ?? $current['violation_type_id']);
        $newLevelId = $this->sanitize($input['violationLevel'] ?? $current['violation_level_id']);
        $newDate    = $this->sanitize($input['violationDate']  ?? $current['violation_date']);
        $newTime    = $this->sanitize($input['violationTime']  ?? $current['violation_time']);
        $newLocation= $this->sanitize($input['location']       ?? $current['location']);
        $newStatus  = $this->sanitize($input['status']         ?? $current['status']);
        $newNotes   = $this->sanitize($input['notes']          ?? $current['notes'] ?? '');

        // RBAC: Only 'admin' role can mark a violation as 'resolved'
        if ($newStatus === 'resolved' && ($current['status'] ?? '') !== 'resolved') {
            if (($_SESSION['role'] ?? '') !== 'admin') {
                $this->error('Access denied', 'Only Administrators can resolve violations.', 403);
            }
        }

        // --- Build audit trail appended to notes ---
        $changes = [];
        if ((string)$newTypeId  !== (string)$current['violation_type_id'])  $changes[] = 'type';
        if ((string)$newLevelId !== (string)$current['violation_level_id']) $changes[] = 'level';
        if ($newDate    !== ($current['violation_date'] ?? ''))              $changes[] = 'date';
        if ($newTime    !== ($current['violation_time'] ?? ''))              $changes[] = 'time';
        if ($newLocation !== ($current['location'] ?? ''))                   $changes[] = 'location';
        if ($newStatus  !== ($current['status'] ?? ''))                      $changes[] = 'status';

        $auditEntry = '';
        if (!empty($changes)) {
            $auditEntry = "\n[Edited by {$editorName} on {$editedAt}: " . implode(', ', $changes) . " changed]";
        } else {
            $auditEntry = "\n[Notes updated by {$editorName} on {$editedAt}]";
        }

        // Append audit trail to notes (keeps history visible)
        $finalNotes = rtrim($newNotes) . $auditEntry;

        $data = [
            'violation_type_id'  => $newTypeId,
            'violation_level_id' => $newLevelId,
            'violation_date'     => $newDate,
            'violation_time'     => $newTime,
            'location'           => $newLocation,
            'reported_by'        => $current['reported_by'], // never change original reporter
            'status'             => $newStatus,
            'notes'              => $finalNotes,
            'attachments'        => isset($input['attachments']) ? json_encode($input['attachments']) : $current['attachments'],
            'updated_at'         => $editedAt
        ];

        try {
            $this->model->update($id, $data);

            // Update reports
            try {
                $this->reportModel->generateReportsFromViolations();
            } catch (Exception $e) {
                error_log("Failed to auto-update reports: " . $e->getMessage());
            }

            // Notify student if significant fields changed
            if (!empty($changes)) {
                try {
                    require_once __DIR__ . '/../services/PushNotificationService.php';
                    $studentId = $current['student_id'] ?? '';
                    if ($studentId) {
                        $typeInfo  = $this->model->query("SELECT name FROM violation_types WHERE id = ?",  [$newTypeId]);
                        $levelInfo = $this->model->query("SELECT name FROM violation_levels WHERE id = ?", [$newLevelId]);
                        $typeName  = $typeInfo[0]['name']  ?? 'Violation';
                        $levelName = $levelInfo[0]['name'] ?? '';

                        // Dedicated "Resolved" notification when status changes to resolved
                        if ($newStatus === 'resolved' && ($current['status'] ?? '') !== 'resolved') {
                            $studentInfo = $this->model->query(
                                "SELECT first_name FROM students WHERE student_id = ? LIMIT 1",
                                [$studentId]
                            );
                            $firstName = $studentInfo[0]['first_name'] ?? 'Student';

                            (new PushNotificationService())->notifyStudent(
                                $studentId,
                                '✅ Violation Resolved',
                                "Hi {$firstName}, your violation ({$current['case_id']}) for \"{$typeName}\" has been marked as resolved by {$editorName}. No further action is required.",
                                ['type' => 'violation_resolved', 'id' => $id, 'page' => 'user-page/my_violations', 'tag' => 'violation-resolved-' . $id]
                            );

                            // Also notify admins that a violation was resolved
                            $studentFullInfo = $this->model->query(
                                "SELECT first_name, last_name FROM students WHERE student_id = ? LIMIT 1",
                                [$studentId]
                            );
                            $studentFullName = trim(($studentFullInfo[0]['first_name'] ?? '') . ' ' . ($studentFullInfo[0]['last_name'] ?? ''));
                            (new PushNotificationService())->notifyAdmins(
                                'Violation Resolved',
                                "{$editorName} marked violation {$current['case_id']} for {$studentFullName} ({$studentId}) as resolved.",
                                ['type' => 'admin_violation_resolved', 'id' => $id, 'page' => 'violations', 'tag' => 'admin-resolved-' . $id],
                                $_SESSION['user_id'] ?? null
                            );
                        } else {
                            (new PushNotificationService())->notifyStudent(
                                $studentId,
                                'Violation Record Updated',
                                "Your violation record ({$current['case_id']}) for \"{$typeName}\" ({$levelName}) has been updated by {$editorName}. Please check your E-OSAS portal for details.",
                                ['type' => 'violation_updated', 'id' => $id, 'page' => 'user-page/my_violations', 'tag' => 'violation-update-' . $id]
                            );
                        }
                    }
                } catch (Throwable $e) {
                    error_log('Violation edit push: ' . $e->getMessage());
                }
            }

            $this->success('Violation updated successfully', [
                'id'      => $id,
                'changes' => $changes,
                'edited_by' => $editorName,
                'edited_at' => $editedAt
            ]);
        } catch (Exception $e) {
            $this->error('Failed to update violation: ' . $e->getMessage());
        }
    }

    /**
     * DELETE /api/violations.php?id=1
     */
    public function delete()
    {
        $id = intval($this->getGet('id', 0));
        if ($id === 0) {
            $this->error('Violation ID required');
        }

        if (!isset($_SESSION['user_id'])) {
            $this->error('Authentication required', 'Please login first', 401);
        }
        if (!in_array($_SESSION['role'] ?? '', ['admin', 'OSAS Staff', 'CSC Officer', 'Officer', 'Faculty Member'])) {
            $this->error('Access denied', 'Admin privileges required', 403);
        }

        try {
            $this->model->delete($id);

            // Update reports
            try {
                $this->reportModel->generateReportsFromViolations();
            } catch (Exception $e) {
                error_log("Failed to auto-update reports: " . $e->getMessage());
            }

            $this->success('Violation deleted successfully');
        } catch (Exception $e) {
            $this->error('Failed to delete violation');
        }
    }

    /**
     * Get violation types and levels
     */
    private function get_types() {
        try {
            $includeArchived = $this->getGet('include_archived', '0') === '1';
            $types = $this->model->getViolationTypes($includeArchived);
            $result = [];
            
            if ($types && count($types) > 0) {
                foreach ($types as $type) {
                    $levels = $this->model->getViolationLevels($type['id'], $includeArchived);
                    $type['levels'] = $levels;
                    $result[] = $type;
                }
            }
            
            $this->success('Violation types retrieved successfully', $result);
        } catch (Exception $e) {
            error_log("Error getting types: " . $e->getMessage());
            $this->error('Failed to retrieve violation types: ' . $e->getMessage());
        }
    }

    /**
     * Parse JSON or form input for type/level management
     */
    private function getManagementInput() {
        $input = $_POST;
        if (empty($input)) {
            $jsonInput = json_decode(file_get_contents('php://input'), true);
            if ($jsonInput) {
                $input = $jsonInput;
            }
        }
        return $input;
    }

    private function create_type() {
        $this->requireAdmin();
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        $input = $this->getManagementInput();
        $name = $this->sanitize($input['name'] ?? '');
        $description = $this->sanitize($input['description'] ?? '');

        try {
            $typeId = $this->model->createViolationType($name, $description);
            $levels = $this->model->getViolationLevels($typeId);
            $this->success('Violation type created successfully', [
                'id' => $typeId,
                'name' => $name,
                'description' => $description,
                'levels' => $levels
            ]);
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function update_type() {
        $this->requireAdmin();
        if (!in_array($_SERVER['REQUEST_METHOD'], ['POST', 'PUT'], true)) {
            $this->error('Invalid request method');
        }

        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        $name = $this->sanitize($input['name'] ?? '');
        $description = $this->sanitize($input['description'] ?? '');

        if ($id <= 0 || $name === '') {
            $this->error('Type ID and name are required');
        }

        try {
            $this->model->updateViolationType($id, $name, $description);
            $this->success('Violation type updated successfully', [
                'id' => $id,
                'name' => $name,
                'description' => $description
            ]);
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function delete_type() {
        $this->requireAdmin();

        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        if ($id <= 0) {
            $this->error('Type ID is required');
        }

        try {
            $this->model->deleteViolationType($id);
            $this->success('Violation type deleted successfully');
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function create_level() {
        $this->requireAdmin();
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        $input = $this->getManagementInput();
        $typeId = (int)($input['violation_type_id'] ?? $input['typeId'] ?? 0);
        $name = $this->sanitize($input['name'] ?? '');
        $description = $this->sanitize($input['description'] ?? '');
        $levelOrder = isset($input['level_order']) ? (int)$input['level_order'] : null;
        $defaultStatus = $this->sanitize($input['default_status'] ?? 'warning');
        $statusColor = $this->sanitize($input['status_color'] ?? '#f59e0b');
        $sanctionName = $this->sanitize($input['sanction_name'] ?? '') ?: null;
        $sanctionDescription = $this->sanitize($input['sanction_description'] ?? '') ?: null;

        if ($typeId <= 0) {
            $this->error('Violation type ID is required');
        }

        try {
            $levelId = $this->model->createViolationLevel($typeId, $name, $description, $levelOrder, $defaultStatus, $statusColor, $sanctionName, $sanctionDescription);
            $levels = $this->model->getViolationLevels($typeId, true);
            $level = null;
            foreach ($levels as $l) {
                if ((int)$l['id'] === $levelId) { $level = $l; break; }
            }
            $this->success('Violation level created successfully', $level ?: ['id' => $levelId]);
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function update_level() {
        $this->requireAdmin();
        if (!in_array($_SERVER['REQUEST_METHOD'], ['POST', 'PUT'], true)) {
            $this->error('Invalid request method');
        }

        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        $name = $this->sanitize($input['name'] ?? '');
        $description = $this->sanitize($input['description'] ?? '');
        $levelOrder = isset($input['level_order']) ? (int)$input['level_order'] : null;
        $defaultStatus = $this->sanitize($input['default_status'] ?? 'warning');
        $statusColor = $this->sanitize($input['status_color'] ?? '#f59e0b');
        $sanctionName = $this->sanitize($input['sanction_name'] ?? '') ?: null;
        $sanctionDescription = $this->sanitize($input['sanction_description'] ?? '') ?: null;

        if ($id <= 0 || $name === '') {
            $this->error('Level ID and name are required');
        }

        try {
            $this->model->updateViolationLevel($id, $name, $description, $levelOrder, $defaultStatus, $statusColor, $sanctionName, $sanctionDescription);
            $this->success('Violation level updated successfully');
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function delete_level() {
        $this->requireAdmin();

        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        if ($id <= 0) {
            $this->error('Level ID is required');
        }

        try {
            $this->model->deleteViolationLevel($id);
            $this->success('Violation level deleted successfully');
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function restore_type() {
        $this->requireAdmin();
        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        if ($id <= 0) $this->error('Type ID is required');

        try {
            $this->model->restoreViolationType($id);
            $this->success('Violation type restored successfully');
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function restore_level() {
        $this->requireAdmin();
        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        if ($id <= 0) $this->error('Level ID is required');

        try {
            $this->model->restoreViolationLevel($id);
            $this->success('Violation level restored successfully');
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function get_statuses() {
        try {
            $includeArchived = $this->getGet('include_archived', '0') === '1';
            $statuses = $this->model->getViolationStatuses($includeArchived);
            $this->success('Violation statuses retrieved successfully', $statuses);
        } catch (Exception $e) {
            $this->error('Failed to retrieve statuses: ' . $e->getMessage());
        }
    }

    private function create_status() {
        $this->requireAdmin();
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') $this->error('Invalid request method');
        $input = $this->getManagementInput();
        $name = $this->sanitize($input['name'] ?? '');
        $color = $this->sanitize($input['status_color'] ?? $input['color'] ?? '#f59e0b');
        try {
            $id = $this->model->createViolationStatus($name, $color);
            $this->success('Violation status created successfully', ['id' => $id, 'name' => $name, 'status_color' => $color]);
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function update_status() {
        $this->requireAdmin();
        if (!in_array($_SERVER['REQUEST_METHOD'], ['POST', 'PUT'], true)) $this->error('Invalid request method');
        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        $name = $this->sanitize($input['name'] ?? '');
        $color = $this->sanitize($input['status_color'] ?? $input['color'] ?? '#f59e0b');
        try {
            $this->model->updateViolationStatus($id, $name, $color);
            $this->success('Violation status updated successfully');
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function delete_status() {
        $this->requireAdmin();
        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        try {
            $this->model->deleteViolationStatus($id);
            $this->success('Violation status deleted/archived successfully');
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    private function restore_status() {
        $this->requireAdmin();
        $input = $this->getManagementInput();
        $id = (int)($input['id'] ?? $this->getGet('id', 0));
        try {
            $this->model->restoreViolationStatus($id);
            $this->success('Violation status restored successfully');
        } catch (Exception $e) {
            $this->error($e->getMessage());
        }
    }

    /**
     * Generate Entrance Slip DOCX
     */
    public function get_slip_template() {
        $templatePath = __DIR__ . '/../assets/SLIP.docx';
        if (!file_exists($templatePath)) {
            $templatePath = __DIR__ . '/../assets/EntranceSlip.docx';
        }

        if (file_exists($templatePath)) {
            header('Content-Description: File Transfer');
            header('Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document');
            header('Content-Disposition: attachment; filename="template.docx"');
            header('Content-Transfer-Encoding: binary');
            header('Expires: 0');
            header('Cache-Control: must-revalidate');
            header('Pragma: public');
            header('Content-Length: ' . filesize($templatePath));
            readfile($templatePath);
            exit;
        } else {
            http_response_code(404);
            echo "Template not found.";
            exit;
        }
    }

    /**
     * Get Violation Data for PDF Slip generation
     */
    private function get_slip_data()
    {
        $violationId = $this->getGet('violation_id', '');
        if (empty($violationId)) {
            $this->error('Violation ID is required');
        }

        // Pass specificId as the 7th argument
        $violations = $this->model->getAllWithStudentInfo('all', '', '', '', '', 0, $violationId);
        
        if (empty($violations)) {
            $this->error('Violation not found');
        }

        // Security check
        if (isset($_SESSION['role']) && $_SESSION['role'] === 'user') {
            $currentStudentId = $_SESSION['student_id_code'] ?? '';
            if (trim($violations[0]['studentId']) !== trim($currentStudentId)) {
                $this->error('Unauthorized access to this violation slip');
            }

            // Check if there's an approved request
            $approvedRequest = $this->model->getApprovedSlipRequest($violationId, $currentStudentId);
            if (!$approvedRequest) {
                $this->error('Slip generation requires admin approval.', '', 403);
            }
        }

        $violation = $violations[0];
        $currentDate = $violation['dateReported'];
        $month = date('m', strtotime($currentDate));
        $year = date('Y', strtotime($currentDate));
        $studentId = $violation['studentId'] ?? '';

        // Fetch all active violation types from DB (dynamic, not hardcoded)
        $allTypes = $this->model->getViolationTypes(false); // active only
        $monthlyViolations = [];
        $typeLevelsMap = [];
        foreach ($allTypes as $t) {
            if (($t['status'] ?? 'active') !== 'active') continue; // extra safety guard
            $monthlyViolations[$t['name']] = [];
            $levels = $this->model->getViolationLevels($t['id'], false);
            $typeLevelsMap[$t['name']] = array_column($levels, 'name');
        }

        // Union of all level names in order
        $allLevelNames = [];
        foreach ($typeLevelsMap as $levels) {
            foreach ($levels as $lvl) {
                if (!in_array($lvl, $allLevelNames)) $allLevelNames[] = $lvl;
            }
        }

        $history = $this->model->getAllWithStudentInfo('all', '', $studentId);

        foreach ($history as $v) {
            $vDate = $v['dateReported'];
            $ts = strtotime(str_replace('/', '-', $vDate));
            if (!$ts) $ts = strtotime($vDate);

            if ($ts && date('m', $ts) == $month && date('Y', $ts) == $year) {
                $typeLabel = $v['violationTypeLabel'] ?? '';
                // Match by exact name first, then fallback to key-based lookup
                if (array_key_exists($typeLabel, $monthlyViolations)) {
                    $monthlyViolations[$typeLabel][] = $v;
                } else {
                    // Try case-insensitive match
                    foreach ($monthlyViolations as $key => $val) {
                        if (strcasecmp($key, $typeLabel) === 0) {
                            $monthlyViolations[$key][] = $v;
                            break;
                        }
                    }
                }
            }
        }

        foreach ($monthlyViolations as $k => &$vList) {
            usort($vList, function($a, $b) {
                $tsA = strtotime(str_replace('/', '-', $a['dateReported']) . ' ' . $a['violationTime']);
                $tsB = strtotime(str_replace('/', '-', $b['dateReported']) . ' ' . $b['violationTime']);
                return $tsA - $tsB;
            });
        }
        unset($vList);

        $this->json([
            'status' => 'success',
            'data' => [
                'violation' => $violation,
                'monthlyViolations' => $monthlyViolations,
                'violationTypes' => array_column($allTypes, 'name'), // send type names to frontend
                'violationLevels' => $allLevelNames, // all level names in order (for PDF columns)
                'generatedAt' => date('Y-m-d H:i:s'),
                'adminName' => $_SESSION['full_name'] ?? 'OSAS Admin'
            ]
        ]);
    }

    /**
     * Request a slip (Student)
     */
    private function request_slip() {
        $violationId = $this->getPost('violation_id', $this->getGet('violation_id', ''));
        $studentIdCode = $_SESSION['student_id_code'] ?? '';
        $userId = $_SESSION['user_id'] ?? 0;

        if (empty($violationId) || empty($studentIdCode)) {
            $this->error('Violation ID and Student session required');
        }

        try {
            $res = $this->model->createSlipRequest($violationId, $studentIdCode, $userId);
            if ($res) {
                // Notify admin that a student requested a slip
                try {
                    require_once __DIR__ . '/../services/PushNotificationService.php';
                    $studentName = $_SESSION['full_name'] ?? 'A student';
                    (new PushNotificationService())->notifyAdmins(
                        'Entrance Slip Request',
                        "{$studentName} ({$studentIdCode}) is requesting an entrance slip. Please review in the Violations module.",
                        ['type' => 'slip_request', 'page' => 'violations', 'tag' => 'slip-request-' . $violationId]
                    );
                } catch (Throwable $e) {
                    error_log('Slip request push: ' . $e->getMessage());
                }
                $this->success('Slip request sent to admin for approval');
            } else {
                $this->error('Failed to create slip request');
            }
        } catch (Exception $e) {
            $this->error('Server error: ' . $e->getMessage());
        }
    }

    /**
     * Get slip status (Student)
     */
    private function slip_status() {
        $violationId = $this->getGet('violation_id', '');
        $studentIdCode = $_SESSION['student_id_code'] ?? '';

        if (empty($violationId) || empty($studentIdCode)) {
            $this->error('Missing parameters');
        }

        $status = $this->model->getSlipRequestStatus($violationId, $studentIdCode);
        $this->json(['status' => 'success', 'data' => ['request_status' => $status]]);
    }

    /**
     * Get student's own slip requests with status
     */
    private function my_slip_requests() {
        $studentIdCode = $_SESSION['student_id_code'] ?? '';
        if (empty($studentIdCode)) {
            $this->error('Not authenticated as student');
            return;
        }

        try {
            $requests = $this->model->getStudentSlipRequests($studentIdCode);
            $this->json(['status' => 'success', 'data' => $requests]);
        } catch (Exception $e) {
            $this->error('Server error: ' . $e->getMessage());
        }
    }

    /**
     * Get all slip requests (Admin)
     */
    private function get_pending_slip_requests() {
        $this->requireAdmin();
        if (($_SESSION['role'] ?? '') !== 'admin') {
            $this->error('Access denied', 'Only Administrators can view slip requests.', 403);
        }
        try {
            $requests = $this->model->getSlipRequests();
            $this->json(['status' => 'success', 'data' => $requests]);
        } catch (Exception $e) {
            $this->error('Server error: ' . $e->getMessage());
        }
    }

    /**
     * Approve slip (Admin)
     */
    private function approve_slip() {
        $this->requireAdmin();
        if (($_SESSION['role'] ?? '') !== 'admin') {
            $this->error('Access denied', 'Only Administrators can approve slip requests.', 403);
        }
        $requestId = $this->getPost('request_id', $this->getGet('request_id', ''));
        if (empty($requestId)) $this->error('Request ID required');

        try {
            $res = $this->model->updateSlipRequestStatus($requestId, 'approved');
            if ($res) {
                // Notify the student that their slip was approved
                try {
                    require_once __DIR__ . '/../services/PushNotificationService.php';
                    $request = $this->model->query(
                        "SELECT sr.student_id_code, s.first_name FROM slip_requests sr LEFT JOIN students s ON BINARY TRIM(sr.student_id_code) = BINARY TRIM(s.student_id) WHERE sr.id = ?",
                        [$requestId]
                    );
                    if (!empty($request)) {
                        $studentId = $request[0]['student_id_code'];
                        $firstName = $request[0]['first_name'] ?? 'Student';
                        (new PushNotificationService())->notifyStudent(
                            $studentId,
                            'Entrance Slip Approved',
                            "Hi {$firstName}, your entrance slip request has been approved! You can now download it from your violations page.",
                            ['type' => 'slip_approved', 'page' => 'user-page/my_violations', 'tag' => 'slip-approved-' . $requestId]
                        );
                    }
                } catch (Throwable $e) {
                    error_log('Slip approve push: ' . $e->getMessage());
                }
                $this->success('Slip request approved');
            } else {
                $this->error('Failed to approve request');
            }
        } catch (Exception $e) {
            $this->error('Server error: ' . $e->getMessage());
        }
    }

    /**
     * Deny slip (Admin)
     */
    private function deny_slip() {
        $this->requireAdmin();
        if (($_SESSION['role'] ?? '') !== 'admin') {
            $this->error('Access denied', 'Only Administrators can deny slip requests.', 403);
        }
        $requestId = $this->getPost('request_id', $this->getGet('request_id', ''));
        if (empty($requestId)) $this->error('Request ID required');

        try {
            $res = $this->model->updateSlipRequestStatus($requestId, 'denied');
            if ($res) {
                // Notify the student that their slip was denied
                try {
                    require_once __DIR__ . '/../services/PushNotificationService.php';
                    $request = $this->model->query(
                        "SELECT sr.student_id_code, s.first_name FROM slip_requests sr LEFT JOIN students s ON BINARY TRIM(sr.student_id_code) = BINARY TRIM(s.student_id) WHERE sr.id = ?",
                        [$requestId]
                    );
                    if (!empty($request)) {
                        $studentId = $request[0]['student_id_code'];
                        $firstName = $request[0]['first_name'] ?? 'Student';
                        (new PushNotificationService())->notifyStudent(
                            $studentId,
                            'Entrance Slip Denied',
                            "Hi {$firstName}, your entrance slip request was denied. Please contact the Office of Student Affairs for more information.",
                            ['type' => 'slip_denied', 'page' => 'user-page/my_violations', 'tag' => 'slip-denied-' . $requestId]
                        );
                    }
                } catch (Throwable $e) {
                    error_log('Slip deny push: ' . $e->getMessage());
                }
                $this->success('Slip request denied');
            } else {
                $this->error('Failed to deny request');
            }
        } catch (Exception $e) {
            $this->error('Server error: ' . $e->getMessage());
        }
    }

    private function generate_slip()
    {
        // 1. Get Violation Data
        $violationId = $this->getGet('violation_id', '');
        if (empty($violationId)) {
            $this->error('Violation ID is required');
        }

        // Use getAllWithStudentInfo to search by specific ID and get FULL details (joined tables)
        // pass specificId as the 7th argument
        $violations = $this->model->getAllWithStudentInfo('all', '', '', '', '', 0, $violationId);
        
        if (empty($violations)) {
            $this->error('Violation not found');
        }

        // Security check: If user is student, ensure violation belongs to them
        if (isset($_SESSION['role']) && $_SESSION['role'] === 'user') {
            $currentStudentId = $_SESSION['student_id_code'] ?? '';
            // Check if violation's student_id matches
            if ($violations[0]['studentId'] !== $currentStudentId) {
                $this->error('Unauthorized access to this violation slip');
            }
        }

        // Get the current violation
        $violation = $violations[0];
        $currentDate = $violation['dateReported']; // Fix: use dateReported instead of violation_date
        $month = date('m', strtotime($currentDate));
        $year = date('Y', strtotime($currentDate));
        $studentId = $violation['studentId'] ?? '';

        // 1.1 Fetch all active violation types + their levels from DB (fully dynamic)
        // Only 'active' status types appear as rows in the slip — archived/deleted types are excluded.
        $allTypes = $this->model->getViolationTypes(false); // false = active only
        $monthlyViolations = [];
        $typeNames = [];
        $typeLevelsMap = []; // typeName => [level names in order]

        foreach ($allTypes as $t) {
            if (($t['status'] ?? 'active') !== 'active') continue; // extra safety guard
            $monthlyViolations[$t['name']] = [];
            $typeNames[] = $t['name'];
            $levels = $this->model->getViolationLevels($t['id'], false);
            $typeLevelsMap[$t['name']] = array_column($levels, 'name');
        }

        // Union of all level names (preserving order by first occurrence) for column headers
        $allLevelNames = [];
        foreach ($typeLevelsMap as $levels) {
            foreach ($levels as $lvl) {
                if (!in_array($lvl, $allLevelNames)) {
                    $allLevelNames[] = $lvl;
                }
            }
        }

        $history = $this->model->getAllWithStudentInfo('all', '', $studentId);

        foreach ($history as $v) {
            $vDate = $v['dateReported'];
            $ts = strtotime(str_replace('/', '-', $vDate));
            if (!$ts) $ts = strtotime($vDate);

            if ($ts && date('m', $ts) == $month && date('Y', $ts) == $year) {
                $typeLabel = $v['violationTypeLabel'] ?? '';
                if (array_key_exists($typeLabel, $monthlyViolations)) {
                    $monthlyViolations[$typeLabel][] = $v;
                } else {
                    foreach ($monthlyViolations as $key => $val) {
                        if (strcasecmp($key, $typeLabel) === 0) {
                            $monthlyViolations[$key][] = $v;
                            break;
                        }
                    }
                }
            }
        }

        // Sort each type's violations by datetime ASC
        foreach ($monthlyViolations as $k => &$vList) {
            usort($vList, function($a, $b) {
                $tsA = strtotime(str_replace('/', '-', $a['dateReported']) . ' ' . $a['violationTime']);
                $tsB = strtotime(str_replace('/', '-', $b['dateReported']) . ' ' . $b['violationTime']);
                return $tsA - $tsB;
            });
        }
        unset($vList);

        // 2. Load Template (Native PHP ZipArchive)
        $templatePath = __DIR__ . '/../assets/SLIP.docx';
        if (!file_exists($templatePath)) {
            $templatePath = __DIR__ . '/../assets/EntranceSlip.docx';
            if (!file_exists($templatePath)) {
                $this->error('Template file not found: ' . $templatePath);
            }
        }

        // Create temp file
        $tempDir = sys_get_temp_dir();
        $tempFile = $tempDir . '/EntranceSlip_' . $violationId . '_' . time() . '.docx';
        if (!copy($templatePath, $tempFile)) {
            $this->error('Failed to create temporary file');
        }

        // 3. Prepare Data
        $studentName = $violation['studentName'] ?? 'N/A';
        // $studentId already set
        $section = $violation['section'] ?? 'N/A';
        $yearLevel = $violation['studentYearlevel'] ?? 'N/A';
        $courseYear = "$section - $yearLevel";
        
        $vTypeLabel = trim($violation['violationTypeLabel'] ?? '');
        $vLevelLabel = trim($violation['violationLevelLabel'] ?? '');

        // 4. Modify XML
        $zip = new ZipArchive;
        if ($zip->open($tempFile) === TRUE) {
            $xml = $zip->getFromName('word/document.xml');

            // 4.1 Replace the entire data section of the violation table dynamically.
            // Rebuilds both header columns and data rows from DB types/levels.
            $xml = $this->rebuildViolationTableRows($xml, $typeNames, $monthlyViolations, $allLevelNames);

            // 4.2 Replace violation type labels in the header/checkbox area with checkmarks
            foreach ($typeNames as $typeName) {
                $isChecked = strcasecmp(trim($typeName), $vTypeLabel) === 0;
                $mark = $isChecked ? ' ✔' : '';
                // Safe XML text replacement
                $xml = str_replace(
                    htmlspecialchars($typeName),
                    htmlspecialchars($typeName) . $mark,
                    $xml
                );
            }

            // 4.3 Replace offense level labels with checkmarks
            // Collect distinct levels from all violations this month + current
            $levelsSeen = [];
            foreach ($monthlyViolations as $vList) {
                foreach ($vList as $v) {
                    $lvl = trim($v['violationLevelLabel'] ?? '');
                    if ($lvl && !in_array($lvl, $levelsSeen)) $levelsSeen[] = $lvl;
                }
            }
            if ($vLevelLabel && !in_array($vLevelLabel, $levelsSeen)) {
                array_unshift($levelsSeen, $vLevelLabel);
            }
            foreach ($levelsSeen as $lvlName) {
                $isChecked = strcasecmp(trim($lvlName), $vLevelLabel) === 0;
                $mark = $isChecked ? ' ✔' : '';
                $xml = str_replace(
                    htmlspecialchars($lvlName),
                    htmlspecialchars($lvlName) . $mark,
                    $xml
                );
            }

            // 4.2 Standard Replacements (Sequential & Safe)
            // Sequence: ID (Left), Course (Left), Name (Left), ID (Right), Course (Right), Name (Right)
            $replacements = [
                ['label' => 'ID Number', 'value' => $studentId],
                ['label' => 'Course and Year', 'value' => $courseYear],
                ['label' => 'Name', 'value' => $studentName],
                ['label' => 'ID Number', 'value' => $studentId],
                ['label' => 'Course and Year', 'value' => $courseYear],
                ['label' => 'Name', 'value' => $studentName],
            ];

            // Readable font size: sz=18 is 9pt
            // Black color, Century Gothic
            $props = '<w:rPr><w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic" w:cs="Century Gothic"/><w:sz w:val="18"/><w:szCs w:val="18"/><w:u w:val="single"/></w:rPr>';

            foreach ($replacements as $rep) {
                $label = $rep['label'];
                $value = $rep['value'];
                
                // Flexible regex for labels to handle split tags and variations (like "D Number")
                if ($label === 'ID Number') {
                    $labelRegex = '(?:I(?:\s|<[^>]+>)*)?D(?:\s|<[^>]+>)*N(?:\s|<[^>]+>)*u(?:\s|<[^>]+>)*m(?:\s|<[^>]+>)*b(?:\s|<[^>]+>)*e(?:\s|<[^>]+>)*r';
                } else {
                    $labelRegex = '';
                    for ($i = 0; $i < strlen($label); $i++) {
                        $char = $label[$i];
                        $labelRegex .= preg_quote($char) . '(?:<[^>]+>)*';
                    }
                }

                $replacementXml = "</w:t></w:r><w:r>$props<w:t> $value </w:t></w:r>";
                
                // Add padding only for ID Number to separate it from Course and Year
                  if ($label === 'ID Number') {
                      $replacementXml .= "<w:r><w:t xml:space=\"preserve\">                        </w:t></w:r>";
                  }
                
                $replacementXml .= "<w:r><w:t>";
                
                // Pattern matches the label, the colon, and ALL subsequent underscores
                // $1 captures the label and colon, $2 captures all underscores
                $pattern = '/(' . $labelRegex . '(?:\s|<[^>]+>)*:(?:\s|<[^>]+>)*)(_+)/s';
                
                // We replace the whole match with Group 1 (label: ) + our new XML (value)
                // This removes ALL matched underscores cleanly.
                $xml = preg_replace($pattern, '$1' . $replacementXml, $xml, 1);
            }

            // Write back
            $zip->addFromString('word/document.xml', $xml);
            $zip->close();

            // 5. Download with unique filename to prevent caching
            if (ob_get_level()) ob_end_clean();
            
            $downloadName = 'Entrance_Slip_' . $studentId . '_' . date('His') . '.docx';
            header('Content-Description: File Transfer');
            header('Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document');
            header('Content-Disposition: attachment; filename="' . $downloadName . '"');
            header('Content-Transfer-Encoding: binary');
            header('Expires: 0');
            header('Cache-Control: must-revalidate');
            header('Pragma: public');
            header('Content-Length: ' . filesize($tempFile));
            readfile($tempFile);
            
            // Cleanup
            unlink($tempFile);
            exit;
        } else {
            $this->error('Failed to open DOCX template');
        }
    }

    /**
     * Dynamically rebuild the violation table:
     * - tblGrid: recalculate column widths for the new column count
     * - Row 1: fix the "Month" cell's gridSpan to match level count
     * - Header row 2: replace level columns with DB-fetched level names
     * - Data rows: one row per DB type, one date cell per level column
     */
    private function rebuildViolationTableRows($xml, array $typeNames, array $monthlyViolations, array $allLevelNames) {
        $tablePattern = '/<w:tbl>(?:(?!<w:tbl>).)*?<\/w:tbl>/s';

        return preg_replace_callback($tablePattern, function($tableMatch) use ($typeNames, $monthlyViolations, $allLevelNames) {
            $tableXml = $tableMatch[0];

            // Split into rows
            preg_match_all('/<w:tr[ >].*?<\/w:tr>/s', $tableXml, $rowMatches);
            $rows = $rowMatches[0];
            if (count($rows) < 2) return $tableXml;

            // Detect row types by content markers only — no hardcoded type names
            // Row 1: has both "Violation" and "Month" text cells
            // Row 2: level header — has "Permitted" or "Offense" level names
            // Data rows: any remaining rows with multiple cells (template rows)
            $row1 = null;
            $row2 = null;
            $dataRowTemplate = null;
            $dataRowIndices = [];

            foreach ($rows as $idx => $row) {
                if ($row1 === null && strpos($row, '>Violation<') !== false && strpos($row, '>Month<') !== false) {
                    $row1 = $row;
                    continue;
                }
                if ($row2 === null && (
                    stripos($row, 'Permitted') !== false ||
                    stripos($row, 'Offense') !== false
                )) {
                    $row2 = $row;
                    continue;
                }
                // Any remaining row with at least 2 cells is a data row (template structure)
                preg_match_all('/<w:tc[ >]/', $row, $tcMatches);
                if (count($tcMatches[0]) >= 2) {
                    $dataRowIndices[] = $idx;
                    if ($dataRowTemplate === null) $dataRowTemplate = $row;
                }
            }

            if ($dataRowTemplate === null) return $tableXml;

            $numLevelCols = count($allLevelNames);
            // Total columns = 1 (Violation label) + 1 (Month/date col) + numLevelCols
            // But the original layout is: col0=Violation(label), col1=first date col, col2..N=remaining date cols
            // Actually: col0 = Violation (label), cols 1..N = level date columns
            $totalCols = 1 + $numLevelCols;

            // --- Rebuild tblGrid with equal-width columns ---
            // Original total table width ~6979 dxa. Keep it, distribute evenly.
            $totalWidth = 6979;
            $labelColWidth = 1822; // keep original label column width
            $levelColWidth = (int)(($totalWidth - $labelColWidth) / max($numLevelCols, 1));
            
            $newGrid = '<w:tblGrid>';
            $newGrid .= '<w:gridCol w:w="' . $labelColWidth . '"/>';
            for ($i = 0; $i < $numLevelCols; $i++) {
                $newGrid .= '<w:gridCol w:w="' . $levelColWidth . '"/>';
            }
            $newGrid .= '</w:tblGrid>';

            $tableXml = preg_replace('/<w:tblGrid>.*?<\/w:tblGrid>/s', $newGrid, $tableXml);

            // --- Fix Row 1: update the "Month" + empty merged cell gridSpan ---
            // Row 1 has: [Violation vMerge:restart] [Month] [empty gridSpan=4]
            // The empty cell needs gridSpan = numLevelCols (covers all level columns)
            // and the Month cell has no span (it maps to 1 col by itself... 
            // actually in the original: Month=1col, empty=gridSpan4 covering 4 cols = 5 total date cols)
            // New layout: Month cell = 1 col? No — looking at XML, Month spans 1 col,
            // and the 3rd cell has gridSpan=4 (originally). We want them to merge into numLevelCols together.
            // Simplest: give Month cell gridSpan=numLevelCols, remove the empty cell.
            if ($row1 !== null) {
                $row1 = $this->fixRow1GridSpan($row1, $numLevelCols);
            }

            // --- Rebuild row 2 (level header) with dynamic columns ---
            $newRow2 = '';
            if ($row2 !== null) {
                $newRow2 = $this->rebuildLevelHeaderRow($row2, $allLevelNames);
            }

            // --- Rebuild data rows ---
            $newDataRows = '';
            preg_match_all('/<w:tc[ >].*?<\/w:tc>/s', $dataRowTemplate, $cellMatches);
            $cellStructures = $cellMatches[0];
            foreach ($typeNames as $typeName) {
                $violations = $monthlyViolations[$typeName] ?? [];
                $newDataRows .= $this->buildDataRowByLevel(
                    $dataRowTemplate, $cellStructures, $typeName, $violations, $allLevelNames
                );
            }

            // Rebuild table content
            $newTableContent = preg_replace('/<w:tr[ >].*?<\/w:tr>/s', '', $tableXml);
            $replacement = ($row1 ?? '') . ($newRow2 !== '' ? $newRow2 : ($row2 ?? '')) . $newDataRows;
            $newTableContent = str_replace('</w:tbl>', $replacement . '</w:tbl>', $newTableContent);

            return $newTableContent;
        }, $xml);
    }

    /**
     * Fix Row 1 so the "Month" header spans all level columns correctly.
     * Original: [Violation vMerge] [Month 1-col] [empty gridSpan=4]
     * New:      [Violation vMerge] [Month gridSpan=numLevelCols]
     */
    private function fixRow1GridSpan($row1Xml, $numLevelCols) {
        // Get all cells
        preg_match_all('/<w:tc[ >].*?<\/w:tc>/s', $row1Xml, $cellMatches);
        $cells = $cellMatches[0];
        if (count($cells) < 2) return $row1Xml;

        // Cell 0 = Violation (vMerge:restart) — keep exactly as-is
        $violationCell = $cells[0];

        // Cell 1 = Month — update its gridSpan to cover all level cols
        $monthCell = $cells[1];
        // Remove any existing gridSpan
        $monthCell = preg_replace('/<w:gridSpan[^\/]*\/>/s', '', $monthCell);
        // Insert gridSpan after tcW (or at start of tcPr)
        if ($numLevelCols > 1) {
            $monthCell = preg_replace(
                '/(<w:tcPr>)/',
                '$1<w:gridSpan w:val="' . $numLevelCols . '"/>',
                $monthCell,
                1
            );
        }

        // Get row properties
        $trPr = '';
        if (preg_match('/<w:tblPrEx>.*?<\/w:tblPrEx>/s', $row1Xml, $m)) $trPr .= $m[0];
        if (preg_match('/<w:trPr>.*?<\/w:trPr>/s', $row1Xml, $m)) $trPr .= $m[0];

        // Rebuild with only 2 cells (drop the old empty gridSpan cell)
        return '<w:tr>' . $trPr . $violationCell . $monthCell . '</w:tr>';
    }

    /**
     * Rebuild the level header row (row 2) replacing old level cells with DB level names.
     */
    private function rebuildLevelHeaderRow($row2Xml, array $allLevelNames) {
        // Get row properties
        $trPr = '';
        if (preg_match('/<w:trPr>.*?<\/w:trPr>/s', $row2Xml, $m)) $trPr = $m[0];
        if (preg_match('/<w:tblPrEx>.*?<\/w:tblPrEx>/s', $row2Xml, $m)) $trPr = $m[0] . $trPr;

        // Extract all cells from the row
        preg_match_all('/<w:tc[ >].*?<\/w:tc>/s', $row2Xml, $cellMatches);
        $cells = $cellMatches[0];

        // Cell 0 is the vMerge:continue "Violation" cell — keep it
        $firstCell = $cells[0] ?? '';

        // Use cell 1 as template for level cells (has the right borders/shading)
        $levelCellTemplate = $cells[1] ?? $cells[0];
        $tcPr = '';
        if (preg_match('/<w:tcPr>.*?<\/w:tcPr>/s', $levelCellTemplate, $m)) $tcPr = $m[0];

        $newCells = $firstCell;
        foreach ($allLevelNames as $levelName) {
            $newCells .= '<w:tc>' . $tcPr
                . '<w:p><w:pPr><w:pStyle w:val="6"/><w:jc w:val="center"/></w:pPr>'
                . '<w:r><w:rPr>'
                . '<w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic" w:cs="Century Gothic"/>'
                . '<w:b/><w:bCs/><w:sz w:val="15"/><w:szCs w:val="15"/>'
                . '</w:rPr><w:t xml:space="preserve">' . htmlspecialchars($levelName) . '</w:t></w:r></w:p>'
                . '</w:tc>';
        }

        return '<w:tr>' . $trPr . $newCells . '</w:tr>';
    }

    /**
     * Build a data row where each date cell maps to the specific level column.
     * A violation is placed in the column matching its violationLevelLabel.
     */
    private function buildDataRowByLevel($templateRow, $cellStructures, $typeName, $violations, array $allLevelNames) {
        $trPr = '';
        if (preg_match('/<w:tblPrEx>.*?<\/w:tblPrEx>/s', $templateRow, $m)) $trPr .= $m[0];
        if (preg_match('/<w:trPr>.*?<\/w:trPr>/s', $templateRow, $m)) $trPr .= $m[0];

        // Get cell properties from template data cells (index 1 onward = date cells)
        $dateCellTcPr = '';
        if (isset($cellStructures[1]) && preg_match('/<w:tcPr>.*?<\/w:tcPr>/s', $cellStructures[1], $m)) {
            $dateCellTcPr = $m[0];
        }

        // Get label cell properties (index 0)
        $labelCellTcPr = '';
        if (isset($cellStructures[0]) && preg_match('/<w:tcPr>.*?<\/w:tcPr>/s', $cellStructures[0], $m)) {
            $labelCellTcPr = $m[0];
        }

        // Build an index: levelName => violation record (use first match per level)
        $levelToViolation = [];
        foreach ($violations as $v) {
            $lvl = trim($v['violationLevelLabel'] ?? '');
            if ($lvl && !isset($levelToViolation[$lvl])) {
                $levelToViolation[$lvl] = $v;
            }
        }

        // Label cell
        $cells = '<w:tc>' . $labelCellTcPr
            . '<w:p><w:pPr><w:pStyle w:val="6"/></w:pPr>'
            . '<w:r><w:rPr>'
            . '<w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic" w:cs="Century Gothic"/>'
            . '<w:b/><w:bCs/><w:sz w:val="15"/><w:szCs w:val="15"/>'
            . '</w:rPr><w:t xml:space="preserve">' . htmlspecialchars($typeName) . '</w:t></w:r></w:p>'
            . '</w:tc>';

        // One cell per level column
        foreach ($allLevelNames as $levelName) {
            $v = null;
            // Exact match first, then case-insensitive
            if (isset($levelToViolation[$levelName])) {
                $v = $levelToViolation[$levelName];
            } else {
                foreach ($levelToViolation as $k => $rec) {
                    if (strcasecmp($k, $levelName) === 0) { $v = $rec; break; }
                }
            }

            if ($v !== null) {
                $ts = strtotime(str_replace('/', '-', $v['dateReported']) . ' ' . $v['violationTime']);
                if (!$ts) $ts = strtotime($v['dateReported'] . ' ' . $v['violationTime']);
                $dateStr = $ts ? date('m/d/Y g:i A', $ts) : $v['dateReported'];
                $content = '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
                    . '<w:r><w:rPr>'
                    . '<w:rFonts w:ascii="Century Gothic" w:hAnsi="Century Gothic" w:cs="Century Gothic"/>'
                    . '<w:sz w:val="14"/><w:szCs w:val="14"/>'
                    . '</w:rPr><w:t xml:space="preserve">' . htmlspecialchars($dateStr) . '</w:t></w:r></w:p>';
            } else {
                $content = '<w:p><w:r><w:t></w:t></w:r></w:p>';
            }

            $cells .= '<w:tc>' . $dateCellTcPr . $content . '</w:tc>';
        }

        return '<w:tr>' . $trPr . $cells . '</w:tr>';
    }

}
