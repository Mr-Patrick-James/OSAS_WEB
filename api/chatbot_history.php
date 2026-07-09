<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

require_once __DIR__ . '/../app/config/db_connect.php';
session_start();

$user_id = $_SESSION['user_id'] ?? null;

if (!$user_id) {
    echo json_encode(['success' => false, 'error' => 'Not authenticated']);
    exit;
}

if (!isset($conn) || $conn->connect_error) {
    echo json_encode(['success' => false, 'error' => 'Database connection failed']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    // Delete session
    $input = json_decode(file_get_contents('php://input'), true);
    $client_session_id = $input['session_id'] ?? '';
    if ($client_session_id) {
        $stmt = $conn->prepare("DELETE FROM chat_sessions WHERE client_session_id = ? AND user_id = ?");
        $stmt->bind_param("si", $client_session_id, $user_id);
        $stmt->execute();
        echo json_encode(['success' => true]);
    } else {
        echo json_encode(['success' => false, 'error' => 'Missing session_id']);
    }
    exit;
}

// GET request: Fetch all sessions
try {
    $stmt = $conn->prepare("SELECT id, client_session_id, title, DATE(created_at) as session_date FROM chat_sessions WHERE user_id = ? ORDER BY created_at DESC LIMIT 30");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $res = $stmt->get_result();
    
    $sessions = [];
    while ($row = $res->fetch_assoc()) {
        $db_session_id = $row['id'];
        $client_session_id = $row['client_session_id'];
        
        // Fetch messages for this session
        $msg_stmt = $conn->prepare("SELECT sender, message, created_at FROM chat_messages WHERE session_id = ? ORDER BY created_at ASC");
        $msg_stmt->bind_param("i", $db_session_id);
        $msg_stmt->execute();
        $msg_res = $msg_stmt->get_result();
        
        $messages = [];
        while ($msg = $msg_res->fetch_assoc()) {
            $messages[] = [
                'role' => $msg['sender'] === 'bot' ? 'assistant' : 'user',
                'content' => $msg['message'],
                'time' => $msg['created_at']
            ];
        }
        
        $sessions[$client_session_id] = [
            'date' => $row['session_date'],
            'messages' => $messages
        ];
    }
    
    echo json_encode([
        'success' => true,
        'sessions' => $sessions
    ]);
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}
