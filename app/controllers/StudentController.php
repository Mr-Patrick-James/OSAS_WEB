<?php
require_once __DIR__ . '/../core/Controller.php';
require_once __DIR__ . '/../models/StudentModel.php';

class StudentController extends Controller {
    private $model;

    public function __construct() {
        ob_start();
        error_reporting(E_ALL);
        ini_set('display_errors', 0);
        ini_set('log_errors', 1);
        header('Content-Type: application/json');
        @session_start();
        
        $this->model = new StudentModel();
    }

    public function index() {
        // Check if student_id parameter is provided for single student lookup
        $studentId = trim($this->getGet('student_id', ''));
        
        if (!empty($studentId)) {
            // Get single student by student_id
            try {
                error_log("StudentController::index - Looking for student_id: " . $studentId);
                $student = $this->model->getByStudentId($studentId);
                if ($student) {
                    error_log("StudentController::index - Student found: " . json_encode($student));
                    $this->success('Student retrieved successfully', $student);
                } else {
                    error_log("StudentController::index - Student not found for student_id: " . $studentId);
                    // Try to see if student exists but is archived
                    $allStudents = $this->model->query("SELECT student_id, status FROM students WHERE student_id = ?", [$studentId]);
                    if (!empty($allStudents)) {
                        error_log("StudentController::index - Student exists but status is: " . $allStudents[0]['status']);
                        $this->error('Student not found or is archived');
                    } else {
                        $this->error('Student not found');
                    }
                }
            } catch (Exception $e) {
                error_log("StudentController::index - Exception: " . $e->getMessage());
                error_log("StudentController::index - Stack trace: " . $e->getTraceAsString());
                $this->error('Failed to retrieve student: ' . $e->getMessage());
            }
            return;
        }
        
        // Otherwise, get all students (paginated)
        $filter = $this->getGet('filter', 'all');
        $search = $this->getGet('search', '');
        $page = intval($this->getGet('page', 1));
        $limit = intval($this->getGet('limit', 10));

        try {
            $students = $this->model->getAllWithDetails($filter, $search, $page, $limit);
            $totalCount = $this->model->getCountWithFilters($filter, $search);
            $this->success('Students retrieved successfully', [
                'students' => $students,
                'total' => $totalCount,
                'page' => $page,
                'limit' => $limit,
                'total_pages' => ceil($totalCount / max(1, $limit))
            ]);
        } catch (Exception $e) {
            $this->error('Failed to retrieve students: ' . $e->getMessage());
        }
    }

    public function stats() {
        try {
            $stats = $this->model->getStats();
            $this->success('Statistics retrieved successfully', $stats);
        } catch (Exception $e) {
            $this->error('Failed to retrieve statistics: ' . $e->getMessage());
        }
    }

    public function create() {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        $studentId = $this->sanitize($this->getPost('studentIdCode', $this->getPost('studentId', '')));
        $firstName = $this->sanitize($this->getPost('firstName', ''));
        $middleName = $this->sanitize($this->getPost('middleName', ''));
        $lastName = $this->sanitize($this->getPost('lastName', ''));
        $email = $this->sanitize($this->getPost('studentEmail', ''));
        $contact = $this->sanitize($this->getPost('studentContact', ''));
        $address = $this->sanitize($this->getPost('studentAddress', ''));
        $department = $this->sanitize($this->getPost('studentDept', ''));
        $sectionId = intval($this->getPost('studentSection', 0));
        $yearlevel = $this->sanitize($this->getPost('studentYearlevel', ''));
        $status = $this->sanitize($this->getPost('studentStatus', 'active'));
        $avatar = $this->sanitize($this->getPost('studentAvatar', ''));

        // Handle Image Upload if present
        if (isset($_FILES['studentImage']) && $_FILES['studentImage']['error'] === UPLOAD_ERR_OK) {
            $file = $_FILES['studentImage'];
            $uploadDir = __DIR__ . '/../assets/img/students/';
            
            // Create directory if not exists
            if (!file_exists($uploadDir)) {
                mkdir($uploadDir, 0777, true);
            }

            $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
            $filename = 'student_' . time() . '_' . uniqid() . '.' . $ext;
            $filepath = $uploadDir . $filename;

            if (move_uploaded_file($file['tmp_name'], $filepath)) {
                $avatar = 'app/assets/img/students/' . $filename;
            }
        }

        if (empty($studentId) || empty($firstName) || empty($lastName) || empty($email)) {
            $this->error('Student ID, First Name, Last Name, and Email are required.');
        }

        if ($this->model->studentIdExists($studentId)) {
            $this->error('Student ID already exists.');
        }

        if ($this->model->emailExists($email)) {
            $this->error('Email already exists.');
        }

        try {
            $data = [
                'student_id' => $studentId,
                'first_name' => $firstName,
                'middle_name' => $middleName ?: null,
                'last_name' => $lastName,
                'email' => $email,
                'contact_number' => $contact ?: null,
                'address' => $address ?: null,
                'department' => $department ?: null,
                'section_id' => $sectionId ?: null,
                'yearlevel' => $yearlevel ?: null,
                'year_level' => $yearlevel ?: '1st Year', // Include underscore version for DB compatibility
                'avatar' => $avatar ?: null,
                'status' => $status,
                'created_at' => date('Y-m-d H:i:s')
            ];

            $id = $this->model->create($data);
            
            // Sync user account for the student
            if ($id) {
                $fullName = $firstName . ' ' . ($middleName ? $middleName . ' ' : '') . $lastName;
                $this->model->syncUser($studentId, $email, $fullName);
            }
            
            $this->success('Student added successfully!', ['id' => $id]);
        } catch (Exception $e) {
            $this->error('Failed to add student: ' . $e->getMessage());
        }
    }

