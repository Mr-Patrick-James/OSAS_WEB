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

        if ($action === 'generate_slip') {
            $this->generate_slip();
            return;
        }

        if ($action === 'get_slip_template') {
            $this->get_slip_template();
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
                $count = $this->model->archiveOldViolations();
                $this->json([
                    'status' => 'success',
                    'message' => "Successfully archived $count violations and reset all student violation levels."
                ]);
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

        if (isset($_SESSION['role']) && $_SESSION['role'] === 'user') {
            $studentId = $_SESSION['student_id_code'] ?? '';
            if (empty($studentId)) {
                $this->error('Student ID not found. Please login again.', '', 401);
            }
        }

        try {
            $violations = $this->model->getAllWithStudentInfo(
                $filter,
                $search,
                $studentId,
                $dateFrom,
                $dateTo,
                $isArchived
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

        if (!isset($_SESSION['user_id'])) {
            $this->error('Authentication required', 'Please login first', 401);
        }
        if (($_SESSION['role'] ?? '') !== 'admin') {
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
        $status         = $this->sanitize($input['status'] ?? 'warning');
        $notes          = $this->sanitize($input['notes'] ?? '');

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
            // Check for duplicate violation (Double Submission Check)
            // We check if a violation with the same details was already created
            // This prevents "2 copies of the same violation"
            $existingId = $this->model->checkDuplicateSubmission(
               $studentId, 
               $violationType, 
               $violationLevel,
               $violationDate, 
               $violationTime, 
               $location
            );
            
            if ($existingId) {
                // If it exists, we check if it was created very recently (e.g. < 10 seconds ago) to treat it as a double-submit
                // Or just block it entirely as "Duplicate".
                // User said "prevent duplicate of the same violation only one", so blocking duplicates is correct.
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
            $this->error('Access denied', 'Admin privileges required', 403);
        }

        $input = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $current = $this->model->getById($id);

        if (!$current) {
            $this->error('Violation not found');
        }

        $data = [
            'violation_type_id'  => $this->sanitize($input['violationType'] ?? $current['violation_type_id']),
            'violation_level_id' => $this->sanitize($input['violationLevel'] ?? $current['violation_level_id']),
            'violation_date'  => $this->sanitize($input['violationDate'] ?? $current['violation_date']),
            'violation_time'  => $this->sanitize($input['violationTime'] ?? $current['violation_time']),
            'location'        => $this->sanitize($input['location'] ?? $current['location']),
            'reported_by'     => $current['reported_by'],
            'status'          => $this->sanitize($input['status'] ?? $current['status']),
            'notes'           => $this->sanitize($input['notes'] ?? $current['notes']),
            'attachments'     => isset($input['attachments']) ? json_encode($input['attachments']) : $current['attachments'],
            'updated_at'      => date('Y-m-d H:i:s')
        ];

        try {
            $this->model->update($id, $data);
            
            // Update reports
            try {
                $this->reportModel->generateReportsFromViolations();
            } catch (Exception $e) {
                error_log("Failed to auto-update reports: " . $e->getMessage());
            }

            $this->success('Violation updated successfully');
        } catch (Exception $e) {
            $this->error('Failed to update violation');
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
        if (($_SESSION['role'] ?? '') !== 'admin') {
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
            $types = $this->model->getViolationTypes();
            $result = [];
            
            // If types are returned as assoc array with 'id' key (single row) or array of arrays
            // Check structure of getViolationTypes return
            if ($types && count($types) > 0) {
                foreach ($types as $type) {
                    $levels = $this->model->getViolationLevels($type['id']);
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

        // 1.1 Fetch Violation History for this Month
        $history = $this->model->getAllWithStudentInfo('all', '', $studentId);
        $monthlyViolations = [
            'Improper Uniform' => [],
            'Improper Foot Wear' => [],
            'No ID' => []
        ];

        foreach ($history as $v) {
            $vDate = $v['dateReported']; // Fix: use dateReported instead of violation_date
            // Parse date carefully (handle d/m/Y or Y-m-d)
            $ts = strtotime(str_replace('/', '-', $vDate));
            if (!$ts) $ts = strtotime($vDate);
            
            if ($ts && date('m', $ts) == $month && date('Y', $ts) == $year) {
                $type = strtolower($v['violationTypeLabel'] ?? ''); // Fix: use violationTypeLabel
                
                // Categorize
                if (strpos($type, 'uniform') !== false) {
                    $monthlyViolations['Improper Uniform'][] = $v;
                } elseif (strpos($type, 'foot') !== false || strpos($type, 'shoe') !== false) {
                    $monthlyViolations['Improper Foot Wear'][] = $v;
                } elseif (strpos($type, 'id') !== false) {
                    $monthlyViolations['No ID'][] = $v;
                }
            }
        }

        // Sort by datetime ASC
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
        
        $vType = strtolower($violation['violationTypeLabel'] ?? '');
        $vLevel = strtolower($violation['violationLevelLabel'] ?? '');

        // Checkmark Logic (Legacy support + Visual indicator)
        $checkUniform = (strpos($vType, 'uniform') !== false) ? '✔' : ' ';
        $checkFootwear = (strpos($vType, 'foot') !== false || strpos($vType, 'shoe') !== false) ? '✔' : ' ';
        $checkID = (strpos($vType, 'id') !== false || strpos($vType, 'identification') !== false) ? '✔' : ' ';
        
        $check1st = (strpos($vLevel, '1st') !== false) ? '✔' : ' ';
        $check2nd = (strpos($vLevel, '2nd') !== false) ? '✔' : ' ';
        $check3rd = (strpos($vLevel, '3rd') !== false) ? '✔' : ' ';

        // 4. Modify XML
        $zip = new ZipArchive;
        if ($zip->open($tempFile) === TRUE) {
            $xml = $zip->getFromName('word/document.xml');

            // 4.1 Inject Monthly Violation Dates into Table
            // Note: We do this BEFORE simple str_replace to ensure anchors are intact
            $xml = $this->injectViolationsIntoTable($xml, 'Improper Uniform', $monthlyViolations['Improper Uniform']);
            $xml = $this->injectViolationsIntoTable($xml, 'Improper Foot Wear', $monthlyViolations['Improper Foot Wear']);
            $xml = $this->injectViolationsIntoTable($xml, 'No ID', $monthlyViolations['No ID']);

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

            // Violations (Text replacement - appends checkmark to label)
            $xml = str_replace('Improper Uniform', "Improper Uniform $checkUniform", $xml);
            $xml = str_replace('Improper Foot Wear', "Improper Foot Wear $checkFootwear", $xml);
            $xml = str_replace('No ID', "No ID $checkID", $xml);
            
            $xml = str_replace('1st Offense', "1st Offense $check1st", $xml);
            $xml = str_replace('2nd Offense', "2nd Offense $check2nd", $xml);
            $xml = str_replace('3rd Offense', "3rd Offense $check3rd", $xml);

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

    private function injectViolationsIntoTable($xml, $anchor, $violations) {
        // Pattern: Find any table row (<w:tr>) that contains the anchor text
        // This is much more robust than explode() because it handles multiple tables automatically
        $pattern = '/<w:tr(?:(?!<w:tr).)*?' . preg_quote($anchor) . '.*?<\/w:tr>/s';
        
        return preg_replace_callback($pattern, function($match) use ($violations) {
            $rowXml = $match[0];
            
            // Now we have the XML of ONE row. We need to fill its cells.
            // Split by cell start tag to find columns
            $cells = preg_split('/(?=<w:tc[ >])/', $rowXml);
            if (count($cells) < 2) return $rowXml;

            $newRowXml = $cells[0]; // Content before first cell
            
            // Iterate through cells starting from index 1 (the first <w:tc>)
            for ($i = 1; $i < count($cells); $i++) {
                $cellContent = $cells[$i];

                // Map violations: index 0 -> Cell 1, index 1 -> Cell 2, etc.
                // We offset by 1 because the first cell is the label
                $vIndex = $i - 2; 
                
                if ($vIndex >= 0 && $vIndex < 5 && isset($violations[$vIndex])) {
                    $v = $violations[$vIndex];
                    $dateStrRaw = $v['dateReported'];
                    $timeStrRaw = $v['violationTime'];
                    
                    // Parse date carefully
                    $ts = strtotime(str_replace('/', '-', $dateStrRaw) . ' ' . $timeStrRaw);
                    if (!$ts) $ts = strtotime($dateStrRaw . ' ' . $timeStrRaw);
                    
                    $dateStr = date('m/d/Y- g:i A', $ts);
                    
                    // Inject into <w:p> with standard small font size
                    $runXml = '<w:r><w:rPr><w:sz w:val="16"/><w:szCs w:val="16"/></w:rPr><w:t>' . $dateStr . '</w:t></w:r>';
                    
                    if (strpos($cellContent, '</w:p>') !== false) {
                        // Find the last </w:p> in this cell and insert before it
                        $lastPPos = strrpos($cellContent, '</w:p>');
                        $cellContent = substr($cellContent, 0, $lastPPos) . $runXml . substr($cellContent, $lastPPos);
                    } else {
                        // Fallback: wrap in a paragraph
                        $cellContent = preg_replace('/(<\/w:tc>)/', '<w:p>' . $runXml . '</w:p>$1', $cellContent);
                    }
                }
                
                $newRowXml .= $cellContent;
            }
            
            return $newRowXml;
        }, $xml);
    }

}
