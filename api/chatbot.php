<?php
/**
 * Chatbot API Endpoint
 * Handles chat messages and integrates with AI API
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/../app/config/db_connect.php';

// Load AI API configuration
$ai_config_file = __DIR__ . '/../app/config/ai_config.php';
if (file_exists($ai_config_file)) {
    require_once $ai_config_file;
} else {
    // Default configuration
    define('AI_API_TYPE', 'openai'); // 'openai' or 'custom'
    define('AI_API_KEY', ''); // Set your API key here
    define('AI_API_URL', 'https://api.openai.com/v1/chat/completions');
    define('AI_MODEL', 'gpt-3.5-turbo');
    define('USE_DATABASE_CONTEXT', true); // Whether to include database context in prompts
}

// Verify configuration is loaded
if (!defined('AI_API_KEY')) {
    define('AI_API_KEY', '');
}
if (!defined('AI_API_TYPE')) {
    define('AI_API_TYPE', 'openai');
}
if (!defined('AI_API_URL')) {
    define('AI_API_URL', 'https://api.openai.com/v1/chat/completions');
}
if (!defined('AI_MODEL')) {
    define('AI_MODEL', 'gpt-3.5-turbo');
}
if (!defined('USE_DATABASE_CONTEXT')) {
    define('USE_DATABASE_CONTEXT', true);
}

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// Get request data
$input = json_decode(file_get_contents('php://input'), true);
$message = $input['message'] ?? '';
$conversation_history = $input['history'] ?? [];

if (empty($message)) {
    http_response_code(400);
    echo json_encode(['error' => 'Message is required']);
    exit;
}

// Get user context from session if available
session_start();
$user_id = $_SESSION['user_id'] ?? null;
$user_role = $_SESSION['role'] ?? null;

// Build system prompt with optional database context
$system_prompt = <<<PROMPT
You are **OSAS Bot**, the intelligent virtual assistant for the **E-OSAS (Electronic Office of Student Affairs System)** — a web-based student discipline and records management platform used by the Office of Student Affairs.

═══════════════════════════════════════════
IDENTITY & PERSONALITY
═══════════════════════════════════════════
- Name: OSAS Bot
- Role: AI assistant embedded in the E-OSAS web application
- Tone: Friendly, professional, helpful, and concise
- Language: Respond in the same language the user uses (English or Filipino/Tagalog). If the user mixes languages (Taglish), match that style.
- System Owner/Administrator/Head: Cedrick H. Almarez

═══════════════════════════════════════════
CORE CAPABILITIES
═══════════════════════════════════════════
You can help with:
1. **Student Records** — Look up student info, counts, departments, sections
2. **Violations & Discipline** — Explain violation types, levels, statuses, sanctions, and processes
3. **Announcements** — Summarize active announcements, explain how to create/manage them
4. **Reports** — Explain report generation, types, and how to export data
5. **Departments & Sections** — List, explain, and help manage organizational units
6. **System Navigation** — Guide users on how to use each module/page of E-OSAS
7. **Policies & Procedures** — Explain the student discipline process, due process, and sanctions
8. **Troubleshooting** — Help with common issues (login problems, data not showing, etc.)

═══════════════════════════════════════════
VIOLATION LEVELS & SANCTIONS KNOWLEDGE
═══════════════════════════════════════════
- **Minor Offense (Level 1):** First offense = verbal warning; Second = written warning; Third = community service or counseling referral
- **Major Offense (Level 2):** First offense = suspension (1-3 days); Second = suspension (3-5 days) + parent conference; Third = recommendation for dismissal
- **Serious Offense (Level 3):** Immediate suspension pending investigation; may lead to expulsion after due process
- Due process: Notice → Hearing → Decision → Appeal (if applicable)
- All violations are recorded and tracked per semester; records may be archived at semester end

═══════════════════════════════════════════
SYSTEM MODULES KNOWLEDGE
═══════════════════════════════════════════
- **Dashboard:** Overview of statistics — total students, violations this month, departments, recent activity
- **Students Module:** Add, import (Excel), edit, search, and view student profiles with photos
- **Violations Module:** Record new violations, assign types/levels, track status (pending → resolved → archived), generate entrance slips
- **Departments Module:** Create and manage academic departments with codes
- **Sections Module:** Create sections linked to departments
- **Announcements Module:** Create, edit, publish announcements with audience targeting (all, students, staff)
- **Reports Module:** Generate PDF/Excel reports filtered by date, department, violation type, etc.
- **Settings:** System configuration, user management, backup/restore
- **Entrance Slip:** Auto-generated document a student must present to return to class after a violation

═══════════════════════════════════════════
RESPONSE RULES
═══════════════════════════════════════════
1. **DATA ACCURACY:** ONLY use ACTUAL DATA from the context provided below. NEVER invent or fabricate student names, IDs, case numbers, or statistics.
2. **Unknown Info:** If you don't have specific data in your context, say: "I don't have that specific information in my current data. You may want to check the [relevant module] directly."
3. **Formatting:** Use bullet points, numbered lists, and bold text for clarity. Keep responses scannable.
4. **Length:** Be concise but complete. For simple questions, 1-3 sentences. For how-to guides, use step-by-step format.
5. **Scope:** Only answer questions related to E-OSAS, student affairs, school discipline, and system usage. For unrelated questions, politely redirect: "I'm designed to help with E-OSAS and student affairs topics. Is there something about the system I can help you with?"
6. **Student Privacy:** When discussing specific student records, only share data that the current user's role permits them to see.
7. **Proactive Help:** If a user seems confused, offer related suggestions or ask clarifying questions.
8. **Error Guidance:** If a user reports a problem, provide troubleshooting steps (clear cache, check connection, verify permissions, contact admin).

═══════════════════════════════════════════
HOW-TO GUIDES (for common questions)
═══════════════════════════════════════════
**How to record a violation:**
1. Go to Violations module → Click "Add Violation"
2. Search and select the student
3. Choose violation type and level
4. Fill in date, description, and evidence (if any)
5. Click Save — the violation is now tracked

**How to import students:**
1. Go to Students module → Click "Import"
2. Download the Excel template
3. Fill in student data following the template format
4. Upload the completed file
5. Review and confirm the import

**How to generate a report:**
1. Go to Reports module
2. Select report type (violations, students, department summary)
3. Set date range and filters
4. Click Generate → Download as PDF or Excel

**How to create an announcement:**
1. Go to Announcements module → Click "New Announcement"
2. Enter title, message content, and select audience
3. Choose type (general, urgent, event)
4. Publish immediately or schedule

PROMPT;


// Optionally add database context
if (USE_DATABASE_CONTEXT && $conn && !$conn->connect_error) {
    $context = getDatabaseContext($conn, $user_id, $user_role);
    if ($context) {
        $system_prompt .= "\n\nCurrent system context:\n" . $context;
    }
}

// Prepare messages for AI API
$messages = [
    ['role' => 'system', 'content' => $system_prompt]
];

// Add conversation history
foreach ($conversation_history as $msg) {
    $messages[] = [
        'role' => $msg['role'] ?? 'user',
        'content' => $msg['content'] ?? ''
    ];
}

// Add current message
$messages[] = ['role' => 'user', 'content' => $message];

// Call AI API
try {
    $response = callAIAPI($messages);
    
    if ($response['success']) {
        echo json_encode([
            'success' => true,
            'response' => $response['message'],
            'usage' => $response['usage'] ?? null
        ]);
    } else {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => $response['error'] ?? 'Failed to get AI response'
        ]);
    }
} catch (Exception $e) {
    http_response_code(500);
    error_log("Chatbot API Exception: " . $e->getMessage());
    echo json_encode([
        'success' => false,
        'error' => 'Server error: ' . $e->getMessage()
    ]);
}

/**
 * Get database context for the chatbot
 */
