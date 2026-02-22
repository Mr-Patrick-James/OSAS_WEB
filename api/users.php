<?php
// Prevent any unwanted output
ob_start();

require_once __DIR__ . '/../app/core/Model.php';
require_once __DIR__ . '/../app/core/Controller.php';
require_once __DIR__ . '/../app/models/UserModel.php';
require_once __DIR__ . '/../app/controllers/UserController.php';

// Clean any output from includes
while (ob_get_level() > 0) {
    ob_end_clean();
}

try {
    $controller = new UserController();
    $action = $_GET['action'] ?? '';
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

    if ($method === 'GET' && ($action === 'admins' || $action === '')) {
        $controller->listAdmins();
    } elseif ($method === 'GET' && $action === 'users') {
        $controller->listUsers();
    } elseif ($method === 'GET' && $action === 'profile') {
        $controller->getProfile();
    } elseif ($method === 'POST' && $action === 'addAdmin') {
        $controller->createAdmin();
    } elseif ($method === 'POST' && $action === 'deleteAdmin') {
        $controller->deleteAdmin();
    } elseif ($method === 'POST' && $action === 'updateProfile') {
        $controller->updateProfile();
    } else {
        // Handle invalid request
        header('Content-Type: application/json');
        http_response_code(405);
        echo json_encode([
            'status' => 'error',
            'message' => 'Invalid request',
            'data' => []
        ]);
    }
} catch (Exception $e) {
    // Handle any uncaught exceptions (like DB connection errors in constructor)
    while (ob_get_level() > 0) {
        ob_end_clean();
    }
    
    header('Content-Type: application/json');
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Server Error: ' . $e->getMessage(),
        'data' => []
    ]);
}
exit;