    public function update() {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        $id = intval($this->getPost('id', $this->getPost('studentId', $this->getGet('id', 0))));
        if ($id === 0) {
            $this->error('Invalid student ID');
        }

        $studentId = $this->sanitize($this->getPost('studentIdCode', ''));
        $firstName = $this->sanitize($this->getPost('firstName', ''));
        $middleName = $this->sanitize($this->getPost('middleName', ''));
        $lastName = $this->sanitize($this->getPost('lastName', ''));
        $email = $this->sanitize($this->getPost('studentEmail', ''));
        $contact = $this->sanitize($this->getPost('studentContact', ''));
        $address = $this->sanitize($this->getPost('studentAddress', ''));
        $department = $this->sanitize($this->getPost('studentDept', ''));
        $sectionId = intval($this->getPost('studentSection', 0));
        $yearlevel = $this->sanitize($this->getPost('studentYearlevel', ''));
        $status = $this->sanitize($this->getPost('studentStatus', 'active'));
        $avatar = $this->sanitize($this->getPost('studentAvatar', ''));

        // Handle Image Upload if present
        if (isset($_FILES['studentImage']) && $_FILES['studentImage']['error'] === UPLOAD_ERR_OK) {
            $file = $_FILES['studentImage'];
            $uploadDir = __DIR__ . '/../assets/img/students/';
            
            // Create directory if not exists
            if (!file_exists($uploadDir)) {
                mkdir($uploadDir, 0777, true);
            }

            $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
            $filename = 'student_' . time() . '_' . uniqid() . '.' . $ext;
            $filepath = $uploadDir . $filename;

            if (move_uploaded_file($file['tmp_name'], $filepath)) {
                $avatar = 'app/assets/img/students/' . $filename;
            }
        }

        if (empty($studentId) || empty($firstName) || empty($lastName) || empty($email)) {
            $this->error('Student ID, First Name, Last Name, and Email are required.');
        }

        if ($this->model->studentIdExists($studentId, $id)) {
            $this->error('Student ID already exists.');
        }

        if ($this->model->emailExists($email, $id)) {
            $this->error('Email already exists.');
        }

        try {
            $data = [
                'student_id' => $studentId,
                'first_name' => $firstName,
                'middle_name' => $middleName ?: null,
                'last_name' => $lastName,
                'email' => $email,
                'contact_number' => $contact ?: null,
                'address' => $address ?: null,
                'department' => $department ?: null,
                'section_id' => $sectionId ?: null,
                'yearlevel' => $yearlevel ?: null,
                'year_level' => $yearlevel ?: '1st Year', // Include underscore version for DB compatibility
                'status' => $status,
                'updated_at' => date('Y-m-d H:i:s')
            ];

            if ($avatar !== '') {
                $data['avatar'] = $avatar;
            }

            $this->model->update($id, $data);
            
            // Sync user account for the student
            $fullName = $firstName . ' ' . ($middleName ? $middleName . ' ' : '') . $lastName;
            $this->model->syncUser($studentId, $email, $fullName);
            
            $this->success('Student updated successfully!');
        } catch (Exception $e) {
            $this->error('Failed to update student: ' . $e->getMessage());
        }
    }

    public function delete() {
        $id = intval($this->getGet('id', $this->getPost('id', 0)));
        
        if ($id === 0) {
            $this->error('Invalid student ID');
        }

        try {
            $this->model->archive($id);
            $this->success('Student archived successfully!');
        } catch (Exception $e) {
            $this->error('Failed to archive student: ' . $e->getMessage());
        }
    }

    public function restore() {
        $id = intval($this->getGet('id', $this->getPost('id', 0)));
        
        if ($id === 0) {
            $this->error('Invalid student ID');
        }

        try {
            $this->model->restore($id);
            $this->success('Student restored successfully!');
        } catch (Exception $e) {
            $this->error('Failed to restore student: ' . $e->getMessage());
        }
    }

    /**
     * Import students from JSON data
     * (Called after parsing Excel with Python or if provided directly)
     */
    public function import() {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            $this->error('Invalid request method');
        }

        // We'll look for the JSON file generated by the python script
        // or accept a JSON body directly
        $jsonFile = __DIR__ . '/../../../scripts/students_data.json';
        
        if (!file_exists($jsonFile)) {
            // Attempt to run the python script if the JSON is missing
            $scriptPath = __DIR__ . '/../../../scripts/parse_students_full.py';
            if (file_exists($scriptPath)) {
                $output = [];
                $return_var = 0;
                // Use python or python3 depending on system
                exec("python \"$scriptPath\" 2>&1", $output, $return_var);
                if ($return_var !== 0) {
                    error_log("Failed to run python script: " . implode("\n", $output));
                }
            }
            
            if (!file_exists($jsonFile)) {
                $this->error('Import data not found. The enrollment list could not be parsed.');
            }
        }

        try {
            $jsonData = json_decode(file_get_contents($jsonFile), true);
            if (!$jsonData || !isset($jsonData['students'])) {
                $this->error('Invalid import data format.');
            }

            $results = $this->model->importAll($jsonData);
            $this->success('Import completed successfully!', $results);
        } catch (Exception $e) {
            $this->error('Import failed: ' . $e->getMessage());
        }
    }
}