function getDatabaseContext($conn, $user_id, $user_role) {
    $context = [];
    
    try {
        // Get basic stats
        $stats = [];
        
        // Count students
        $result = @$conn->query("SELECT COUNT(*) as count FROM students");
        if ($result) {
            $row = $result->fetch_assoc();
            $stats['total_students'] = $row['count'] ?? 0;
        }
        
        // Count departments
        $result = @$conn->query("SELECT COUNT(*) as count FROM departments");
        if ($result) {
            $row = $result->fetch_assoc();
            $stats['total_departments'] = $row['count'] ?? 0;
        }
        
        // Count active violations (this month)
        $result = @$conn->query("SELECT COUNT(*) as count FROM violations WHERE is_archived = 0");
        if ($result) {
            $row = $result->fetch_assoc();
            $stats['active_violations'] = $row['count'] ?? 0;
        }

        // Count all-time violations
        $result = @$conn->query("SELECT COUNT(*) as count FROM violations");
        if ($result) {
            $row = $result->fetch_assoc();
            $stats['total_violations_all_time'] = $row['count'] ?? 0;
        }
        
        $context[] = "SYSTEM STATISTICS: " . json_encode($stats);

        // Get departments list
        $result = @$conn->query("SELECT department_code, department_name FROM departments ORDER BY department_name");
        if ($result && $result->num_rows > 0) {
            $depts = [];
            while ($row = $result->fetch_assoc()) {
                $depts[] = $row['department_name'] . " (" . $row['department_code'] . ")";
            }
            $context[] = "DEPARTMENTS: " . implode(', ', $depts);
        }

        // Get sections list
        $result = @$conn->query("SELECT s.section_name, s.section_code, d.department_code FROM sections s LEFT JOIN departments d ON s.department_id = d.id ORDER BY s.section_name LIMIT 30");
        if ($result && $result->num_rows > 0) {
            $sections = [];
            while ($row = $result->fetch_assoc()) {
                $sections[] = $row['section_name'] . " (" . ($row['department_code'] ?? '') . ")";
            }
            $context[] = "SECTIONS: " . implode(', ', $sections);
        }

        // Get recent violations with student info (actual data)
        $result = @$conn->query("
            SELECT v.id, v.case_id, v.student_id, v.violation_date, v.status,
                   CONCAT(s.first_name, ' ', COALESCE(s.middle_name, ''), ' ', s.last_name) as student_name,
                   s.department,
                   vt.name as violation_type,
                   vl.name as violation_level
            FROM violations v
            LEFT JOIN students s ON v.student_id = s.student_id
            LEFT JOIN violation_types vt ON v.violation_type_id = vt.id
            LEFT JOIN violation_levels vl ON v.violation_level_id = vl.id
            WHERE v.is_archived = 0
            ORDER BY v.created_at DESC
            LIMIT 20
        ");
        if ($result && $result->num_rows > 0) {
            $violations = [];
            while ($row = $result->fetch_assoc()) {
                $violations[] = "Case " . ($row['case_id'] ?? $row['id']) . ": " . trim($row['student_name']) . 
                    " (ID: " . $row['student_id'] . ", Dept: " . ($row['department'] ?? 'N/A') . 
                    ") - Type: " . ($row['violation_type'] ?? 'Unknown') . 
                    ", Level: " . ($row['violation_level'] ?? 'Unknown') . 
                    ", Status: " . ($row['status'] ?? 'pending') . 
                    ", Date: " . ($row['violation_date'] ?? 'N/A');
            }
            $context[] = "RECENT VIOLATIONS (actual records):\n" . implode("\n", $violations);
        }

        // Get violation type counts
        $result = @$conn->query("
            SELECT vt.name as type_name, COUNT(*) as count 
            FROM violations v 
            LEFT JOIN violation_types vt ON v.violation_type_id = vt.id 
            WHERE v.is_archived = 0 
            GROUP BY vt.name 
            ORDER BY count DESC
        ");
        if ($result && $result->num_rows > 0) {
            $typeCounts = [];
            while ($row = $result->fetch_assoc()) {
                $typeCounts[] = ($row['type_name'] ?? 'Unknown') . ": " . $row['count'];
            }
            $context[] = "VIOLATION COUNTS BY TYPE (this month): " . implode(', ', $typeCounts);
        }

        // Get recent announcements
        $result = @$conn->query("SELECT title, message, type, created_at FROM announcements WHERE status = 'active' ORDER BY created_at DESC LIMIT 5");
        if ($result && $result->num_rows > 0) {
            $announcements = [];
            while ($row = $result->fetch_assoc()) {
                $announcements[] = "\"" . $row['title'] . "\" (Type: " . ($row['type'] ?? 'general') . ", Date: " . $row['created_at'] . ")";
            }
            $context[] = "ACTIVE ANNOUNCEMENTS: " . implode('; ', $announcements);
        }

        // Add user-specific context if logged in
        if ($user_id && $user_role) {
            $context[] = "Current user role: " . $user_role;
            
            if ($user_role === 'user') {
                $studentId = $_SESSION['student_id_code'] ?? '';
                if ($studentId) {
                    // Get user's own violations
                    $stmt = $conn->prepare("
                        SELECT v.case_id, v.violation_date, v.status, vt.name as violation_type, vl.name as violation_level
                        FROM violations v
                        LEFT JOIN violation_types vt ON v.violation_type_id = vt.id
                        LEFT JOIN violation_levels vl ON v.violation_level_id = vl.id
                        WHERE v.student_id = ?
                        ORDER BY v.created_at DESC
                        LIMIT 10
                    ");
                    if ($stmt) {
                        $stmt->bind_param("s", $studentId);
                        $stmt->execute();
                        $result = $stmt->get_result();
                        if ($result && $result->num_rows > 0) {
                            $myViolations = [];
                            while ($row = $result->fetch_assoc()) {
                                $myViolations[] = "Case " . ($row['case_id'] ?? '') . ": " . ($row['violation_type'] ?? 'Unknown') . 
                                    " (" . ($row['violation_level'] ?? '') . ") - Status: " . ($row['status'] ?? 'pending') . 
                                    ", Date: " . ($row['violation_date'] ?? 'N/A');
                            }
                            $context[] = "YOUR VIOLATIONS (Student ID: $studentId):\n" . implode("\n", $myViolations);
                        } else {
                            $context[] = "You (Student ID: $studentId) have no violations recorded.";
                        }
                        $stmt->close();
                    }
                }
            }
        }
        
    } catch (Exception $e) {
        error_log("Error getting database context: " . $e->getMessage());
    }
    
    return implode("\n", $context);
}

/**
 * Call AI API (OpenAI, Groq, Hugging Face, Cohere, Gemini, or custom)
 */
function callAIAPI($messages) {
    // Check if constants are defined
    if (!defined('AI_API_KEY') || empty(AI_API_KEY) || AI_API_KEY === '') {
        return [
            'success' => false,
            'error' => 'AI API key not configured. Please set AI_API_KEY in app/config/ai_config.php'
        ];
    }
    
    // Check if API type is defined
    $api_type = defined('AI_API_TYPE') ? AI_API_TYPE : 'openai';
    
    // Route to appropriate API handler
    switch ($api_type) {
        case 'groq':
            return callGroqAPI($messages);
        case 'huggingface':
            return callHuggingFaceAPI($messages);
        case 'cohere':
            return callCohereAPI($messages);
        case 'gemini':
            return callGeminiAPI($messages);
        case 'openai':
            return callOpenAI($messages);
        default:
            return callCustomAI($messages);
    }
}

/**
 * Call OpenAI API
 */
function callOpenAI($messages) {
    // Check if CURL is available
    if (!function_exists('curl_init')) {
        return ['success' => false, 'error' => 'CURL is not enabled on this server. Please enable the PHP CURL extension.'];
    }
    
    // Validate API key
    if (empty(AI_API_KEY) || strlen(AI_API_KEY) < 20) {
        return ['success' => false, 'error' => 'Invalid API key. Please check your API key in app/config/ai_config.php'];
    }
    
    $ch = curl_init(AI_API_URL);
    
    if (!$ch) {
        return ['success' => false, 'error' => 'Failed to initialize CURL'];
    }
    
    $data = [
        'model' => AI_MODEL,
        'messages' => $messages,
        'temperature' => 0.7,
        'max_tokens' => 500
    ];
    
    $json_data = json_encode($data);
    if (json_last_error() !== JSON_ERROR_NONE) {
        curl_close($ch);
        return ['success' => false, 'error' => 'Failed to encode request data: ' . json_last_error_msg()];
    }
    
    // SSL Configuration
    // Check if SSL verification should be disabled (for local development)
    $verify_ssl = defined('VERIFY_SSL_CERTIFICATE') ? VERIFY_SSL_CERTIFICATE : true;
    
    // Auto-detect local development environment
    $is_local = in_array($_SERVER['HTTP_HOST'] ?? '', ['localhost', '127.0.0.1']) || 
                strpos($_SERVER['HTTP_HOST'] ?? '', 'localhost') !== false ||
                strpos($_SERVER['HTTP_HOST'] ?? '', '127.0.0.1') !== false ||
                strpos($_SERVER['HTTP_HOST'] ?? '', '.local') !== false;
    
    // Use config setting, but allow auto-disable for local development if not explicitly set
    if (!$verify_ssl || ($is_local && !defined('VERIFY_SSL_CERTIFICATE'))) {
        $verify_ssl = false;
    }
    
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $json_data,
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'Authorization: Bearer ' . AI_API_KEY
        ],
        CURLOPT_TIMEOUT => 30,
        // SSL verification - disabled for local development by default
        // WARNING: Always enable in production!
        CURLOPT_SSL_VERIFYPEER => $verify_ssl,
        CURLOPT_SSL_VERIFYHOST => $verify_ssl ? 2 : 0
    ]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_error = curl_error($ch);
    curl_close($ch);
    
    // Log for debugging (remove in production)
    error_log("OpenAI API Response Code: " . $http_code);
    if ($curl_error) {
        error_log("CURL Error: " . $curl_error);
    }
    
    if ($curl_error) {
        return ['success' => false, 'error' => 'Connection error: ' . $curl_error];
    }
    
    if ($http_code !== 200) {
        $error_data = json_decode($response, true);
        $error_message = 'API request failed';
        
        if (isset($error_data['error']['message'])) {
            $error_message = $error_data['error']['message'];
        } elseif (isset($error_data['error'])) {
            $error_message = is_string($error_data['error']) ? $error_data['error'] : 'Unknown API error';
        } else {
            $error_message = 'API request failed with HTTP code ' . $http_code;
            if ($response) {
                $error_message .= '. Response: ' . substr($response, 0, 200);
            }
        }
        
        return [
            'success' => false,
            'error' => $error_message
        ];
    }
    
    if (empty($response)) {
        return ['success' => false, 'error' => 'Empty response from API'];
    }
    
    $data = json_decode($response, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        return ['success' => false, 'error' => 'Failed to parse API response: ' . json_last_error_msg()];
    }
    
    if (isset($data['choices'][0]['message']['content'])) {
        return [
            'success' => true,
            'message' => trim($data['choices'][0]['message']['content']),
            'usage' => $data['usage'] ?? null
        ];
    }
    
    // Log the response for debugging
    error_log("Unexpected API response format: " . substr($response, 0, 500));
    
    return ['success' => false, 'error' => 'Invalid API response format. Check server logs for details.'];
}

/**
 * Call Groq API (FREE - Very Fast!)
 */
function callGroqAPI($messages) {
    if (!function_exists('curl_init')) {
        return ['success' => false, 'error' => 'CURL is not enabled on this server.'];
    }
    
    $ch = curl_init(AI_API_URL);
    if (!$ch) {
        return ['success' => false, 'error' => 'Failed to initialize CURL'];
    }
    
    $data = [
        'model' => AI_MODEL,
        'messages' => $messages,
        'temperature' => 0.7,
        'max_tokens' => 500
    ];
    
    $verify_ssl = defined('VERIFY_SSL_CERTIFICATE') ? VERIFY_SSL_CERTIFICATE : false;
    
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($data),
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'Authorization: Bearer ' . AI_API_KEY
        ],
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => $verify_ssl,
        CURLOPT_SSL_VERIFYHOST => $verify_ssl ? 2 : 0
    ]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curl_error = curl_error($ch);
    curl_close($ch);
    
    if ($curl_error) {
        return ['success' => false, 'error' => 'Connection error: ' . $curl_error];
    }
    
    if ($http_code !== 200) {
        $error_data = json_decode($response, true);
        $error_message = isset($error_data['error']['message']) ? $error_data['error']['message'] : 'API request failed with code ' . $http_code;
        return ['success' => false, 'error' => $error_message];
    }
    
    $data = json_decode($response, true);
    if (isset($data['choices'][0]['message']['content'])) {
        return [
            'success' => true,
            'message' => trim($data['choices'][0]['message']['content'])
        ];
    }
    
    return ['success' => false, 'error' => 'Invalid API response format'];
}

