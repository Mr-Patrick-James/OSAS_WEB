<?php
echo "PHP Version: " . phpversion() . "\n";
echo "Loaded Extensions:\n";
print_r(get_loaded_extensions());

if (class_exists('mysqli')) {
    echo "MySQLi class exists.\n";
    try {
        $conn = new mysqli("localhost", "root", "", "osas");
        if ($conn->connect_error) {
            echo "MySQLi connection failed: " . $conn->connect_error . "\n";
        } else {
            echo "MySQLi connection successful.\n";
            $conn->close();
        }
    } catch (Exception $e) {
        echo "MySQLi connection exception: " . $e->getMessage() . "\n";
    }
} else {
    echo "MySQLi class DOES NOT exist.\n";
}

if (class_exists('PDO')) {
    echo "PDO class exists.\n";
    try {
        $pdo = new PDO("mysql:host=localhost;dbname=osas", "root", "");
        echo "PDO connection successful.\n";
    } catch (PDOException $e) {
        echo "PDO connection failed: " . $e->getMessage() . "\n";
    }
} else {
    echo "PDO class DOES NOT exist.\n";
}
?>
