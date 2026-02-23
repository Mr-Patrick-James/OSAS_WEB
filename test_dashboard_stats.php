<?php
require_once 'app/config/db_connect.php';

// Check Students
$studentsResult = $conn->query("SELECT COUNT(*) as count FROM students");
if ($studentsResult) {
    $row = $studentsResult->fetch_assoc();
    echo "Total Students: " . $row['count'] . "\n";
} else {
    echo "Error querying students: " . $conn->error . "\n";
}

$studentsResultStatus = $conn->query("SELECT COUNT(*) as count FROM students WHERE status != 'archived' OR status IS NULL");
if ($studentsResultStatus) {
    $row = $studentsResultStatus->fetch_assoc();
    echo "Active Students: " . $row['count'] . "\n";
} else {
    echo "Error querying active students: " . $conn->error . "\n";
}

// Check Departments
$departmentsResult = $conn->query("SELECT COUNT(*) as count FROM departments");
if ($departmentsResult) {
    $row = $departmentsResult->fetch_assoc();
    echo "Total Departments: " . $row['count'] . "\n";
} else {
    echo "Error querying departments: " . $conn->error . "\n";
}

// Check Violations
$violationsResult = $conn->query("SELECT COUNT(*) as count FROM violations");
if ($violationsResult) {
    $row = $violationsResult->fetch_assoc();
    echo "Total Violations: " . $row['count'] . "\n";
} else {
    echo "Error querying violations: " . $conn->error . "\n";
}

// Check Violators
$violatorsResult = $conn->query("SELECT COUNT(DISTINCT student_id) as count FROM violations WHERE student_id IS NOT NULL AND student_id != ''");
if ($violatorsResult) {
    $row = $violatorsResult->fetch_assoc();
    echo "Total Violators: " . $row['count'] . "\n";
} else {
    echo "Error querying violators: " . $conn->error . "\n";
}

// Check Penalties
$penaltiesResult = $conn->query("SELECT COUNT(*) as count FROM violations WHERE status = 'disciplinary' OR violation_level = 'disciplinary'");
if ($penaltiesResult) {
    $row = $penaltiesResult->fetch_assoc();
    echo "Total Penalties: " . $row['count'] . "\n";
} else {
    echo "Error querying penalties: " . $conn->error . "\n";
}
?>