/**
 * Call Hugging Face API (FREE)
 */
function callHuggingFaceAPI($messages) {
    if (!function_exists('curl_init')) {
        return ['success' => false, 'error' => 'CURL is not enabled on this server.'];
    }
    
    // Convert messages to prompt format
    $prompt = '';
    foreach ($messages as $msg) {
        if ($msg['role'] === 'system') {
            $prompt .= $msg['content'] . "\n\n";
        } elseif ($msg['role'] === 'user') {
            $prompt .= "User: " . $msg['content'] . "\n";
        } elseif ($msg['role'] === 'assistant') {
            $prompt .= "Assistant: " . $msg['content'] . "\n";
        }
    }
    $prompt .= "Assistant: ";
    
    $ch = curl_init(AI_API_URL);
    if (!$ch) {
        return ['success' => false, 'error' => 'Failed to initialize CURL'];
    }
    
    $data = ['inputs' => $prompt];
    $verify_ssl = defined('VERIFY_SSL_CERTIFICATE') ? VERIFY_SSL_CERTIFICATE : false;
    
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($data),
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'Authorization: Bearer ' . AI_API_KEY
        ],
        CURLOPT_TIMEOUT => 60,
        CURLOPT_SSL_VERIFYPEER => $verify_ssl,
        CURLOPT_SSL_VERIFYHOST => $verify_ssl ? 2 : 0
    ]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code === 200) {
        $data = json_decode($response, true);
        if (isset($data[0]['generated_text'])) {
            $text = $data[0]['generated_text'];
            // Extract assistant response
            $parts = explode('Assistant: ', $text);
            $assistant_response = end($parts);
            return [
                'success' => true,
                'message' => trim($assistant_response)
            ];
        }
    }
    
    return ['success' => false, 'error' => 'Hugging Face API call failed'];
}

