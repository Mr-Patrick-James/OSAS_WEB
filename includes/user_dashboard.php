<?php
session_start();

// Restore session from cookies if available
if (isset($_COOKIE['user_id']) && isset($_COOKIE['role'])) {
    $_SESSION['user_id'] = $_COOKIE['user_id'];
    $_SESSION['username'] = $_COOKIE['username'] ?? '';
    $_SESSION['role'] = $_COOKIE['role'];
    $_SESSION['student_id'] = $_COOKIE['student_id'] ?? null;
    $_SESSION['student_id_code'] = $_COOKIE['student_id_code'] ?? null;
}

// Redirect if session is missing
if (!isset($_SESSION['user_id']) || !isset($_SESSION['role'])) {
    header('Location: ../login_page.php');
    exit;
}

// Redirect based on role
switch ($_SESSION['role']) {
    case 'admin':
        header('Location: dashboard.php');
        exit;
    case 'user':
        // Regular user, continue
        break;
    default:
        header('Location: ../login_page.php');
        exit;
}

// --------------------
// STUDENT ID HANDLING
// --------------------

// Get student ID code from session (preferred) or fallback to cookies/GET parameter
// student_id_code is the actual student ID string (e.g., "2023-001")
// student_id is the database ID, but we need the code for filtering
$student_id = $_SESSION['student_id_code'] 
           ?? $_COOKIE['student_id_code'] 
           ?? $_SESSION['student_id'] 
           ?? $_COOKIE['student_id'] 
           ?? $_GET['student_id'] 
           ?? null;

// If we got it from cookie, update session for future use
if ($student_id && !isset($_SESSION['student_id_code']) && isset($_COOKIE['student_id_code'])) {
    $_SESSION['student_id_code'] = $_COOKIE['student_id_code'];
    if (isset($_COOKIE['student_id'])) {
        $_SESSION['student_id'] = $_COOKIE['student_id'];
    }
}

// If still null and user is logged in, try to fetch from database
if (!$student_id && isset($_SESSION['user_id']) && $_SESSION['role'] === 'user') {
    require_once __DIR__ . '/../app/core/Model.php';
    require_once __DIR__ . '/../app/models/UserModel.php';
    
    try {
        $userModel = new UserModel();
        
        // Get student_id directly from users table (it's stored there!)
        $user = $userModel->getById($_SESSION['user_id']);
        
        if ($user && !empty($user['student_id'])) {
            $student_id = $user['student_id']; // Use the actual student_id string (e.g., "2023-0195")
            // Update session and cookie for future use
            $_SESSION['student_id_code'] = $student_id;
            
            $expiryTime = time() + (isset($_COOKIE['user_id']) ? 30*24*60*60 : 6*60*60);
            setcookie("student_id_code", $student_id, $expiryTime, "/", "", false, false);
        } else {
            error_log("Student ID not found in users table for user_id: " . $_SESSION['user_id']);
        }
    } catch (Exception $e) {
        error_log("Error fetching student_id from database: " . $e->getMessage());
        error_log("Stack trace: " . $e->getTraceAsString());
    }
}

// If still null, redirect to login or show error
if (!$student_id) {
    die("Student ID not found. Please login again.");
}

?>
<!DOCTYPE html>
<html lang="en">

<script>
    // Inject PHP student ID into JS
    window.STUDENT_ID = <?= json_encode($student_id) ?>;
</script>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-OSAS SYSTEM</title>
    
    <!-- CSS -->
    <link href='https://unpkg.com/boxicons@2.0.9/css/boxicons.min.css' rel='stylesheet'>
    <link rel="stylesheet" href="../app/assets/styles/user_dashboard.css?v=<?= time() ?>">
    <link rel="stylesheet" href="../app/assets/styles/user_topnav.css?v=<?= time() ?>">
    <link rel="stylesheet" href="../app/assets/styles/settings.css?v=<?= time() ?>">
    <link rel="stylesheet" href="../app/assets/styles/violation.css">
    <link rel="stylesheet" href="../app/assets/styles/chatbot.css">
    
    <!-- JS Libraries -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://js.puter.com/v2/"></script>
</head>

<body>
    <?php
    require_once __DIR__ . '/../app/core/View.php';
    require_once __DIR__ . '/../app/models/StudentModel.php';

    // Fetch student details
    $studentModel = new StudentModel();
    $studentData = $studentModel->getByStudentId($student_id);

    // Prepare data for views
    $viewData = [
        'role' => $_SESSION['role'] ?? 'user',
        'student' => $studentData
    ];

    View::partial('user_sidebar', $viewData);
    ?>

    <!-- CONTENT -->
    <section id="content">
        <?php
        $role = $_SESSION['role'] ?? 'user';
        $notificationCount = 7;
        // Merge notification count into view data
        $topnavData = array_merge($viewData, ['notificationCount' => $notificationCount]);
        View::partial('user_topnav', $topnavData);
        ?>

        <!-- MAIN CONTENT -->
        <div id="main-content" data-student-id="<?= htmlspecialchars($student_id) ?>">
            <!-- Dynamic content will be loaded here -->
        </div>
    </section>
    <!-- CONTENT -->

    <!-- JS Scripts -->
    <script src="../app/assets/js/lib/FileSaver.js"></script>
    <script src="../app/assets/js/lib/jspdf.umd.min.js"></script>
    <script src="../app/assets/js/lib/jspdf.plugin.autotable.min.js"></script>
    <script src="../app/assets/js/lib/docx.js"></script>
    <script src="../app/assets/js/utils/theme.js"></script>
    <script src="../app/assets/js/utils/eyeCare.js"></script>
    <script src="../app/assets/js/initModules.js"></script>
    <script src="../app/assets/js/user_dashboard.js?v=<?= time() ?>"></script>
    <script src="../app/assets/js/userDashboardData.js?v=<?= time() ?>"></script>
    <script src="../app/assets/js/userViolations.js?v=<?= time() ?>"></script>
    <script src="../app/assets/js/userAnnouncements.js"></script>
    <script src="../app/assets/js/chatbot.js"></script>
    <?php View::partial('logout_modal'); ?>

    <!-- Download Format Modal -->
    <div id="DownloadFormatModal" class="download-modal" style="display: none;">
        <div class="download-modal-overlay" onclick="closeDownloadModal()"></div>
        <div class="download-modal-container">
            <div class="download-modal-header">
                <h3>Select Download Format</h3>
                <button class="close-btn" onclick="closeDownloadModal()">
                    <i class='bx bx-x'></i>
                </button>
            </div>
            <div class="download-modal-body">
                <p>Please choose your preferred file format:</p>
                <div class="download-options">
                    <button class="download-option" onclick="confirmDownload('csv')">
                        <i class='bx bxs-file-txt' style="color: #28a745;"></i>
                        <span>CSV</span>
                        <small>Spreadsheet compatible</small>
                    </button>
                    <button class="download-option" onclick="confirmDownload('pdf')">
                        <i class='bx bxs-file-pdf' style="color: #dc3545;"></i>
                        <span>PDF</span>
                        <small>Portable Document Format</small>
                    </button>
                    <button class="download-option" onclick="confirmDownload('docx')">
                        <i class='bx bxs-file-doc' style="color: #007bff;"></i>
                        <span>DOCX</span>
                        <small>Microsoft Word</small>
                    </button>
                </div>
            </div>
        </div>
    </div>
</body>

</html>
