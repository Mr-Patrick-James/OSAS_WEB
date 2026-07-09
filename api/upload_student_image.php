<?php
// api/upload_student_image.php - Handle student image uploads

header('Content-Type: application/json');

require_once __DIR__ . '/../app/core/Model.php';
require_once __DIR__ . '/../app/models/StudentModel.php';

// Create uploads directory if it doesn't exist
$uploadDir = __DIR__ . '/../app/assets/img/students/';
if (!file_exists($uploadDir)) {
    if (!mkdir($uploadDir, 0777, true)) {
        echo json_encode([
            'status' => 'error',
            'message' => 'Failed to create upload directory.'
        ]);
        exit;
    }
}

// Check if file was uploaded
if (!isset($_FILES['image']) || $_FILES['image']['error'] !== UPLOAD_ERR_OK) {
    echo json_encode([
        'status' => 'error',
        'message' => 'No file uploaded or upload error occurred.'
    ]);
    exit;
}

$file = $_FILES['image'];
$allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];
$maxSize = 5 * 1024 * 1024; // 5MB

// Validate file type
if (!in_array($file['type'], $allowedTypes)) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Invalid file type. Only JPEG, PNG, GIF, and WebP images are allowed.'
    ]);
    exit;
}

// Validate file size
if ($file['size'] > $maxSize) {
    echo json_encode([
        'status' => 'error',
        'message' => 'File size exceeds 5MB limit.'
    ]);
    exit;
}

// Generate unique filename
$extension = pathinfo($file['name'], PATHINFO_EXTENSION);
$filename = 'student_' . time() . '_' . uniqid() . '.' . $extension;
$filepath = $uploadDir . $filename;

// Move uploaded file
if (move_uploaded_file($file['tmp_name'], $filepath)) {
    $relativePath = 'img/students/' . $filename;

    // Detect project prefix ('' on AWS root, '/OSAS_WEB' on local subfolder)
    $appDirs = ['app', 'api', 'includes', 'assets', 'public'];
    $scriptName = $_SERVER['SCRIPT_NAME'] ?? '';
    $basePath = '';
    if ($scriptName) {
        $parts = explode('/', trim($scriptName, '/'));
        if (!empty($parts[0]) && !in_array($parts[0], $appDirs)) {
            $basePath = '/' . $parts[0];
        }
    }

    // ── Persist avatar path to the students table ────────────────────────
    $studentIdCode = $_POST['student_id'] ?? $_POST['studentId'] ?? null;

    // Also try to get from session if not passed in POST
    if (!$studentIdCode) {
        if (session_status() === PHP_SESSION_NONE) {
            ini_set('session.cookie_samesite', 'Lax');
            session_start();
        }
        $studentIdCode = $_SESSION['student_id_code'] ?? $_SESSION['student_id'] ?? null;
    }

    $dbUpdated = false;
    if ($studentIdCode) {
        try {
            $studentModel = new StudentModel();
            $student = $studentModel->getByStudentId($studentIdCode);
            if ($student) {
                // Delete old avatar file if it exists and is a local file
                if (!empty($student['avatar']) && strpos($student['avatar'], 'img/students/') !== false) {
                    $oldFile = __DIR__ . '/../app/assets/' . $student['avatar'];
                    if (file_exists($oldFile)) {
                        @unlink($oldFile);
                    }
                }
                $studentModel->update($student['id'], ['avatar' => $relativePath]);
                $dbUpdated = true;
            }
        } catch (Exception $e) {
            error_log('upload_student_image: DB update failed — ' . $e->getMessage());
        }
    }
    // ────────────────────────────────────────────────────────────────────

    echo json_encode([
        'status' => 'success',
        'message' => 'Image uploaded successfully.',
        'data' => [
            'path'      => 'app/assets/' . $relativePath,
            'url'       => $basePath . '/app/assets/' . $relativePath,
            'db_saved'  => $dbUpdated,
        ]
    ]);
} else {
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to save uploaded file.'
    ]);
}
?>