/**
 * Call Cohere API (FREE Tier)
 */
function callCohereAPI($messages) {
    if (!function_exists('curl_init')) {
        return ['success' => false, 'error' => 'CURL is not enabled on this server.'];
    }
    
    $ch = curl_init(AI_API_URL);
    if (!$ch) {
        return ['success' => false, 'error' => 'Failed to initialize CURL'];
    }
    
    // Convert messages format for Cohere
    $chat_history = [];
    $message = '';
    foreach ($messages as $msg) {
        if ($msg['role'] === 'user') {
            if (!empty($message)) {
                $chat_history[] = ['role' => 'assistant', 'message' => $message];
                $message = '';
            }
            $message = $msg['content'];
        } elseif ($msg['role'] === 'assistant') {
            $message = $msg['content'];
        }
    }
    
    $data = [
        'model' => AI_MODEL,
        'message' => $message,
        'chat_history' => $chat_history
    ];
    
    $verify_ssl = defined('VERIFY_SSL_CERTIFICATE') ? VERIFY_SSL_CERTIFICATE : false;
    
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($data),
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'Authorization: Bearer ' . AI_API_KEY,
            'Accept: application/json'
        ],
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => $verify_ssl,
        CURLOPT_SSL_VERIFYHOST => $verify_ssl ? 2 : 0
    ]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code === 200) {
        $data = json_decode($response, true);
        if (isset($data['text'])) {
            return [
                'success' => true,
                'message' => trim($data['text'])
            ];
        }
    }
    
    return ['success' => false, 'error' => 'Cohere API call failed'];
}

