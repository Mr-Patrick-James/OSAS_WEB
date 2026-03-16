-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Mar 16, 2026 at 10:52 AM
-- Server version: 8.3.0
-- PHP Version: 8.3.14

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `osas`
--

DELIMITER $$
--
-- Procedures
--
DROP PROCEDURE IF EXISTS `add_student_violation`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `add_student_violation` (IN `p_student_id` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci, IN `p_violation_type` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci, IN `p_violation_date` DATE, IN `p_violation_time` TIME, IN `p_location` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci, IN `p_reported_by` VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci, IN `p_notes` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci, IN `p_case_id` VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci)   BEGIN
        DECLARE v_current_level VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL;
        DECLARE v_previous_level VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL;
        DECLARE v_permitted_count INT DEFAULT 0;
        DECLARE v_warning_count INT DEFAULT 0;
        DECLARE v_total_violations INT DEFAULT 0;
        DECLARE v_level_id INT DEFAULT NULL;
        DECLARE v_new_level VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL;
        
        -- Check if student violation level exists
        SELECT id, current_level, permitted_count, warning_count, total_violations
        INTO v_level_id, v_current_level, v_permitted_count, v_warning_count, v_total_violations
        FROM student_violation_levels
        WHERE student_id = p_student_id COLLATE utf8mb4_0900_ai_ci 
          AND violation_type = p_violation_type COLLATE utf8mb4_0900_ai_ci;
        
        IF v_level_id IS NULL THEN
            -- Create new violation level record
            INSERT INTO student_violation_levels (
                student_id, violation_type, current_level, 
                permitted_count, warning_count, total_violations,
                last_violation_date, last_violation_time, last_location,
                last_reported_by, last_notes, status
            ) VALUES (
                p_student_id, p_violation_type, 'permitted1',
                1, 0, 1,
                p_violation_date, p_violation_time, p_location,
                p_reported_by, p_notes, 'active'
            );
            
            SET v_level_id = LAST_INSERT_ID();
            SET v_previous_level = NULL;
            SET v_new_level = 'permitted1';
            SET v_total_violations = 1;
        ELSE
            -- Update existing record
            SET v_previous_level = v_current_level;
            SET v_total_violations = v_total_violations + 1;
            
            -- Determine new level based on total violations
            SET v_new_level = get_next_violation_level(v_current_level, v_total_violations);
            
            -- Update counts based on new level
            IF v_new_level LIKE 'permitted%' THEN
                SET v_permitted_count = v_permitted_count + 1;
            ELSEIF v_new_level LIKE 'warning%' THEN
                SET v_warning_count = v_warning_count + 1;
            END IF;
            
            -- Update the violation level record
            UPDATE student_violation_levels SET
                current_level = v_new_level,
                permitted_count = v_permitted_count,
                warning_count = v_warning_count,
                total_violations = v_total_violations,
                last_violation_date = p_violation_date,
                last_violation_time = p_violation_time,
                last_location = p_location,
                last_reported_by = p_reported_by,
                last_notes = p_notes,
                status = IF(v_new_level = 'disciplinary', 'disciplinary', 'active'),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_level_id;
        END IF;
        
        -- Add to history
        INSERT INTO violation_history (
            student_violation_level_id, student_id, violation_type,
            previous_level, new_level, violation_date, violation_time,
            location, reported_by, notes, case_id
        ) VALUES (
            v_level_id, p_student_id, p_violation_type,
            v_previous_level, v_new_level, p_violation_date, p_violation_time,
            p_location, p_reported_by, p_notes, p_case_id
        );
        
        -- Return the result
        SELECT 
            v_level_id as id,
            p_student_id as student_id,
            p_violation_type as violation_type,
            v_new_level as current_level,
            v_permitted_count as permitted_count,
            v_warning_count as warning_count,
            v_total_violations as total_violations,
            p_case_id as case_id;
    END$$

--
-- Functions
--
DROP FUNCTION IF EXISTS `get_next_violation_level`$$
CREATE DEFINER=`root`@`localhost` FUNCTION `get_next_violation_level` (`current_level` VARCHAR(50), `total_violations` INT) RETURNS VARCHAR(50) CHARSET utf8mb4 DETERMINISTIC READS SQL DATA BEGIN
        DECLARE next_level VARCHAR(50);
        
        CASE current_level
            WHEN 'permitted1' THEN
                SET next_level = IF(total_violations >= 2, 'permitted2', 'permitted1');
            WHEN 'permitted2' THEN
                SET next_level = IF(total_violations >= 3, 'warning1', 'permitted2');
            WHEN 'warning1' THEN
                SET next_level = IF(total_violations >= 4, 'warning2', 'warning1');
            WHEN 'warning2' THEN
                SET next_level = IF(total_violations >= 5, 'warning3', 'warning2');
            WHEN 'warning3' THEN
                SET next_level = IF(total_violations >= 6, 'disciplinary', 'warning3');
            ELSE
                SET next_level = 'disciplinary';
        END CASE;
        
        RETURN next_level;
    END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `announcements`
--

