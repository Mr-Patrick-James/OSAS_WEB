<?php
// Test script for models
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once __DIR__ . '/app/config/db_connect.php';
require_once __DIR__ . '/app/models/StudentModel.php';
require_once __DIR__ . '/app/models/DepartmentModel.php';
require_once __DIR__ . '/app/models/SectionModel.php';
require_once __DIR__ . '/app/models/ViolationModel.php';

try {
    echo "Testing StudentModel...\n";
    $studentModel = new StudentModel();
    $count = $studentModel->countActive();
    echo "Student count: " . $count . "\n";

    echo "Testing DepartmentModel...\n";
    $deptModel = new DepartmentModel();
    $count = $deptModel->getCountWithFilters('active');
    echo "Department count: " . $count . "\n";

    echo "Testing SectionModel...\n";
    $sectionModel = new SectionModel();
    $count = $sectionModel->countActive();
    echo "Section count: " . $count . "\n";

    echo "Testing ViolationModel...\n";
    $violationModel = new ViolationModel();
    $count = $violationModel->countViolations();
    echo "Violation count: " . $count . "\n";
    
    $violators = $violationModel->countViolators();
    echo "Violators count: " . $violators . "\n";

    $penalties = $violationModel->countPenalties();
    echo "Penalties count: " . $penalties . "\n";

    echo "All tests passed!\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    echo $e->getTraceAsString();
} catch (Error $e) {
    echo "Fatal Error: " . $e->getMessage() . "\n";
    echo $e->getTraceAsString();
}