/**
 * Call Google Gemini API (FREE Tier)
 */
function callGeminiAPI($messages) {
    if (!function_exists('curl_init')) {
        return ['success' => false, 'error' => 'CURL is not enabled on this server.'];
    }
    
    $url = AI_API_URL . '?key=' . AI_API_KEY;
    $ch = curl_init($url);
    if (!$ch) {
        return ['success' => false, 'error' => 'Failed to initialize CURL'];
    }
    
    // Convert messages format for Gemini
    $parts = [];
    foreach ($messages as $msg) {
        if ($msg['role'] !== 'system') {
            $parts[] = [
                'role' => $msg['role'] === 'user' ? 'user' : 'model',
                'parts' => [['text' => $msg['content']]]
            ];
        }
    }
    
    $data = ['contents' => $parts];
    $verify_ssl = defined('VERIFY_SSL_CERTIFICATE') ? VERIFY_SSL_CERTIFICATE : false;
    
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($data),
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json'
        ],
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => $verify_ssl,
        CURLOPT_SSL_VERIFYHOST => $verify_ssl ? 2 : 0
    ]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code === 200) {
        $data = json_decode($response, true);
        if (isset($data['candidates'][0]['content']['parts'][0]['text'])) {
            return [
                'success' => true,
                'message' => trim($data['candidates'][0]['content']['parts'][0]['text'])
            ];
        }
    }
    
    return ['success' => false, 'error' => 'Gemini API call failed'];
}

/**
 * Call Custom AI API (for other providers)
 */
function callCustomAI($messages) {
    // Implement custom AI API call here
    // This is a placeholder for other AI providers
    
    $ch = curl_init(AI_API_URL);
    
    $data = [
        'messages' => $messages
    ];
    
    $verify_ssl = defined('VERIFY_SSL_CERTIFICATE') ? VERIFY_SSL_CERTIFICATE : false;
    
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($data),
        CURLOPT_HTTPHEADER => [
            'Content-Type: application/json',
            'Authorization: Bearer ' . AI_API_KEY
        ],
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => $verify_ssl,
        CURLOPT_SSL_VERIFYHOST => $verify_ssl ? 2 : 0
    ]);
    
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code === 200) {
        $data = json_decode($response, true);
        return [
            'success' => true,
            'message' => $data['response'] ?? $data['message'] ?? 'Response received'
        ];
    }
    
    return ['success' => false, 'error' => 'Custom AI API call failed'];
}