DROP TABLE IF EXISTS `announcements`;
CREATE TABLE IF NOT EXISTS `announcements` (
  `id` int NOT NULL AUTO_INCREMENT,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('info','urgent','warning') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'info',
  `status` enum('active','archived') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active',
  `created_by` int DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`),
  KEY `idx_type` (`type`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `announcements`
--

INSERT INTO `announcements` (`id`, `title`, `message`, `type`, `status`, `created_by`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'System Maintenance', 'The system will undergo maintenance tonight at 10 PM.', '', 'active', 1, '2025-12-15 16:25:36', '2026-03-02 21:35:57', '2026-03-02 13:35:57'),
(2, 'White t shirt', 'Enrollment for the next semester is now open.', 'info', 'active', 1, '2025-12-15 16:25:36', '2026-03-10 01:12:27', '2026-03-09 17:12:27'),
(3, 'Holiday Notice', 'Classes are suspended due to a public holiday.', 'info', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:12:43', '2026-03-09 17:12:43'),
(4, 'Exam Schedule', 'The final exam schedule has been posted.', '', 'archived', 2, '2025-12-15 16:25:36', '2026-03-10 01:12:39', '2026-03-09 17:12:39'),
(5, 'Server Downtime', 'Temporary server downtime may occur this weekend.', 'warning', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(6, 'New Policy Update', 'Please review the updated student handbook.', 'info', 'active', 3, '2025-12-15 16:25:36', '2026-03-11 19:52:52', '2026-03-11 11:52:52'),
(7, 'Payment Deadline', 'Tuition payment deadline is on Friday.', 'warning', 'active', 3, '2025-12-15 16:25:36', '2026-03-10 01:13:13', '2026-03-09 17:13:13'),
(8, 'Library Closed', 'The library will be closed for renovation.', '', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:12:47', '2026-03-09 17:12:47'),
(9, 'Seminar Announcement', 'A leadership seminar will be held in the auditorium.', '', 'active', 1, '2025-12-15 16:25:36', '2026-03-10 01:12:37', '2026-03-09 17:12:37'),
(10, 'System Upgrade', 'New system features have been deployed.', 'info', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(11, 'Network Issue', 'Some users may experience network interruptions.', 'warning', '', 1, '2025-12-15 16:25:36', '2026-03-11 19:52:58', '2026-03-11 11:52:58'),
(12, 'Sports Fest', 'Annual sports fest starts next week.', '', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:12:31', '2026-03-09 17:12:31'),
(13, 'ID Registration', 'Student ID registration is ongoing.', 'info', 'active', 3, '2025-12-15 16:25:36', '2026-03-10 01:12:51', '2026-03-09 17:12:51'),
(14, 'Class Resumption', 'Classes will resume on Monday.', 'info', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:12:57', '2026-03-09 17:12:57'),
(15, 'Fire Drill', 'A campus-wide fire drill will be conducted.', '', 'active', 1, '2025-12-15 16:25:36', '2026-03-10 01:13:01', '2026-03-09 17:13:01'),
(16, 'Parking Advisory', 'Limited parking slots available today.', 'warning', 'active', 3, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(17, 'System Bug Fix', 'Reported bugs have been fixed.', '', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(18, 'Workshop Invite', 'Join the career development workshop.', '', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:13:07', '2026-03-09 17:13:07'),
(19, 'Account Security', 'Enable two-factor authentication for security.', 'warning', 'active', 1, '2025-12-15 16:25:36', '2026-03-10 01:13:19', '2026-03-09 17:13:19'),
(20, 'Announcement Test', 'This is a test announcement record.', 'info', '', 1, '2025-12-15 16:25:36', '2026-03-11 19:53:05', '2026-03-11 11:53:05'),
(21, 'Uniform', 'Alway were proper uniform', 'info', 'active', 2572, '2026-03-09 17:01:12', '2026-03-10 01:12:24', '2026-03-09 17:12:24'),
(22, 'Uniform black', 'black month', 'info', 'active', 2572, '2026-03-09 17:08:02', '2026-03-10 01:12:23', '2026-03-09 17:12:23'),
(23, 'Uniform black', 'tesy', 'info', 'active', 2572, '2026-03-10 01:13:32', '2026-03-11 19:53:11', '2026-03-11 11:53:11');

-- --------------------------------------------------------

--
-- Table structure for table `departments`
--

DROP TABLE IF EXISTS `departments`;
CREATE TABLE IF NOT EXISTS `departments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `department_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `department_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `head_of_department` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` enum('active','archived') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `department_code` (`department_code`),
  KEY `status` (`status`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `departments`
--

INSERT INTO `departments` (`id`, `department_name`, `department_code`, `head_of_department`, `description`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'Bachelor of Technical-Vocational Teacher Education', 'BTVTED', 'Pamela Faye Gelena', '', 'active', '2026-02-22 22:29:58', '2026-03-12 09:31:13', NULL),
(2, 'Bachelor of Public Administration', 'BPA', 'Cedrick H. Almarez', '', 'active', '2026-02-22 22:29:58', '2026-03-12 08:44:03', NULL),
(3, 'Bachelor of Science in Information Systems', 'BSIS', 'June Paul Anouwevo', '', 'active', '2026-02-22 22:29:58', '2026-03-11 15:16:30', NULL),
(11, '04689457', 'wer', 'wer', 'werewr', 'archived', '2026-03-12 09:25:42', '2026-03-12 09:25:48', NULL),
(12, 'BSIT1', 'IT-0012', 'Pamela Faye Gelena', '', 'archived', '2026-03-12 10:16:27', '2026-03-12 10:22:54', NULL),
(14, 'BSIT12', 'IT-00122', 'Pamela Faye Gelena', '', 'archived', '2026-03-12 10:23:29', '2026-03-12 19:18:57', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
CREATE TABLE IF NOT EXISTS `messages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `announcement_id` int NOT NULL,
  `sender_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `sender_role` enum('admin','user') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `sender_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `message` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_read` tinyint(1) DEFAULT '0',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_announcement_id` (`announcement_id`),
  KEY `idx_sender_id` (`sender_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_deleted_at` (`deleted_at`)
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `messages`
--

INSERT INTO `messages` (`id`, `announcement_id`, `sender_id`, `sender_role`, `sender_name`, `message`, `is_read`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 5, '2023-0195', 'user', 'Unknown', 'why', 1, '2026-01-12 15:35:08', '2026-01-12 23:35:49', NULL),
(2, 5, '2023-0195', 'user', 'Unknown', 'hey', 1, '2026-01-12 15:35:24', '2026-01-12 23:35:49', NULL),
(3, 5, '2023', 'admin', 'Unknown', 'kasi maan ngayun', 1, '2026-01-12 15:36:11', '2026-01-12 23:36:29', NULL),
(4, 7, '2023-0195', 'user', 'Jumyr Manalo Moreno', 'hey', 1, '2026-01-12 15:41:01', '2026-01-12 23:47:26', NULL),
(5, 7, '2023-0195', 'user', 'Jumyr Manalo Moreno', 'bakit ganun', 1, '2026-01-12 15:46:20', '2026-01-12 23:47:26', NULL),
(6, 5, '2023-0195', 'user', 'Jumyr Manalo Moreno', 'oh', 1, '2026-01-12 15:46:54', '2026-01-12 23:47:20', NULL),
(7, 5, '2023-0195', 'user', 'Jumyr Manalo Moreno', 'huuuuu', 1, '2026-01-12 15:52:17', '2026-01-13 00:18:07', NULL),
(8, 5, '2023-0195', 'admin', 'Unknown', 'jijij', 0, '2026-01-12 16:00:15', '2026-01-13 00:00:15', NULL),
(9, 5, '2023-0195', 'user', 'Jumyr Moreno', 'bat ganun', 1, '2026-01-12 16:13:13', '2026-01-13 00:18:07', NULL),
(10, 5, '2023-0195', 'user', 'Jumyr Moreno', 'hala ka', 1, '2026-01-12 16:13:26', '2026-01-13 00:18:07', NULL),
(11, 5, '2023-0195', 'user', 'Jumyr Moreno', 'saan na', 1, '2026-01-12 16:14:35', '2026-01-13 00:18:07', NULL),
(12, 5, '2023-0195', 'user', 'Jumyr Moreno', 'diko makita', 1, '2026-01-12 16:14:39', '2026-01-13 00:18:07', NULL),
(13, 5, '2023', 'admin', 'jumyr', 'hgcfgfc', 1, '2026-01-12 16:24:41', '2026-01-13 09:37:11', NULL),
(14, 19, '2023', 'admin', 'jumyr', 'any feedback', 0, '2026-01-12 16:26:15', '2026-01-13 00:26:15', NULL),
(15, 19, '2023', 'admin', 'jumyr', 'lol', 0, '2026-01-12 16:26:40', '2026-01-13 00:26:40', NULL),
(16, 19, '2023', 'admin', 'jumyr', 'lol', 0, '2026-01-12 16:26:45', '2026-01-13 00:26:45', NULL),
(17, 19, '2023', 'admin', 'jumyr', 'hoho', 0, '2026-01-12 16:26:56', '2026-01-13 00:26:56', NULL),
(18, 19, '2023', 'admin', 'jumyr', 'j', 0, '2026-01-12 16:27:21', '2026-01-13 00:27:21', NULL),
(19, 19, '2023', 'admin', 'jumyr', 'k', 0, '2026-01-12 16:27:23', '2026-01-13 00:27:23', NULL),
(20, 19, '2023', 'admin', 'jumyr', 'k', 0, '2026-01-12 16:27:23', '2026-01-13 00:27:23', NULL),
(21, 19, '2023', 'admin', 'jumyr', 'k', 0, '2026-01-12 16:27:24', '2026-01-13 00:27:24', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `password_resets`
--

DROP TABLE IF EXISTS `password_resets`;
CREATE TABLE IF NOT EXISTS `password_resets` (
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `reports`
--

DROP TABLE IF EXISTS `reports`;
CREATE TABLE IF NOT EXISTS `reports` (
  `id` int NOT NULL AUTO_INCREMENT,
  `report_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `student_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `student_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `student_contact` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `department` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `department_code` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `section` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `section_id` int DEFAULT NULL,
  `yearlevel` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `uniform_count` int DEFAULT '0',
  `footwear_count` int DEFAULT '0',
  `no_id_count` int DEFAULT '0',
  `total_violations` int DEFAULT '0',
  `status` enum('permitted','warning','disciplinary') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'permitted',
  `last_violation_date` date DEFAULT NULL,
  `report_period_start` date DEFAULT NULL,
  `report_period_end` date DEFAULT NULL,
  `generated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `report_id` (`report_id`),
  UNIQUE KEY `unique_report_id` (`report_id`),
  KEY `idx_student_id` (`student_id`),
  KEY `idx_department` (`department_code`),
  KEY `idx_section` (`section_id`),
  KEY `idx_status` (`status`),
  KEY `idx_generated_at` (`generated_at`),
  KEY `idx_report_period` (`report_period_start`,`report_period_end`),
  KEY `idx_reports_student_dept` (`student_id`,`department_code`),
  KEY `idx_reports_status_date` (`status`,`generated_at`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reports`
--

INSERT INTO `reports` (`id`, `report_id`, `student_id`, `student_name`, `student_contact`, `department`, `department_code`, `section`, `section_id`, `yearlevel`, `uniform_count`, `footwear_count`, `no_id_count`, `total_violations`, `status`, `last_violation_date`, `report_period_start`, `report_period_end`, `generated_at`, `updated_at`, `deleted_at`) VALUES
(12, 'R491', '2023-0206', 'Patrick James V Romasanta', 'N/A', 'Bachelor of Science in Information Systems', 'BSIS', 'BSIS3', 12, '3rd Year', 1, 2, 1, 4, 'permitted', '2026-03-08', '2026-03-08', '2026-03-08', '2026-03-08 11:15:04', '2026-03-08 12:31:57', NULL),
(13, 'R489', '2023-0195', 'Jumyr M Moreno', NULL, 'Bachelor of Science in Information Systems', 'BSIS', 'BSIS3', 12, '3', 0, 2, 0, 2, 'permitted', '2026-03-11', '2026-03-11', '2026-03-11', '2026-03-11 20:03:55', '2026-03-11 23:02:33', NULL),
(14, 'R463', '2023-0216', 'Cristine S Manalo', NULL, 'Bachelor of Science in Information Systems', 'BSIS', 'BSIS3', 12, '3', 0, 2, 0, 2, 'permitted', '2026-03-12', '2026-03-12', '2026-03-12', '2026-03-12 09:13:27', '2026-03-12 10:44:27', NULL),
(15, 'R451', '2023-0216', 'Cristine S Manalo', NULL, 'Bachelor of Science in Information Systems', 'BSIS', 'BSIS3', 12, 'N/A', 0, 2, 0, 2, 'permitted', '2026-03-12', '2026-03-12', '2026-03-12', '2026-03-15 21:28:31', NULL, NULL),
(16, 'R477', '2023-0195', 'Jumyr M Moreno', NULL, 'Bachelor of Science in Information Systems', 'BSIS', 'BSIS3', 12, 'N/A', 0, 2, 0, 2, 'permitted', '2026-03-11', '2026-03-11', '2026-03-11', '2026-03-15 21:28:31', NULL, NULL),
(17, 'R479', '2023-0206', 'Patrick James U Romasanta', NULL, 'Bachelor of Science in Information Systems', 'BSIS', 'BSIS3', 12, 'N/A', 1, 2, 1, 4, 'permitted', '2026-03-08', '2026-03-08', '2026-03-08', '2026-03-15 21:28:31', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `report_recommendations`
--

DROP TABLE IF EXISTS `report_recommendations`;
CREATE TABLE IF NOT EXISTS `report_recommendations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `report_id` int NOT NULL,
  `recommendation` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `priority` enum('low','medium','high') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'medium',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_report_id` (`report_id`)
) ENGINE=InnoDB AUTO_INCREMENT=452 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `report_recommendations`
--

INSERT INTO `report_recommendations` (`id`, `report_id`, `recommendation`, `priority`, `created_at`) VALUES
(438, 12, 'Issue written warning', 'medium', '2026-03-15 21:28:31'),
(439, 12, 'Monitor uniform compliance', 'medium', '2026-03-15 21:28:31'),
(440, 12, 'Schedule follow-up meeting', 'medium', '2026-03-15 21:28:31'),
(441, 13, 'Remind student about dress code policies', 'medium', '2026-03-15 21:28:31'),
(442, 13, 'Monitor compliance for 2 weeks', 'medium', '2026-03-15 21:28:31'),
(443, 14, 'Remind student about dress code policies', 'medium', '2026-03-15 21:28:31'),
(444, 14, 'Monitor compliance for 2 weeks', 'medium', '2026-03-15 21:28:31'),
(445, 15, 'Remind student about dress code policies', 'medium', '2026-03-15 21:28:31'),
(446, 15, 'Monitor compliance for 2 weeks', 'medium', '2026-03-15 21:28:31'),
(447, 16, 'Remind student about dress code policies', 'medium', '2026-03-15 21:28:31'),
(448, 16, 'Monitor compliance for 2 weeks', 'medium', '2026-03-15 21:28:31'),
(449, 17, 'Issue written warning', 'medium', '2026-03-15 21:28:31'),
(450, 17, 'Monitor uniform compliance', 'medium', '2026-03-15 21:28:31'),
(451, 17, 'Schedule follow-up meeting', 'medium', '2026-03-15 21:28:31');

-- --------------------------------------------------------

--
-- Table structure for table `report_violations`
--

DROP TABLE IF EXISTS `report_violations`;
CREATE TABLE IF NOT EXISTS `report_violations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `report_id` int NOT NULL,
  `violation_id` int DEFAULT NULL,
  `violation_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `violation_level` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `violation_date` date NOT NULL,
  `violation_time` time DEFAULT NULL,
  `status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_report_id` (`report_id`),
  KEY `idx_violation_id` (`violation_id`),
  KEY `idx_violation_date` (`violation_date`)
) ENGINE=InnoDB AUTO_INCREMENT=327 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `report_violations`
--

INSERT INTO `report_violations` (`id`, `report_id`, `violation_id`, `violation_type`, `violation_level`, `violation_date`, `violation_time`, `status`, `notes`, `created_at`) VALUES
(311, 17, 97, 'Improper Footwear', 'Permitted 1', '2026-03-08', '11:14:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(312, 12, 97, 'Improper Footwear', 'Permitted 1', '2026-03-08', '11:14:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(313, 17, 98, 'Improper Footwear', 'Permitted 2', '2026-03-08', '12:16:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(314, 12, 98, 'Improper Footwear', 'Permitted 2', '2026-03-08', '12:16:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(315, 17, 99, 'Improper Uniform', 'Permitted 1', '2026-03-08', '12:26:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(316, 12, 99, 'Improper Uniform', 'Permitted 1', '2026-03-08', '12:26:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(317, 17, 100, 'No ID', 'Permitted 1', '2026-03-08', '12:31:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(318, 12, 100, 'No ID', 'Permitted 1', '2026-03-08', '12:31:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(319, 16, 101, 'Improper Footwear', 'Permitted 1', '2026-03-11', '20:03:00', 'permitted', 'not wearing proper uniform', '2026-03-15 21:28:31'),
(320, 13, 101, 'Improper Footwear', 'Permitted 1', '2026-03-11', '20:03:00', 'permitted', 'not wearing proper uniform', '2026-03-15 21:28:31'),
(321, 16, 102, 'Improper Footwear', 'Permitted 2', '2026-03-11', '23:02:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(322, 13, 102, 'Improper Footwear', 'Permitted 2', '2026-03-11', '23:02:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(323, 15, 103, 'Improper Footwear', 'Permitted 1', '2026-03-12', '09:12:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(324, 14, 103, 'Improper Footwear', 'Permitted 1', '2026-03-12', '09:12:00', 'permitted', NULL, '2026-03-15 21:28:31'),
(325, 15, 104, 'Improper Footwear', 'Permitted 2', '2026-03-12', '10:43:00', 'permitted', 'Matigas an ulo', '2026-03-15 21:28:31'),
(326, 14, 104, 'Improper Footwear', 'Permitted 2', '2026-03-12', '10:43:00', 'permitted', 'Matigas an ulo', '2026-03-15 21:28:31');

-- --------------------------------------------------------

--
-- Table structure for table `sections`
--

DROP TABLE IF EXISTS `sections`;
CREATE TABLE IF NOT EXISTS `sections` (
  `id` int NOT NULL AUTO_INCREMENT,
  `section_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `section_code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `department_id` int NOT NULL,
  `academic_year` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('active','archived') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `section_code` (`section_code`),
  KEY `department_id` (`department_id`),
  KEY `status` (`status`)
) ENGINE=InnoDB AUTO_INCREMENT=44 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sections`
--

INSERT INTO `sections` (`id`, `section_name`, `section_code`, `department_id`, `academic_year`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'BTVTED-WFT1', 'BTVTED-WFT1', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(2, 'BTVTED-CHS1', 'BTVTED-CHS1', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(3, 'BPA1', 'BPA1', 2, '2023-2026', 'active', '2026-02-22 22:29:58', '2026-03-12 09:51:39', NULL),
(4, 'BSIS1', 'BSIS1', 3, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(5, 'BTVTED-WFT2', 'BTVTED-WFT2', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(6, 'BTVTED-CHS2', 'BTVTED-CHS2', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(7, 'BPA2', 'BPA2', 2, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(8, 'BSIS2', 'BSIS2', 3, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(9, 'BTVTED-CHS3', 'BTVTED-CHS3', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(10, 'BTVTED-WFT3', 'BTVTED-WFT3', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(11, 'BPA3', 'BPA3', 2, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(12, 'BSIS3', 'BSIS3', 3, '2024-2025', 'active', '2026-02-22 22:29:58', '2026-03-15 16:05:41', NULL),
(13, 'BTVTED-CHS4', 'BTVTED-CHS4', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(14, 'BTVTED-WFT4', 'BTVTED-WFT4', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `settings`
--

DROP TABLE IF EXISTS `settings`;
CREATE TABLE IF NOT EXISTS `settings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `setting_value` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `setting_type` enum('string','integer','boolean','json') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'string',
  `category` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'general',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `is_public` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `setting_key` (`setting_key`),
  UNIQUE KEY `unique_setting_key` (`setting_key`),
  KEY `idx_category` (`category`),
  KEY `idx_is_public` (`is_public`)
) ENGINE=InnoDB AUTO_INCREMENT=37 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `settings`
--

INSERT INTO `settings` (`id`, `setting_key`, `setting_value`, `setting_type`, `category`, `description`, `is_public`, `created_at`, `updated_at`) VALUES
(1, 'system_name', 'OSAS System', 'string', 'general', 'System name displayed in the application', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(2, 'system_email', 'osas@school.edu', 'string', 'general', 'System email address for notifications', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(3, 'system_phone', '+63 912 345 6789', 'string', 'general', 'System contact phone number', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(4, 'system_address', 'School Address', 'string', 'general', 'System physical address', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(5, 'timezone', 'Asia/Manila', 'string', 'general', 'System timezone', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(6, 'date_format', 'Y-m-d', 'string', 'general', 'Date format for display', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(7, 'time_format', 'H:i:s', 'string', 'general', 'Time format for display', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(8, 'items_per_page', '10', 'integer', 'general', 'Number of items per page in tables', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(9, 'enable_notifications', '1', 'boolean', 'notifications', 'Enable system notifications', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(10, 'email_notifications', '1', 'boolean', 'notifications', 'Enable email notifications', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(11, 'sms_notifications', '0', 'boolean', 'notifications', 'Enable SMS notifications', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(12, 'violation_auto_escalate', '1', 'boolean', 'violations', 'Automatically escalate violations after warnings', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(13, 'violation_warning_limit', '3', 'integer', 'violations', 'Number of warnings before disciplinary action', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(14, 'violation_reminder_days', '7', 'integer', 'violations', 'Days before sending violation reminder', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(15, 'report_auto_generate', '0', 'boolean', 'reports', 'Automatically generate reports daily', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(16, 'report_retention_days', '365', 'integer', 'reports', 'Number of days to retain reports', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(17, 'session_timeout', '30', 'integer', 'security', 'Session timeout in minutes', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(18, 'password_min_length', '8', 'integer', 'security', 'Minimum password length', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(19, 'password_require_uppercase', '1', 'boolean', 'security', 'Require uppercase letter in password', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(20, 'password_require_lowercase', '1', 'boolean', 'security', 'Require lowercase letter in password', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(21, 'password_require_number', '1', 'boolean', 'security', 'Require number in password', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(22, 'password_require_special', '0', 'boolean', 'security', 'Require special character in password', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(23, 'login_attempts_limit', '5', 'integer', 'security', 'Maximum login attempts before lockout', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(24, 'lockout_duration', '15', 'integer', 'security', 'Account lockout duration in minutes', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(25, 'enable_2fa', '0', 'boolean', 'security', 'Enable two-factor authentication', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(26, 'maintenance_mode', '0', 'boolean', 'system', 'Enable maintenance mode', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(27, 'maintenance_message', 'System is under maintenance. Please check back later.', 'string', 'system', 'Maintenance mode message', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(28, 'backup_enabled', '1', 'boolean', 'system', 'Enable automatic backups', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(29, 'backup_frequency', 'daily', 'string', 'system', 'Backup frequency (daily, weekly, monthly)', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(30, 'backup_retention', '30', 'integer', 'system', 'Number of backups to retain', 0, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(31, 'theme_default', 'light', 'string', 'appearance', 'Default theme (light, dark, auto)', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(32, 'logo_url', '', 'string', 'appearance', 'System logo URL', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(33, 'favicon_url', '', 'string', 'appearance', 'Favicon URL', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(34, 'primary_color', '#000000', 'string', 'appearance', 'Primary color (gold)', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(35, 'secondary_color', '#E3E3E3', 'string', 'appearance', 'Secondary color', 1, '2026-01-08 11:39:32', '2026-01-09 02:02:39'),
(36, 'last_monthly_reset', '2026-03', 'string', 'system', 'Last month when the violations were archived', 0, '2026-02-15 11:26:48', '2026-03-01 12:19:33');

-- --------------------------------------------------------

--
-- Table structure for table `students`
--

DROP TABLE IF EXISTS `students`;
CREATE TABLE IF NOT EXISTS `students` (
  `id` int NOT NULL AUTO_INCREMENT,
  `student_id` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `middle_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `gender` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `contact_number` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `department` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `section_id` int DEFAULT NULL,
  `yearlevel` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `year_level` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '1st Year',
  `avatar` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('active','inactive','graduating','archived') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `student_id` (`student_id`),
  UNIQUE KEY `email` (`email`),
  KEY `section_id` (`section_id`),
  KEY `status` (`status`),
  KEY `department` (`department`),
  KEY `idx_students_year_level` (`year_level`)
) ENGINE=InnoDB AUTO_INCREMENT=537 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `students`
--

INSERT INTO `students` (`id`, `student_id`, `first_name`, `middle_name`, `last_name`, `gender`, `email`, `contact_number`, `address`, `department`, `section_id`, `yearlevel`, `year_level`, `avatar`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, '2025-0760', 'Jerlyn', 'M', 'Aday', 'F', 'jerlyn.aday@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:34', '2026-03-16 18:47:16', NULL),
(2, '2025-0812', 'Althea Nicole Shane', 'M', 'Dudas', 'F', 'altheanicoleshane.dudas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:16', NULL),
(3, '2025-0631', 'Jasmine', 'H', 'Gelena', 'F', 'jasmine.gelena@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(4, '2025-0714', 'Kyla', 'M', 'Jacob', 'F', 'kyla.jacob@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(5, '2025-0706', 'Kylyn', 'M', 'Jacob', 'F', 'kylyn.jacob@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(6, '2025-0607', 'Amaya', 'C', 'Mañibo', 'F', 'amaya.maibo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(7, '2025-0704', 'Keana', 'G', 'Marquinez', 'F', 'keana.marquinez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(8, '2025-0792', 'Ashley', 'A', 'Mendoza', 'F', 'ashley.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(9, '2025-0761', 'Ana Marie', 'A', 'Quimora', 'F', 'anamarie.quimora@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(10, '2025-0707', 'Camille', 'M', 'Tordecilla', 'F', 'camille.tordecilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(11, '2025-0630', 'Jonalyn', 'H', 'Untalan', 'F', 'jonalyn.untalan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(12, '2025-0810', 'Lyra Mae', 'M', 'Villanueva', 'F', 'lyramae.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:17', NULL),
(13, '2025-0608', 'Rhaizza', 'D', 'Villanueva', 'F', 'rhaizza.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:35', '2026-03-16 18:47:18', NULL),
(14, '2025-0687', 'John Philip Montillana', '', 'Batarlo', 'M', 'johnphilipmontillana.batarlo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(15, '2025-0807', 'Ace Romar', 'B', 'Castillo', 'M', 'aceromar.castillo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(16, '2025-0773', 'John Lloyd', 'B', 'Castillo', 'M', 'johnlloyd.castillo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(17, '2025-0616', 'Jericho', 'M', 'Del Mundo', 'M', 'jericho.delmundo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(18, '2025-0799', 'Khyn', 'C', 'Delos Reyes', 'M', 'khyn.delosreyes@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(19, '2025-0604', 'Gian Dominic Riza', '', 'Dudas', 'M', 'giandominicriza.dudas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(20, '2025-0703', 'Mark Neil', 'V', 'Fajil', 'M', 'markneil.fajil@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(21, '2025-0602', 'Mark Angelo Riza', '', 'Francisco', 'M', 'markangeloriza.francisco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(22, '2025-0363', 'Jhake Perillo', '', 'Garan', 'M', 'jhakeperillo.garan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(23, '2025-0593', 'Jared', '', 'Gasic', 'M', 'jared.gasic@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:18', NULL),
(24, '2025-0603', 'Bobby Jr.', 'M', 'Godoy', 'M', 'bobbyjr.godoy@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:19', NULL),
(25, '2025-0795', 'Edward John', 'S', 'Holgado', 'M', 'edwardjohn.holgado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:19', NULL),
(26, '2025-0794', 'Jaypee', 'G', 'Jacob', 'M', 'jaypee.jacob@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:36', '2026-03-16 18:47:19', NULL),
(27, '2025-0746', 'Jhon Loyd', 'D', 'Macapuno', 'M', 'jhonloyd.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:19', NULL),
(28, '2025-0672', 'Paul Tristan', 'V', 'Madla', 'M', 'paultristan.madla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:19', NULL),
(29, '2025-0594', 'Marlex', 'L', 'Mendoza', 'M', 'marlex.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:19', NULL),
(30, '2025-0649', 'Ron-Ron', '', 'Montero', 'M', 'ronron.montero@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:19', NULL),
(31, '2025-0757', 'Sandy', 'M', 'Laylay', 'F', 'johnlord.moreno@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:21', NULL),
(32, '2025-0686', 'Johnwin', 'A', 'Pastor', 'M', 'johnwin.pastor@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:19', NULL),
(33, '2025-0606', 'Jhon Jake', '', 'Perez', 'M', 'jhonjake.perez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:19', NULL),
(34, '2025-0692', 'John Kenneth', '', 'Perez', 'M', 'johnkenneth.perez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:19', NULL),
(35, '2025-0534', 'Khim', 'M', 'Tejada', 'M', 'khim.tejada@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:20', NULL),
(36, '2025-0784', 'Mary Ann', 'B', 'Asi', 'F', 'maryann.asi@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:20', NULL),
(37, '2025-0797', 'Marydith', 'L', 'Atienza', 'F', 'marydith.atienza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:20', NULL),
(38, '2025-0745', 'Charisma', 'M', 'Banila', 'F', 'charisma.banila@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:20', NULL),
(39, '2025-0658', 'Myka', 'S', 'Braza', 'F', 'myka.braza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:37', '2026-03-16 18:47:20', NULL),
(40, '2025-0676', 'Rhealyne', 'C', 'Cardona', 'F', 'rhealyne.cardona@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:20', NULL),
(41, '2025-0758', 'Danica Bea', 'T', 'Castillo', 'F', 'danicabea.castillo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:20', NULL),
(42, '2025-0793', 'Marra Jane', 'V', 'Cleofe', 'F', 'marrajane.cleofe@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:20', NULL),
(43, '2025-0637', 'Jocelyn', 'T', 'De Guzman', 'F', 'jocelyn.deguzman@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:20', NULL),
(44, '2025-0790', 'Anna Nicole', '', 'De Leon', 'F', 'annanicole.deleon@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:20', NULL),
(45, '2025-0778', 'Shane', 'M', 'Dudas', 'F', 'shane.dudas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:20', NULL),
(46, '2025-0754', 'Analyn', 'M', 'Fajardo', 'F', 'analyn.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:21', NULL),
(47, '2025-0668', 'Zean Dane', 'A', 'Falcutila', 'F', 'zeandane.falcutila@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:21', NULL),
(48, '2025-0755', 'Sharmaine', 'G', 'Fonte', 'F', 'sharmaine.fonte@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:21', NULL),
(49, '2025-0756', 'Crystal', 'E', 'Gagote', 'F', 'crystal.gagote@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:21', NULL),
(50, '2025-0667', 'Janel', 'M', 'Garcia', 'F', 'janel.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:21', NULL),
(51, '2025-0800', 'Aleah', 'G', 'Gida', 'F', 'aleah.gida@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:21', NULL),
(52, '2025-0786', 'Bhea Jane', 'Y', 'Gillado', 'F', 'bheajane.gillado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:38', '2026-03-16 18:47:21', NULL),
(53, '2025-0805', 'Mae', 'M', 'Hernandez', 'F', 'mae.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:21', NULL),
(54, '2025-0656', 'Arian Bello', '', 'Maculit', 'F', 'arianbello.maculit@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:21', NULL),
(55, '2025-0771', 'Mikee', 'M', 'Manay', 'F', 'mikee.manay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:21', NULL),
(56, '2025-0763', 'Lorain B', '', 'Medina', 'F', 'lorainb.medina@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:22', NULL),
(57, '2025-0767', 'Lovely Joy', 'A', 'Mercado', 'F', 'lovelyjoy.mercado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:22', NULL),
(58, '2025-0772', 'Romelyn', 'M', 'Mongcog', 'F', 'romelyn.mongcog@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:22', NULL),
(59, '2025-0699', 'Lleyn Angela', 'J', 'Olympia', 'F', 'lleynangela.olympia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:22', NULL),
(60, '2025-0766', 'Althea', 'A', 'Paala', 'F', 'althea.paala@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:22', NULL),
(61, '2025-0770', 'Ivy Kristine', 'A', 'Petilo', 'F', 'ivykristine.petilo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:22', NULL),
(62, '2025-0789', 'Irish Catherine', 'M', 'Ramos', 'F', 'irishcatherine.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:22', NULL),
(63, '2025-0796', 'Rubilyn', 'V', 'Roxas', 'F', 'rubilyn.roxas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:39', '2026-03-16 18:47:22', NULL),
(64, '2025-0718', 'Marie Bernadette', 'S', 'Tolentino', 'F', 'mariebernadette.tolentino@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:22', NULL),
(65, '2025-0643', 'Wyncel', 'A', 'Tolentino', 'F', 'wyncel.tolentino@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:22', NULL),
(66, '2025-0629', 'Felicity', 'O', 'Villegas', 'F', 'felicity.villegas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:22', NULL),
(67, '2025-0705', 'Danilo R. Jr', '', 'Cabiles', 'M', 'danilorjr.cabiles@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:23', NULL),
(68, '2025-0726', 'Aldrin', 'L', 'Carable', 'M', 'aldrin.carable@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:23', NULL),
(69, '2025-0743', 'Daniel', 'A', 'Franco', 'M', 'daniel.franco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:23', NULL),
(70, '2025-0636', 'Jarred', 'L', 'Gomez', 'M', 'jarred.gomez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:23', NULL),
(71, '2025-0785', 'James Andrei', 'D', 'Fajardo', 'M', 'jairus.macuha@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:27', NULL),
(72, '2025-0801', 'Mel Gabriel', 'N', 'Magat', 'M', 'melgabriel.magat@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:23', NULL),
(73, '2025-0762', 'Erwin', 'M', 'Tejedor', 'M', 'erwin.tejedor@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:23', NULL),
(74, '2025-0747', 'Jaydie A', '', 'Fabiano', 'F', 'brixmatthew.velasco@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:28', NULL),
(75, '2025-0617', 'K-Ann', 'E', 'Abela', 'F', 'kann.abela@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:23', NULL),
(76, '2025-0733', 'Shane Ashley', 'C', 'Abendan', 'F', 'shaneashley.abendan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:40', '2026-03-16 18:47:23', NULL),
(77, '2025-0619', 'Hanna', 'N', 'Aborde', 'F', 'hanna.aborde@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:23', NULL),
(78, '2025-0765', 'Rysa Mae', 'G', 'Alfante', 'F', 'rysamae.alfante@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(79, '2025-0809', 'Jeny', 'M', 'Amado', 'F', 'jeny.amado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(80, '2025-0680', 'Jonah Trisha', 'D', 'Asi', 'F', 'jonahtrisha.asi@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(81, '2025-0646', 'Jhovelyn', 'G', 'Bacay', 'F', 'jhovelyn.bacay@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(82, '2025-0679', 'Alexa Jane', '', 'Bon', 'F', 'alexajane.bon@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(83, '2025-0783', 'Lorraine', 'D', 'Bonado', 'F', 'lorraine.bonado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(84, '2025-0638', 'Shiella Mae', 'A', 'Bonifacio', 'F', 'shiellamae.bonifacio@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(85, '2025-0711', 'Claren', 'I', 'Carable', 'F', 'claren.carable@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(86, '2025-0727', 'Prences Angel', 'L', 'Consigo', 'F', 'prencesangel.consigo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(87, '2025-0742', 'Jamhyca', 'C', 'De Chavez', 'F', 'jamhyca.dechavez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(88, '2025-0673', 'Nicole', 'P', 'Defeo', 'F', 'nicole.defeo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(89, '2025-0722', 'Sophia Angela', 'M', 'Delos Reyes', 'F', 'sophiaangela.delosreyes@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:24', NULL),
(90, '2025-0612', 'Romelyn', '', 'Elida', 'F', 'romelyn.elida@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:41', '2026-03-16 18:47:25', NULL),
(91, '2025-0611', 'Christina Sofia Lie', 'D', 'Enriquez', 'F', 'christinasofialie.enriquez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(92, '2025-0688', 'Elayca Mae', 'E', 'Fajardo', 'F', 'elaycamae.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(93, '2025-0657', 'Ailla', 'F', 'Fajura', 'F', 'ailla.fajura@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(94, '2025-0618', 'Judith', 'B', 'Fallarna', 'F', 'judith.fallarna@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(95, '2025-0654', 'Jenelyn', 'R', 'Fonte', 'F', 'jenelyn.fonte@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(96, '2025-0713', 'Katrice', 'I', 'Garcia', 'F', 'katrice.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(97, '2025-0737', 'Shalemar', 'M', 'Geroleo', 'F', 'shalemar.geroleo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(98, '2025-0655', 'Edlyn', 'M', 'Hernandez', 'F', 'edlyn.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(99, '2025-0633', 'Angela', 'T', 'Lotho', 'F', 'angela.lotho@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(100, '2025-0808', 'Remz Ann Escarlet', 'G', 'Macapuno', 'F', 'remzannescarlet.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(101, '2025-0609', 'Leslie', 'B', 'Melgar', 'F', 'leslie.melgar@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:25', NULL),
(102, '2025-0729', 'Camille', 'B', 'Milambiling', 'F', 'camille.milambiling@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:42', '2026-03-16 18:47:26', NULL),
(103, '2025-0710', 'Erica Mae', 'B', 'Motol', 'F', 'ericamae.motol@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(104, '2025-0728', 'Ma. Teresa', 'S', 'Obando', 'F', 'materesa.obando@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(105, '2025-0647', 'Argel', 'B', 'Ocampo', 'F', 'argel.ocampo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(106, '2025-0779', 'Jea Francine', '', 'Rivera', 'F', 'jeafrancine.rivera@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(107, '2025-0788', 'Ashly Nicole', '', 'Rana', 'F', 'ashlynicole.rana@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(108, '2025-0741', 'Aimie Jane', 'M', 'Reyes', 'F', 'aimiejane.reyes@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(109, '2025-0734', 'Rhenelyn', 'A', 'Sandoval', 'F', 'rhenelyn.sandoval@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(110, '2025-0777', 'Nicole', 'S', 'Silva', 'F', 'nicole.silva@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(111, '2025-0731', 'Jeane', 'T', 'Sulit', 'F', 'jeane.sulit@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(112, '2025-0723', 'Pauleen', 'H', 'Villaruel', 'F', 'pauleen.villaruel@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(113, '2025-0806', 'Megan Michaela', 'M', 'Visaya', 'F', 'meganmichaela.visaya@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:26', NULL),
(114, '2025-0684', 'Rodel', '', 'Arenas', 'M', 'rodel.arenas@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:43', '2026-03-16 18:47:27', NULL),
(115, '2025-0690', 'Rexner', 'M', 'Eguillon', 'M', 'rexner.eguillon@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(116, '2025-0815', 'Aldrin', 'J', 'Bueno', 'M', 'reymart.elmido@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:35', NULL),
(117, '2025-0627', 'Kervin', 'B', 'Garachico', 'M', 'kervin.garachico@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(118, '2025-0865', 'Zyris', 'A', 'Guavez', 'M', 'zyris.guavez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(119, '2025-0740', 'Marjun A', '', 'Linayao', 'M', 'marjuna.linayao@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(120, '2025-0660', 'John Lloyd', '', 'Macapuno', 'M', 'johnlloyd.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(121, '2025-0732', 'Helbert', 'F', 'Maulion', 'M', 'helbert.maulion@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(122, '2025-0645', 'Dindo', 'S', 'Tolentino', 'M', 'dindo.tolentino@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(123, '2025-0621', 'Novelyn', 'D', 'Albufera', 'F', 'novelyn.albufera@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(124, '2025-0775', 'Angela', 'F', 'Aldea', 'F', 'angela.aldea@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:27', NULL),
(125, '2025-0601', 'Maria Fe', 'C', 'Aldovino', 'F', 'mariafe.aldovino@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:28', NULL),
(126, '2025-0661', 'Aizel', 'M', 'Alvarez', 'F', 'aizel.alvarez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:44', '2026-03-16 18:47:28', NULL),
(127, '2025-0752', 'Sherilyn', 'T', 'Anyayahan', 'F', 'sherilyn.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(128, '2025-0623', 'Mika Dean', '', 'Buadilla', 'F', 'mikadean.buadilla@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(129, '2025-0669', 'Daniela Faye', '', 'Cabiles', 'F', 'danielafaye.cabiles@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(130, '2025-0599', 'Prinses Gabriela', 'Q', 'Calaolao', 'F', 'prinsesgabriela.calaolao@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(131, '2025-0719', 'Deah Angella S', '', 'Carpo', 'F', 'deahangellas.carpo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(132, '2025-0802', 'Jedidiah', 'C', 'Gelena', 'F', 'jedidiah.gelena@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(133, '2025-0664', 'Aleyah Janelle', 'B', 'Jara', 'F', 'aleyahjanelle.jara@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(134, '2025-0720', 'Charese', 'M', 'Jolo', 'F', 'charese.jolo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(135, '2025-0682', 'Janice', 'G', 'Lugatic', 'F', 'janice.lugatic@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:28', NULL),
(136, '2025-0739', 'Abegail', '', 'Malogueño', 'F', 'abegail.malogueo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:29', NULL),
(137, '2025-0708', 'Ericca', 'A', 'Marquez', 'F', 'ericca.marquez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:29', NULL),
(138, '2025-0748', 'Arien', 'M', 'Montesa', 'F', 'arien.montesa@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:45', '2026-03-16 18:47:29', NULL),
(139, '2025-0653', 'Jasmine', 'Q', 'Nuestro', 'F', 'jasmine.nuestro@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:29', NULL),
(140, '2025-0738', 'Nicole', 'G', 'Ola', 'F', 'nicole.ola@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:29', NULL),
(141, '2025-0628', 'Alyssa Mae', 'M', 'Quintia', 'F', 'alyssamae.quintia@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:29', NULL),
(142, '2025-0774', 'Jona Marie', 'G', 'Romero', 'F', 'jonamarie.romero@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:29', NULL),
(143, '2025-0634', 'Marbhel', 'H', 'Rucio', 'F', 'marbhel.rucio@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:29', NULL),
(144, '2025-0814', 'Lovely', 'K', 'Torres', 'F', 'lovely.torres@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:29', NULL),
(145, '2025-0620', 'Rexon', 'E', 'Abanilla', 'M', 'rexon.abanilla@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:29', NULL),
(146, '2025-0791', 'Ramfel', 'H', 'Azucena', 'M', 'ramfel.azucena@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:29', NULL),
(147, '2025-0632', 'Jeverson', 'M', 'Bersoto', 'M', 'jeverson.bersoto@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:30', NULL),
(148, '2025-0626', 'Shervin Jeral', 'M', 'Castro', 'M', 'shervinjeral.castro@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:30', NULL),
(149, '2025-0652', 'Daniel', 'D', 'De Ade', 'M', 'daniel.deade@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:30', NULL),
(150, '2025-0782', 'Dave Ruzzele', 'D', 'Despa', 'M', 'daveruzzele.despa@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:30', NULL),
(151, '2025-0696', 'Alexander', 'R', 'Ducado', 'M', 'alexander.ducado@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:46', '2026-03-16 18:47:30', NULL),
(152, '2025-0595', 'Uranus', 'R', 'Evangelista', 'M', 'uranus.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:30', NULL),
(153, '2025-0697', 'Joshua', 'M', 'Gabon', 'M', 'joshua.gabon@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:30', NULL),
(154, '2025-0681', 'John Andrew', 'R', 'Gavilan', 'M', 'johnandrew.gavilan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:30', NULL),
(155, '2025-0715', 'Mc Lenard', 'A', 'Gibo', 'M', 'mclenard.gibo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:30', NULL),
(156, '2025-0716', 'Dan Kian', 'A', 'Hatulan', 'M', 'dankian.hatulan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:30', NULL),
(157, '2025-0803', 'Benjamin Jr. D', '', 'Hernandez', 'M', 'benjaminjrd.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:31', NULL),
(158, '2025-0753', 'Renz', 'F', 'Hernandez', 'M', 'renz.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:31', NULL),
(159, '2025-0662', 'Ralph Adriane', 'D', 'Javier', 'M', 'ralphadriane.javier@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:31', NULL),
(160, '2025-0598', 'Andrew', 'M', 'Laredo', 'M', 'andrew.laredo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:31', NULL),
(161, '2025-0663', 'Janryx', 'S', 'Las Pinas', 'M', 'janryx.laspinas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:31', NULL),
(162, '2025-0735', 'Bricks', 'M', 'Lindero', 'M', 'bricks.lindero@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:31', NULL),
(163, '2025-0639', 'Luigi', 'B', 'Lomio', 'M', 'luigi.lomio@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:47', '2026-03-16 18:47:31', NULL),
(164, '2025-0596', 'John Lemuel', 'O', 'Macalindol', 'M', 'johnlemuel.macalindol@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:31', NULL),
(165, '2025-0781', 'Jandy', 'S', 'Macapuno', 'M', 'jandy.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:32', NULL),
(166, '2025-0693', 'Cedrick', 'M', 'Mandia', 'M', 'cedrick.mandia@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:32', NULL),
(167, '2025-0650', 'Eric John', 'C', 'Marinduque', 'M', 'ericjohn.marinduque@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:32', NULL),
(168, '2025-0730', 'Jimrex', 'M', 'Mayano', 'M', 'jimrex.mayano@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:32', NULL),
(169, '2025-0624', 'Hedyen', 'C', 'Mendoza', 'M', 'hedyen.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:32', NULL),
(170, '2025-0625', 'Mark Angelo', 'E', 'Montevirgen', 'M', 'markangelo.montevirgen@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:32', NULL),
(171, '2025-0651', 'JM', 'B', 'Nas', 'M', 'jm.nas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:32', NULL),
(172, '2025-0725', 'Vhon Jerick O', '', 'Ornos', 'M', 'vhonjericko.ornos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:32', NULL),
(173, '2025-0659', 'Carl Justine', 'D', 'Padua', 'M', 'carljustine.padua@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:33', NULL),
(174, '2025-0600', 'Patrick Lanz', '', 'Paz', 'M', 'patricklanz.paz@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:33', NULL),
(175, '2025-0622', 'Mark Justin', 'C', 'Pecolados', 'M', 'markjustin.pecolados@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:33', NULL),
(176, '2025-0764', 'Tristan Jay', 'M', 'Plata', 'M', 'tristanjay.plata@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:48', '2026-03-16 18:47:33', NULL),
(177, '2025-0776', 'Jude Michael', '', 'Somera', 'M', 'judemichael.somera@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:33', NULL),
(178, '2025-0695', 'Philip Jhon', 'N', 'Tabor', 'M', 'philipjhon.tabor@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:33', NULL),
(179, '2025-0597', 'Ivan Lester', 'D', 'Ylagan', 'M', 'ivanlester.ylagan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:33', NULL),
(180, '2024-0513', 'Kiana Jane', 'P', 'Añonuevo', 'F', 'kianajane.aonuevo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:33', NULL),
(181, '2024-0514', 'Kyla', '', 'Anonuevo', 'F', 'kyla.anonuevo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:33', NULL),
(182, '2024-0569', 'Katrice', 'F', 'Antipasado', 'F', 'katrice.antipasado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:33', NULL),
(183, '2024-0591', 'Regine', '', 'Antipasado', 'F', 'regine.antipasado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:33', NULL),
(184, '2024-0550', 'Juneth', 'H', 'Baliday', 'F', 'juneth.baliday@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:33', NULL),
(185, '2024-0546', 'Gielysa', 'C', 'Concha', 'F', 'gielysa.concha@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:34', NULL),
(186, '2024-0506', 'Maecelle', 'V', 'Fiedalan', 'F', 'maecelle.fiedalan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:34', NULL),
(187, '2024-0508', 'Lara Mae', 'E', 'Garcia', 'F', 'laramae.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:34', NULL),
(188, '2024-0459', 'Jade', 'S', 'Garing', 'F', 'jade.garing@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:49', '2026-03-16 18:47:34', NULL),
(189, '2024-0446', 'Rica', 'D', 'Glodo', 'F', 'rica.glodo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:34', NULL),
(190, '2024-0549', 'Danica Mae', 'N', 'Hornilla', 'F', 'danicamae.hornilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:34', NULL),
(191, '2024-0473', 'Jenny', 'F', 'Idea', 'F', 'jenny.idea@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:34', NULL),
(192, '2024-0487', 'Roma', 'L', 'Mendoza', 'F', 'roma.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:34', NULL),
(193, '2024-0535', 'Evangeline', 'V', 'Mojica', 'F', 'evangeline.mojica@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:34', NULL),
(194, '2024-0570', 'Carla', 'G', 'Nineria', 'F', 'carla.nineria@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:34', NULL),
(195, '2024-0516', 'Kyla', 'G', 'Oliveria', 'F', 'kyla.oliveria@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:34', NULL),
(196, '2024-0457', 'Mikayla', 'M', 'Paala', 'F', 'mikayla.paala@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:34', NULL),
(197, '2024-0442', 'Necilyn', 'B', 'Ramos', 'F', 'necilyn.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:35', NULL),
(198, '2024-0469', 'Mischell', 'U', 'Velasquez', 'F', 'mischell.velasquez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:35', NULL),
(199, '2024-0539', 'Emerson', 'M', 'Adarlo', 'M', 'emerson.adarlo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:35', NULL),
(200, '2024-0491', 'Shim Andrian', 'L', 'Adarlo', 'M', 'shimandrian.adarlo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:50', '2026-03-16 18:47:35', NULL),
(201, '2024-0485', 'Cedrick', 'C', 'Cardova', 'M', 'cedrick.cardova@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:35', NULL),
(202, '2024-0477', 'John Paul', 'M', 'De Lemos', 'M', 'johnpaul.delemos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:35', NULL),
(203, '2024-0489', 'Reymar', 'G', 'Faeldonia', 'M', 'reymar.faeldonia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:35', NULL),
(204, '2024-0500', 'John Ray', 'A', 'Fegidero', 'M', 'johnray.fegidero@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:35', NULL),
(205, '2024-0488', 'John Lester', 'C', 'Gaba', 'M', 'johnlester.gaba@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:35', NULL),
(206, '2024-0475', 'Antonio Gabriel', 'A', 'Francisco', 'M', 'antoniogabriel.francisco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:35', NULL),
(207, '2024-0345', 'karl Andrew', 'R', 'Hardin', 'M', 'karlandrew.hardin@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:35', NULL),
(208, '2024-0499', 'Prince', 'L', 'Geneta', 'M', 'prince.geneta@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:36', NULL),
(209, '2024-0495', 'John Reign', 'A', 'Laredo', 'M', 'johnreign.laredo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:36', NULL),
(210, '2024-0490', 'Mc Ryan', '', 'Masangkay', 'M', 'mcryan.masangkay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:36', NULL),
(211, '2025-0592', 'Aaron Vincent', 'R', 'Manalo', 'M', 'aaronvincent.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:36', NULL),
(212, '2024-0494', 'Great', 'B', 'Mendoza', 'M', 'great.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:36', NULL),
(213, '2024-0497', 'Jhon Marc', 'D', 'Oliveria', 'M', 'jhonmarc.oliveria@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:51', '2026-03-16 18:47:36', NULL),
(214, '2024-0455', 'Kevin', 'G', 'Rucio', 'M', 'kevin.rucio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:36', NULL),
(215, '2024-0445', 'Arhizza Sheena', 'R', 'Abanilla', 'F', 'arhizzasheena.abanilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:36', NULL),
(216, '2024-0503', 'Angelica', 'M', 'Cabello', 'F', 'carlaandrea.azucena@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:39', NULL),
(217, '2024-0548', 'Angel Ann', 'D', 'Fajardo', 'F', 'angel.cason@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:44', NULL),
(218, '2024-0461', 'KC May', 'A', 'De Guzman', 'F', 'kcmay.deguzman@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:36', NULL),
(219, '2024-0531', 'Francene', '', 'Delos Santos', 'F', 'francene.delossantos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:36', NULL),
(220, '2024-0470', 'Shane Ayessa', 'L', 'Elio', 'F', 'shaneayessa.elio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:37', NULL),
(221, '2024-0502', 'Maria Angela', 'B', 'Garcia', 'F', 'mariaangela.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:37', NULL),
(222, '2024-0466', 'Shane Mary', 'C', 'Gardoce', 'F', 'shanemary.gardoce@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:37', NULL),
(223, '2024-0441', 'Janah', 'M', 'Glor', 'F', 'janah.glor@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:37', NULL),
(224, '2024-0476', 'Catherine', 'R', 'Gomez', 'F', 'catherine.gomez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:37', NULL),
(225, '2024-0554', 'April Joy', '', 'Llamoso', 'F', 'apriljoy.llamoso@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:37', NULL),
(226, '2024-0440', 'Irene', 'Y', 'Loto', 'F', 'irene.loto@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:52', '2026-03-16 18:47:37', NULL),
(227, '2024-0463', 'Angela', 'M', 'Lumanglas', 'F', 'angela.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:37', NULL),
(228, '2024-0464', 'Michelle Micah', 'M', 'Lumanglas', 'F', 'michellemicah.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:37', NULL),
(229, '2024-0545', 'Febelyn', 'M', 'Magboo', 'F', 'febelyn.magboo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:37', NULL),
(230, '2024-0458', 'Chelo Rose', 'P', 'Marasigan', 'F', 'chelorose.marasigan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:37', NULL),
(231, '2024-0456', 'Joana Marie', 'L', 'Paala', 'F', 'joanamarie.paala@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:37', NULL),
(232, '2024-0538', 'Maria Irene', 'T', 'Pasado', 'F', 'mariairene.pasado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:38', NULL),
(233, '2024-0563', 'Danica', '', 'Pederio', 'F', 'danica.pederio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:38', NULL),
(234, '2024-0444', 'Angela Clariss', 'P', 'Teves', 'F', 'angelaclariss.teves@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:38', NULL),
(235, '2024-0454', 'Zairene', 'R', 'Undaloc', 'F', 'zairene.undaloc@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:38', NULL),
(236, '2024-0449', 'John Ivan', 'P', 'Cuasay', 'M', 'johnivan.cuasay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:38', NULL),
(237, '2024-0505', 'Bert', 'B', 'Ferrera', 'M', 'bert.ferrera@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:38', NULL),
(238, '2024-0450', 'Rickson', 'C', 'Ferry', 'M', 'rickson.ferry@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:53', '2026-03-16 18:47:38', NULL),
(239, '2024-0555', 'John Mariol', 'L', 'Fransisco', 'M', 'johnmariol.fransisco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:38', NULL),
(240, '2024-0530', 'Allan', 'Y', 'Loto', 'M', 'allan.loto@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:38', NULL),
(241, '2024-0401', 'Jhon Kenneth', 'S', 'Obando', 'M', 'jhonkenneth.obando@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:38', NULL),
(242, '2024-0462', 'Rodel', 'T', 'Roldan', 'M', 'rodel.roldan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:38', NULL),
(243, '2024-0358', 'Ashlyn Kieth', 'V', 'Abanilla', 'F', 'ashlynkieth.abanilla@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:38', NULL),
(244, '2024-0352', 'Patricia Mae', 'M', 'Agoncillo', 'F', 'patriciamae.agoncillo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:39', NULL),
(245, '2024-0378', 'Benelyn', 'D', 'Aguho', 'F', 'benelyn.aguho@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:39', NULL),
(246, '2024-0504', 'Lynse', 'C', 'Albufera', 'F', 'lynse.albufera@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:39', NULL),
(247, '2024-0521', 'Lara Mae', 'M', 'Altamia', 'F', 'laramae.altamia@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:39', NULL),
(248, '2024-0379', 'Crislyn', 'M', 'Anyayahan', 'F', 'crislyn.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:39', NULL),
(249, '2024-0360', 'Rocel Liegh', 'L', 'Arañez', 'F', 'rocelliegh.araez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:39', NULL),
(250, '2024-0372', 'Katrice Allaine', 'A', 'Atienza', 'F', 'katriceallaine.atienza@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:39', NULL);
INSERT INTO `students` (`id`, `student_id`, `first_name`, `middle_name`, `last_name`, `gender`, `email`, `contact_number`, `address`, `department`, `section_id`, `yearlevel`, `year_level`, `avatar`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(251, '2024-0354', 'Maica', 'C', 'Bacal', 'F', 'maica.bacal@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:54', '2026-03-16 18:47:39', NULL),
(252, '2024-0347', 'Cherylyn', 'C', 'Bacsa', 'F', 'cherylyn.bacsa@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:39', NULL),
(253, '2024-0364', 'Realyn', 'M', 'Bercasi', 'F', 'realyn.bercasi@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:39', NULL),
(254, '2024-0355', 'Elyza', 'M', 'Buquis', 'F', 'elyza.buquis@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:39', NULL),
(255, '2024-0474', 'Kim Ashley Nicole', 'M', 'Caringal', 'F', 'kimashleynicole.caringal@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:40', NULL),
(256, '2024-0351', 'Shane', 'B', 'Dalisay', 'F', 'shane.dalisay@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:40', NULL),
(257, '2024-0369', 'Mariel', 'V', 'Delos Santos', 'F', 'mariel.delossantos@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:40', NULL),
(258, '2024-0520', 'Angel', 'G', 'Dimoampo', 'F', 'angel.dimoampo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:40', NULL),
(259, '2024-0374', 'Kristine', 'B', 'Dris', 'F', 'kristine.dris@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:40', NULL),
(260, '2024-0367', 'Rexlyn Joy', 'M', 'Eguillon', 'F', 'rexlynjoy.eguillon@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:40', NULL),
(261, '2024-0363', 'Maricar', 'A', 'Evangelista', 'F', 'maricar.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:40', NULL),
(262, '2024-0388', 'Chariz', 'M', 'Fajardo', 'F', 'chariz.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:55', '2026-03-16 18:47:40', NULL),
(263, '2024-0366', 'Hazel Ann', 'B', 'Feudo', 'F', 'hazelann.feudo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:40', NULL),
(264, '2024-0385', 'Marie Joy', 'C', 'Gado', 'F', 'mariejoy.gado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:40', NULL),
(265, '2024-0371', 'Leah', 'M', 'Galit', 'F', 'leah.galit@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:40', NULL),
(266, '2024-0507', 'Aiexa Danielle', 'A', 'Guira', 'F', 'aiexadanielle.guira@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:40', NULL),
(267, '2024-0375', 'Andrea Mae', 'M', 'Hernandez', 'F', 'andreamae.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:41', NULL),
(268, '2024-0501', 'Eslley Ann', 'T', 'Hernandez', 'F', 'eslleyann.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:41', NULL),
(269, '2024-0376', 'Jazleen', '', 'Llamoso', 'F', 'jazleen.llamoso@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:41', NULL),
(270, '2024-0368', 'Joan Kate', 'G', 'Lomio', 'F', 'joankate.lomio@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:41', NULL),
(271, '2024-0391', 'Kriselle Ann', 'T', 'Mabuti', 'F', 'kriselleann.mabuti@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:41', NULL),
(272, '2024-0387', 'Angel Rose', 'S', 'Mascarinas', 'F', 'angelrose.mascarinas@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:41', NULL),
(273, '2024-0587', 'Hannah', 'A', 'Melgar', 'F', 'hannah.melgar@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:56', '2026-03-16 18:47:41', NULL),
(274, '2024-0586', 'Rexy Mae', 'D', 'Mingo', 'F', 'rexymae.mingo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:41', NULL),
(275, '2024-0349', 'Precious Nicole', 'N', 'Moya', 'F', 'preciousnicole.moya@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:41', NULL),
(276, '2024-0377', 'Cherese Gelyn', 'C', 'Nao', 'F', 'cheresegelyn.nao@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:41', NULL),
(277, '2024-0384', 'Margie', 'N', 'Nuñez', 'F', 'margie.nuez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:41', NULL),
(278, '2024-0350', 'Hazel Ann', 'F', 'Panganiban', 'F', 'hazelann.panganiban@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:41', NULL),
(279, '2024-0568', 'Angela', '', 'Papasin', 'F', 'angela.papasin@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:42', NULL),
(280, '2024-0359', 'Jasmine', 'A', 'Prangue', 'F', 'jasmine.prangue@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:42', NULL),
(281, '2024-0380', 'Jeyzelle', 'G', 'Rellora', 'F', 'jeyzelle.rellora@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:42', NULL),
(282, '2024-0264', 'Katrina T', '', 'Rufino', 'F', 'katrinat.rufino@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:42', NULL),
(283, '2024-0382', 'Niña Zyrene', 'R', 'Sanchez', 'F', 'niazyrene.sanchez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:42', NULL),
(284, '2024-0509', 'Edcel Jane', 'B', 'Santillan', 'F', 'edceljane.santillan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:42', NULL),
(285, '2024-0451', 'Mary Joy', 'M', 'Sara', 'F', 'maryjoy.sara@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:57', '2026-03-16 18:47:42', NULL),
(286, '2024-0453', 'Cynthia', '', 'Torres', 'F', 'cynthia.torres@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:42', NULL),
(287, '2024-0556', 'Jolie', 'L', 'Tugmin', 'F', 'jolie.tugmin@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:42', NULL),
(288, '2024-0356', 'Lesley Ann', 'M', 'Villanueva', 'F', 'lesleyann.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:42', NULL),
(289, '2024-0365', 'Lany', 'G', 'Ylagan', 'F', 'lany.ylagan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:42', NULL),
(290, '2024-0373', 'Marvin', 'M', 'Caraig', 'M', 'marvin.caraig@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:43', NULL),
(291, '2024-0557', 'Denniel', 'C', 'Delos Santos', 'M', 'denniel.delossantos@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:43', NULL),
(292, '2024-0389', 'Alex', 'T', 'Magsisi', 'M', 'alex.magsisi@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:43', NULL),
(293, '2024-0525', 'Jan Carlo', 'G', 'Manalo', 'M', 'jancarlo.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:43', NULL),
(294, '2024-0386', 'AJ', 'M', 'Masangkay', 'M', 'aj.masangkay@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:43', NULL),
(295, '2024-0480', 'John Paul', 'M', 'Roldan', 'M', 'johnpaul.roldan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:43', NULL),
(296, '2024-0523', 'Ronald', '', 'Tañada', 'M', 'ronald.taada@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:58', '2026-03-16 18:47:43', NULL),
(297, '2024-0492', 'D-Jay', 'G', 'Teriompo', 'M', 'djay.teriompo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:43', NULL),
(298, '2025-0816', 'Marsha Lhee', 'G', 'Azucena', 'F', 'marshalhee.azucena@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:43', NULL),
(299, '2024-0438', 'Melsan', 'G', 'Aday', 'F', 'melsan.aday@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:43', NULL),
(300, '2024-0405', 'Jonice', 'P', 'Alturas', 'F', 'jonice.alturas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:43', NULL),
(301, '2024-0411', 'Precious', 'S', 'Apil', 'F', 'precious.apil@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:43', NULL),
(302, '2024-0418', 'Ludelyn', 'T', 'Belbes', 'F', 'ludelyn.belbes@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:44', NULL),
(303, '2024-0424', 'Princess Hazel', 'D', 'Cabasi', 'F', 'princesshazel.cabasi@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:44', NULL),
(304, '2024-0342', 'Charlaine', 'M', 'De Belen', 'F', 'charlaine.debelen@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:44', NULL),
(305, '2024-0437', 'Arjean Joy', 'S', 'De Castro', 'F', 'arjeanjoy.decastro@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:44', NULL),
(306, '2024-0343', 'Precious Cindy', 'G', 'De Guzman', 'F', 'preciouscindy.deguzman@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:44', NULL),
(307, '2024-0404', 'Marina', 'M', 'De Luzon', 'F', 'marina.deluzon@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:44', NULL),
(308, '2024-0417', 'Nesvita', 'V', 'Dorias', 'F', 'nesvita.dorias@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:29:59', '2026-03-16 18:47:44', NULL),
(309, '2024-0432', 'Stella Rey', 'A', 'Flores', 'F', 'stellarey.flores@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:00', '2026-03-16 18:47:44', NULL),
(310, '2024-0567', 'Arlene', 'S', 'Gaba', 'F', 'arlene.gaba@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:00', '2026-03-16 18:47:44', NULL),
(311, '2024-0422', 'Jay-Ann', 'G', 'Jamilla', 'F', 'jayann.jamilla@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:00', '2026-03-16 18:47:44', NULL),
(312, '2024-0416', 'Mikaela Joy', 'M', 'Layson', 'F', 'mikaelajoy.layson@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:00', '2026-03-16 18:47:44', NULL),
(313, '2024-0427', 'Christine Joy', 'A', 'Lomio', 'F', 'christinejoy.lomio@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:00', '2026-03-16 18:47:45', NULL),
(314, '2024-0544', 'Ariane', 'M', 'Magboo', 'F', 'ariane.magboo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:00', '2026-03-16 18:47:45', NULL),
(315, '2024-0415', 'Nerissa', 'R', 'Magsisi', 'F', 'nerissa.magsisi@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:00', '2026-03-16 18:47:45', NULL),
(316, '2024-0472', 'Keycel Joy', 'M', 'Manalo', 'F', 'keyceljoy.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:45', NULL),
(317, '2024-0412', 'Grace Cell', 'G', 'Manibo', 'F', 'gracecell.manibo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:45', NULL),
(318, '2024-0571', 'Lovelyn', 'A', 'Marcos', 'F', 'lovelyn.marcos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:45', NULL),
(319, '2024-0314', 'Shenna Marie', 'P', 'Obando', 'F', 'shennamarie.obando@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:45', NULL),
(320, '2024-0348', 'Myzell', 'U', 'Ramos', 'F', 'myzell.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:45', NULL),
(321, '2024-0582', 'Shella Mae', 'T', 'Ramos', 'F', 'shellamae.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:45', NULL),
(322, '2024-0426', 'Desiree', 'G', 'Raymundo', 'F', 'desiree.raymundo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:46', NULL),
(323, '2023-0433', 'Romelyn', 'A', 'Rocha', 'F', 'romelyn.rocha@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:46', NULL),
(324, '2023-0519', 'John Michael', '', 'Bacsa', 'M', 'johnmichael.bacsa@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:46', NULL),
(325, '2024-0043', 'John Kenneth Joseph', 'G', 'Balansag', 'M', 'johnkennethjoseph.balansag@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:46', NULL),
(326, '2024-0398', 'Raphael', 'M', 'Bugayong', 'M', 'raphael.bugayong@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:01', '2026-03-16 18:47:46', NULL),
(327, '2024-0572', 'Mark Jayson', 'D', 'Bunag', 'M', 'markjayson.bunag@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:46', NULL),
(328, '2024-0561', 'Alvin', 'M', 'Corona', 'M', 'alvin.corona@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:46', NULL),
(329, '2023-0407', 'Joseph', 'E', 'Elio', 'M', 'markjanssen.cueto@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:46', NULL),
(330, '2023-0447', 'Charles Darwin', 'S', 'Dimailig', 'M', 'charlesdarwin.dimailig@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:46', NULL),
(331, '2024-0413', 'Airon', 'R', 'Evangelista', 'M', 'airon.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:46', NULL),
(332, '2024-0517', 'Gino', 'L', 'Genabe', 'M', 'gino.genabe@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:47', NULL),
(333, '2024-0420', 'Miklo', 'M', 'Lumanglas', 'M', 'miklo.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:47', NULL),
(334, '2023-0151', 'Ramcil', 'M', 'Macapuno', 'M', 'ramcil.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:47', NULL),
(335, '2024-0395', 'Florence', 'R', 'Macalelong', 'M', 'florence.macalelong@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:47', NULL),
(336, '2023-0465', 'Patrick', 'T', 'Matanguihan', 'M', 'patrick.matanguihan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:47', NULL),
(337, '2024-0478', 'Dranzel', 'L', 'Miranda', 'M', 'dranzel.miranda@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:47', NULL),
(338, '2024-0394', 'Carlo', 'G', 'Mondragon', 'M', 'carlo.mondragon@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:02', '2026-03-16 18:47:47', NULL),
(339, '2024-0410', 'John Rexcel', 'E', 'Montianto', 'M', 'johnrexcel.montianto@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:47', NULL),
(340, '2024-0428', 'Christian', 'M', 'Moreno', 'M', 'christian.moreno@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:47', NULL),
(341, '2024-0393', 'Amiel Geronne', 'M', 'Pantua', 'M', 'amielgeronne.pantua@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:47', NULL),
(342, '2024-0392', 'James Lorence', 'C', 'Paradijas', 'M', 'jameslorence.paradijas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:47', NULL),
(343, '2024-0436', 'Jhezreel', 'P', 'Pastorfide', 'M', 'jhezreel.pastorfide@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:47', NULL),
(344, '2024-0578', 'Matt Raphael', 'G', 'Reyes', 'M', 'mattraphael.reyes@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:48', NULL),
(345, '2024-0580', 'Merwin', 'D', 'Santos', 'M', 'merwin.santos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:48', NULL),
(346, '2024-0423', 'Benjamin Jr.', 'D', 'Sarvida', 'M', 'benjaminjr.sarvida@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:48', NULL),
(347, '2024-0408', 'Jerus', 'B', 'Savariz', 'M', 'jerus.savariz@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:48', NULL),
(348, '2024-0406', 'Gerson', 'C', 'Urdanza', 'M', 'gerson.urdanza@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:48', NULL),
(349, '2024-0397', 'Jyrus', 'M', 'Ylagan', 'M', 'jyrus.ylagan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:48', NULL),
(350, '2023-0304', 'Jonah Rhyza', 'N', 'Anyayahan', 'F', 'jonahrhyza.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:03', '2026-03-16 18:47:48', NULL),
(351, '2023-0337', 'Leica', 'M', 'Banila', 'F', 'leica.banila@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:48', NULL),
(352, '2023-0327', 'Juvylyn', 'G', 'Basa', 'F', 'juvylyn.basa@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:48', NULL),
(353, '2022-0088', 'Rashele', 'M', 'Delgaco', '', 'rashele.delgaco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:48', NULL),
(354, '2023-0288', 'Cristal Jean', 'D', 'De Chusa', 'F', 'cristaljean.dechusa@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:48', NULL),
(355, '2023-0305', 'Jaime Elizabeth', 'L', 'Evora', 'F', 'jaimeelizabeth.evora@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:48', NULL),
(356, '2023-0317', 'Jeanlyn', 'B', 'Garcia', 'F', 'jeanlyn.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:49', NULL),
(357, '2023-0161', 'Baby Anh Marie', 'M', 'Godoy', 'F', 'babyanhmarie.godoy@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:49', NULL),
(358, '2023-0169', 'Herjane', 'F', 'Gozar', 'F', 'herjane.gozar@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:49', NULL),
(359, '2023-0200', 'Zyra', 'M', 'Gutierrez', 'F', 'zyra.gutierrez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:49', NULL),
(360, '2023-0251', 'Angielene', 'C', 'Landicho', 'F', 'angielene.landicho@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:49', NULL),
(361, '2023-0298', 'Laila', 'A', 'Limun', 'F', 'laila.limun@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:49', NULL),
(362, '2023-0244', 'Jennie Vee', 'P', 'Lopez', 'F', 'jennievee.lopez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:04', '2026-03-16 18:47:49', NULL),
(363, '2023-0215', 'Judy Ann', 'M', 'Madrigal', 'F', 'judyann.madrigal@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:49', NULL),
(364, '2023-0285', 'Maan', 'M', 'Masangkay', 'F', 'maan.masangkay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:49', NULL),
(365, '2023-0225', 'Genesis Mae', 'M', 'Mendoza', 'F', 'genesismae.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:49', NULL),
(366, '2023-0224', 'Marian', 'L', 'Mendoza', 'F', 'marian.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:49', NULL),
(367, '2023-0173', 'Lailin', 'S', 'Obando', 'F', 'lailin.obando@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:49', NULL),
(368, '2023-0303', 'Kyla', 'G', 'Rucio', 'F', 'kyla.rucio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:50', NULL),
(369, '2023-0241', 'Anthony', 'L', 'Sto. Niño', 'M', 'lyn.velasquez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:56', NULL),
(370, '2023-0336', 'Jhon Jerald', 'P', 'Acojedo', 'M', 'jhonjerald.acojedo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:50', NULL),
(371, '2023-0345', 'Sherwin', 'T', 'Calibot', 'M', 'sherwin.calibot@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:50', NULL),
(372, '2023-0233', 'Joriz Cezar', 'M', 'Collado', 'M', 'jorizcezar.collado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:50', NULL),
(373, '2023-1080', 'Mark Lee', 'C', 'Dalay', 'M', 'marklee.dalay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:50', NULL),
(374, '2023-0239', 'Adrian', 'C', 'Dilao', 'M', 'adrian.dilao@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:05', '2026-03-16 18:47:50', NULL),
(375, '2023-0167', 'Mc Lowell', 'F', 'Fabellon', 'M', 'mclowell.fabellon@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:50', NULL),
(376, '2023-0177', 'John Paul', 'M', 'Fernandez', 'M', 'johnpaul.fernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:50', NULL),
(377, '2023-0249', 'Mark Lyndon', 'L', 'Fransisco', 'M', 'marklyndon.fransisco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:50', NULL),
(378, '2023-0243', 'Princess Elaine', 'A', 'De Torres', 'F', 'kianvash.gale@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:56', NULL),
(379, '2023-0332', 'Michael', 'B', 'Magat', 'M', 'michael.magat@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:50', NULL),
(380, '2023-0308', 'John Khim', 'J', 'Moreno', 'M', 'johnkhim.moreno@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:51', NULL),
(381, '2023-0255', 'Jayson', 'A', 'Ramos', 'M', 'jayson.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:51', NULL),
(382, '2023-0322', 'Joel', 'B', 'Villena', 'M', 'joel.villena@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:51', NULL),
(383, '2023-0248', 'Jazzle Irish', 'M', 'Cudiamat', 'F', 'jazzleirish.cudiamat@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:51', NULL),
(384, '2023-0240', 'Jenny', 'M', 'Fajardo', 'F', 'jenny.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:51', NULL),
(385, '2023-0299', 'Mary Joy', 'D', 'Sim', 'F', 'maryjoy.sim@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:51', NULL),
(386, '2023-0309', 'Jordan', 'V', 'Abeleda', 'M', 'jordan.abeleda@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:06', '2026-03-16 18:47:51', NULL),
(387, '2023-0150', 'Ralf Jenvher', 'V', 'Atienza', 'M', 'ralfjenvher.atienza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:51', NULL),
(388, '2023-0284', 'Mon Andrei', 'M', 'Bae', 'M', 'monandrei.bae@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:51', NULL),
(389, '2023-0261', 'John Mark', 'M', 'Balmes', 'M', 'johnmark.balmes@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:51', NULL),
(390, '2023-0209', 'John Russel', 'G', 'Bolaños', 'M', 'johnrussel.bolaos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:51', NULL),
(391, '2023-0166', 'Justine James', 'A', 'Dela Cruz', 'M', 'justinejames.delacruz@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:51', NULL),
(392, '2023-0313', 'Carl John', 'M', 'Evangelista', 'M', 'carljohn.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:52', NULL),
(393, '2023-0274', 'Mon Lester', 'B', 'Faner', 'M', 'monlester.faner@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:52', NULL),
(394, '2023-0159', 'John Paul', '', 'Freyra', 'M', 'johnpaul.freyra@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:52', NULL),
(395, '2023-0258', 'Ryan', 'I', 'Garcia', 'M', 'ryan.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:52', NULL),
(396, '2023-0223', 'Apple', 'M', 'Braña', 'F', 'jeshlerclifford.gervacio@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:53', NULL),
(397, '2023-0333', 'Melvic John', 'A', 'Magsino', 'M', 'melvicjohn.magsino@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:52', NULL),
(398, '2023-0213', 'Jerome', 'B', 'Mauro', 'M', 'jerome.mauro@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:07', '2026-03-16 18:47:52', NULL),
(399, '2023-0279', 'Jundell', 'M', 'Morales', 'M', 'jundell.morales@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:52', NULL),
(400, '2023-0171', 'Adrian', 'R', 'Pampilo', 'M', 'adrian.pampilo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:52', NULL),
(401, '2023-0300', 'John Carl', 'C', 'Pedragoza', 'M', 'johncarl.pedragoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:52', NULL),
(402, '2023-0295', 'King', 'C', 'Saranillo', 'M', 'king.saranillo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:53', NULL),
(403, '2023-0260', 'Jhon Laurence', 'D', 'Victoriano', 'M', 'jhonlaurence.victoriano@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:53', NULL),
(404, '2023-0210', 'Janelle', 'R', 'Absin', 'F', 'janelle.absin@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:53', NULL),
(405, '2023-0188', 'Jan Ashley', 'R', 'Bonado', 'F', 'janashley.bonado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:53', NULL),
(406, '2023-0202', 'Robelyn', 'D', 'Bonado', 'F', 'robelyn.bonado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:53', NULL),
(407, '2023-0253', 'Princes', 'A', 'Capote', 'F', 'princes.capote@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:08', '2026-03-16 18:47:53', NULL),
(408, '2023-0228', 'Joann', 'M', 'Carandan', 'F', 'joann.carandan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:53', NULL),
(409, '2023-0272', 'Christine Rose', 'F', 'Catapang', 'F', 'christinerose.catapang@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:53', NULL),
(410, '2023-0192', 'Arlyn', 'P', 'Corona', 'F', 'arlyn.corona@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:53', NULL),
(411, '2023-0185', 'Stacy Anne', 'G', 'Cortez', 'F', 'stacyanne.cortez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:53', NULL),
(412, '2023-0199', '', '', 'De Claro Alexa Jane C.', 'F', '.declaroalexajanec@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:54', NULL),
(413, '2023-0266', 'Angel Ann', 'M', 'De Lara', 'F', 'angelann.delara@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:54', NULL),
(414, '2023-0172', 'Lorebel', 'A', 'De Leon', 'F', 'lorebel.deleon@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:54', NULL),
(415, '2023-0257', 'Rocelyn', 'P', 'Dela Rosa', 'F', 'rocelyn.delarosa@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:54', NULL),
(416, '2023-0256', 'Ronalyn Paulita', '', 'Dela Rosa', 'F', 'ronalynpaulita.delarosa@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:54', NULL),
(417, '2023-0137', 'Krisnah Joy', 'V', 'Dorias', 'F', 'krisnahjoy.dorias@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:54', NULL),
(418, '2023-0287', 'Ayessa Jhoy', 'M', 'Gaba', 'F', 'ayessajhoy.gaba@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:54', NULL),
(419, '2023-0193', 'Margie', 'R', 'Gatilo', 'F', 'margie.gatilo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:09', '2026-03-16 18:47:54', NULL),
(420, '2023-0296', 'Jasmine', 'C', 'Gayao', 'F', 'jasmine.gayao@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:54', NULL),
(421, '2023-0197', 'Mikaela M', '', 'Hernandez', 'F', 'mikaelam.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:54', NULL),
(422, '2023-0189', 'Vanessa Nicole', '', 'Latoga', 'F', 'vanessanicole.latoga@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:54', NULL),
(423, '2023-0262', 'Alwena', 'A', 'Madrigal', 'F', 'alwena.madrigal@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:54', NULL),
(424, '2023-0191', 'Maria Eliza', 'T', 'Magsisi', 'F', 'mariaeliza.magsisi@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:55', NULL),
(425, '2023-0227', 'Carla Joy', 'L', 'Matira', 'F', 'carlajoy.matira@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:55', NULL),
(426, '2023-0163', 'Allysa Mae', 'A', 'Mirasol', 'F', 'allysamae.mirasol@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:55', NULL),
(427, '2023-0247', 'Manilyn', 'G', 'Narca', 'F', 'manilyn.narca@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:55', NULL),
(428, '2023-0211', 'Sharah Mae', 'P', 'Ojales', 'F', 'sharahmae.ojales@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:55', NULL),
(429, '2023-0340', 'Geselle', 'C', 'Rivas', 'F', 'geselle.rivas@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:55', NULL),
(430, '2023-0184', 'Angel Joy', 'A', 'Sanchez', 'F', 'angeljoy.sanchez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:10', '2026-03-16 18:47:55', NULL),
(431, '2023-0341', 'Jamaica Rose', 'M', 'Sarabia', 'F', 'jamaicarose.sarabia@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:55', NULL),
(432, '2023-0194', 'Nicole', 'A', 'Villafranca', 'F', 'nicole.villafranca@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:55', NULL),
(433, '2023-0203', 'Jennylyn', 'T', 'Villanueva', 'F', 'jennylyn.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:55', NULL),
(434, '2023-0277', 'John Lloyd David', 'M', 'Amido', 'M', 'johnlloyddavid.amido@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:55', NULL),
(435, '2023-0290', 'Reniel', 'L', 'Borja', 'M', 'reniel.borja@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:55', NULL),
(436, '2023-0179', 'John Carlo', 'G', 'Chiquito', 'M', 'johncarlo.chiquito@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:56', NULL),
(437, '2023-0301', 'Justin', 'S', 'Como', 'M', 'justin.como@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:56', NULL),
(438, '2023-0236', 'Moises', 'G', 'Delos Santos', 'M', 'moises.delossantos@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:56', NULL),
(439, '2023-0226', 'Philip', 'F', 'Garcia', 'M', 'philip.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:56', NULL),
(440, '2023-0182', 'Bryan', 'A', 'Peñaescosa', 'M', 'bryan.peaescosa@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:56', NULL),
(441, '2023-0297', 'John Rick', 'F', 'Ramos', 'M', 'johnrick.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:11', '2026-03-16 18:47:56', NULL),
(442, '2023-0220', 'Rezlyn Jhoy', 'S', 'Aguba', 'F', 'rezlynjhoy.aguba@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:56', NULL),
(443, '2023-0153', 'Lyzel', 'G', 'Bool', 'F', 'lyzel.bool@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:56', NULL),
(444, '2023-0219', 'Jesca Mae', 'M', 'Chavez', 'F', 'jescamae.chavez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:56', NULL),
(445, '2023-0270', 'Hiedie', 'H', 'Claus', 'F', 'hiedie.claus@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:56', NULL),
(446, '2023-0155', 'KC', 'D', 'Dela Roca', 'F', 'kc.delaroca@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:57', NULL),
(447, '2023-0154', 'Bea', 'A', 'Fajardo', 'F', 'bea.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:57', NULL),
(448, '2023-0320', 'Sherlyn', '', 'Festin', 'F', 'sherlyn.festin@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:57', NULL),
(449, '2023-0204', 'Clarissa', 'B', 'Feudo', 'F', 'clarissa.feudo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:57', NULL),
(450, '2023-0156', 'Irish Karyl', 'G', 'Magcamit', 'F', 'irishkaryl.magcamit@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:57', NULL),
(451, '2023-0216', 'Cristine', 'S', 'Manalo', 'F', 'cristine.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:57', NULL),
(452, '2023-0331', 'Geraldine', 'G', 'Manalo', 'F', 'geraldine.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:12', '2026-03-16 18:47:57', NULL),
(453, '2023-0198', 'Shiloh', 'G', 'Manhic', 'F', 'shiloh.manhic@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:57', NULL),
(454, '2023-0242', 'Shylyn', '', 'Mansalapus', 'F', 'shylyn.mansalapus@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:57', NULL),
(455, '2023-0291', 'Irish May Roselle', 'C', 'Nao', 'F', 'irishmayroselle.nao@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:57', NULL),
(456, '2023-0208', 'Paulyn Grace', '', 'Perez', 'F', 'paulyngrace.perez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:57', NULL),
(457, '2023-0181', 'Shane', 'T', 'Ramos', 'F', 'shane.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:57', NULL),
(458, '2023-0566', 'Andrea Chel', 'D', 'Rivera', 'F', 'andreachel.rivera@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:58', NULL),
(459, '2023-0344', 'Angel Bellie', 'G', 'Vargas', 'F', 'angelbellie.vargas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:58', NULL),
(460, '2023-0221', 'Jamaica Mickaela', 'Y', 'Villena', 'F', 'jamaicamickaela.villena@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:58', NULL),
(461, '2023-0268', 'Monaliza', 'F', 'Waing', 'F', 'monaliza.waing@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:58', NULL),
(462, '2023-0157', 'Jay', 'T', 'Aguilar', 'M', 'jay.aguilar@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:58', NULL),
(463, '2023-0263', 'Ken Celwyn', 'R', 'Algaba', 'M', 'kencelwyn.algaba@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:58', NULL),
(464, '2023-0273', 'Mark Lester', 'M', 'Baes', 'M', 'marklester.baes@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:13', '2026-03-16 18:47:58', NULL),
(465, '2023-0293', 'John Albert', 'C', 'Bastida', 'M', 'johnalbert.bastida@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:58', NULL),
(466, '2023-0218', 'Vitoel', 'G', 'Curatcha', 'M', 'vitoel.curatcha@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:58', NULL),
(467, '2023-0286', 'Karl Marion', 'R', 'De Leon', 'M', 'karlmarion.deleon@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:58', NULL),
(468, '2023-0212', 'Renzie Carl', 'C', 'Escaro', 'M', 'renziecarl.escaro@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:58', NULL),
(469, '2023-0196', 'Nathaniel', 'C', 'Falcunaya', 'M', 'nathaniel.falcunaya@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:58', NULL),
(470, '2023-0292', 'Kyzer', 'A', 'Gonda', 'M', 'kyzer.gonda@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:59', NULL),
(471, '2023-0283', 'John Dexter', '', 'Gonzales', 'M', 'johndexter.gonzales@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:59', NULL),
(472, '2023-0319', 'Reniel', 'B', 'Jara', 'M', 'reniel.jara@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:59', NULL),
(473, '2023-0158', 'Steven Angelo', '', 'Legayada', 'M', 'stevenangelo.legayada@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:59', NULL),
(474, '2023-0152', 'Angelo', 'M', 'Lumanglas', 'M', 'angelo.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:59', NULL),
(475, '2023-0214', 'Jhon Lester', 'M', 'Madrigal', 'M', 'jhonlester.madrigal@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:59', NULL),
(476, '2023-0162', 'Rhaven', 'G', 'Magmanlac', 'M', 'rhaven.magmanlac@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:14', '2026-03-16 18:47:59', NULL),
(477, '2023-0195', 'Jumyr', 'M', 'Moreno', 'M', 'jumyr.moreno@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:47:59', NULL),
(478, '2023-0176', 'Dan Lloyd', 'B', 'Paala', 'M', 'danlloyd.paala@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:47:59', NULL),
(479, '2023-0206', 'Patrick James', 'V', 'Romasanta', 'M', 'patrickjames.romasanta@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:47:59', NULL),
(480, '2023-0186', 'Jereck', 'M', 'Roxas', 'M', 'jereck.roxas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:47:59', NULL),
(481, '2023-0217', 'Jan Denmark', 'C', 'Santos', 'M', 'jandenmark.santos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:47:59', NULL),
(482, '2023-0267', 'John Paolo', 'N', 'Torralba', 'M', 'johnpaolo.torralba@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:48:00', NULL),
(483, '2022-0079', 'Dianne Christine Joy', 'A', 'Alulod', 'F', 'diannechristinejoy.alulod@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:48:00', NULL),
(484, '2022-0080', 'Rechel', 'R', 'Arenas', 'F', 'rechel.arenas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:48:00', NULL),
(485, '2022-0081', 'Allyna', 'A', 'Atienza', 'F', 'allyna.atienza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:48:00', NULL),
(486, '2022-0130', 'Angela', 'A', 'Bonilla', 'F', 'angela.bonilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:48:00', NULL),
(487, '2022-0082', 'Aira', 'F', 'Cabulao', 'F', 'aira.cabulao@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:48:00', NULL),
(488, '2022-0124', 'Janice', 'C', 'Cadacio', 'F', 'janice.cadacio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:15', '2026-03-16 18:48:00', NULL),
(489, '2022-0083', 'Maries', 'D', 'Cantos', 'F', 'maries.cantos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:00', NULL),
(490, '2022-0084', 'Veronica', 'C', 'Cantos', 'F', 'veronica.cantos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:00', NULL),
(491, '2022-0139', 'Diana', 'G', 'Caringal', 'F', 'diana.caringal@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:00', NULL),
(492, '2022-0085', 'Lorebeth', 'C', 'Casapao', 'F', 'lorebeth.casapao@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:00', NULL),
(493, '2022-0086', 'Carla Jane', 'G', 'Chiquito', 'F', 'carlajane.chiquito@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:00', NULL),
(494, '2022-0089', 'Melody', 'T', 'Enriquez', 'F', 'melody.enriquez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:01', NULL),
(495, '2022-0090', 'Maricon', 'A', 'Evangelista', 'F', 'maricon.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:01', NULL),
(496, '2022-0091', 'Mary Ann', 'D', 'Fajardo', 'F', 'maryann.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:01', NULL),
(497, '2022-0092', 'Kaecy', 'F', 'Ferry', 'F', 'kaecy.ferry@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:01', NULL),
(498, '2022-0140', 'Zybel', 'V', 'Garan', 'F', 'zybel.garan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:01', NULL),
(499, '2022-0118', 'IC Pamela', 'M', 'Gutierrez', 'F', 'icpamela.gutierrez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:01', NULL);
INSERT INTO `students` (`id`, `student_id`, `first_name`, `middle_name`, `last_name`, `gender`, `email`, `contact_number`, `address`, `department`, `section_id`, `yearlevel`, `year_level`, `avatar`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(500, '2022-0096', 'Jane Monica', 'P', 'Mansalapus', 'F', 'janemonica.mansalapus@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:16', '2026-03-16 18:48:01', NULL),
(501, '2022-0097', 'Hanna Yesha Mae', 'D', 'Mercado', 'F', 'hannayeshamae.mercado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:01', NULL),
(502, '2022-0098', 'Abegail', 'D', 'Moong', 'F', 'abegail.moong@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:01', NULL),
(503, '2022-0125', 'Laiza Marie', 'M', 'Pole', 'F', 'laizamarie.pole@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:01', NULL),
(504, '2022-0142', 'Jarryfel', 'N', 'Tembrevilla', 'F', 'jarryfel.tembrevilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:01', NULL),
(505, '2022-0136', 'Jay Mark', 'G', 'Avelino', 'M', 'jaymark.avelino@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:01', NULL),
(506, '2022-0072', 'Jairus', 'A', 'Cabales', 'M', 'jairus.cabales@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:02', NULL),
(507, '2022-0075', 'Jleo Nhico Mari', 'M', 'Mazo', 'M', 'jleonhicomari.mazo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:02', NULL),
(508, '2022-0076', 'Mark Cyrel', 'F', 'Panganiban', 'M', 'markcyrel.panganiban@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:02', NULL),
(509, '2022-0117', 'Bernabe Dave', 'F', 'Solas', 'M', 'bernabedave.solas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:02', NULL),
(510, '2022-0078', 'Mark June', 'G', 'Villena', 'M', 'markjune.villena@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:02', NULL),
(511, '2022-0122', 'Nhicel', 'M', 'Bueno', 'F', 'nhicel.bueno@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:02', NULL),
(512, '2022-0135', 'Dianne Mae', 'R', 'Cezar', 'F', 'diannemae.cezar@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:17', '2026-03-16 18:48:02', NULL),
(513, '2022-0147', 'Princess Joy', 'P', 'De Castro', 'F', 'princessjoy.decastro@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:02', NULL),
(514, '2022-0141', 'Shiela Mae', 'M', 'Fajardo', 'F', 'shielamae.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:02', NULL),
(515, '2022-0115', 'Shiela Marie', 'B', 'Garcia', 'F', 'shielamarie.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:02', NULL),
(516, '2022-0129', 'Jessa', 'M', 'Geneta', 'F', 'jessa.geneta@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:02', NULL),
(517, '2022-0094', 'Jee Anne', 'R', 'Llamoso', 'F', 'jeeanne.llamoso@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:02', NULL),
(518, '2022-0123', 'Princess Jenille', 'A', 'Santos', 'F', 'princessjenille.santos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:03', NULL),
(519, '2022-0099', 'Von Lester', 'R', 'Algaba', 'M', 'vonlester.algaba@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:03', NULL),
(520, '2022-0100', 'John Aaron', 'M', 'Aniel', 'M', 'johnaaron.aniel@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:03', NULL),
(521, '2022-0101', 'Keil John', 'C', 'Antenor', 'M', 'keiljohn.antenor@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:03', NULL),
(522, '2022-0102', 'Mark Joshua', 'M', 'Bacay', 'M', 'markjoshua.bacay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:03', NULL),
(523, '2022-0128', 'Michael', 'A', 'De Guzman', 'M', 'michael.deguzman@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:03', NULL),
(524, '2022-0107', 'Christian', '', 'Delda', 'M', 'christian.delda@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:18', '2026-03-16 18:48:03', NULL),
(525, '2022-0108', 'Mark Vincent Earl', 'R', 'Gan', 'M', 'lloyd.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:03', NULL),
(526, '2022-0073', 'Samson', 'L', 'Fulgencio', 'M', 'samson.fulgencio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:03', NULL),
(527, '2022-0145', 'John Dragan', 'B', 'Gardoce', 'M', 'johndragan.gardoce@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:03', NULL),
(528, '2022-0127', 'John Elmer', '', 'Gonzales', 'M', 'johnelmer.gonzales@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:04', NULL),
(529, '2022-0144', 'Mark Vender', 'N', 'Muhi', 'M', 'markvender.muhi@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:04', NULL),
(530, '2022-0112', 'Marc Paulo', 'B', 'Relano', 'M', 'marcpaulo.relano@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:04', NULL),
(531, '2022-0113', 'Cee Jey', 'G', 'Rellora', 'M', 'ceejey.rellora@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:04', NULL),
(532, '2022-0134', 'Franklin', 'R', 'Salcedo', 'M', 'franklin.salcedo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:04', NULL),
(533, '2022-0120', 'Russel', 'I', 'Sason', 'M', 'russel.sason@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:04', NULL),
(534, '2022-0132', 'John Paul', 'D', 'Teves', 'M', 'johnpaul.teves@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:04', NULL),
(535, '2022-0131', 'John Xavier', 'A', 'Villanueva', 'M', 'johnxavier.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:19', '2026-03-16 18:48:04', NULL),
(536, '2022-0114', 'Reinier Aron', 'L', 'Visayana', 'M', 'reinieraron.visayana@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, 'N/A', 'N/A', NULL, 'active', '2026-03-15 19:30:20', '2026-03-16 18:48:04', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `student_violation_levels`
--

DROP TABLE IF EXISTS `student_violation_levels`;
CREATE TABLE IF NOT EXISTS `student_violation_levels` (
  `id` int NOT NULL AUTO_INCREMENT,
  `student_id` varchar(50) NOT NULL,
  `violation_type` varchar(50) NOT NULL,
  `current_level` enum('permitted1','permitted2','warning1','warning2','warning3','disciplinary') NOT NULL DEFAULT 'permitted1',
  `permitted_count` int NOT NULL DEFAULT '0',
  `warning_count` int NOT NULL DEFAULT '0',
  `total_violations` int NOT NULL DEFAULT '0',
  `last_violation_date` date DEFAULT NULL,
  `last_violation_time` time DEFAULT NULL,
  `last_location` varchar(50) DEFAULT NULL,
  `last_reported_by` varchar(100) DEFAULT NULL,
  `last_notes` text,
  `status` enum('active','resolved','disciplinary') NOT NULL DEFAULT 'active',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_student_violation` (`student_id`,`violation_type`),
  KEY `idx_student_id` (`student_id`),
  KEY `idx_violation_type` (`violation_type`),
  KEY `idx_current_level` (`current_level`),
  KEY `idx_status` (`status`),
  KEY `idx_last_violation_date` (`last_violation_date`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `system_logs`
--

DROP TABLE IF EXISTS `system_logs`;
CREATE TABLE IF NOT EXISTS `system_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `username` varchar(255) NOT NULL,
  `action` varchar(255) NOT NULL,
  `details` text,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `created_at` (`created_at`)
) ENGINE=MyISAM AUTO_INCREMENT=114 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `system_logs`
--

INSERT INTO `system_logs` (`id`, `user_id`, `username`, `action`, `details`, `ip_address`, `user_agent`, `created_at`) VALUES
(1, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 02:10:21'),
(2, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 02:10:49'),
(3, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 02:11:00'),
(4, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 02:15:48'),
(5, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 02:20:38'),
(6, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 02:23:22'),
(7, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 02:40:55'),
(8, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 03:12:44'),
(9, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 03:15:17'),
(10, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:15:46'),
(11, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:18:53'),
(12, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:26:05'),
(13, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:27:40'),
(14, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:27:53'),
(15, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:30:16'),
(16, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:33:24'),
(17, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:35:48'),
(18, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:44:04'),
(19, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:58:36'),
(20, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 04:59:33'),
(21, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 05:04:16'),
(22, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 05:27:42'),
(23, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 05:31:30'),
(24, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 05:35:26'),
(25, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 05:43:34'),
(26, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-08 06:18:05'),
(27, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 15:35:50'),
(28, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 15:49:02'),
(29, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 16:00:29'),
(30, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 16:05:33'),
(31, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 16:13:07'),
(32, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 16:20:43'),
(33, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 16:25:23'),
(34, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 16:53:21'),
(35, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 17:04:39'),
(36, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 17:12:13'),
(37, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 17:16:24'),
(38, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 17:17:33'),
(39, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 17:17:42'),
(40, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 17:23:24'),
(41, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 17:26:10'),
(42, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-09 23:27:36'),
(43, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 02:48:52'),
(44, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 02:49:29'),
(45, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 03:49:55'),
(46, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1 Edg/145.0.0.0', '2026-03-10 04:00:19'),
(47, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 04:01:06'),
(48, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1 Edg/145.0.0.0', '2026-03-10 04:01:29'),
(49, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1 Edg/145.0.0.0', '2026-03-10 04:01:45'),
(50, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 04:09:11'),
(51, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 04:10:44'),
(52, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 04:10:52'),
(53, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 04:11:39'),
(54, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 04:13:22'),
(55, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 07:28:39'),
(56, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 07:54:11'),
(57, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 22:56:19'),
(58, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 23:05:00'),
(59, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 03:32:00'),
(60, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 03:32:33'),
(61, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 03:36:59'),
(62, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 03:39:40'),
(63, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 03:39:57'),
(64, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 03:52:24'),
(65, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 06:18:42'),
(66, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 07:11:10'),
(67, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 07:44:46'),
(68, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 12:16:14'),
(69, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 13:56:56'),
(70, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 14:02:25'),
(71, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 14:04:46'),
(72, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 14:17:12'),
(73, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 14:20:55'),
(74, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 15:20:14'),
(75, 3051, '2023-0195', 'Login', 'User logged in: 2023-0195 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 15:20:53'),
(76, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 20:45:18'),
(77, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 20:53:30'),
(78, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 20:54:05'),
(79, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 21:00:19'),
(80, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 21:05:02'),
(81, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-11 21:07:08'),
(82, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 00:40:49'),
(83, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 00:41:39'),
(84, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 00:53:09'),
(85, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 00:53:41'),
(86, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 01:01:47'),
(87, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 01:02:35'),
(88, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 01:03:34'),
(89, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 01:14:19'),
(90, 3025, '2023-0216', 'Login', 'User logged in: 2023-0216 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 01:14:57'),
(91, 3025, '2023-0216', 'Login', 'User logged in: 2023-0216 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 01:22:20'),
(92, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 01:25:18'),
(93, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 01:48:42'),
(94, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 02:00:21'),
(95, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 02:04:18'),
(96, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 02:21:11'),
(97, 2572, 'adminOsas@colegio.edu', 'Admin Created', 'New admin created: user (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 02:42:40'),
(98, 3116, 'user', 'Login', 'User logged in: user (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 02:43:05'),
(99, 3025, '2023-0216', 'Login', 'User logged in: 2023-0216 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 02:56:34'),
(100, 3116, 'user', 'Login', 'User logged in: user (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 11:17:56'),
(101, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-12 12:27:42'),
(102, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-13 11:29:43'),
(103, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-13 23:26:34'),
(104, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 06:05:36'),
(105, 2572, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 07:32:50'),
(106, 3116, 'user', 'Login', 'User logged in: user (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 13:39:41'),
(107, 3116, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 13:41:26'),
(108, 3116, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 14:02:56'),
(109, 3116, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 14:13:51'),
(110, 3116, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 14:14:40'),
(111, 5739, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 14:15:10'),
(112, 3116, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-15 23:11:08'),
(113, 3116, 'adminOsas@colegio.edu', 'Login', 'User logged in: adminOsas@colegio.edu (Role: admin)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0', '2026-03-16 10:31:52');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
CREATE TABLE IF NOT EXISTS `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `google_id` varchar(255) DEFAULT NULL,
  `facebook_id` varchar(255) DEFAULT NULL,
  `profile_picture` varchar(500) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `role` varchar(50) NOT NULL DEFAULT 'admin',
  `full_name` varchar(100) NOT NULL,
  `student_id` varchar(20) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT '1',
  `status` enum('active','inactive','archived') NOT NULL DEFAULT 'active',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_users_google_id` (`google_id`(250)),
  KEY `idx_users_facebook_id` (`facebook_id`(250))
) ENGINE=MyISAM AUTO_INCREMENT=5797 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `email`, `google_id`, `facebook_id`, `profile_picture`, `password`, `role`, `full_name`, `student_id`, `is_active`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(5796, '2022-0114', 'reinieraron.visayana@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$mJKSL31GnA5Yuob.h5ezh.UBoSoQ2OJwVQhkboJfjOqZGiHhOGr9C', 'user', 'Reinier Aron Visayana', '2022-0114', 1, 'active', '2026-03-15 11:30:20', '2026-03-15 11:30:20', NULL),
(5795, '2022-0131', 'johnxavier.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.GcVmrovNU78sEaJMoDkterJ4dDz8aQKueTX.OH9eEa1Brqgu2JRS', 'user', 'John Xavier Villanueva', '2022-0131', 1, 'active', '2026-03-15 11:30:20', '2026-03-15 11:30:20', NULL),
(5794, '2022-0132', 'johnpaul.teves@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$AmXx7i970cLzNiJWRlUlCOtZH1yGODR47DecKn1varr7Yil6jqkZS', 'user', 'John Paul Teves', '2022-0132', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5793, '2022-0120', 'russel.sason@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3k2DcUw1J/nwD.Dxao5JNuLol4ZMGwa83kL0LfTqYbEjDb6G8S3yC', 'user', 'Russel Sason', '2022-0120', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5792, '2022-0134', 'franklin.salcedo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$TNNx7tXUcqj6xYUTlPIp/ugkGriFRIhpXw5XZMvZVEUWTpAEMIoUq', 'user', 'Franklin Salcedo', '2022-0134', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5791, '2022-0113', 'ceejey.rellora@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$1ebxNefMeJomxB49wBT/heMlj1KdYAOa86ChCLWxnCgyduQ/N3DaW', 'user', 'Cee Jey Rellora', '2022-0113', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5787, '2022-0145', 'johndragan.gardoce@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0Ij4HrCuQGrClBuodBYh2e6PnloCTm1..6e9r0HbBBQf/hXStO22y', 'user', 'John Dragan Gardoce', '2022-0145', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5788, '2022-0127', 'johnelmer.gonzales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Z3VRDqM9/DoThk/WyTiWS.0rNWh7XusuH3F4rar.ZdKhEj.ziCPpS', 'user', 'John Elmer Gonzales', '2022-0127', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5789, '2022-0144', 'markvender.muhi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$muBUYmHjvZHX4s2HpI0td.mtt6Cugbrpx5bfAg.T8ZR7GLknxAspa', 'user', 'Mark Vender Muhi', '2022-0144', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5790, '2022-0112', 'marcpaulo.relano@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$vZpnRVjXAzqlN2E3Wz/IIeiICp5VnOJdwp7wcJHDWDqeF58AUouS.', 'user', 'Marc Paulo Relano', '2022-0112', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5786, '2022-0073', 'samson.fulgencio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$nrWd4c1XIi2foqlSNlNny.7iJBKyAfFa4X0uWScA1.M/pzLrMUul2', 'user', 'Samson Fulgencio', '2022-0073', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5785, '2022-0108', 'lloyd.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$gTS/mx5vOvE6KXfE5Bz9oejtwncrfY17hTRkrIdVmEoqMY7IZk6Ze', 'user', 'Lloyd Evangelista', '2022-0108', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5783, '2022-0128', 'michael.deguzman@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$n4NBURYf81DiJud3NP8es.fO8ji1kAWm5mCfHU6BnEyRJswpz3Y3m', 'user', 'Michael De Guzman', '2022-0128', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5784, '2022-0107', 'christian.delda@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PC08P0Ip7bFWTwr3D/WAQe1ZmuH6/pqWBXLeVOJIovqvR5b0WVDNO', 'user', 'Christian Delda', '2022-0107', 1, 'active', '2026-03-15 11:30:19', '2026-03-15 11:30:19', NULL),
(5782, '2022-0102', 'markjoshua.bacay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$NApCkrSbQHHc3/DCN9g6NuAdq3OSdoMIh93AEUR1YX4f/I5pgbnD2', 'user', 'Mark Joshua Bacay', '2022-0102', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5779, '2022-0099', 'vonlester.algaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$b99NS3B2QBWuVN5iZSQX4OnU/NqfhEZnTBwJqpmOUgCJ4dbMnXs5S', 'user', 'Von Lester Algaba', '2022-0099', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5780, '2022-0100', 'johnaaron.aniel@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$E0A7j1UOGVqJHcU7fL1lRujl6g/G1K2eOb0kooNFb7TgNOGZplTSi', 'user', 'John Aaron Aniel', '2022-0100', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5781, '2022-0101', 'keiljohn.antenor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$8HaTuidWJD9JtYstI4pakOO5WrM03zvczbHeeF2ZlbwH/Of0uPol.', 'user', 'Keil John Antenor', '2022-0101', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5778, '2022-0123', 'princessjenille.santos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$uvcCwopytMakSLlmjbiLFO4pUsDpMKKWnH0wYm2TyU8vJjlXQ.S9e', 'user', 'Princess Jenille Santos', '2022-0123', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5777, '2022-0094', 'jeeanne.llamoso@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$6cW/tBtWE7IikLIMG1r9/u3Or.bJloDn90stv1Ufdfex7zPhp5l32', 'user', 'Jee Anne Llamoso', '2022-0094', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5775, '2022-0115', 'shielamarie.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$OY45/IwJjuodD1.cLdBF8.MCv1YbjRNK1Gv051/NoZznLFuaIKCR.', 'user', 'Shiela Marie Garcia', '2022-0115', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5776, '2022-0129', 'jessa.geneta@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$cOxLHJkvikBeg6qaWCL/iuaB8DNll7dspWXu02FlND1DdE30QovpG', 'user', 'Jessa Geneta', '2022-0129', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5774, '2022-0141', 'shielamae.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$c5a85AGl9xKZCBwoX364xOZiYa2LRuUbNDtmOzInpX3QcoB1DvS6K', 'user', 'Shiela Mae Fajardo', '2022-0141', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5773, '2022-0147', 'princessjoy.decastro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$f7zd98RoIYlzmGytGtKJS.UF7M96gfOn6zNXZgnCY9CvB8Iv/a83K', 'user', 'Princess Joy De Castro', '2022-0147', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5772, '2022-0135', 'diannemae.cezar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$bp.dUTA0EWq5h4b/MC9WZ.1K4Fx4SqumhOCDlIyD3AsT6LxrdzVgG', 'user', 'Dianne Mae Cezar', '2022-0135', 1, 'active', '2026-03-15 11:30:18', '2026-03-15 11:30:18', NULL),
(5770, '2022-0078', 'markjune.villena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$SJlO50TosmEz0qWNLEf8wuIF6sV8zaeB7ixzBawEwyQxQG2OtMyYa', 'user', 'Mark June Villena', '2022-0078', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5771, '2022-0122', 'nhicel.bueno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$6MlhHaLbJpyrd6Y6.e9gbeEKlGSYiIYsaplFI7ZO6FlCC495MtxR6', 'user', 'Nhicel Bueno', '2022-0122', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5769, '2022-0117', 'bernabedave.solas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$U3FwPu2y4miNs4rQ0rnD8OQGtaI6ay3YmwKV8OxBLM85XPt9ARBki', 'user', 'Bernabe Dave Solas', '2022-0117', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5766, '2022-0072', 'jairus.cabales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$TRmOO92Pqen7rPbVBYN6ve/hXAadqghdqv.wMqvmspNRNGAqKm0Jq', 'user', 'Jairus Cabales', '2022-0072', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5767, '2022-0075', 'jleonhicomari.mazo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$nzVeO.JNb2wTF5vlE7Irh./f5bnq69l7Ap.c3AT5TEuUksoirNbQy', 'user', 'Jleo Nhico Mari Mazo', '2022-0075', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5768, '2022-0076', 'markcyrel.panganiban@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$7Tazho6arcZJ/XrhQouifuOVcrEHNHE8Ets.Ga9vVoQ1enSugIyyi', 'user', 'Mark Cyrel Panganiban', '2022-0076', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5765, '2022-0136', 'jaymark.avelino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$l6NqnKUrCYYcqTe1vlKace9EAbiASo4hIpO.ImcfcxtpsH.Pfj8/O', 'user', 'Jay Mark Avelino', '2022-0136', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5764, '2022-0142', 'jarryfel.tembrevilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$kUbgTOUWyPNndYqYQ.eCKuDIyiZyOFAUnPO5Rnb2uPjknhCgNjaNW', 'user', 'Jarryfel Tembrevilla', '2022-0142', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5762, '2022-0098', 'abegail.moong@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GSgd9sWhd.NEd3y9.TNc.u0.EcLFIX5vGl90CTYNuDBSYvZGLs4.W', 'user', 'Abegail Moong', '2022-0098', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5763, '2022-0125', 'laizamarie.pole@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ZmHnQpCGCg1AfZTMylxxzOTwEBXdLZPVEh2o07WIeSt3cPBvy2KGG', 'user', 'Laiza Marie Pole', '2022-0125', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5761, '2022-0097', 'hannayeshamae.mercado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$awhOoda6yLFPkFwSCNv8Wesl.ZbPM3Fc9sdSxHz0A40w9BjRcttPa', 'user', 'Hanna Yesha Mae Mercado', '2022-0097', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5757, '2022-0092', 'kaecy.ferry@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$F0BR3WvniVAyE1N396/EI.ad/bcglYodFesJ.dgeTWv38zNzadU5S', 'user', 'Kaecy Ferry', '2022-0092', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5758, '2022-0140', 'zybel.garan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$CqfPT/y3JmeasHPDRb9WJuFf4STz3Gyjsb08jUp/6eYzIe.0WaYga', 'user', 'Zybel Garan', '2022-0140', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5759, '2022-0118', 'icpamela.gutierrez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$a0A0MmwfryY8AuSiQBfwV.XsqwYem.rq1AKXZxytS1vyZ2PdO.bAi', 'user', 'IC Pamela Gutierrez', '2022-0118', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5760, '2022-0096', 'janemonica.mansalapus@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$gyo.rTfTFmB5aOZUnTjoO.Mu0evzusJRCNJcutIPHhik3q7C9SzFK', 'user', 'Jane Monica Mansalapus', '2022-0096', 1, 'active', '2026-03-15 11:30:17', '2026-03-15 11:30:17', NULL),
(5756, '2022-0091', 'maryann.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$p62c7x3DuJzu0cZCJ1ru2.SoERZ6.5ETlvVvPVGU4dwTlM6IcdiUu', 'user', 'Mary Ann Fajardo', '2022-0091', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5755, '2022-0090', 'maricon.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zjYce43oWrcNClztTnCxL.FsHpKruukx1.P6cAOFDrZ/sfpRm35oW', 'user', 'Maricon Evangelista', '2022-0090', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5752, '2022-0085', 'lorebeth.casapao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3Y/6Nqutj1xI/.99.U7Z0.HRHaF1OpT4gp17SYn5m/H0/tdZBujv6', 'user', 'Lorebeth Casapao', '2022-0085', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5753, '2022-0086', 'carlajane.chiquito@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DNjCvPYcdI/bQuvRD5u7ZOyBg0nmy2EHDy/BrbQ4Ap7e9/kGguwzG', 'user', 'Carla Jane Chiquito', '2022-0086', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5754, '2022-0089', 'melody.enriquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$NJOemcjDCZSaqeGFpWgIH.11kzZ9VwoTGHd51g9Ab3hpNj6oGA/Ya', 'user', 'Melody Enriquez', '2022-0089', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5751, '2022-0139', 'diana.caringal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PNWZZ9MlNZpVcxHS3leTq.mwpSgfVcZ6UORSOrzYLCsRlxtj28xeS', 'user', 'Diana Caringal', '2022-0139', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5750, '2022-0084', 'veronica.cantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$x3.YrQswdZV7vcYmZQCjGORiTx41q2N3oV.evZF/6UGFB7qQzgAqa', 'user', 'Veronica Cantos', '2022-0084', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5749, '2022-0083', 'maries.cantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$2rXe2LQMh30g45IDpE2Xnu.JOHUAlhMvdu9aFB5DulX7ZJ8ZU623S', 'user', 'Maries Cantos', '2022-0083', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5748, '2022-0124', 'janice.cadacio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jDDbI5nP4gaNVGTCvg1AN.yqm1LZmVnnoKzZVQI1TF9HapVGbeydi', 'user', 'Janice Cadacio', '2022-0124', 1, 'active', '2026-03-15 11:30:16', '2026-03-15 11:30:16', NULL),
(5746, '2022-0130', 'angela.bonilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$eWapp2STj6CUTjBLRHPMR.ppn2qss8ypFPno4eZu2fZKZ/pgmcEPO', 'user', 'Angela Bonilla', '2022-0130', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5747, '2022-0082', 'aira.cabulao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iiAYdumDYcCCdH5NfwCUx.EDZECmfoMTeVtKxJ3QpXpVCpBM8E.Y6', 'user', 'Aira Cabulao', '2022-0082', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5745, '2022-0081', 'allyna.atienza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$6dkeYvjnfh1WGGpD4OqBIe.Lo4j9io/SAbgJR6.IIm9vj1jYSespC', 'user', 'Allyna Atienza', '2022-0081', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5743, '2022-0079', 'diannechristinejoy.alulod@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$AX1DOtSES/WJrl/Ynu2ZDOkR974Q8UxNUdNdQDxcrFqbNqyvXutiq', 'user', 'Dianne Christine Joy Alulod', '2022-0079', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5744, '2022-0080', 'rechel.arenas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4XEZlFpx5ajUrawYEjquG.Qo3zceBXuHSiZwNDA.bLJaPKDWzbgPy', 'user', 'Rechel Arenas', '2022-0080', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5740, '2023-0186', 'jereck.roxas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0Iha0zNO0O67Tz.ivIzUHOyKDjmN4QfG0UeQPsu.btqnJcMjrM1be', 'user', 'Jereck Roxas', '2023-0186', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5741, '2023-0217', 'jandenmark.santos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iAH.VSOMUR9OH7ttiat0CeSzX/7gU9tytvcIDy2nQPj1cpmxbicuO', 'user', 'Jan Denmark Santos', '2023-0217', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5742, '2023-0267', 'johnpaolo.torralba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$m1IzxeGD5pTRKbnsPsadMO8kO8c0MBB0hYVBIXfq.t38OEh4SEgcy', 'user', 'John Paolo Torralba', '2023-0267', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5739, '2023-0206', 'patrickjames.romasanta@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$o8MwxuG1DmfLtIJXzppsy.xwPgOwJ8yaDhyoR3mVZzjhWQHrunnb6', 'user', 'Patrick James Romasanta', '2023-0206', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5738, '2023-0176', 'danlloyd.paala@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ZuVyEMVDHOdf/5aGBTnR3.X2p.caN3LiWYBA0g3pjytg/9wff7PwG', 'user', 'Dan Lloyd Paala', '2023-0176', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5734, '2023-0152', 'angelo.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$rQVIgcQ0kZK13l.f8tIWg.PFHZ3SkFxaR45E4MZ97.rktSixW9vWW', 'user', 'Angelo Lumanglas', '2023-0152', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5735, '2023-0214', 'jhonlester.madrigal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Dzk7snMaS.gPv7AFCyx2q.Xo0mJnb9M5F1Af1XvwfojwZqlj5QJmq', 'user', 'Jhon Lester Madrigal', '2023-0214', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5737, '2023-0195', 'jumyr.moreno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$SppimluOijO5r/4M/SI8JuBfKzVl52LlWd9.Rwn9hmgTboOHKpdI.', 'user', 'Jumyr Moreno', '2023-0195', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5736, '2023-0162', 'rhaven.magmanlac@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$AC6DpeMagGLTt7oY4/nY7./k91m.h6BLpR.z1b.sysGQozL1W530C', 'user', 'Rhaven Magmanlac', '2023-0162', 1, 'active', '2026-03-15 11:30:15', '2026-03-15 11:30:15', NULL),
(5733, '2023-0158', 'stevenangelo.legayada@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$yYYZb5usj0pSYK8XX5o7zeD14iMvjsnl2QsmWMMCLwD9zNCSH8jYC', 'user', 'Steven Angelo Legayada', '2023-0158', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5732, '2023-0319', 'reniel.jara@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$IqDUXLydzz92BtSH1pGR3OoQ32G/I7thXsmW6tY80UxUGfeREO7TK', 'user', 'Reniel Jara', '2023-0319', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5728, '2023-0212', 'renziecarl.escaro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$C1LfRroR.5l6d90x9.2l2.Wtxl7NieXVOC4mmRDbJvL3t25O0rPmW', 'user', 'Renzie Carl Escaro', '2023-0212', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5729, '2023-0196', 'nathaniel.falcunaya@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$uF2IIuaQiGUEXO1eNR5kTeu7RCmLQ2dGoyJle8I0q2v.5dnIHxhvW', 'user', 'Nathaniel Falcunaya', '2023-0196', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5731, '2023-0283', 'johndexter.gonzales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$RWWtQ4p9GQ9rKHuBK4J5Nu6m1CBKC8JzokoqtS3ALgwHfytWtK9X.', 'user', 'John Dexter Gonzales', '2023-0283', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5730, '2023-0292', 'kyzer.gonda@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$WzRv6ArOtGsErkPhOakAT.OdgTxdTmp4Bjo7Jc1X9y2aiSDQi8GBu', 'user', 'Kyzer Gonda', '2023-0292', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5727, '2023-0286', 'karlmarion.deleon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$W7HMKgbNGYqCxban7NArLOeneaH4aPcvF86YBUoSd5I12ZBlz/2Ry', 'user', 'Karl Marion De Leon', '2023-0286', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5726, '2023-0218', 'vitoel.curatcha@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$L3r8.OTU3fAzhIDnXyOfvuMgOkzPiGAn2IeS.sBAn2EwlKUmkP4G2', 'user', 'Vitoel Curatcha', '2023-0218', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5724, '2023-0273', 'marklester.baes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$TjWiTn.Cy3vWiMlCQy79.OxU94HN/kEp72ATz9vmZllgzV8sU.9aa', 'user', 'Mark Lester Baes', '2023-0273', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5720, '2023-0221', 'jamaicamickaela.villena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$1OLf/mKpkl039x.R8YgCzO4KL4giNpPE9g5aO8.XOLRRWPiFs0nMe', 'user', 'Jamaica Mickaela Villena', '2023-0221', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5725, '2023-0293', 'johnalbert.bastida@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$JH1027.4AWZEEJGar2GVmeJjIuL8HHFoowaa9du/mMRtzBVGfKMLq', 'user', 'John Albert Bastida', '2023-0293', 1, 'active', '2026-03-15 11:30:14', '2026-03-15 11:30:14', NULL),
(5722, '2023-0157', 'jay.aguilar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$9XpqeX3eh2IQUE6vCioHcOYsqEdENULNfuAdwbntpOPrl9JIQLFPS', 'user', 'Jay Aguilar', '2023-0157', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5723, '2023-0263', 'kencelwyn.algaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$uAe370laxIR0KIYaYTYoheMgHJA1ZBSsUzypW60atcvk8E9FblNgy', 'user', 'Ken Celwyn Algaba', '2023-0263', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5721, '2023-0268', 'monaliza.waing@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$OKlb5mTz/Gc.HLDZZ/CntOhzPdhbELHAvl6dGuBP1owiU5VGs.h6i', 'user', 'Monaliza Waing', '2023-0268', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5719, '2023-0344', 'angelbellie.vargas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$FP2xCOHppjfFVRIAzawxHe7xU7lcR82rswPggCR.No1vp/9Pye/Pq', 'user', 'Angel Bellie Vargas', '2023-0344', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5716, '2023-0208', 'paulyngrace.perez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zXxd3/Vr6L9OglDYnlEIdusHwvPs0wwkXFL71FkEEII3vojzT/hlG', 'user', 'Paulyn Grace Perez', '2023-0208', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5717, '2023-0181', 'shane.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$sK9.if6BtX7Qz2TxILteTebtppHmSNzRaruaH3sHRaUH1pIg6gEAK', 'user', 'Shane Ramos', '2023-0181', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5718, '2023-0566', 'andreachel.rivera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GSNQvBOzPwhdpiaEn7Yy1Omqr7LtKzNJyObw6NSJMYV07SqXBbvi.', 'user', 'Andrea Chel Rivera', '2023-0566', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5714, '2023-0242', 'shylyn.mansalapus@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$IC9driQg2EN5s.VVoKvX6Oz0cSV8NqwVxJqQezzj4J/tV3pypUA9.', 'user', 'Shylyn Mansalapus', '2023-0242', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5715, '2023-0291', 'irishmayroselle.nao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$u5gosxvK0yY/szhsuqXjee0TSWF4VpuceItzR03GVFLwgpdkxRB/C', 'user', 'Irish May Roselle Nao', '2023-0291', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5713, '2023-0198', 'shiloh.manhic@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$LtpX9FVYy75plWF2SK3UYe9Z3I2RCkPI3KvBpS4t6ub3zPqt60LFK', 'user', 'Shiloh Manhic', '2023-0198', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5712, '2023-0331', 'geraldine.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ti/IC/cmJoQj9fGaMio7x.9FEi9cy6A3/9lXdNaNfKBEyZnKeinhG', 'user', 'Geraldine Manalo', '2023-0331', 1, 'active', '2026-03-15 11:30:13', '2026-03-15 11:30:13', NULL),
(5711, '2023-0216', 'cristine.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$C7/upXkRF7bfXdJfvepVxOo3rqL7U69QpUGcrZVI9vY9LFux3fxWO', 'user', 'Cristine Manalo', '2023-0216', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5710, '2023-0156', 'irishkaryl.magcamit@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wrOjlyMxG5b7hcbFA.mae.j.l1LEExcrwAEBAHhN5MGrD4hO4yGaS', 'user', 'Irish Karyl Magcamit', '2023-0156', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5709, '2023-0204', 'clarissa.feudo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$prtgoSgjAaacMGNlPUNrvenUZeZhqpeJ5br32uLYr2d8NJ5x5mFiC', 'user', 'Clarissa Feudo', '2023-0204', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5708, '2023-0320', 'sherlyn.festin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$WtJBIexrkZR2zkXWpjlufuObCeiPbcsYr8kdaybH382TqoyeuwNyq', 'user', 'Sherlyn Festin', '2023-0320', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5707, '2023-0154', 'bea.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zR2lMgxL1xtE5.No6CzgZuDrJLYdjlITyzemlQf8BnEW9Ag/6ctJa', 'user', 'Bea Fajardo', '2023-0154', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5706, '2023-0155', 'kc.delaroca@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wc8keY50bB2Ig2U8o8E7.Obo4Ggfgm1ZpARfvctmvmbRJM0fhy4Vu', 'user', 'KC Dela Roca', '2023-0155', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5705, '2023-0270', 'hiedie.claus@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ErIQbR6d0o/Oh1dijmrMV.sCA3ck9T9vX/Fe2f/SzYrb8mIMj38Bm', 'user', 'Hiedie Claus', '2023-0270', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5704, '2023-0219', 'jescamae.chavez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jpjwOlN16uuNHDsUdjo03OttcwK/.L.VH8b9uKpRvaR6A1q.TYfa.', 'user', 'Jesca Mae Chavez', '2023-0219', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5701, '2023-0297', 'johnrick.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$NuH/ygfdalZngM0su018.OVupNxwK6ijwEgtBsB3MKRNTX8IhrfRm', 'user', 'John Rick Ramos', '2023-0297', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5702, '2023-0220', 'rezlynjhoy.aguba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$MCQ5bbOlMbkvKT3ncJ14ge61taBH0mWGg/1dxCfePOztloT73dfn2', 'user', 'Rezlyn Jhoy Aguba', '2023-0220', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5703, '2023-0153', 'lyzel.bool@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$UaPk.OC50p/qmCkMRLX5QObA5muPLQzUTG/jpaf8kTDhhyafmzVqe', 'user', 'Lyzel Bool', '2023-0153', 1, 'active', '2026-03-15 11:30:12', '2026-03-15 11:30:12', NULL),
(5700, '2023-0182', 'bryan.peaescosa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$/8ReeWixhFZ76PuDN6iOQOQiwRdcR/q0x3pzy5LzQfO0viTkNcfHu', 'user', 'Bryan Peñaescosa', '2023-0182', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5698, '2023-0236', 'moises.delossantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$IZ9EoEJ4bZszL6Gch.PI9eXeACxbAUDhomoNnIVap597263n1AqMS', 'user', 'Moises Delos Santos', '2023-0236', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5699, '2023-0226', 'philip.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$cTSEuq4.m.PbKLzTq.xijemQz4gpLG5HQ2Mu7bsnECi5W.7R0bY6u', 'user', 'Philip Garcia', '2023-0226', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5697, '2023-0301', 'justin.como@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$fiZaTrY.3OKuqvtxjPDxEOuo2KvH9PdM1X0/xEDPs2cNG20LzP54u', 'user', 'Justin Como', '2023-0301', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5696, '2023-0179', 'johncarlo.chiquito@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$TTHCVXcaI.SfwBIZ31lP.OzytIN5UwFL3TOcvvDmgckA3taKtkYUS', 'user', 'John Carlo Chiquito', '2023-0179', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5695, '2023-0290', 'reniel.borja@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$lofzDZlnH4ziB70W4SY7aOUpuN1ZNJLeXwnMBPZyG/KvLmBDF/KCW', 'user', 'Reniel Borja', '2023-0290', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5694, '2023-0277', 'johnlloyddavid.amido@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Ka4hiCAGHZYU0RZK8u1tq.c5IwufWMe5xFkaJXA5LI03mRgpfatZy', 'user', 'John Lloyd David Amido', '2023-0277', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5691, '2023-0341', 'jamaicarose.sarabia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Z//qdWJJ/TiHfy2z7pJ.C.TT8vTyKqdytdM0lTsTjBhwEeP.2.tFe', 'user', 'Jamaica Rose Sarabia', '2023-0341', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5692, '2023-0194', 'nicole.villafranca@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$7.QW9w1MSdfxz1.4BCsuTeMIkAXgZCFm2OvcOMaRg0LKsg21LiFdq', 'user', 'Nicole Villafranca', '2023-0194', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5693, '2023-0203', 'jennylyn.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DpQO/KLpkYQR9fuOGBiA1ORhDDYQQuQrxr.3UAarjXJfDJRvYpzOu', 'user', 'Jennylyn Villanueva', '2023-0203', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5690, '2023-0184', 'angeljoy.sanchez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ZBQa83SjV2IVL8I9vmi8weKBYGv3YM.DPh1mGjcH9wHh0klyd2Qgi', 'user', 'Angel Joy Sanchez', '2023-0184', 1, 'active', '2026-03-15 11:30:11', '2026-03-15 11:30:11', NULL),
(5689, '2023-0340', 'geselle.rivas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$5o1LN4hYsFJORcpFPAq1N.a7G0LfpZ0r0p3bVoIzfkVFMEutLiRxu', 'user', 'Geselle Rivas', '2023-0340', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5687, '2023-0247', 'manilyn.narca@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Wf3scuP9e8g1crM4PAoAI.7kPxFAG8Dqx0JRQ.8VJ1TPwGF3IA2Fe', 'user', 'Manilyn Narca', '2023-0247', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5688, '2023-0211', 'sharahmae.ojales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$YprKxmNfOBK2jZQiWWavWugiNAgj82HOeCHs9SWYn0ZI2B1y/eV2y', 'user', 'Sharah Mae Ojales', '2023-0211', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5684, '2023-0191', 'mariaeliza.magsisi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$V93N4qZ4vDWatUMFn6sAuOFZRsj.JlEyi.v4fI5f9fDqq.baHJBG2', 'user', 'Maria Eliza Magsisi', '2023-0191', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5685, '2023-0227', 'carlajoy.matira@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GzfET/5EQgSZsE61.FAbl.rFLWzXQW792MF5UO.aQCQkVDWiMXYB2', 'user', 'Carla Joy Matira', '2023-0227', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5686, '2023-0163', 'allysamae.mirasol@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0ufGc2m8Pm1tKP8yQGjMXeJ4UmZwkpKjXTdNDxpX2NGX1DUchrT/y', 'user', 'Allysa Mae Mirasol', '2023-0163', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5682, '2023-0189', 'vanessanicole.latoga@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$n7HkNlOaDQ0HCJzDJxZK0Ob8RFyqjNdyLYRJBTr9lwt3j.KbEBA4a', 'user', 'Vanessa Nicole Latoga', '2023-0189', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5683, '2023-0262', 'alwena.madrigal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PKUmqmRyxfNeQs1ovR7OCu3BK6fioDMn4McpBUhG6qEJjAib1QIre', 'user', 'Alwena Madrigal', '2023-0262', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5681, '2023-0197', 'mikaelam.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$xHbH.saj3FGDNSCMApM.f.whPo84WOdTDVI7.0hSHVCsZfDiaL7z2', 'user', 'Mikaela M Hernandez', '2023-0197', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5680, '2023-0296', 'jasmine.gayao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4n8PwFIFrG3M7Nmcc56Eued28Mj6S6I58u4ElMCczfxQWmD07vWZe', 'user', 'Jasmine Gayao', '2023-0296', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5678, '2023-0287', 'ayessajhoy.gaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$FthzWL5esFFEbSf6I7/.RuR0DEfz65WAJLpoApVFABOMZYuBfAFDW', 'user', 'Ayessa Jhoy Gaba', '2023-0287', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5679, '2023-0193', 'margie.gatilo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$hOonrkdgnhCOyUwSKVodv.tJDwReodfq/NXiQpKw2wRp4kvzMr1LG', 'user', 'Margie Gatilo', '2023-0193', 1, 'active', '2026-03-15 11:30:10', '2026-03-15 11:30:10', NULL),
(5677, '2023-0137', 'krisnahjoy.dorias@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$V9SLJ01jnjCztXJTudBwGuAHz4S8znlJDOuG.P9QSWJ.9.spJncD6', 'user', 'Krisnah Joy Dorias', '2023-0137', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5675, '2023-0257', 'rocelyn.delarosa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$LXAMi1EWdtMEI0KnyIwXTuVMWqUz8g13sfWxqDSD/jSOO/lXxSANa', 'user', 'Rocelyn Dela Rosa', '2023-0257', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5676, '2023-0256', 'ronalynpaulita.delarosa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ZDc0KueolJrwNtyib6RSaOlqY1Yrmt7RItyxYt7STkW45l8C1SctG', 'user', 'Ronalyn Paulita Dela Rosa', '2023-0256', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5674, '2023-0172', 'lorebel.deleon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$yc85P.iBnYk6yFGdfM5Cue803XCeF7p0ZvpFCRahFzWJrKZ0Rg1JG', 'user', 'Lorebel De Leon', '2023-0172', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5673, '2023-0266', 'angelann.delara@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$6qMGNmuzNIpIEcfZ6B4KDOmD/Qu713MzG2ljok9slo2Yvd3ixwhgG', 'user', 'Angel Ann De Lara', '2023-0266', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5672, '2023-0199', '.declaroalexajanec@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$OuBYU4yjbNP7.fAgb8JzoOHSw4ozj34qds.83m0UR/7z4g/ll6ibS', 'user', ' De Claro Alexa Jane C.', '2023-0199', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5670, '2023-0192', 'arlyn.corona@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ptVqDxR2vYkcPlU77WmgPuLRsCeaKg9xXshAok61RTfjU2FwRJwWm', 'user', 'Arlyn Corona', '2023-0192', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5671, '2023-0185', 'stacyanne.cortez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$IVljLuJxggUkxmUbORWYfej6TNSejthsz5ZL.jBFm.iKv8TC4looC', 'user', 'Stacy Anne Cortez', '2023-0185', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5669, '2023-0272', 'christinerose.catapang@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4NE.0OaOpbMYCGYHrIBrJ.lW6ujq9l3CuayOHuwrPKnBjduoEdxvO', 'user', 'Christine Rose Catapang', '2023-0272', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5668, '2023-0228', 'joann.carandan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$FXCHiS.mDG0ZvJOHtsExveepW1qZOlhXVK.3vmzECikOGr4ifX2aq', 'user', 'Joann Carandan', '2023-0228', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5665, '2023-0188', 'janashley.bonado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$bbbJmf5W/X.Hkyy1ITScLe.8ip53yO1d.3puR2z9ysv0Uhpm0akfm', 'user', 'Jan Ashley Bonado', '2023-0188', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5666, '2023-0202', 'robelyn.bonado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$a/YrKYnkFdVaBy1iRsiPXeD80A/OZ5OlEs5jX.o4HDsCT6CPjMuHm', 'user', 'Robelyn Bonado', '2023-0202', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5667, '2023-0253', 'princes.capote@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Ys48Rl/OeS2tk.4.bCdKQOfFDN.fIS4uTVoMym03JWJzrgZFf1EyK', 'user', 'Princes Capote', '2023-0253', 1, 'active', '2026-03-15 11:30:09', '2026-03-15 11:30:09', NULL),
(5662, '2023-0295', 'king.saranillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$uEP8/bkZ3d72zrxzKlAxkOfUi7xrbVam5QlB7A2gA3Um1uioRxRnm', 'user', 'King Saranillo', '2023-0295', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5663, '2023-0260', 'jhonlaurence.victoriano@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iSFN7P2Zrwj5gyw.JFynf.dvWEDN72kcZ1cMAqe9Rpef3laN8EpzW', 'user', 'Jhon Laurence Victoriano', '2023-0260', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5664, '2023-0210', 'janelle.absin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$xHgbjKtM5v0T2b/J00NnvemnpSrwyZDf2kQ4RrqTDmLC5jxuEy48a', 'user', 'Janelle Absin', '2023-0210', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5661, '2023-0300', 'johncarl.pedragoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3koOVG5Lo2v9zqF/armKoOCIyB5w/9Z2GuDQAkXsPF/e1YEEo8aom', 'user', 'John Carl Pedragoza', '2023-0300', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5658, '2023-0213', 'jerome.mauro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DOA0iSkc3FcfMZygba5LQOW6HfkQH/r8u9tpZUhCzidvo52/LheLC', 'user', 'Jerome Mauro', '2023-0213', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5659, '2023-0279', 'jundell.morales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$aOmrb9W1nS3FqZmkhRvdduV3noWkKeqcY/5Bc1m.2w/SDsDt9Mwt2', 'user', 'Jundell Morales', '2023-0279', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5660, '2023-0171', 'adrian.pampilo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$NVkeDbEJDlzwZ4zBK6/0QOjOkEArqeLLZr6IMKL9RsVBLbcZO0NEC', 'user', 'Adrian Pampilo', '2023-0171', 1, 'active', '2026-03-15 11:30:08', '2026-03-15 11:30:08', NULL),
(5657, '2023-0333', 'melvicjohn.magsino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$mrpB9laV8WsO9DGa8Z6BiOl0qKhw6Bh7wEWu/dj1YWs3o.OHlMsQ2', 'user', 'Melvic John Magsino', '2023-0333', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5656, '2023-0223', 'jeshlerclifford.gervacio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$xvDfg/I0N4HURjM2.lzUmOOFmdyRcuuTHJBJUq6.zDjm3d7mGEqFu', 'user', 'Jeshler Clifford Gervacio', '2023-0223', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5654, '2023-0159', 'johnpaul.freyra@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$pMaSNw2QNT4Z8MTXY8ua3emcWHn.nRffUQ4HgY70nJhA3PRql2/we', 'user', 'John Paul Freyra', '2023-0159', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5655, '2023-0258', 'ryan.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$nMmeZ7qzmXmfsoGgFBXX9.BiFuk3PwRJJnUm4nWHcepusBMQXfqOq', 'user', 'Ryan Garcia', '2023-0258', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5652, '2023-0313', 'carljohn.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Cpx1xdC4v7Iy0Hgtr6Dpe.p9Q.J66sHt2kSAnn3gcD3oYPPtv1LGa', 'user', 'Carl John Evangelista', '2023-0313', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5653, '2023-0274', 'monlester.faner@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$SeidW.2BQyq5sk05TAIaHunznFUr8dMZgQT73vreOsbNP4u.Pu8ba', 'user', 'Mon Lester Faner', '2023-0274', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5650, '2023-0209', 'johnrussel.bolaos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$uhYmeTZUvVByXvMPn9mjzeMUwi4uAoCJ4iFveAH0LYFnqx0nu0CIm', 'user', 'John Russel Bolaños', '2023-0209', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5651, '2023-0166', 'justinejames.delacruz@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Fgou.SjlC71ABEDH7VJXo.0FJNMadQON32efR8djlyQAb4pcS3mPy', 'user', 'Justine James Dela Cruz', '2023-0166', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5649, '2023-0261', 'johnmark.balmes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$bXr4w10mraa.Odctt7Ix/uNkDfFgn5h8fZjNQ4IdStiogUR7v4.Hi', 'user', 'John Mark Balmes', '2023-0261', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5648, '2023-0284', 'monandrei.bae@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$aKUEHTSVVTGp/dMI0Cg0TeAHt5Wcya7hmbYRYADWZy1r7oHJuJyM2', 'user', 'Mon Andrei Bae', '2023-0284', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5647, '2023-0150', 'ralfjenvher.atienza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Q8Xj.MoNzLXDEdALDWDd5eWGZIy0EFdzRKTtwyiZ6oU8K.fZz3iHG', 'user', 'Ralf Jenvher Atienza', '2023-0150', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5646, '2023-0309', 'jordan.abeleda@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$xYRg50jbPmnIpZrH89M37.X.bvD1ixqTGolEWfWo0CnUzUQqqUc7m', 'user', 'Jordan Abeleda', '2023-0309', 1, 'active', '2026-03-15 11:30:07', '2026-03-15 11:30:07', NULL),
(5645, '2023-0299', 'maryjoy.sim@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jrmdXcIyQ6W5S7tZfIXkWOOfoe4p78Ha8H0TRKo49LtX1aBazhsGq', 'user', 'Mary Joy Sim', '2023-0299', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5642, '2023-0322', 'joel.villena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Tvc88eAmO5y00YjKVZcAZ.SdtZjJUSKLjev6tLyAdemDAzDtNVDyC', 'user', 'Joel Villena', '2023-0322', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5644, '2023-0240', 'jenny.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GF0VhNCA5zeBv0oNayMQy.YdyGWEieMnbIq86.pCjoHygar3Buyum', 'user', 'Jenny Fajardo', '2023-0240', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5643, '2023-0248', 'jazzleirish.cudiamat@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jsrtA4OVXnB9VqsVb44fGuPCWqHsduNQZMPf7E432l//S2s0XEVA.', 'user', 'Jazzle Irish Cudiamat', '2023-0248', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5641, '2023-0255', 'jayson.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$eKtELAQnmZaT5gLffNt1xOU996pzcrFlcHL59sOngm1ypzuvJMMeC', 'user', 'Jayson Ramos', '2023-0255', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5640, '2023-0308', 'johnkhim.moreno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$kJoaSVJi73nEC.GR9VK6SOAfolRuPFSqKF9i.rEa1K3ZeliwoQOoe', 'user', 'John Khim Moreno', '2023-0308', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5639, '2023-0332', 'michael.magat@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qwCsiJLYTM5RLpKFATTkbOahuBhN7ik/15db3MEg3GKosxc5YppxC', 'user', 'Michael Magat', '2023-0332', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5638, '2023-0243', 'kianvash.gale@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$QwropxDvknfWS2WB09JRSOpkX8VFvJZjw3CbbfudrVbmcLrZfVU8y', 'user', 'Kian Vash Gale', '2023-0243', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5637, '2023-0249', 'marklyndon.fransisco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Ybb0qU2AVMJK195uzZnZm.XnDSPSIiQZl7aLm.FoVXOEhwM3C3cqC', 'user', 'Mark Lyndon Fransisco', '2023-0249', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5635, '2023-0167', 'mclowell.fabellon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jmLLLB7NvULFWFmHStjNmu/6WbwwX5Ee3D2BWPpNDur8OIUvL0ScW', 'user', 'Mc Lowell Fabellon', '2023-0167', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5636, '2023-0177', 'johnpaul.fernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4ccxGfNFKEyszE1kNTTy1.WLNZ6i8Cppx8qbJYCOPw3F/HXP2cklW', 'user', 'John Paul Fernandez', '2023-0177', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5633, '2023-1080', 'marklee.dalay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$QunGSHTCbY1IMEYoIRPOfe6oMtArGgsAnGDCsMRhdbjjmWixxaw2i', 'user', 'Mark Lee Dalay', '2023-1080', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5634, '2023-0239', 'adrian.dilao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$V/LKUqAr.VGG591YPih75uZxLgZ4vVj7fQJbSj8bTR8jhdAHYRcVi', 'user', 'Adrian Dilao', '2023-0239', 1, 'active', '2026-03-15 11:30:06', '2026-03-15 11:30:06', NULL),
(5632, '2023-0233', 'jorizcezar.collado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$cFNwpdur/rZWHjlartq87OmqOmuANUb4QHVdQYMXT2GOy/v1WU7YS', 'user', 'Joriz Cezar Collado', '2023-0233', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5631, '2023-0345', 'sherwin.calibot@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$bB.bKDlBBSFLMtJzpFbdg.8q9loVFdVMfHM.EpEfr9w4lZ2uOMj7S', 'user', 'Sherwin Calibot', '2023-0345', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5630, '2023-0336', 'jhonjerald.acojedo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$/7tht0UAaPdt6kKaYqswdu.T9qcOAVbW1SfZR9UC7FQuGtBZUTx5.', 'user', 'Jhon Jerald Acojedo', '2023-0336', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5629, '2023-0241', 'lyn.velasquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$VgvQ5aFnGrrjcJukG3bkeeJQ42E90Ly7nQqttzhz4MT2lKteKANAW', 'user', 'Lyn Velasquez', '2023-0241', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5627, '2023-0173', 'lailin.obando@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qVM1Azz4wyrvgnbZbMMRP.Gx19RsZd.XPzuJQKQ60l7D0H0QqJSO6', 'user', 'Lailin Obando', '2023-0173', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5628, '2023-0303', 'kyla.rucio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Q5uPCbqDAF13ULrW9Z23uOzp2zEuEDX4pbiauD9tm2MNZeD5aeToq', 'user', 'Kyla Rucio', '2023-0303', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5625, '2023-0225', 'genesismae.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4/y8MikCO46HfxWshFc5VONn.e5jNJx97cYSZw1Z1X4kmP8hzbTXq', 'user', 'Genesis Mae Mendoza', '2023-0225', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5626, '2023-0224', 'marian.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$KW9A0xou1XcUrU86DlnSHO57cedPbrAETdvR.3tmTqsa0J8WrwVx6', 'user', 'Marian Mendoza', '2023-0224', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5624, '2023-0285', 'maan.masangkay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$V438CQVwItDkQZrs1cyAyuM/YhuRuh.LM8gHl26cWkiVnccIlYOrG', 'user', 'Maan Masangkay', '2023-0285', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5623, '2023-0215', 'judyann.madrigal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$kMvVAdw39R8DZ57U7BH65uU7AoN.Si0WYhuLGH8m1JjTgMXSGReIu', 'user', 'Judy Ann Madrigal', '2023-0215', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5621, '2023-0298', 'laila.limun@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$FkJcbGP8egx5/I0/t8Sz6eBMpaUoZQEHB72Tzt2AQpvUIVD7ViIGa', 'user', 'Laila Limun', '2023-0298', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5622, '2023-0244', 'jennievee.lopez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$MY1c0tkrEOINKhGwugJ2Aeu6m2KjewpK/FyLXY.kpcyPSHimkB4xy', 'user', 'Jennie Vee Lopez', '2023-0244', 1, 'active', '2026-03-15 11:30:05', '2026-03-15 11:30:05', NULL),
(5617, '2023-0161', 'babyanhmarie.godoy@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$To6du9k6RtkjEw63YSA2.OcCK0FNjReeKPsf4.nhAz/gNfYUAE.T6', 'user', 'Baby Anh Marie Godoy', '2023-0161', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5620, '2023-0251', 'angielene.landicho@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$5VGC2aIwC9T./iHHq5fFQen07HbW03ncKT43qzHxvUarsogckphFq', 'user', 'Angielene Landicho', '2023-0251', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5619, '2023-0200', 'zyra.gutierrez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$nmVAnp/yTmQcQpb.KsguMuunABUbm3E580UyAvgYzak6jyb1/e60e', 'user', 'Zyra Gutierrez', '2023-0200', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5618, '2023-0169', 'herjane.gozar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wWhm.fhg2lgrzVseXDBeN.E0STfwdD3nkqZxaLp07aNIjGxj9eNdW', 'user', 'Herjane Gozar', '2023-0169', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5616, '2023-0317', 'jeanlyn.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$whE2noLdhQucKF6E47mnR.yQN4s9SsHvqZ8W0Yf96dHRBI92Fae6a', 'user', 'Jeanlyn Garcia', '2023-0317', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5615, '2023-0305', 'jaimeelizabeth.evora@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$yKeAYBk7A7zgUkIpPpMvyue3opfTyt5uMiRzBBfRc7dZ.SX4KQ.Xm', 'user', 'Jaime Elizabeth Evora', '2023-0305', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5612, '2023-0327', 'juvylyn.basa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$cPS4WnQ7wWj8jG2s2qaoKuQuk.nqXEADn0oLE0ULOCwLwnM.IcBwy', 'user', 'Juvylyn Basa', '2023-0327', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5613, '2022-0088', 'rashele.delgaco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$e9S5o7U.zpqGnJiancZgruRNLc4jUgfLxHWASSun./sU0gpMSQO2a', 'user', 'Rashele Delgaco', '2022-0088', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5614, '2023-0288', 'cristaljean.dechusa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$cHPdGT8fwdjDM7YHV0zEJ./qZWJRHKeKl1xBhGyWHfBdfan.bg3MW', 'user', 'Cristal Jean De Chusa', '2023-0288', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5611, '2023-0337', 'leica.banila@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$mXIuF/7io/fUh3tsXRBS1uqQz.5gIZDHGzAqrkty1iXVEPpr8HMfG', 'user', 'Leica Banila', '2023-0337', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5608, '2024-0406', 'gerson.urdanza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Lf54T6KEvUHThSfSnZdgvOR2CvY3EYXa1qFDgfbe6omKUrCbnfXaG', 'user', 'Gerson Urdanza', '2024-0406', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5610, '2023-0304', 'jonahrhyza.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Wd0LSUCZsqg1eXlCh10NIuSJ4vMkFzCv0Qc0GFMrZtsR1OGwlX95u', 'user', 'Jonah Rhyza Anyayahan', '2023-0304', 1, 'active', '2026-03-15 11:30:04', '2026-03-15 11:30:04', NULL),
(5609, '2024-0397', 'jyrus.ylagan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$pQrBUJHB1MePHirVJhBSnOczFvxBHadG/f6nyOWyGzhGjMY/cLi8q', 'user', 'Jyrus Ylagan', '2024-0397', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5607, '2024-0408', 'jerus.savariz@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$gE6X5XEJa5n4UfLxfUlrdOdodKXycl2zRjnrUY1ApkSUKuOLvE0Y2', 'user', 'Jerus Savariz', '2024-0408', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5606, '2024-0423', 'benjaminjr.sarvida@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$CU3YcZWvHTK1k8P9nlsp/uZ.HnonqeAVdW.WS6r.PfSnefXejVYPC', 'user', 'Benjamin Jr. Sarvida', '2024-0423', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5605, '2024-0580', 'merwin.santos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DyC7q6IP.OJvbzXnrvwRQuLIFPcxNiD8Orr5jO/Z3YiFyEOZUtA9W', 'user', 'Merwin Santos', '2024-0580', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5603, '2024-0436', 'jhezreel.pastorfide@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zCAHvM8MpRLRpg8M84rTnuR8lOvAI1jleYuwOsvKhfddIHSiJrIQ6', 'user', 'Jhezreel Pastorfide', '2024-0436', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5604, '2024-0578', 'mattraphael.reyes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GE1gkghYs7kk3qZZ9reA6Ol2Kpw0EefkQ01C4TX/NebydFlWSxtFu', 'user', 'Matt Raphael Reyes', '2024-0578', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5601, '2024-0393', 'amielgeronne.pantua@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$9P4Acn3EKtUKS4umqidgC.XUyE7lpIIfqR/1NH.RzxwZUbkg1WthG', 'user', 'Amiel Geronne Pantua', '2024-0393', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5602, '2024-0392', 'jameslorence.paradijas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$8E3mhtc2YfjhyRhy3z314e4D3N/M2VCq9kxp1TPSCJWnG7XxyBahO', 'user', 'James Lorence Paradijas', '2024-0392', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5600, '2024-0428', 'christian.moreno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$SJ8CG0K5jfQ82qiZEM6leuigV4U.nB5EJDmW.6u4s34WU/QG0zN3.', 'user', 'Christian Moreno', '2024-0428', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5598, '2024-0394', 'carlo.mondragon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$kHNppdOTB702RUbIEXtlNe22YRxmS77IfPyAJi/LXUb/K66BR.XKm', 'user', 'Carlo Mondragon', '2024-0394', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL);
INSERT INTO `users` (`id`, `username`, `email`, `google_id`, `facebook_id`, `profile_picture`, `password`, `role`, `full_name`, `student_id`, `is_active`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(5599, '2024-0410', 'johnrexcel.montianto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Y0gSTZ3V0OYO1Z3IWf5DLO79Y3KtDKFDzDpXLMDxu2qB.zbrfF/eq', 'user', 'John Rexcel Montianto', '2024-0410', 1, 'active', '2026-03-15 11:30:03', '2026-03-15 11:30:03', NULL),
(5596, '2023-0465', 'patrick.matanguihan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$mLRrqWJgjKORx0KRH7baM./JSw.Dvv2lZNK7jZWfgGCIhKKwt36o.', 'user', 'Patrick Matanguihan', '2023-0465', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5597, '2024-0478', 'dranzel.miranda@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$vdc3kuRtzy9TfKEl.8FoB.57zCOAh6gOxIyG2A7uTPivksucpS7BG', 'user', 'Dranzel Miranda', '2024-0478', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5595, '2024-0395', 'florence.macalelong@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$cIZwAQxxFBIqwbZbdM8s7eecv67TVadIQGmQJcW91KmnKjWGXFcE2', 'user', 'Florence Macalelong', '2024-0395', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5594, '2023-0151', 'ramcil.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wYnsVPP7NdW1ozOtXljdjeFPSEB9XxpnUmepWHkPXWlW81YMFC6VO', 'user', 'Ramcil Macapuno', '2023-0151', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5593, '2024-0420', 'miklo.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ksitWiEFAozkPfJSNea2T.KgLHQjfgD.LUNG1Q8l4fVlEEs0yJ9DW', 'user', 'Miklo Lumanglas', '2024-0420', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5592, '2024-0517', 'gino.genabe@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$tV8SiO3ZVlYOgY9dbQZjDuP1EylbdeUtpL.4UO7acUfslAAcz6riC', 'user', 'Gino Genabe', '2024-0517', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5590, '2023-0447', 'charlesdarwin.dimailig@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$CvI6ZxMp89zDUGWtT2ONzeJs1mn7qGasC62bwoPr8lh3IuuVbN3Ai', 'user', 'Charles Darwin Dimailig', '2023-0447', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5591, '2024-0413', 'airon.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$1lnpl39brzLF/H/UUNLsweGZkLGdiaqk11kh.dseA8faCz0sSTkLW', 'user', 'Airon Evangelista', '2024-0413', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5588, '2024-0561', 'alvin.corona@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$WGyX/TC.l1paGbVVs6eXCOb62i/Y//OZldIp8HhA/J1i7Spp5WxXy', 'user', 'Alvin Corona', '2024-0561', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5589, '2023-0407', 'markjanssen.cueto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Y4jgy8n.fSbSAcg4ALERxucJa5hz4UYCqBARfwH2iAzEkAtClCpzu', 'user', 'Mark Janssen Cueto', '2023-0407', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5586, '2024-0398', 'raphael.bugayong@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$OKJuyyJ.oS0/vPYV7dfv0OK0MVFCWqpse53c9Kbz6AK9k0Tl0fM0e', 'user', 'Raphael Bugayong', '2024-0398', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5587, '2024-0572', 'markjayson.bunag@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$rtztPSZPXn/GaHvHdqMGNeAJ2c1t9BpImpws6MZgv0y59ZvqKV4Qi', 'user', 'Mark Jayson Bunag', '2024-0572', 1, 'active', '2026-03-15 11:30:02', '2026-03-15 11:30:02', NULL),
(5585, '2024-0043', 'johnkennethjoseph.balansag@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$7TdVBMAG2YAZAsIjJneMw.y3IneM8CiOfwtv7g6mpVrFh5nKo4gge', 'user', 'John Kenneth Joseph Balansag', '2024-0043', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5584, '2023-0519', 'johnmichael.bacsa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$L241R3zjcDW/9oBWHCvHm.V.UfeavkwNDrxT70wLuONaHUFLefKbm', 'user', 'John Michael Bacsa', '2023-0519', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5583, '2023-0433', 'romelyn.rocha@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$H7.hV60PxOf8aMGdjvKNe.8QbujD1D7EbBJXB47rj4R0WYLuN50Hu', 'user', 'Romelyn Rocha', '2023-0433', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5580, '2024-0348', 'myzell.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$nmS59V/JGDLkH27g.rl76.DV75WsX5slq5Z.fZGzU4.xQHMcnlfru', 'user', 'Myzell Ramos', '2024-0348', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5581, '2024-0582', 'shellamae.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jB3mplp2c8wRPt1PmRloeu4rXAcPdffN2imrPJC2KYTo76iNaClwm', 'user', 'Shella Mae Ramos', '2024-0582', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5582, '2024-0426', 'desiree.raymundo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$BI71sjRbnze7JOAZi9RiPey3TSa59kgCrPbQhH9YWHtPwjdhhgyv.', 'user', 'Desiree Raymundo', '2024-0426', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5577, '2024-0412', 'gracecell.manibo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$dtpeY922n5N.O9DQgchBCOJjnltfac6nyPUXW.3v41mBlakaVPKja', 'user', 'Grace Cell Manibo', '2024-0412', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5578, '2024-0571', 'lovelyn.marcos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$RABVmEooYEgqOfIhK0yMA.1eKYqUDkI0AzDDU7NkETkx0x1fnp4nG', 'user', 'Lovelyn Marcos', '2024-0571', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5579, '2024-0314', 'shennamarie.obando@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$YV/VR2QvLjYIzuieKCEAnu.ygNuSDMUIquZKajYPegAPRIK/aNy3.', 'user', 'Shenna Marie Obando', '2024-0314', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5576, '2024-0472', 'keyceljoy.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.I09ytn17zhZzEEEFkahFOVYR79rKnFP42jserCnt4cCwTLXVx6um', 'user', 'Keycel Joy Manalo', '2024-0472', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5574, '2024-0544', 'ariane.magboo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Q.KsCFpTRetw.CeHF5WJH.b.hzjyO8TxwzDluGyb5ujKOAcrkJxJO', 'user', 'Ariane Magboo', '2024-0544', 1, 'active', '2026-03-15 11:30:00', '2026-03-15 11:30:00', NULL),
(5575, '2024-0415', 'nerissa.magsisi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wlbTQDD7Z0AOTbqTPE86iu16iOfUGDr2wkBVR0OaosIMIIknNK6ZG', 'user', 'Nerissa Magsisi', '2024-0415', 1, 'active', '2026-03-15 11:30:01', '2026-03-15 11:30:01', NULL),
(5571, '2024-0422', 'jayann.jamilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Gx44UUIyD5XPycS0cA8qXehBX1loJsNbnsva0bF52m88OF4SkZn2m', 'user', 'Jay-Ann Jamilla', '2024-0422', 1, 'active', '2026-03-15 11:30:00', '2026-03-15 11:30:00', NULL),
(5572, '2024-0416', 'mikaelajoy.layson@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zq5VugeZgJV/sDrhNtZn6OvrQ2sW1ACwyKHsX.TOzdaZ61BIotqri', 'user', 'Mikaela Joy Layson', '2024-0416', 1, 'active', '2026-03-15 11:30:00', '2026-03-15 11:30:00', NULL),
(5573, '2024-0427', 'christinejoy.lomio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$MGl2ZbAAX8sTtw6bhnEExOct8UscA9ca4dksYpjxjCGtVsv6qYfEi', 'user', 'Christine Joy Lomio', '2024-0427', 1, 'active', '2026-03-15 11:30:00', '2026-03-15 11:30:00', NULL),
(5570, '2024-0567', 'arlene.gaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DNZxXdjetyrNMhJRcC0yW.nFQdG7CPNH6IX28uhgsgB0M.3XDs6.6', 'user', 'Arlene Gaba', '2024-0567', 1, 'active', '2026-03-15 11:30:00', '2026-03-15 11:30:00', NULL),
(5568, '2024-0417', 'nesvita.dorias@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DWovzv/HXflmMA8WPWfL9O.bAyVE2/fOF50prbjJ1lHgfVSBQHILm', 'user', 'Nesvita Dorias', '2024-0417', 1, 'active', '2026-03-15 11:30:00', '2026-03-15 11:30:00', NULL),
(5569, '2024-0432', 'stellarey.flores@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$XUxHDV1FqyvdL/gaoWisZOvovpsjTzpIP6hrgR9tqFaBIjTfRbkFa', 'user', 'Stella Rey Flores', '2024-0432', 1, 'active', '2026-03-15 11:30:00', '2026-03-15 11:30:00', NULL),
(5567, '2024-0404', 'marina.deluzon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4Ez/.jSi3bPUq4BTL6vEyO6T1QoMKpeCugVg/qRwbZpI4OxQoXX92', 'user', 'Marina De Luzon', '2024-0404', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5566, '2024-0343', 'preciouscindy.deguzman@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0Ngemwi3GQiYYhhdVu.wKeePWMZR.wlmxoUQylq1zrsHmmjkpdBr.', 'user', 'Precious Cindy De Guzman', '2024-0343', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5565, '2024-0437', 'arjeanjoy.decastro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Gxcovk92V7JGGMJ14E9MpO65SPh5R3nB7J7WPEhgzN.ijx9mc2z3G', 'user', 'Arjean Joy De Castro', '2024-0437', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5564, '2024-0342', 'charlaine.debelen@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$f9sfCNPRGMGjN2NeEZOrWey3JMsrurEI4qx18CnZTiTf.TP9BL02G', 'user', 'Charlaine De Belen', '2024-0342', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5563, '2024-0424', 'princesshazel.cabasi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$M5qwmPraY2Gyz.przotc/.65Hqhcr6jwLGTquElMNQOHbG5YUq7oG', 'user', 'Princess Hazel Cabasi', '2024-0424', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5562, '2024-0418', 'ludelyn.belbes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.P5AcPPaOZME0y6llCdVz.Ui8SjC3.PQISQmgwzHeNTDGd0cHN6LW', 'user', 'Ludelyn Belbes', '2024-0418', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5559, '2024-0438', 'melsan.aday@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$LUiUdi28ewI4KNnoSpCCAuRbE9d2YAp9x/CDL4xA/T4CC/MlFOfCW', 'user', 'Melsan Aday', '2024-0438', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5561, '2024-0411', 'precious.apil@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jpCT/b9DdnzgVHzS9f.04.Pxk6woTT8Ff0yFf7yqshabtSY7zb.82', 'user', 'Precious Apil', '2024-0411', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5560, '2024-0405', 'jonice.alturas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ImHZe1nZXT4enU3VLVcYd.eC1tffeSrOyELBs6OoZtSfBfNGJFneO', 'user', 'Jonice Alturas', '2024-0405', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5558, '2025-0816', 'marshalhee.azucena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3gKPus0eCvoWxVlqwJwXBejfU/VCWo.TS8MjoAaIs7ml1jHbxPp2O', 'user', 'Marsha Lhee Azucena', '2025-0816', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5557, '2024-0492', 'djay.teriompo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iMUKjmQv1cGweLn9XEEd5uXJkk4gxwupVw6IjxK/RaI8MLx7yblWe', 'user', 'D-Jay Teriompo', '2024-0492', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5556, '2024-0523', 'ronald.taada@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$7/t7m.ng1J4XnWpvCji7EuLWs7dOG2GrNqoth0cyhe328vZWBDvrq', 'user', 'Ronald Tañada', '2024-0523', 1, 'active', '2026-03-15 11:29:59', '2026-03-15 11:29:59', NULL),
(5554, '2024-0386', 'aj.masangkay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$h0nvRRjh7xYOjVI3R/tMTenNYccDAXSU5mfMF/zuu2Yx1R2Ca6YDW', 'user', 'AJ Masangkay', '2024-0386', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5555, '2024-0480', 'johnpaul.roldan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Y4vmnQkFA0BmnUxPI.GiF.XfJfWqyLtpUUxSu/hVocO93sq1lIrT6', 'user', 'John Paul Roldan', '2024-0480', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5553, '2024-0525', 'jancarlo.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$vBXdm0Hay0ZOnZyZl1Z87OerMJQ.OYBfdsj4n.A7C3yVxD5CFJcQ.', 'user', 'Jan Carlo Manalo', '2024-0525', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5549, '2024-0365', 'lany.ylagan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$XFjq5a80wDNyuUB5Tsx8neXQsstR8vehZNMnmp3dmq2f6aDRU2VW2', 'user', 'Lany Ylagan', '2024-0365', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5552, '2024-0389', 'alex.magsisi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$20iY65rfVIkuUTmtULQAQOn0L2iotyjs0AxkaVyyksEuqd05GXbEK', 'user', 'Alex Magsisi', '2024-0389', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5551, '2024-0557', 'denniel.delossantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$41hoTdUvADxv/84EgvLoWOMzhZhGsg5lqrA2fy6w.0nMVuO7KIC.e', 'user', 'Denniel Delos Santos', '2024-0557', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5550, '2024-0373', 'marvin.caraig@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3odvz2bpn/sx7fi4E8SzWOP9xszx5tW54o/dH1NJNIb3nZoDOVSQS', 'user', 'Marvin Caraig', '2024-0373', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5548, '2024-0356', 'lesleyann.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GBDU8XcdZW4dq.Bs/lGijez9bHvLE7RbbeQDYx/GLXNxeqXYpjlAi', 'user', 'Lesley Ann Villanueva', '2024-0356', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5547, '2024-0556', 'jolie.tugmin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iPk0pU8UIbSviooAXoO6nedK8nrPwMx0izA2FAmxQy6VCix0hJDVS', 'user', 'Jolie Tugmin', '2024-0556', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5546, '2024-0453', 'cynthia.torres@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$l4fSjFJb6QLabGOWmoC1LOWcW8D5x1VbjgJcH6QKwxSR2aAk6mBRi', 'user', 'Cynthia Torres', '2024-0453', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5545, '2024-0451', 'maryjoy.sara@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$YedkITRqVh2J3/lfdTYrEe60GQN9KlAcQecCEfM9O3xBwL9cXicNK', 'user', 'Mary Joy Sara', '2024-0451', 1, 'active', '2026-03-15 11:29:58', '2026-03-15 11:29:58', NULL),
(5544, '2024-0509', 'edceljane.santillan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.rkY1UB0W/MTqIDJM9G.iOU2WHoVGbjKsaEgixbEQ/I9oUyPlHPIS', 'user', 'Edcel Jane Santillan', '2024-0509', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5542, '2024-0264', 'katrinat.rufino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$MS6sb0EKOxhSRzEgWRtMnenzoxwGonPmSJvgV/4GD8iJKSHlczCvO', 'user', 'Katrina T Rufino', '2024-0264', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5543, '2024-0382', 'niazyrene.sanchez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$sA3YdR7YDNvo1oY775ZexuyWJYjsZNsXJfTZaRz4kKk8wsJ26ufQ6', 'user', 'Niña Zyrene Sanchez', '2024-0382', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5539, '2024-0568', 'angela.papasin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$KmhVRJgVWYldjVQtDWAm/OD9nCM36mv1fylQXh0Bji1IafRxmyMQ6', 'user', 'Angela Papasin', '2024-0568', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5541, '2024-0380', 'jeyzelle.rellora@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$x0GMJ7vKC4oNi8laKzMDAuuSEbFjKcaSwn/VM45b3vtv7J1aT2p8C', 'user', 'Jeyzelle Rellora', '2024-0380', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5540, '2024-0359', 'jasmine.prangue@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Ux2WrLh64RsLRirea6418eo.WcR4xd.rVwrWfdxajt3h0aF5Y0hFm', 'user', 'Jasmine Prangue', '2024-0359', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5538, '2024-0350', 'hazelann.panganiban@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$5qHS5/E/J2sxdFZ6Fhx/3e3zEOIHOSVp4/lok/KD1La6ndJtIRroq', 'user', 'Hazel Ann Panganiban', '2024-0350', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5537, '2024-0384', 'margie.nuez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$U.mOtjxDnR4mhwl7UDSOuux4LQZVU58g9FNWPMoNENmvYkwEJMcMa', 'user', 'Margie Nuñez', '2024-0384', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5536, '2024-0377', 'cheresegelyn.nao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$EGZ.38DavBRPlJq9y/EGAu.z0GLQlLM3icc1ZmQQ0fH7pdBJcqO3O', 'user', 'Cherese Gelyn Nao', '2024-0377', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5534, '2024-0586', 'rexymae.mingo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$FvZXNHWi8o8YSdEUk1qjBezd9g2CLLCMKdQHVHIkhnsf91n9ePere', 'user', 'Rexy Mae Mingo', '2024-0586', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5535, '2024-0349', 'preciousnicole.moya@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$yDmD6WPhVQhxBCPNFbAgXOb/4VgVN/wuTW8D1c5uG.3BD497klbPa', 'user', 'Precious Nicole Moya', '2024-0349', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5531, '2024-0391', 'kriselleann.mabuti@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wVga7S5Uto0TaU/uB0loDO1sLigXUQ7/b0u/55u3/yQJDfhYNRQWi', 'user', 'Kriselle Ann Mabuti', '2024-0391', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5533, '2024-0587', 'hannah.melgar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$CqZDyudmTuCsL4LOe4nd4OqUeJF07Nr3zdRdZcQ4ptgiWoWjFUNte', 'user', 'Hannah Melgar', '2024-0587', 1, 'active', '2026-03-15 11:29:57', '2026-03-15 11:29:57', NULL),
(5532, '2024-0387', 'angelrose.mascarinas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$KbUUwfrAyTn6ylHqoh5pmOVMj5cv7ku1lKnkttRjOKGyUg2j1Tpbi', 'user', 'Angel Rose Mascarinas', '2024-0387', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5530, '2024-0368', 'joankate.lomio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$XCsTL1bf8jXqc2uEtahcKeogYoyPAQ4ntMUzSZPFzu/Mad1CaDM4K', 'user', 'Joan Kate Lomio', '2024-0368', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5529, '2024-0376', 'jazleen.llamoso@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qt7ZW0aIheTs197ExM7iheLJ7n5rsT.wFJFOoa2QrkGvF0rcMaQ.O', 'user', 'Jazleen Llamoso', '2024-0376', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5526, '2024-0507', 'aiexadanielle.guira@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$gMOQpDDwjKzJb5q3qGWu3ezQeSfyZsk9tI/8JbwVpb2JLL1fQUUH2', 'user', 'Aiexa Danielle Guira', '2024-0507', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5528, '2024-0501', 'eslleyann.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$m2hKpWAN8g.yGRz5ePIoHeWEEuG91PuLzzPtrWYbjIGhjj5xZwoXu', 'user', 'Eslley Ann Hernandez', '2024-0501', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5527, '2024-0375', 'andreamae.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$95.107gpBTaRenY.5pnA1eQLnCtIVDUXvxCVbSGwOW/ONvX0MkQI2', 'user', 'Andrea Mae Hernandez', '2024-0375', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5524, '2024-0385', 'mariejoy.gado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qrujDCKvWSKD7tb9IGrd4ub3YPFLEIDuJKxlzykfgmVtOsQ7Xoy4C', 'user', 'Marie Joy Gado', '2024-0385', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5525, '2024-0371', 'leah.galit@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3Vr.viQW6GCn/.JupjcpEed2CGmIbJH.i4nZnk5vvN8dG0mG.NAtu', 'user', 'Leah Galit', '2024-0371', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5523, '2024-0366', 'hazelann.feudo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$74aSUni/eH2PhsGpra6Hd.OxZGBH8SAodiEo3BAWPfZFxeQIQCvLO', 'user', 'Hazel Ann Feudo', '2024-0366', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5522, '2024-0388', 'chariz.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PckUf33EXvTXTH6GznLYIuIsQ9.PC0raPdoklcw3mF7egdYdVuWWW', 'user', 'Chariz Fajardo', '2024-0388', 1, 'active', '2026-03-15 11:29:56', '2026-03-15 11:29:56', NULL),
(5521, '2024-0363', 'maricar.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$uEXNDqDEukJhERdD.25M2uBaIT8YPi1Gur1ZTr2Pnb0C4l8BAmaK.', 'user', 'Maricar Evangelista', '2024-0363', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5520, '2024-0367', 'rexlynjoy.eguillon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$xru1q1tgXX2oMhhlzZHryego23lQstLmMUlYvPXOXq9k0Gzzg0rAq', 'user', 'Rexlyn Joy Eguillon', '2024-0367', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5516, '2024-0351', 'shane.dalisay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zEzwKzLPYiDtdcqyts64mu9LGESLDKMIJWWmYMrlzLgCIoxMXPvfq', 'user', 'Shane Dalisay', '2024-0351', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5517, '2024-0369', 'mariel.delossantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$nqDAO1/96MbDzNBrxz1HmOpWfMum.hHwtb5AfVFVjWEgFUsTA0Ndy', 'user', 'Mariel Delos Santos', '2024-0369', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5518, '2024-0520', 'angel.dimoampo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3lXoWqjiDET8Epw6VmN7cubr2tVEbQW3QI9VRR9Ipwpn/dwWvE5S.', 'user', 'Angel Dimoampo', '2024-0520', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5519, '2024-0374', 'kristine.dris@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$FJjUcMPqyPZ5qdYiNkiRUecl4LKFCpRDPXZmqvpTf04FrY25OtsaS', 'user', 'Kristine Dris', '2024-0374', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5515, '2024-0474', 'kimashleynicole.caringal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0ryMrouuhapdryOFYsg9C.QAAiHlbLTz/fVPPGHGCJywLAVs9vyIq', 'user', 'Kim Ashley Nicole Caringal', '2024-0474', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5514, '2024-0355', 'elyza.buquis@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$1Igc15xx/CPONSRD5ZtC/eK12lMutpoCniDLvGORsyo3EPmulo0S6', 'user', 'Elyza Buquis', '2024-0355', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5512, '2024-0347', 'cherylyn.bacsa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zS3ypo6VXVO9SGv0Qs2r7OwrTq1Yg3YeSft7EQs0nAaXLjjjgWfPW', 'user', 'Cherylyn Bacsa', '2024-0347', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5513, '2024-0364', 'realyn.bercasi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PEFwNQyOVqim.zJi2Ybyq.cHreeSudN7kkwI7Q8A9Zcx.2fW3preW', 'user', 'Realyn Bercasi', '2024-0364', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5511, '2024-0354', 'maica.bacal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$rTPoqN1bgqBFn//2XCnuiO.1HQfDxaaIW1byONkb3k7qlKLlcKQai', 'user', 'Maica Bacal', '2024-0354', 1, 'active', '2026-03-15 11:29:55', '2026-03-15 11:29:55', NULL),
(5510, '2024-0372', 'katriceallaine.atienza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$MML.TqjmXPUdl6H92xZ5uOAHwUJ6nrUecTlC/M8vpoLpcvH0OTl.2', 'user', 'Katrice Allaine Atienza', '2024-0372', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5509, '2024-0360', 'rocelliegh.araez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$fJxiSG2Lkub3/Axpk6bDZOmL6oVVNTD6s/nA.0Xtjb79RIxg1HbKK', 'user', 'Rocel Liegh Arañez', '2024-0360', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5506, '2024-0504', 'lynse.albufera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jZcWhvI3W.fQVYIvOy61VeXkPWW/jApivQZju1wZA6ESbEU2OENdW', 'user', 'Lynse Albufera', '2024-0504', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5507, '2024-0521', 'laramae.altamia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$dLDYW.vvQhdo/xtjZXnRwuOhBYs1M.T1RsQoYB08i2MySxIFnjyQy', 'user', 'Lara Mae Altamia', '2024-0521', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5508, '2024-0379', 'crislyn.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$/OayrT865gCkJggUKAzcZ./K7WfvgI2.RBkc1AkSzXV476bmQWu32', 'user', 'Crislyn Anyayahan', '2024-0379', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5505, '2024-0378', 'benelyn.aguho@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DCt5PNTG/Q0hCfagT82yFeCwfbYPXpIFozHPfdvl2OVqijwOemu82', 'user', 'Benelyn Aguho', '2024-0378', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5504, '2024-0352', 'patriciamae.agoncillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$18XPZLikByiIwxKpjCDbkeBzxArBkWzFypE2Ira3DfBUW0RrPK7QG', 'user', 'Patricia Mae Agoncillo', '2024-0352', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5503, '2024-0358', 'ashlynkieth.abanilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iucv3hUV.U.cbFatur1qiuQ/KUzUNZPg30gGCh93.7T4L39PWGNPi', 'user', 'Ashlyn Kieth Abanilla', '2024-0358', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5501, '2024-0401', 'jhonkenneth.obando@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jKcFHHYasND.9Z1w5S7C6epYWZAugs8WwD3CScmnH3K/Nlt5rNFXe', 'user', 'Jhon Kenneth Obando', '2024-0401', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5502, '2024-0462', 'rodel.roldan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$VU0Sz1XJ/kqPEOZ2iNhnZOj.ZF9Z5z7a2liCyxRdNX0SJ0ma6c3ca', 'user', 'Rodel Roldan', '2024-0462', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5500, '2024-0530', 'allan.loto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$7baD5H1H6Dqp7wYL06G42O61ymf9a7so6gMNljXjaRXnfZrWpv.xu', 'user', 'Allan Loto', '2024-0530', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5499, '2024-0555', 'johnmariol.fransisco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$JUjvJhGv/MdPN0JXw2ZSb.gQJZP.8jJfeYwLCxKIsKHpVque/fMOy', 'user', 'John Mariol Fransisco', '2024-0555', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5498, '2024-0450', 'rickson.ferry@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$oamOyG35/NS7prq7zHDYmuBeATA8trFEWVq7YaZMJLyN/yqLVzBxK', 'user', 'Rickson Ferry', '2024-0450', 1, 'active', '2026-03-15 11:29:54', '2026-03-15 11:29:54', NULL),
(5494, '2024-0444', 'angelaclariss.teves@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wkMb0to199pcZ9/cV/4/uu6OVZ6C/gUNRGkyXiD7Un.PXRxLaybNq', 'user', 'Angela Clariss Teves', '2024-0444', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5495, '2024-0454', 'zairene.undaloc@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4bztkGK6BxdZ6XWfjs9KGOnIO0.RCStuNGICCgyccyBk6CFaTPqrm', 'user', 'Zairene Undaloc', '2024-0454', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5496, '2024-0449', 'johnivan.cuasay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$FnXxdOqoXsPXRTJjjSY/Y.PWOEw6MDvIt9tuMM2qXYcz.AZsOhJEG', 'user', 'John Ivan Cuasay', '2024-0449', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5497, '2024-0505', 'bert.ferrera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$O0JvBTajGNzh7rXmYVQHr.H1/EdbKptBGI4ox1UzPpBwcuEehzEAm', 'user', 'Bert Ferrera', '2024-0505', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5493, '2024-0563', 'danica.pederio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$74ons4TguYRLYtUxlkKDKOliqpVov4I2B.LKprtvmGRVTc3ffxHnW', 'user', 'Danica Pederio', '2024-0563', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5492, '2024-0538', 'mariairene.pasado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$f2hPg2zEvIAzStYhFQPiauBhVB1jRgrsBNUicL6T3N.QqcC9O19be', 'user', 'Maria Irene Pasado', '2024-0538', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5490, '2024-0458', 'chelorose.marasigan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qR6l7JhwZ.aMejY0CpWMXOkLBXjQxWIjdKjTNU.L4Y8OzT4HLBxVi', 'user', 'Chelo Rose Marasigan', '2024-0458', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5491, '2024-0456', 'joanamarie.paala@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$H8WDepGfu.lcflOmvcs4gOYrQAOF8guJUQ4P7RWzYzE6ZZr8GLNeq', 'user', 'Joana Marie Paala', '2024-0456', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5489, '2024-0545', 'febelyn.magboo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ig.Nz7UY/mRmHEMyd4dVA.S22H8ZJjlS4o3Lhpx8DcwyvFtVIRewe', 'user', 'Febelyn Magboo', '2024-0545', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5488, '2024-0464', 'michellemicah.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$RFIuwHqmBce1ZIJRtoQHjeNtvu/tFgVLIy7KY9x9y5GTB.1BJcQUW', 'user', 'Michelle Micah Lumanglas', '2024-0464', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5487, '2024-0463', 'angela.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$G4cC3dlY9FSFqrtl0PtsjunrGJuaFwEQwmhhUptHZY4QRXp6zHuGi', 'user', 'Angela Lumanglas', '2024-0463', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5485, '2024-0554', 'apriljoy.llamoso@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4YmMNj53QFyvTXIksFWq4uxTBKMSQYC5q/M7aIopdLsAybX.NSRJW', 'user', 'April Joy Llamoso', '2024-0554', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5486, '2024-0440', 'irene.loto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$WABYGz0LjcNMpb/xWh595uPPYN9VOeEGa./fcVd5Ga/vM5h71S/.W', 'user', 'Irene Loto', '2024-0440', 1, 'active', '2026-03-15 11:29:53', '2026-03-15 11:29:53', NULL),
(5484, '2024-0476', 'catherine.gomez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.fqD42K4kkcDBiE/svW3TuAHEBEgL2kFqX.arv0gWIfOtN6bAfuiu', 'user', 'Catherine Gomez', '2024-0476', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5483, '2024-0441', 'janah.glor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wUWosMShxiYMl3k.jXg0EecJ0HGEt7tJfR.Mj.grTUo6bmkLirj/C', 'user', 'Janah Glor', '2024-0441', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5482, '2024-0466', 'shanemary.gardoce@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Zbj8nF2jntcl2j6SWUfLJO7hIMWi2ZBSxQ3pxhfWNzLDHa2hHLbFm', 'user', 'Shane Mary Gardoce', '2024-0466', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5477, '2024-0548', 'angel.cason@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$F6JYrGzq.STMnCdwSr3XX.k2FFHUN/IO4H6MdDUB..m9r9lp/BKM6', 'user', 'Angel Cason', '2024-0548', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5478, '2024-0461', 'kcmay.deguzman@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Z92i04i4pmsoKU4YTbzgF.3EOBiq2WOTQOeokCppoE87.9hbwGn5e', 'user', 'KC May De Guzman', '2024-0461', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5479, '2024-0531', 'francene.delossantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$XEIbiFW3wa2VKAdR3REQ2u1BMU.xPqzEvL2u6EV/Kca1SSrDwOBJm', 'user', 'Francene Delos Santos', '2024-0531', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5480, '2024-0470', 'shaneayessa.elio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$6zOsOtb3aiO5B6KAh6lRre5sqC8VZZkjGoVsssQSLBVddVoscLh0.', 'user', 'Shane Ayessa Elio', '2024-0470', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5481, '2024-0502', 'mariaangela.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$rF8IYejoaf7Wp1FiC.VA6.A0s.LCEhf4S8c/yksFDz0eITYN9xE9C', 'user', 'Maria Angela Garcia', '2024-0502', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5476, '2024-0503', 'carlaandrea.azucena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.S3x.dHidm333I.qlEj.9uwwHSCY8rbleVEpKOD5s5Xvk1yJD41FS', 'user', 'Carla Andrea Azucena', '2024-0503', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5472, '2024-0494', 'great.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$44QPH3cdc2WOE7ZnPkJkAOnwH41WVFTbRJf8w.NffpFhIPKW.rmYq', 'user', 'Great Mendoza', '2024-0494', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5473, '2024-0497', 'jhonmarc.oliveria@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$BbBvv17/WMxAALNR8FQV4.P62AXpAAoaVBR5IaqcIhCvsQMd0DSRm', 'user', 'Jhon Marc Oliveria', '2024-0497', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5474, '2024-0455', 'kevin.rucio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$rj5YjpYSCTEwGfKOpnNOqO2F1rFhLXllM0EjRiafVZScTVpIgeIFi', 'user', 'Kevin Rucio', '2024-0455', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5475, '2024-0445', 'arhizzasheena.abanilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$f35mmgJk4Hldf8ERwmqg/u1tD9M2pQE8pfYZBcc18LfYSjpAlxh8O', 'user', 'Arhizza Sheena Abanilla', '2024-0445', 1, 'active', '2026-03-15 11:29:52', '2026-03-15 11:29:52', NULL),
(5470, '2024-0490', 'mcryan.masangkay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$8Fns1nWQP545.7gZ3lX6Bei14G4kzzgTbMndonMjbCoUb71n744Qq', 'user', 'Mc Ryan Masangkay', '2024-0490', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5471, '2025-0592', 'aaronvincent.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$IqMjGThp3ROxeTuhVBo.OuHg731NeRetyZSsLopvIvFLcdovkvCam', 'user', 'Aaron Vincent Manalo', '2025-0592', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5468, '2024-0499', 'prince.geneta@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$pMm6lW8xL79hVBAeHK3V3.NrcAq/IdzjkZi69Iw.JvRlrocV2sTCq', 'user', 'Prince Geneta', '2024-0499', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5469, '2024-0495', 'johnreign.laredo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DK7hbPn27KL7Zjhc3c08M.cTk.Jz2ZSrwVYYdvk7PZUSpg.KLWya6', 'user', 'John Reign Laredo', '2024-0495', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5466, '2024-0475', 'antoniogabriel.francisco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wOgdvEWp6oXYpmAkMElMe.vPfsy9vPHlKM8JouJCK.Q70TcM61V7.', 'user', 'Antonio Gabriel Francisco', '2024-0475', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5467, '2024-0345', 'karlandrew.hardin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$r8fc5tutOYZYr/EBKJhdgeHGJWcSjxIMKilHzXoc/z7SmOhvOYhyK', 'user', 'karl Andrew Hardin', '2024-0345', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5463, '2024-0489', 'reymar.faeldonia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PJ3O912W1pPwU4CJ6HigLuffl4XcvfsFn58ufczyAOkxHKRg6b1.y', 'user', 'Reymar Faeldonia', '2024-0489', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5465, '2024-0488', 'johnlester.gaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$T9MRT62QsJCYjfnIh.pP8O8eoOQBDQu3e7W48UrzoGHob3mjcJUDe', 'user', 'John Lester Gaba', '2024-0488', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5464, '2024-0500', 'johnray.fegidero@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$dpRurST8mKLNTa29Tx9NjupNyXXfxhL.BD9V8O3nkk671TlrPQ5Qe', 'user', 'John Ray Fegidero', '2024-0500', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5462, '2024-0477', 'johnpaul.delemos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$KJU/B8yQd47f9tXtJnRafOj6DYOWSVTxJwvs4rn..q4HOUd24dwaC', 'user', 'John Paul De Lemos', '2024-0477', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5461, '2024-0485', 'cedrick.cardova@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$YRibM0zH.Q61xEM5udxaq.gd3n6Sc1GZFK2fTKO2NQwp4kLik1Vx2', 'user', 'Cedrick Cardova', '2024-0485', 1, 'active', '2026-03-15 11:29:51', '2026-03-15 11:29:51', NULL),
(5459, '2024-0539', 'emerson.adarlo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$CMNfjhtMFg9hh9V2VcIEUuPgPr4Ti6vamr12tztnHM6EW7pgjjbhu', 'user', 'Emerson Adarlo', '2024-0539', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5460, '2024-0491', 'shimandrian.adarlo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$NLKkLRWeJqNRegmpIx23wOyG1GTSu2yvT3dNw91XU8uLkyGbiwUDu', 'user', 'Shim Andrian Adarlo', '2024-0491', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5458, '2024-0469', 'mischell.velasquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3jESb6MPtZEwMH2pukTdPu1mVzWqQToOgMndNmUaskU9JgQFE8iaK', 'user', 'Mischell Velasquez', '2024-0469', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5456, '2024-0457', 'mikayla.paala@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$euJxXc3r7p2HI/H8uyS9Q.EHak59LD84tHoNtWTY8T/T80UFanuR2', 'user', 'Mikayla Paala', '2024-0457', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5457, '2024-0442', 'necilyn.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$2S16Bl9vNNI6dV1dLU4CS.oM5XlaimYDZt/jKLv1FGHA2VTDFeWmu', 'user', 'Necilyn Ramos', '2024-0442', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5454, '2024-0570', 'carla.nineria@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Ml4qIF7vDeZ6sYL17ankmuhD9.mn1EGayrTEtsn6yOvQuhWE/6eqy', 'user', 'Carla Nineria', '2024-0570', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5455, '2024-0516', 'kyla.oliveria@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$fzGa8PU8rnDtuQVlB3Ghv.ZUAGpFcsMXK8mP6m7iZSRtX5nk1k91y', 'user', 'Kyla Oliveria', '2024-0516', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5453, '2024-0535', 'evangeline.mojica@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iFM6JCipReXj18qTx.SDwuv2kTPPgcYGaAiFmbzXZCo7Lx0g//TqG', 'user', 'Evangeline Mojica', '2024-0535', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5452, '2024-0487', 'roma.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ZEuYUgGB1XquJAhAn9sdTewzKA7YYwmF/fAop74dwbCByrKfI45lq', 'user', 'Roma Mendoza', '2024-0487', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5450, '2024-0549', 'danicamae.hornilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$S8UNfyW4iACqkRyRZJ3qdeM253vXY5QbNHfwQt4HHO1t1JUbGqEBq', 'user', 'Danica Mae Hornilla', '2024-0549', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5451, '2024-0473', 'jenny.idea@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$LBsDJe7Ld9/pqyVZs.NgZe6aNZPV47lVq0f3znowBS8qHCjM0koxK', 'user', 'Jenny Idea', '2024-0473', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5447, '2024-0508', 'laramae.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$hgcSXwIqThZ7lVXfsfWA3Onyhd1A.r3ts0kOn1osy3c2o4HpuR5/i', 'user', 'Lara Mae Garcia', '2024-0508', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5449, '2024-0446', 'rica.glodo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$yXzOh9y7LmR4uv62vp5qk.F4DZJe3hnY7ImK7tIFRKdBCNJQ9mdZ2', 'user', 'Rica Glodo', '2024-0446', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5448, '2024-0459', 'jade.garing@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iUozF0yspblVgflqqnCCcuOTqJ.FfaqPQILaB72EVn5XvICUnEHVW', 'user', 'Jade Garing', '2024-0459', 1, 'active', '2026-03-15 11:29:50', '2026-03-15 11:29:50', NULL),
(5446, '2024-0506', 'maecelle.fiedalan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$j0ReZNvg1S9lS42gbY7qPum8IbjzgNfmflV8erkPRwv6Qwp4gSamq', 'user', 'Maecelle Fiedalan', '2024-0506', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5445, '2024-0546', 'gielysa.concha@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$tKAMl8zkhKcJfhK.zWOn1.tXc7GKpptsgTxd7y0HKCh7ih6sQC8om', 'user', 'Gielysa Concha', '2024-0546', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5444, '2024-0550', 'juneth.baliday@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Ab5UxuvUEtX23Q/Efq7GuOnCi7gNC.Y7YVYn.TtGGUdaH7XWFFvcW', 'user', 'Juneth Baliday', '2024-0550', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5441, '2024-0514', 'kyla.anonuevo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$M5gvhQNAmNjuPwCQ5S.oQuArqk3rpCoRvFSfWqycoX70elEmIgbYe', 'user', 'Kyla Anonuevo', '2024-0514', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5442, '2024-0569', 'katrice.antipasado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PgYlBjgvkujJw0gQf3yym.dhrYuMNsyXcJ2j4ZHpyCbNBQSotKjZm', 'user', 'Katrice Antipasado', '2024-0569', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5443, '2024-0591', 'regine.antipasado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0Flf2zzJn2CZO.bpGHbDjOriR/HV.LMll3ob.Q0lkHuoIJBRRwmuS', 'user', 'Regine Antipasado', '2024-0591', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5439, '2025-0597', 'ivanlester.ylagan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$b.SRTjT5vZDKI7ZnoKAcp.xG3ieSeKq1eZaYFiSdjWRVZeSX95VzS', 'user', 'Ivan Lester Ylagan', '2025-0597', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5440, '2024-0513', 'kianajane.aonuevo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$75CmU2uAQa/PkX.VZTE5tu6Q1luv544pCp9pQ9Keyqd3GdT.rq3hG', 'user', 'Kiana Jane Añonuevo', '2024-0513', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5437, '2025-0776', 'judemichael.somera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$fY.djnSfvWRaWy4zXbweSuDqVK3EDWT4ypNV0p1LLFT6uuGso7Em.', 'user', 'Jude Michael Somera', '2025-0776', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5438, '2025-0695', 'philipjhon.tabor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$5Op8vfidCM5mCLYw3u0wR.GtSpDXZqE287L7dLWFX/wef6gnSLxwi', 'user', 'Philip Jhon Tabor', '2025-0695', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5436, '2025-0764', 'tristanjay.plata@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$YfaeGFnlX.n3awf0FdLpOeNqleyREsrJwVH1ul2v2ylPVPEciVRae', 'user', 'Tristan Jay Plata', '2025-0764', 1, 'active', '2026-03-15 11:29:49', '2026-03-15 11:29:49', NULL),
(5433, '2025-0659', 'carljustine.padua@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$F2p.aWUo4SuD2zuMdDRG4OiYbEPSBb8lTByfO9eYiHGtKNhaATgci', 'user', 'Carl Justine Padua', '2025-0659', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5434, '2025-0600', 'patricklanz.paz@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$84HF74lrBuh64b/m8UNYuueUkj8qEWepMT4YKrY/jOMR84e5K7o2q', 'user', 'Patrick Lanz Paz', '2025-0600', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5435, '2025-0622', 'markjustin.pecolados@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$dw.ld2pZhRT0zr7diyjW8uQG70hza5Nntq9JngAoQ9mR5V9/wltG2', 'user', 'Mark Justin Pecolados', '2025-0622', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5431, '2025-0651', 'jm.nas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$uRYkGqFGCSMMMKGskkTD6e.KnE4lqDHuXBXyxkKMbIZolKyR5MwR.', 'user', 'JM Nas', '2025-0651', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5432, '2025-0725', 'vhonjericko.ornos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PlbezeHkQ.3PxrePfR/9ROjFO3DEZZeENz/yZE7RGyAZkSAHLr3XW', 'user', 'Vhon Jerick O Ornos', '2025-0725', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5430, '2025-0625', 'markangelo.montevirgen@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Z9iwXlg4Z8MnmOEWRaeZGuwpzpp4/0SiCNpNqwIVXwsPgJlzucA4q', 'user', 'Mark Angelo Montevirgen', '2025-0625', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5429, '2025-0624', 'hedyen.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qn7q.rG8dOqI6k.dLguOiuj3RJEGYuij.OEvlb3vtc5yFXwTFMLr6', 'user', 'Hedyen Mendoza', '2025-0624', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5427, '2025-0650', 'ericjohn.marinduque@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Fl.tRu8GlJn/62UZR3ZdmejLCRkLuG4p5f3Sob30kiWWohGoAmH5e', 'user', 'Eric John Marinduque', '2025-0650', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5428, '2025-0730', 'jimrex.mayano@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$3QhW8t8RaRFhymqKDqVAiOz2qJKZ1vxq6qxMs1.qVtn/UvXw.SJwK', 'user', 'Jimrex Mayano', '2025-0730', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5425, '2025-0781', 'jandy.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PAYKDr7ViollOv5MFxNAcObufpbjjNahCMITTF7YZPGNYNCb43HDK', 'user', 'Jandy Macapuno', '2025-0781', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5426, '2025-0693', 'cedrick.mandia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$vXDxoiAcXZ/iqRfAWaYsp.CWl4m.t/q.//QCSLZ7X/BKCWpEoZEKy', 'user', 'Cedrick Mandia', '2025-0693', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5424, '2025-0596', 'johnlemuel.macalindol@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Cix8U.FxRZ68OJppGIEv3eUDtgjWNG/rNkpIWCZDi4Je6vcn9XvJW', 'user', 'John Lemuel Macalindol', '2025-0596', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5423, '2025-0639', 'luigi.lomio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$lIZX3xWcdYtqWZF4EgmAeeq1q4uteZyF94RsqVlKgDxowYvbi6XRa', 'user', 'Luigi Lomio', '2025-0639', 1, 'active', '2026-03-15 11:29:48', '2026-03-15 11:29:48', NULL),
(5422, '2025-0735', 'bricks.lindero@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$bW9oemB7H0NISVYQqf9.7OrelrXW/1.XnSCGF6n8NU7/Ibddzzosq', 'user', 'Bricks Lindero', '2025-0735', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5421, '2025-0663', 'janryx.laspinas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$xTLJyKf1vnjzvB.FFFsPjOPL70JP7gCVRiN3gC17Vm3s3D9SgWgfO', 'user', 'Janryx Las Pinas', '2025-0663', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5420, '2025-0598', 'andrew.laredo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$EeTZ3JcnL6jLS6nMM6R0vOMEjtIhb.G/ogowk3KdSk5JW.ZJK3PAa', 'user', 'Andrew Laredo', '2025-0598', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5419, '2025-0662', 'ralphadriane.javier@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$trevJ6CfMu7th39aGN98UOsOCGQtMI0vKWBSSXT.FLxe7qICw1YL2', 'user', 'Ralph Adriane Javier', '2025-0662', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5417, '2025-0803', 'benjaminjrd.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$2caMG7aD2n.taPRCHnAii.eUlBIKqdfN0qSiWSka4c8rb37U/dwcu', 'user', 'Benjamin Jr. D Hernandez', '2025-0803', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5416, '2025-0716', 'dankian.hatulan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PV7ug7q9BdJW5fGbduwOSe4OXfyJn9Dmp98/yXq/7o/YkwWR9QxeW', 'user', 'Dan Kian Hatulan', '2025-0716', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5418, '2025-0753', 'renz.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$c2TysSCPZcW05d6e5NlmJuwnofoNNFyV3LJz7NMvW/l8iWfx6gaCi', 'user', 'Renz Hernandez', '2025-0753', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5413, '2025-0697', 'joshua.gabon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$tlSU7VtmfM1o7f0FKD6Ou.u87UReBYP04ssAdCAlDk1QBHNUo7c6O', 'user', 'Joshua Gabon', '2025-0697', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5414, '2025-0681', 'johnandrew.gavilan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$aHYrXgjgAT80YownptNnKO2zqLH.1JQxEMJYFJPo9dWmm7owJxJI6', 'user', 'John Andrew Gavilan', '2025-0681', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5415, '2025-0715', 'mclenard.gibo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iU7TJRwjefyk.RAX5pWuj.DJOJ9rWreQrbaWmf4isfTrYnoO0KE42', 'user', 'Mc Lenard Gibo', '2025-0715', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5412, '2025-0595', 'uranus.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0euSOdXEi0sjn2fLHuE8FeWX5KsYJgAteGeA7mNCDEAu/ht50ajsW', 'user', 'Uranus Evangelista', '2025-0595', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5411, '2025-0696', 'alexander.ducado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zR.6As6AFoPLDUEvRsDY7OnJJInOrZAcV3kpOCvm4ayk9V/xcyL46', 'user', 'Alexander Ducado', '2025-0696', 1, 'active', '2026-03-15 11:29:47', '2026-03-15 11:29:47', NULL),
(5410, '2025-0782', 'daveruzzele.despa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$9uJ9jUGUe.hG9Vh/Y2msJeKUWP7bagGlIsi7pLoH4zKIrO0QC7hgO', 'user', 'Dave Ruzzele Despa', '2025-0782', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5408, '2025-0626', 'shervinjeral.castro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zb5q/o3RWj9aH0MPA/V1p.4udWgLgRkt4rDzKNEJSrYhYGR.3Dw4S', 'user', 'Shervin Jeral Castro', '2025-0626', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5409, '2025-0652', 'daniel.deade@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$QNBtsOEm/Ock59ue9tsZr.N20qLT8D/RX0D.yiDz5V7Zq3Yu2wdsG', 'user', 'Daniel De Ade', '2025-0652', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5406, '2025-0791', 'ramfel.azucena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$t7bG5qb7OBoQ6Shd3dTCHuoOA8Cg2dGsb45lVUXWrZyVudj.H9AQO', 'user', 'Ramfel Azucena', '2025-0791', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5407, '2025-0632', 'jeverson.bersoto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$SNIhaH7qINQxLmsBQyIExO2HkEjEAAUhfj/BZCxv1fPFdqwh1djoG', 'user', 'Jeverson Bersoto', '2025-0632', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5405, '2025-0620', 'rexon.abanilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$i3tk9R.ZUyDX6R3U0vku8.eCw/evb.HAfbB53WfTQp0.G63HHdGOy', 'user', 'Rexon Abanilla', '2025-0620', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5404, '2025-0814', 'lovely.torres@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$eewbWzwNx.4r3tU93BheBehzrejWsTBmqs69dBFFTFAhpq1Zlw97e', 'user', 'Lovely Torres', '2025-0814', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5403, '2025-0634', 'marbhel.rucio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$fqCjzIKeRvaTkJzah96QgeeHZxVyE6gGgv3nkNuHR18D7x1vdX51m', 'user', 'Marbhel Rucio', '2025-0634', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5401, '2025-0628', 'alyssamae.quintia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$gFikOeaO3gikXITmRr3DQeL8NYAEqPd4TlRJIutCYFjkHRjfiwJJq', 'user', 'Alyssa Mae Quintia', '2025-0628', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5402, '2025-0774', 'jonamarie.romero@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$tzTBGhHc.lsk3ERPGlsEL.qj95eYEajZ7c6csVGMhGysXF7.dA2Lm', 'user', 'Jona Marie Romero', '2025-0774', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5398, '2025-0748', 'arien.montesa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$EWJMX6hSKCQM0HH8S/.KMuzF/fBnr9gR26T/KKRMKUp16YBWlKjsG', 'user', 'Arien Montesa', '2025-0748', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL);
INSERT INTO `users` (`id`, `username`, `email`, `google_id`, `facebook_id`, `profile_picture`, `password`, `role`, `full_name`, `student_id`, `is_active`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(5399, '2025-0653', 'jasmine.nuestro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$EyYWCj9Qz7UEdmlpzs01wOc4PTfV/tfFY0XbnQpLB/OZN7RSkS/rO', 'user', 'Jasmine Nuestro', '2025-0653', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5400, '2025-0738', 'nicole.ola@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$9xJJRejT9Bs1Dhb78npC6eQFTXgW/YrTCev18zRsHPl14EbjBHqS6', 'user', 'Nicole Ola', '2025-0738', 1, 'active', '2026-03-15 11:29:46', '2026-03-15 11:29:46', NULL),
(5397, '2025-0708', 'ericca.marquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$KeJ/83is5Ardrt4mUSllPuZrT0Kpl29qD4HDzO2dq3nf5wG5cfV1m', 'user', 'Ericca Marquez', '2025-0708', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5396, '2025-0739', 'abegail.malogueo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$7GukzeRGRSWxDviI7ceavOgZ4vHQO9ThJdAq2N6MfLUZDTtBmPYfq', 'user', 'Abegail Malogueño', '2025-0739', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5394, '2025-0720', 'charese.jolo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$W9ZDDltayle.cSUpnamUK.g/fJDgv01sDrMx/Qw5HXH9/baAfeSP6', 'user', 'Charese Jolo', '2025-0720', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5395, '2025-0682', 'janice.lugatic@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wJDLGP3NRgUqP.RtWuIhaOQaOVp6k1SmGTcilYL7YIct3jlrutPkq', 'user', 'Janice Lugatic', '2025-0682', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5393, '2025-0664', 'aleyahjanelle.jara@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$TzPeanrlAAtMPsSmLnL3ZOAU4atCHkAOz0z5SOObf5Baf4Z8DQfzS', 'user', 'Aleyah Janelle Jara', '2025-0664', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5392, '2025-0802', 'jedidiah.gelena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ve6Xy8uBzHjOIoa.inb/sOccGHAEdCOIctBezLA6icFIhI8nj9UpO', 'user', 'Jedidiah Gelena', '2025-0802', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5391, '2025-0719', 'deahangellas.carpo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$87QpUG5J0SzMSY1qHuhV1ujsALPyq0b7oGmHlOo2bllbWCnQZv2U6', 'user', 'Deah Angella S Carpo', '2025-0719', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5389, '2025-0669', 'danielafaye.cabiles@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$6kYQIVG0jyoPc5nUX1pjyeNdQIPKEvjTSUQ3OoJQul9raNw3QjeeS', 'user', 'Daniela Faye Cabiles', '2025-0669', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5390, '2025-0599', 'prinsesgabriela.calaolao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$VKWIIho/u7BjwFMrGwZPR.NbgmwqHPadAG3ws1le/ajqti9WMzuh.', 'user', 'Prinses Gabriela Calaolao', '2025-0599', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5388, '2025-0623', 'mikadean.buadilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$InmvMRpr2X9r1fR2hsJqQepsLGM4iqBA5SGsj23Vc8aRSAoRdVvhi', 'user', 'Mika Dean Buadilla', '2025-0623', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5387, '2025-0752', 'sherilyn.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$D58cwEXodOwbKB8nuNt4t.MmATQFYhXMSAD8iFvqxUhHNgfbAxOqG', 'user', 'Sherilyn Anyayahan', '2025-0752', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5386, '2025-0661', 'aizel.alvarez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0AgvJuPDIu6DaWmQdlPQdum.eLa3khXZea8zQReVWLlMMtvguYbgW', 'user', 'Aizel Alvarez', '2025-0661', 1, 'active', '2026-03-15 11:29:45', '2026-03-15 11:29:45', NULL),
(5384, '2025-0775', 'angela.aldea@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$IQ1x9qZDQOMoqo122o6OVus5i.o63Ze99D51ucKNxBzd5ppd29EKO', 'user', 'Angela Aldea', '2025-0775', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5385, '2025-0601', 'mariafe.aldovino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$cY1jQ01QXIcggZc1k6afbO8zFrmP.sN6jitG3gfzFy2hsl7FixCyK', 'user', 'Maria Fe Aldovino', '2025-0601', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5383, '2025-0621', 'novelyn.albufera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$2T.nL3S8Y9Gp4lCEZhyiXu4CR4qX0CdrV9Tyrf0dRuWzbiQWPdXtW', 'user', 'Novelyn Albufera', '2025-0621', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5382, '2025-0645', 'dindo.tolentino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PXoyz7oBmNw2BA8cRSN21uDci1WlqpQyN1WsIUQzL5arExoJJb/hO', 'user', 'Dindo Tolentino', '2025-0645', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5378, '2025-0865', 'zyris.guavez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$7rFE6Ft9osgcS.K279qCrelzheDw.YpOPedpevHoVxwQl8utnO8jO', 'user', 'Zyris Guavez', '2025-0865', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5375, '2025-0690', 'rexner.eguillon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Sbp12mdKNwr0/KCABtEOcedmfHsDZmKBgFI0aVeEnYeTSy3hkGuua', 'user', 'Rexner Eguillon', '2025-0690', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5376, '2025-0815', 'reymart.elmido@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$EGIiQwyYCSLP8qgqTO8UNOLUduZxJoOnlWJ6Z953c.vVFCmoL2IlK', 'user', 'Reymart Elmido', '2025-0815', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5377, '2025-0627', 'kervin.garachico@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$8nskq.IVMBZCCLCsq7JjR.ejw6WuZNcHYL9yXwuTYkhoKDwH1OEp.', 'user', 'Kervin Garachico', '2025-0627', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5373, '2025-0806', 'meganmichaela.visaya@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ELnQmCZwOTngBYGB8YTZ3.kwdAuT0gR3JRHyoi97fvvau10UZkf2u', 'user', 'Megan Michaela Visaya', '2025-0806', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5381, '2025-0732', 'helbert.maulion@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$rSgen7sFClJBKebGzOUQa.4pjCVhtzCjFLiK3KI94MuVNRRmiKbve', 'user', 'Helbert Maulion', '2025-0732', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(2574, '1', 'admin@gmail.com', NULL, NULL, NULL, '$2y$10$hBNUdr9u8zu.f7zVAUNYG.l7a8lKrpIZeEBZsEjkWYOYNEmDjARDe', 'admin', 'test', '1111', 0, 'archived', '2026-02-24 01:05:02', '2026-02-24 14:09:45', '2026-02-24 06:09:45'),
(5379, '2025-0740', 'marjuna.linayao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DMatRzO8/xSKkK3fsWs/kOJpNjojXBECyUoesM2aiKFsqaI/5xjrq', 'user', 'Marjun A Linayao', '2025-0740', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5380, '2025-0660', 'johnlloyd.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$DYOm6XPF8Utd8375XO4yjOS.M/A/0C160qIVyIg8/.NuZ1dtcySQ.', 'user', 'John Lloyd Macapuno', '2025-0660', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5374, '2025-0684', 'rodel.arenas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$biH0abhLk1xF45wWFvSd2uU0TdcgxG.77PQEBCdWA4fV4QjO974re', 'user', 'Rodel Arenas', '2025-0684', 1, 'active', '2026-03-15 11:29:44', '2026-03-15 11:29:44', NULL),
(5372, '2025-0723', 'pauleen.villaruel@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$f7Fg9zO0qgczr6csa47N4.LqisirR4HcMdOfVdCNjUe.0XJ7j1HIO', 'user', 'Pauleen Villaruel', '2025-0723', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5370, '2025-0777', 'nicole.silva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$j2T5y0J8dFrfXovVAtyenuZNm7YVOHROUx30/WpW5ZhCZWlJ7vICe', 'user', 'Nicole Silva', '2025-0777', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5371, '2025-0731', 'jeane.sulit@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qRUECwIcCt5SpiRKbfqz.udDZH87A3tMfzOjIdWYVegr8YAVf2y7y', 'user', 'Jeane Sulit', '2025-0731', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5369, '2025-0734', 'rhenelyn.sandoval@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Wvn12CJotrlr3mShJKl0OuIcMQBFjLfZTr4bxBWV/GzqVTTWQyihO', 'user', 'Rhenelyn Sandoval', '2025-0734', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5366, '2025-0779', 'jeafrancine.rivera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$BeVQMHebCWZH5W4WyohO9utLfBWhW3PTk2kfphN1p437R2ik8n58i', 'user', 'Jea Francine Rivera', '2025-0779', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5367, '2025-0788', 'ashlynicole.rana@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GHrczWPz.Jhqxpt.kY.76.K5iJI.e4Tg.4py4Vv7QZ0WWY1mtY0FG', 'user', 'Ashly Nicole Rana', '2025-0788', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5368, '2025-0741', 'aimiejane.reyes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zJJeIYfai.u0qdYI99lWw.XsnH.2bkCpnpSBhsCD2o1TXvL9MgfLu', 'user', 'Aimie Jane Reyes', '2025-0741', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5365, '2025-0647', 'argel.ocampo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$g0dBicW/HqLQedFfjqUOBeRUbUqeEWpuDRsgSat9NzAubzMXxmHNm', 'user', 'Argel Ocampo', '2025-0647', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5364, '2025-0728', 'materesa.obando@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Q8C7Zonaajbx3cYQy61esuqJha3GtzDNZ2DFFxNk273Si93SXxl3i', 'user', 'Ma. Teresa Obando', '2025-0728', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5363, '2025-0710', 'ericamae.motol@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Z48ChxcYI7YvRCUw21C3XeFsRmkQfonOMAjHkvueehS1EDkiO3eLy', 'user', 'Erica Mae Motol', '2025-0710', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5362, '2025-0729', 'camille.milambiling@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$LU4xii8Tu2gE8epZqI8hZuRyqko2166IZIzmqHf.3gc6d6Qunk.AW', 'user', 'Camille Milambiling', '2025-0729', 1, 'active', '2026-03-15 11:29:43', '2026-03-15 11:29:43', NULL),
(5361, '2025-0609', 'leslie.melgar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Cp75AEzeQx0pmpyRXiZgzu3xBa3SCKt5OPwPcBYcrQj8VNnl3lJJi', 'user', 'Leslie Melgar', '2025-0609', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5360, '2025-0808', 'remzannescarlet.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$MXY8c4HGVjMB1jfe4GABgeOHt.p0PMWZTAiFWOrAG5ki/ikcGmwo2', 'user', 'Remz Ann Escarlet Macapuno', '2025-0808', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5358, '2025-0655', 'edlyn.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0zdPeVrQY73rFlYi4WV8y.NgiSekEE5hr0bJwApVraaHn73EpV1Fq', 'user', 'Edlyn Hernandez', '2025-0655', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5359, '2025-0633', 'angela.lotho@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$2T4XBJXOP9GwdKAgvtNXnOoOaL2tulR1k8EQURG9HNVCpEQGvJPeu', 'user', 'Angela Lotho', '2025-0633', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5357, '2025-0737', 'shalemar.geroleo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$TtTs5ZIMjIaL3g/Q4Ty0/u.dvbGRdq.Pm8pJLKIqQ4en.LjYXBLLG', 'user', 'Shalemar Geroleo', '2025-0737', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5356, '2025-0713', 'katrice.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zbBVGeEOR8kweElxisZHzeT6U3OV3K6hdX0rTimmElgatc3W3Cm.2', 'user', 'Katrice Garcia', '2025-0713', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5354, '2025-0618', 'judith.fallarna@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$XcljuaeZovTM94ZrlXZDze9rMRpeuGl3V/LaN/ygFVnEXLHPWftvi', 'user', 'Judith Fallarna', '2025-0618', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5355, '2025-0654', 'jenelyn.fonte@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$s4yAi0jxYTzgELsZRtdpbuUacRDqhR6P2JphkO1zIM8AcgCjnOLb6', 'user', 'Jenelyn Fonte', '2025-0654', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5353, '2025-0657', 'ailla.fajura@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$x/fXkwNbUmc7N3qyzxE1xekbY8lseg1/PyM/yZjrHNU6Eh24XS44C', 'user', 'Ailla Fajura', '2025-0657', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5352, '2025-0688', 'elaycamae.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$BE9tTAe4CuBs3S8g5Lmmuea/uL.Cpp1oiSgWPnvBhT8Ul098szKm6', 'user', 'Elayca Mae Fajardo', '2025-0688', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5351, '2025-0611', 'christinasofialie.enriquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.CjVY3KDot8TbrhW0k/lfOb73KzjMiwm0zqfpRKIC/pIWgSphQb9m', 'user', 'Christina Sofia Lie Enriquez', '2025-0611', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5350, '2025-0612', 'romelyn.elida@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qM59mBV5GdnVf5OKoSSiouHipLRKm6Npwqr8N.6O4SeKriEX/5Vc6', 'user', 'Romelyn Elida', '2025-0612', 1, 'active', '2026-03-15 11:29:42', '2026-03-15 11:29:42', NULL),
(5346, '2025-0727', 'prencesangel.consigo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$/j6jCEzJKLb.6lkiCDEoWOJTt6oDWpEObVOfGnc13KwXWCifK.uWm', 'user', 'Prences Angel Consigo', '2025-0727', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5347, '2025-0742', 'jamhyca.dechavez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Ks1Ze9VUklQt6nCkZfHGL.2IZhn60XsJuXq29o1oV.R5kvexxTe2e', 'user', 'Jamhyca De Chavez', '2025-0742', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5349, '2025-0722', 'sophiaangela.delosreyes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$gNbFH2T3UIeTXkBjlERz3O.vgAckakbvHEAlLu2gU/U871qshxy3W', 'user', 'Sophia Angela Delos Reyes', '2025-0722', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5348, '2025-0673', 'nicole.defeo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$HzZMABL9csktD6Bfy.2Sx.YE.mlKX9FEUTy2wb0iOo8gatmVoqqF6', 'user', 'Nicole Defeo', '2025-0673', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5345, '2025-0711', 'claren.carable@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$0qsKEt.mv/oLEMx0g4NuN.e3QdnBFTuTb.X0HoKK2nEcEvvtTv/2e', 'user', 'Claren Carable', '2025-0711', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5344, '2025-0638', 'shiellamae.bonifacio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$qyC.dmnfxjdYsnIpTW9nBuNGe.LBEHZQI9SeyM3kuCTj.UAxxOFdK', 'user', 'Shiella Mae Bonifacio', '2025-0638', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5343, '2025-0783', 'lorraine.bonado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$uL6pjos54J1ZlX4QpKugmOka3itjYXvPwRlamX1nvXBMV2/vY8M2e', 'user', 'Lorraine Bonado', '2025-0783', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5342, '2025-0679', 'alexajane.bon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$EVKb4Dt3UwhHWFU4g3jZOO1U6AkilagKE25eGLarCcQC2RN.Ax2cu', 'user', 'Alexa Jane Bon', '2025-0679', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5341, '2025-0646', 'jhovelyn.bacay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$c9uJGoJxtm8z/lXkREKD1Olf9CKwxPYsap/5JlvJgMnKq4nACtlWa', 'user', 'Jhovelyn Bacay', '2025-0646', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5340, '2025-0680', 'jonahtrisha.asi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$LbjLc1FH9sMvXnqxza14h.rTxCSKtz3NlHzzHEy4tkwo8Cq58G9PS', 'user', 'Jonah Trisha Asi', '2025-0680', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5337, '2025-0619', 'hanna.aborde@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$QOSUJ/hJOWqfol326gCQOOoPdNNnYupC6CoD28Of8DIe7TtLGOhlm', 'user', 'Hanna Aborde', '2025-0619', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5338, '2025-0765', 'rysamae.alfante@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.a7Ktz4zpQZkJ9iaWvn.u.qHo0I5Z9Q37a2CFEI/fOEaAaqwefyOa', 'user', 'Rysa Mae Alfante', '2025-0765', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5339, '2025-0809', 'jeny.amado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$lUDpxKdillk9NMvUPafFuuW2jSDAdDmMkhaImfVl0mqmbmu1c4v6q', 'user', 'Jeny Amado', '2025-0809', 1, 'active', '2026-03-15 11:29:41', '2026-03-15 11:29:41', NULL),
(5336, '2025-0733', 'shaneashley.abendan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$smF4sUiySpWNlOYB8NW6hubQLGpRkmJzOnFLUZdkEME5o0sWPepoG', 'user', 'Shane Ashley Abendan', '2025-0733', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5333, '2025-0762', 'erwin.tejedor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$HNhcEZJcFHoYdJ8bXsLg0OQ/dL53eQLFOMZZv3rvU4JO32bARrDEa', 'user', 'Erwin Tejedor', '2025-0762', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5335, '2025-0617', 'kann.abela@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Ik0kBYeMKTrZUkEZR3twP.PGJWYMlsijcCMhEALouiCja1qyvPYvu', 'user', 'K-Ann Abela', '2025-0617', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5334, '2025-0747', 'brixmatthew.velasco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$knJMiav3bxKncrpRJMiQAOdI93DlTJA2rYFx9wO8SXaRpecioEn5O', 'user', 'Brix Matthew Velasco', '2025-0747', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5332, '2025-0801', 'melgabriel.magat@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ImbsCdf5jfl2mzpkiKs7ZORwIWx36GUk5EVWt3QaDrQwxzoV4SHPa', 'user', 'Mel Gabriel Magat', '2025-0801', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5331, '2025-0785', 'jairus.macuha@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GiM49QzFA1NJeVGuMLIyE.ZleBn89anNY3JIjQlNZsGzFvPR7qhN.', 'user', 'Jairus Macuha', '2025-0785', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5330, '2025-0636', 'jarred.gomez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$5aMSbVPA.KHvSrRS6Gm42.Ouq4JHZP8eFrjQ5Ws.g.qW4JBYtDU/u', 'user', 'Jarred Gomez', '2025-0636', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5328, '2025-0726', 'aldrin.carable@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$FlMmr0du/3.WBe4qtXGeaeSUlba1cfdes7djWJ/oZ2foCoc19w6da', 'user', 'Aldrin Carable', '2025-0726', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5329, '2025-0743', 'daniel.franco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$SlNP5A0/Cu7Fc4frL1Q3o.YwC0ZjAby8Tq//D3DwC87awbnoZPQ0O', 'user', 'Daniel Franco', '2025-0743', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5327, '2025-0705', 'danilorjr.cabiles@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ouuTtpcf8eyMcnBzjr/ZSez5wSD/Zbm64YhwU6AHUk5gOppmk9RUW', 'user', 'Danilo R. Jr Cabiles', '2025-0705', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5326, '2025-0629', 'felicity.villegas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$PnEtykm0i2lDgdwsGRUsbOPTKXYRx4VZoGedwbNHs.2a54zx4gzc2', 'user', 'Felicity Villegas', '2025-0629', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5325, '2025-0643', 'wyncel.tolentino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$QNFPQkgQ8ULxXvCaRVlUpudNuc1rVpT7YFrgCLCDwWnytC79W6jpy', 'user', 'Wyncel Tolentino', '2025-0643', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5323, '2025-0796', 'rubilyn.roxas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$sbZztP.8dRgEOrdBA/qpse.rjUPjGqdtvdAhHI4WfR5/Y173lYoiu', 'user', 'Rubilyn Roxas', '2025-0796', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(5324, '2025-0718', 'mariebernadette.tolentino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$w5.Y03OeJiCINTSVq/0AIuw4zXWq4uzVgM08ZwiFGFNYda4rSY7k.', 'user', 'Marie Bernadette Tolentino', '2025-0718', 1, 'active', '2026-03-15 11:29:40', '2026-03-15 11:29:40', NULL),
(3116, 'adminOsas@colegio.edu', 'adminOsas@colegio.edu', NULL, NULL, NULL, '$2y$10$18hPsHdTOOqn8S0jcVE8Je8URHOsCgj6QUzuYFPCqxrrhri0TN2T6', 'admin', 'Cedrick H. Almarez', '2020', 1, 'active', '2026-03-12 02:42:40', '2026-03-15 13:41:23', NULL),
(5322, '2025-0789', 'irishcatherine.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$lsoD3YFarQ4FGM7VrcNxw.TfW3ctaEWFDAPk96bVZsgAPhznWztui', 'user', 'Irish Catherine Ramos', '2025-0789', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5321, '2025-0770', 'ivykristine.petilo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$mkhdz99lnKZOoUxVojPch.BK6GOMfc1Mu90yuVs6cOxfjTc4Nbb2a', 'user', 'Ivy Kristine Petilo', '2025-0770', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5320, '2025-0766', 'althea.paala@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$w7Jk3TttKDE1ZfLWoOv4kupIlBoTJkKE7FxFvO0erGH8qT1HFlfxG', 'user', 'Althea Paala', '2025-0766', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5319, '2025-0699', 'lleynangela.olympia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$2aJhhQKti2NY7tkm8s1ODOheqK8tuAkBXLQItd4YpZ29Hdv/jlQwa', 'user', 'Lleyn Angela Olympia', '2025-0699', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5318, '2025-0772', 'romelyn.mongcog@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ZljqjBIfyAZTn3nu.p0uvekB.YtBLNputRNDO7HZGZTWTaxOEtomm', 'user', 'Romelyn Mongcog', '2025-0772', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5316, '2025-0763', 'lorainb.medina@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$S1cXE5uBksfPD.evNXQRa.78wxwZO4Wmmp2sDmv4HucZ75GtKrA5S', 'user', 'Lorain B Medina', '2025-0763', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5317, '2025-0767', 'lovelyjoy.mercado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$rhBN3Vd7xMMHFGp6MsAqMOz.I/wtrmoQch7BRFRGsnaIdkZV.y6Ji', 'user', 'Lovely Joy Mercado', '2025-0767', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5315, '2025-0771', 'mikee.manay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$AmEbmoXOo6AZ5UOd.E9bnuPbDLeiIsiDguSuIaxd1lYcnejmAtY2S', 'user', 'Mikee Manay', '2025-0771', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5313, '2025-0805', 'mae.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ye1CHgcH9IcWmPMtXLg5pOruIwyshOP4CM2WtysjsfonM/n1rrxPO', 'user', 'Mae Hernandez', '2025-0805', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5314, '2025-0656', 'arianbello.maculit@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$d/EhJ37qAKT2CKHleey5vORWmmzRD3zQ9qtf5V0rHk8KFp6aAZZme', 'user', 'Arian Bello Maculit', '2025-0656', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5312, '2025-0786', 'bheajane.gillado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4wchgd8gBn3b2KxIvtfnmeXpH6X1TUCBgCumEN8jykV1WV6goufwy', 'user', 'Bhea Jane Gillado', '2025-0786', 1, 'active', '2026-03-15 11:29:39', '2026-03-15 11:29:39', NULL),
(5311, '2025-0800', 'aleah.gida@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$x1sP9Dj3ZsBxLtKAjkwii.LEauaoR.k.XCbJYZMSLKbvljP04b4fm', 'user', 'Aleah Gida', '2025-0800', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5310, '2025-0667', 'janel.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$wDCqZG5xuUnHIuMQTTU/VOS7C/KLfFe1nSlGH9/QKMiVgePV9Ymrq', 'user', 'Janel Garcia', '2025-0667', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5308, '2025-0755', 'sharmaine.fonte@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$5eRgYzjlcSLP/fP/OZtGZOth0A8M18wsI6Ju9gE7A42uwCRDgH0fO', 'user', 'Sharmaine Fonte', '2025-0755', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5309, '2025-0756', 'crystal.gagote@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$r4N46JeCtkjy5dWazN5JYOUWg9kEMZ.7qDIl1dQ5j4jHwWXvf0VyS', 'user', 'Crystal Gagote', '2025-0756', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5307, '2025-0668', 'zeandane.falcutila@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$8X5hC04bkBAlQAF4/F6uouse.q3eLh9NQqTvfGOPn4V8g56OJJRSe', 'user', 'Zean Dane Falcutila', '2025-0668', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5306, '2025-0754', 'analyn.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$NoyGln/9cFdwbwCrkUm.h..B6Bt6Q4aNCBppn8aEm7MCJELNhW4HG', 'user', 'Analyn Fajardo', '2025-0754', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5305, '2025-0778', 'shane.dudas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$QNjqAXDFb7xuze9mq54Rw.CaPHyhNpwcKVw4dwOfkmr1Si3zYqmD6', 'user', 'Shane Dudas', '2025-0778', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5302, '2025-0793', 'marrajane.cleofe@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$TdcGRXAAMcqsIZBk4onOy.UDPYPHfgGW9Kuafqg2zCjxY2J8XJDOa', 'user', 'Marra Jane Cleofe', '2025-0793', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5304, '2025-0790', 'annanicole.deleon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$vIyfnrRX/MuE/dJ8.aCkw.KjPZk3IMJYbVDaRMyS0wYGJ0DrEWAae', 'user', 'Anna Nicole De Leon', '2025-0790', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5303, '2025-0637', 'jocelyn.deguzman@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Lrv.jCV1xlB7RjvC73ph/OokUqpfgjycPcxK2/V/qWe.FQfwE73Xq', 'user', 'Jocelyn De Guzman', '2025-0637', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5301, '2025-0758', 'danicabea.castillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$fKOIqgE8thh4WDhIRrTI2ukoqzq1mW53V6Ot96fmNwO7ATU9adpdC', 'user', 'Danica Bea Castillo', '2025-0758', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5300, '2025-0676', 'rhealyne.cardona@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$TKcBMsdvY7K2yEMoj8Yc3ubP/PxGRuQ4VnCX5FjU7hSSYu5Q5xrei', 'user', 'Rhealyne Cardona', '2025-0676', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5299, '2025-0658', 'myka.braza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4klrEbrof3ximDU.BG6Cwu6jddV.ZkoO.kr0OIVWNAwFANFyObSRi', 'user', 'Myka Braza', '2025-0658', 1, 'active', '2026-03-15 11:29:38', '2026-03-15 11:29:38', NULL),
(5298, '2025-0745', 'charisma.banila@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$jH5Co2rTE9sbbFGtAuy4ROlq8vt.dTvwM2ExY.lZiSn/jJ66dEQ4W', 'user', 'Charisma Banila', '2025-0745', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5297, '2025-0797', 'marydith.atienza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$VNJ6Kj8A5W0Qx/oO6.EdquwgwdnM79rvAGh0mUSta2K7COCHJ4wwu', 'user', 'Marydith Atienza', '2025-0797', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5295, '2025-0534', 'khim.tejada@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$D1Cq9U99daMw56dkc917beOdqgszwJyGD0QljZykie7Jk3W8ymmwG', 'user', 'Khim Tejada', '2025-0534', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5296, '2025-0784', 'maryann.asi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$tw27GlZobAQtGVH2P1YPxu9iA6ZFTX.WJbPKYr8v9XL/rvqVQI3wu', 'user', 'Mary Ann Asi', '2025-0784', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5294, '2025-0692', 'johnkenneth.perez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iIfW1pe6NqUbUg9NJaWuU.t80j5cEqmvpaQnFpjxE0PxtnIcnEvVe', 'user', 'John Kenneth Perez', '2025-0692', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5293, '2025-0606', 'jhonjake.perez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$YyCN5tcZE9yPOndcCrXPheLOiuhkT.ZScQg12ZjnxRHSDdOvoFWiW', 'user', 'Jhon Jake Perez', '2025-0606', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5292, '2025-0686', 'johnwin.pastor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$z2XmT72b1C9x/IJ1/bZMxOtysw3TMafwoEt3mtpCsoFWA1Jn1efoK', 'user', 'Johnwin Pastor', '2025-0686', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5291, '2025-0757', 'johnlord.moreno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4xklPmSoqBMVeZ9R4iErxePEEjOYrcfXnRJArzCG/lrvXlGyqPSIi', 'user', 'John Lord Moreno', '2025-0757', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5290, '2025-0649', 'ronron.montero@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$vO16SXjH.GoYTFe4wiNBWetNGgVTyurcHLFt5zVPoOV8z3BURPxHW', 'user', 'Ron-Ron Montero', '2025-0649', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5289, '2025-0594', 'marlex.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$X5MzpLmzDx2uzJtyMu73cuxUa1IXi88dFEBwFZIkou8Q3Dnp3a.TO', 'user', 'Marlex Mendoza', '2025-0594', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5287, '2025-0746', 'jhonloyd.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$zkvbJb/2JM/T3HR03iGw0OC48Fu5exW74Z36m3UgEjZ9c5M3eSTPy', 'user', 'Jhon Loyd Macapuno', '2025-0746', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5288, '2025-0672', 'paultristan.madla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ibaIg7h7x5b/rAJptuuPWO.WsJKpzIV/qhvIAH7SzPqRo2PVfajNC', 'user', 'Paul Tristan Madla', '2025-0672', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5286, '2025-0794', 'jaypee.jacob@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$C37Gf.2/50sFFNn30ydyVeiG8380pyyKTNd7nV9WNofHHDxzTS5w2', 'user', 'Jaypee Jacob', '2025-0794', 1, 'active', '2026-03-15 11:29:37', '2026-03-15 11:29:37', NULL),
(5285, '2025-0795', 'edwardjohn.holgado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$4fXxEMZSiuw2PPVrEbnE1.bwsjsHqjsgM4hs1lCoK/ysjlwQrCLmu', 'user', 'Edward John Holgado', '2025-0795', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5284, '2025-0603', 'bobbyjr.godoy@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$u0NVcHS2MDw3tgNAezmZBO2Jc.eCSsNgdLbXmsvTowfCmHSPZJuea', 'user', 'Bobby Jr. Godoy', '2025-0603', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5283, '2025-0593', 'jared.gasic@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$HKac8xK4BG/F.Skw4MIsWOaveG0LvAAHC4/ity9AxMms2KJZXaOJa', 'user', 'Jared Gasic', '2025-0593', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5281, '2025-0602', 'markangeloriza.francisco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$BV6XOjaBqA99jbY07YvIVO8312z5eCi.GeotJVW.FCfRjsfGEh7R6', 'user', 'Mark Angelo Riza Francisco', '2025-0602', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5282, '2025-0363', 'jhakeperillo.garan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Vx5aBGpZtpb3/3wVIupbD.DXZzmm.KkAyN690R4thKosDyX2qcF2m', 'user', 'Jhake Perillo Garan', '2025-0363', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5279, '2025-0604', 'giandominicriza.dudas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$CamsAshJhpL9p1PemqPa0eIGhNLp/tFacYDikjTY5zZnVca4tYQMS', 'user', 'Gian Dominic Riza Dudas', '2025-0604', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5280, '2025-0703', 'markneil.fajil@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$xVaih0xaV5QP4/Rx47EenOrL7rTUUZzPcy9I7uD/wvqLZwaTvbsyO', 'user', 'Mark Neil Fajil', '2025-0703', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5278, '2025-0799', 'khyn.delosreyes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$opDJ2nhzbriex81gSzx1FeFq9M.BCgB9QyURu2C9Rlaqc5mnvvzjC', 'user', 'Khyn Delos Reyes', '2025-0799', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5276, '2025-0773', 'johnlloyd.castillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ge0W8shnLWmjGR/pDKq6U.xW9e8Kqej6BygqNdDNaUyBUm9XZAonO', 'user', 'John Lloyd Castillo', '2025-0773', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5277, '2025-0616', 'jericho.delmundo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$iwu5g4bo/ghrEwZhF7Vayug0XnCV5AFNtXFwY0eoiw3sU6qPA2CUu', 'user', 'Jericho Del Mundo', '2025-0616', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5275, '2025-0807', 'aceromar.castillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$803UP2qXA/kOqcf23ZoyruSKuQpifJzUhxLvfTUj6pfdqNEiVv9lG', 'user', 'Ace Romar Castillo', '2025-0807', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5272, '2025-0810', 'lyramae.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GwuFKrQ3RCMDor0wEy80Xuz0tBrhY1kiBtnr.2eOoVN1cLxiyigzu', 'user', 'Lyra Mae Villanueva', '2025-0810', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5274, '2025-0687', 'johnphilipmontillana.batarlo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$ZrVERJVgXv4XtFPFNC8nZuAxrP6fqngnxGz.W5UR0UAj46KmFpHA2', 'user', 'John Philip Montillana Batarlo', '2025-0687', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5273, '2025-0608', 'rhaizza.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$cARQUoeRuWIoG6CvMNG3w.H8S28xFlBO41MIjaQSMhcEUiMBxRpOW', 'user', 'Rhaizza Villanueva', '2025-0608', 1, 'active', '2026-03-15 11:29:36', '2026-03-15 11:29:36', NULL),
(5271, '2025-0630', 'jonalyn.untalan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$dtdLzgK7mK/bRfq9MeVjjuv.A8nA00bQnWV7d20W/EZWyf/9UG2hC', 'user', 'Jonalyn Untalan', '2025-0630', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5270, '2025-0707', 'camille.tordecilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$U8UkDQASAekT/KBpYOL6Gez.bG3kh3EyG3zf2vtqhTj.Gaz/aS8lC', 'user', 'Camille Tordecilla', '2025-0707', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5268, '2025-0792', 'ashley.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$.tM5ZEjTxGChjF53RM6jG.IivR2GFlgBAxYPap7JLdc9nf9FMcm9S', 'user', 'Ashley Mendoza', '2025-0792', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5269, '2025-0761', 'anamarie.quimora@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$LBc/YMMWmF37aBCemxeO/ujO7GPHYnO5t.lo6XfITFTNTnkeCQloa', 'user', 'Ana Marie Quimora', '2025-0761', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5267, '2025-0704', 'keana.marquinez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$fukaMnZiquwDFx8wNSGnjugdXwa9GjeWHSqlILnF3JT0EjL55g9eK', 'user', 'Keana Marquinez', '2025-0704', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5266, '2025-0607', 'amaya.maibo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$UGS.zrxff0WTeJJ2g.j1U.l.n29PbudzhZx.hAmBvCZZVo49/jMhO', 'user', 'Amaya Mañibo', '2025-0607', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5265, '2025-0706', 'kylyn.jacob@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$GpW6fnrc4UMcov4vtB50h.mKBUyA7TFqzOetmJGkbqXcpu10v1AJe', 'user', 'Kylyn Jacob', '2025-0706', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5262, '2025-0812', 'altheanicoleshane.dudas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$Eid.WlzNt4xFqMnvxa0PPek1jywlyYLYKIHHTDWo9iUFTf4kWE1uG', 'user', 'Althea Nicole Shane Dudas', '2025-0812', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5264, '2025-0714', 'kyla.jacob@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$CqQVCcVXbKJgyVj1JTIYQeu6y.ytj7HMBuijm19I7Egjb8IlSLHNC', 'user', 'Kyla Jacob', '2025-0714', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5263, '2025-0631', 'jasmine.gelena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$JBkoc/oZR/kVxM61Ee4AUenfiwfm4m7fQYF.THV482gBNjCYMAxga', 'user', 'Jasmine Gelena', '2025-0631', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL),
(5261, '2025-0760', 'jerlyn.aday@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$bCQ5Xq7v4xXn4FpF0CXtIeezlAYIAffRiEHjcBv3hV7o7fmbVlrJG', 'user', 'Jerlyn Aday', '2025-0760', 1, 'active', '2026-03-15 11:29:35', '2026-03-15 11:29:35', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `violations`
--

DROP TABLE IF EXISTS `violations`;
CREATE TABLE IF NOT EXISTS `violations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `case_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `student_id` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `violation_type_id` int NOT NULL,
  `violation_level_id` int NOT NULL,
  `department` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `section` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `violation_date` date NOT NULL,
  `violation_time` time NOT NULL,
  `location` enum('gate_1','gate_2','classroom','library','cafeteria','gym','others') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `reported_by` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `status` enum('permitted','warning','disciplinary','resolved') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'warning',
  `attachments` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `is_archived` tinyint(1) DEFAULT '0',
  `is_read` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `case_id` (`case_id`),
  KEY `idx_case_id` (`case_id`),
  KEY `idx_student_id` (`student_id`),
  KEY `idx_department` (`department`),
  KEY `idx_status` (`status`),
  KEY `idx_violation_date` (`violation_date`),
  KEY `idx_violation_type` (`violation_type_id`),
  KEY `idx_violation_level` (`violation_level_id`),
  KEY `idx_is_archived` (`is_archived`),
  KEY `idx_is_read` (`is_read`)
) ENGINE=InnoDB AUTO_INCREMENT=105 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `violations`
--

INSERT INTO `violations` (`id`, `case_id`, `student_id`, `violation_type_id`, `violation_level_id`, `department`, `section`, `violation_date`, `violation_time`, `location`, `reported_by`, `notes`, `status`, `attachments`, `created_at`, `updated_at`, `deleted_at`, `is_archived`, `is_read`) VALUES
(97, 'VIOL-2026-001', '2023-0206', 3, 13, 'Bachelor of Science in Information Systems', '12', '2026-03-08', '11:14:00', 'gate_2', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-07 19:15:04', '2026-03-08 03:15:04', NULL, 0, 0),
(98, 'VIOL-2026-002', '2023-0206', 3, 14, 'Bachelor of Science in Information Systems', '12', '2026-03-08', '12:16:00', 'gate_1', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-07 20:16:29', '2026-03-08 04:16:29', NULL, 0, 0),
(99, 'VIOL-2026-003', '2023-0206', 1, 1, 'Bachelor of Science in Information Systems', '12', '2026-03-08', '12:26:00', 'gate_2', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-08 04:27:06', '2026-03-08 04:27:06', NULL, 0, 0),
(100, 'VIOL-2026-004', '2023-0206', 2, 7, 'Bachelor of Science in Information Systems', '12', '2026-03-08', '12:31:00', 'gate_2', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-08 04:31:57', '2026-03-08 04:31:57', NULL, 0, 0),
(101, 'VIOL-2026-005', '2023-0195', 3, 13, 'Bachelor of Science in Information Systems', '12', '2026-03-11', '20:03:00', 'classroom', 'adminOsas@colegio.edu', 'not wearing proper uniform', 'permitted', NULL, '2026-03-11 12:03:54', '2026-03-11 12:03:54', NULL, 0, 0),
(102, 'VIOL-2026-006', '2023-0195', 3, 14, 'Bachelor of Science in Information Systems', '12', '2026-03-11', '23:02:00', 'gate_2', 'Admin User', NULL, 'permitted', NULL, '2026-03-11 15:02:33', '2026-03-11 15:02:33', NULL, 0, 0),
(103, 'VIOL-2026-007', '2023-0216', 3, 13, 'Bachelor of Science in Information Systems', '12', '2026-03-12', '09:12:00', 'others', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-12 01:13:27', '2026-03-12 01:13:27', NULL, 0, 0),
(104, 'VIOL-2026-008', '2023-0216', 3, 14, 'Bachelor of Science in Information Systems', '12', '2026-03-12', '10:43:00', 'others', 'June Paul Anuevo', 'Matigas an ulo', 'permitted', NULL, '2026-03-12 02:44:26', '2026-03-12 02:44:26', NULL, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `violation_levels`
--

DROP TABLE IF EXISTS `violation_levels`;
CREATE TABLE IF NOT EXISTS `violation_levels` (
  `id` int NOT NULL AUTO_INCREMENT,
  `violation_type_id` int NOT NULL,
  `level_order` int NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `violation_type_id` (`violation_type_id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `violation_levels`
--

INSERT INTO `violation_levels` (`id`, `violation_type_id`, `level_order`, `name`, `description`, `created_at`, `updated_at`) VALUES
(1, 1, 1, 'Permitted 1', 'First permitted instance', '2026-02-04 21:42:49', NULL),
(2, 1, 2, 'Permitted 2', 'Second permitted instance', '2026-02-04 21:42:49', NULL),
(3, 1, 3, 'Warning 1', 'First warning', '2026-02-04 21:42:49', NULL),
(4, 1, 4, 'Warning 2', 'Second warning', '2026-02-04 21:42:49', NULL),
(5, 1, 5, 'Warning 3', 'Final warning', '2026-02-04 21:42:49', NULL),
(6, 1, 6, 'Disciplinary Action', 'Referral to discipline office', '2026-02-04 21:42:49', NULL),
(7, 2, 1, 'Permitted 1', 'First permitted instance', '2026-02-04 21:42:49', NULL),
(8, 2, 2, 'Permitted 2', 'Second permitted instance', '2026-02-04 21:42:49', NULL),
(9, 2, 3, 'Warning 1', 'First warning', '2026-02-04 21:42:49', NULL),
(10, 2, 4, 'Warning 2', 'Second warning', '2026-02-04 21:42:49', NULL),
(11, 2, 5, 'Warning 3', 'Final warning', '2026-02-04 21:42:49', NULL),
(12, 2, 6, 'Disciplinary Action', 'Referral to discipline office', '2026-02-04 21:42:49', NULL),
(13, 3, 1, 'Permitted 1', 'First permitted instance', '2026-02-04 21:42:49', NULL),
(14, 3, 2, 'Permitted 2', 'Second permitted instance', '2026-02-04 21:42:49', NULL),
(15, 3, 3, 'Warning 1', 'First warning', '2026-02-04 21:42:49', NULL),
(16, 3, 4, 'Warning 2', 'Second warning', '2026-02-04 21:42:49', NULL),
(17, 3, 5, 'Warning 3', 'Final warning', '2026-02-04 21:42:49', NULL),
(18, 3, 6, 'Disciplinary Action', 'Referral to discipline office', '2026-02-04 21:42:49', NULL),
(19, 4, 1, 'Permitted 1', 'First permitted instance', '2026-02-04 21:42:49', NULL),
(20, 4, 2, 'Permitted 2', 'Second permitted instance', '2026-02-04 21:42:49', NULL),
(21, 4, 3, 'Warning 1', 'First warning', '2026-02-04 21:42:49', NULL),
(22, 4, 4, 'Warning 2', 'Second warning', '2026-02-04 21:42:49', NULL),
(23, 4, 5, 'Warning 3', 'Final warning', '2026-02-04 21:42:49', NULL),
(24, 4, 6, 'Disciplinary Action', 'Referral to discipline office', '2026-02-04 21:42:49', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `violation_types`
--

DROP TABLE IF EXISTS `violation_types`;
CREATE TABLE IF NOT EXISTS `violation_types` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `violation_types`
--

INSERT INTO `violation_types` (`id`, `name`, `description`, `created_at`, `updated_at`) VALUES
(1, 'Improper Uniform', 'Wearing colored undershirt, improper pants, etc.', '2026-02-04 21:42:49', NULL),
(2, 'No ID', 'Failure to wear or bring student ID', '2026-02-04 21:42:49', NULL),
(3, 'Improper Footwear', 'Wearing slippers, open-toed shoes, etc.', '2026-02-04 21:42:49', NULL),
(4, 'Misconduct', 'Behavioral violations', '2026-02-04 21:42:49', NULL);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `messages`
--
ALTER TABLE `messages`
  ADD CONSTRAINT `fk_messages_announcement` FOREIGN KEY (`announcement_id`) REFERENCES `announcements` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `report_recommendations`
--
ALTER TABLE `report_recommendations`
  ADD CONSTRAINT `fk_report_recommendations_report` FOREIGN KEY (`report_id`) REFERENCES `reports` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `report_violations`
--
ALTER TABLE `report_violations`
  ADD CONSTRAINT `fk_report_violations_report` FOREIGN KEY (`report_id`) REFERENCES `reports` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `sections`
--
ALTER TABLE `sections`
  ADD CONSTRAINT `sections_ibfk_1` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `students`
--
ALTER TABLE `students`
  ADD CONSTRAINT `students_ibfk_1` FOREIGN KEY (`section_id`) REFERENCES `sections` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `violations`
--
ALTER TABLE `violations`
  ADD CONSTRAINT `fk_violations_level` FOREIGN KEY (`violation_level_id`) REFERENCES `violation_levels` (`id`),
  ADD CONSTRAINT `fk_violations_type` FOREIGN KEY (`violation_type_id`) REFERENCES `violation_types` (`id`);

--
-- Constraints for table `violation_levels`
--
ALTER TABLE `violation_levels`
  ADD CONSTRAINT `fk_violation_levels_type` FOREIGN KEY (`violation_type_id`) REFERENCES `violation_types` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
