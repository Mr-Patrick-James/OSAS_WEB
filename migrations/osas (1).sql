-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Mar 10, 2026 at 05:54 AM
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
(6, 'New Policy Update', 'Please review the updated student handbook.', 'info', 'active', 3, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(7, 'Payment Deadline', 'Tuition payment deadline is on Friday.', 'warning', 'active', 3, '2025-12-15 16:25:36', '2026-03-10 01:13:13', '2026-03-09 17:13:13'),
(8, 'Library Closed', 'The library will be closed for renovation.', '', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:12:47', '2026-03-09 17:12:47'),
(9, 'Seminar Announcement', 'A leadership seminar will be held in the auditorium.', '', 'active', 1, '2025-12-15 16:25:36', '2026-03-10 01:12:37', '2026-03-09 17:12:37'),
(10, 'System Upgrade', 'New system features have been deployed.', 'info', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(11, 'Network Issue', 'Some users may experience network interruptions.', 'warning', '', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(12, 'Sports Fest', 'Annual sports fest starts next week.', '', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:12:31', '2026-03-09 17:12:31'),
(13, 'ID Registration', 'Student ID registration is ongoing.', 'info', 'active', 3, '2025-12-15 16:25:36', '2026-03-10 01:12:51', '2026-03-09 17:12:51'),
(14, 'Class Resumption', 'Classes will resume on Monday.', 'info', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:12:57', '2026-03-09 17:12:57'),
(15, 'Fire Drill', 'A campus-wide fire drill will be conducted.', '', 'active', 1, '2025-12-15 16:25:36', '2026-03-10 01:13:01', '2026-03-09 17:13:01'),
(16, 'Parking Advisory', 'Limited parking slots available today.', 'warning', 'active', 3, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(17, 'System Bug Fix', 'Reported bugs have been fixed.', '', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(18, 'Workshop Invite', 'Join the career development workshop.', '', 'active', 2, '2025-12-15 16:25:36', '2026-03-10 01:13:07', '2026-03-09 17:13:07'),
(19, 'Account Security', 'Enable two-factor authentication for security.', 'warning', 'active', 1, '2025-12-15 16:25:36', '2026-03-10 01:13:19', '2026-03-09 17:13:19'),
(20, 'Announcement Test', 'This is a test announcement record.', 'info', '', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(21, 'Uniform', 'Alway were proper uniform', 'info', 'active', 2572, '2026-03-09 17:01:12', '2026-03-10 01:12:24', '2026-03-09 17:12:24'),
(22, 'Uniform black', 'black month', 'info', 'active', 2572, '2026-03-09 17:08:02', '2026-03-10 01:12:23', '2026-03-09 17:12:23'),
(23, 'Uniform black', 'tesy', 'info', 'active', 2572, '2026-03-10 01:13:32', NULL, NULL);

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
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `departments`
--

INSERT INTO `departments` (`id`, `department_name`, `department_code`, `head_of_department`, `description`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'Bachelor of Technical-Vocational Teacher Education', 'BTVTED', NULL, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(2, 'Bachelor of Public Administration', 'BPA', NULL, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(3, 'Bachelor of Science in Information Systems', 'BSIS', NULL, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL);

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
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reports`
--

INSERT INTO `reports` (`id`, `report_id`, `student_id`, `student_name`, `student_contact`, `department`, `department_code`, `section`, `section_id`, `yearlevel`, `uniform_count`, `footwear_count`, `no_id_count`, `total_violations`, `status`, `last_violation_date`, `report_period_start`, `report_period_end`, `generated_at`, `updated_at`, `deleted_at`) VALUES
(12, 'R491', '2023-0206', 'Patrick James V Romasanta', 'N/A', 'Bachelor of Science in Information Systems', 'BSIS', 'BSIS3', 12, '3rd Year', 1, 2, 1, 4, 'permitted', '2026-03-08', '2026-03-08', '2026-03-08', '2026-03-08 11:15:04', '2026-03-08 12:31:57', NULL);

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
) ENGINE=InnoDB AUTO_INCREMENT=330 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `report_recommendations`
--

INSERT INTO `report_recommendations` (`id`, `report_id`, `recommendation`, `priority`, `created_at`) VALUES
(327, 12, 'Issue written warning', 'medium', '2026-03-10 07:18:17'),
(328, 12, 'Monitor uniform compliance', 'medium', '2026-03-10 07:18:17'),
(329, 12, 'Schedule follow-up meeting', 'medium', '2026-03-10 07:18:17');

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
) ENGINE=InnoDB AUTO_INCREMENT=215 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `report_violations`
--

INSERT INTO `report_violations` (`id`, `report_id`, `violation_id`, `violation_type`, `violation_level`, `violation_date`, `violation_time`, `status`, `notes`, `created_at`) VALUES
(211, 12, 97, 'Improper Footwear', 'Permitted 1', '2026-03-08', '11:14:00', 'permitted', NULL, '2026-03-10 07:18:17'),
(212, 12, 98, 'Improper Footwear', 'Permitted 2', '2026-03-08', '12:16:00', 'permitted', NULL, '2026-03-10 07:18:17'),
(213, 12, 99, 'Improper Uniform', 'Permitted 1', '2026-03-08', '12:26:00', 'permitted', NULL, '2026-03-10 07:18:17'),
(214, 12, 100, 'No ID', 'Permitted 1', '2026-03-08', '12:31:00', 'permitted', NULL, '2026-03-10 07:18:17');

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
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sections`
--

INSERT INTO `sections` (`id`, `section_name`, `section_code`, `department_id`, `academic_year`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'BTVTED-WFT1', 'BTVTED-WFT1', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(2, 'BTVTED-CHS1', 'BTVTED-CHS1', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(3, 'BPA1', 'BPA1', 2, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(4, 'BSIS1', 'BSIS1', 3, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(5, 'BTVTED-WFT2', 'BTVTED-WFT2', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(6, 'BTVTED-CHS2', 'BTVTED-CHS2', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(7, 'BPA2', 'BPA2', 2, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(8, 'BSIS2', 'BSIS2', 3, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(9, 'BTVTED-CHS3', 'BTVTED-CHS3', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(10, 'BTVTED-WFT3', 'BTVTED-WFT3', 1, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(11, 'BPA3', 'BPA3', 2, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
(12, 'BSIS3', 'BSIS3', 3, NULL, 'active', '2026-02-22 22:29:58', NULL, NULL),
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
) ENGINE=InnoDB AUTO_INCREMENT=550 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `students`
--

INSERT INTO `students` (`id`, `student_id`, `first_name`, `middle_name`, `last_name`, `email`, `contact_number`, `address`, `department`, `section_id`, `yearlevel`, `year_level`, `avatar`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, '2025-0760', 'Jerlyn', 'M', 'Aday', 'jerlyn.aday@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(2, '2025-0812', 'Althea Nicole Shane', 'M', 'Dudas', 'althea.nicole.shane.dudas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(3, '2025-0631', 'Jasmine', 'H', 'Gelena', 'jasmine.gelena@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(4, '2025-0714', 'Kyla', 'M', 'Jacob', 'kyla.jacob@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(5, '2025-0706', 'Kylyn', 'M', 'Jacob', 'kylyn.jacob@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(6, '2025-0607', 'Amaya', 'C', 'Mañibo', 'amaya.maibo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(7, '2025-0704', 'Keana', 'G', 'Marquinez', 'keana.marquinez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(8, '2025-0792', 'Ashley', 'A', 'Mendoza', 'ashley.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(9, '2025-0761', 'Ana Marie', 'A', 'Quimora', 'ana.marie.quimora@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(10, '2025-0707', 'Camille', 'M', 'Tordecilla', 'camille.tordecilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(11, '2025-0630', 'Jonalyn', 'H', 'Untalan', 'jonalyn.untalan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(12, '2025-0810', 'Lyra Mae', 'M', 'Villanueva', 'lyra.mae.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(13, '2025-0608', 'Rhaizza', 'D', 'Villanueva', 'rhaizza.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(14, '2025-0687', 'John Philip Montillana', '', 'Batarlo', 'john.philip.montillana.batarlo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(15, '2025-0807', 'Ace Romar', 'B', 'Castillo', 'ace.romar.castillo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(16, '2025-0773', 'John Lloyd', 'B', 'Castillo', 'john.lloyd.castillo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(17, '2025-0616', 'Jericho', 'M', 'Del Mundo', 'jericho.delmundo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(18, '2025-0799', 'Khyn', 'C', 'Delos Reyes', 'khyn.delosreyes@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(19, '2025-0604', 'Gian Dominic Riza', '', 'Dudas', 'gian.dominic.riza.dudas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(20, '2025-0703', 'Mark Neil', 'V', 'Fajil', 'mark.neil.fajil@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(21, '2025-0602', 'Mark Angelo Riza', '', 'Francisco', 'mark.angelo.riza.francisco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(22, '2025-0363', 'Jhake Perillo', '', 'Garan', 'jhake.perillo.garan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(23, '2025-0593', 'Jared', '', 'Gasic', 'jared.gasic@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(24, '2025-0603', 'Bobby Jr.', 'M', 'Godoy', 'bobby.jr..godoy@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(25, '2025-0795', 'Edward John', 'S', 'Holgado', 'edward.john.holgado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(26, '2025-0794', 'Jaypee', 'G', 'Jacob', 'jaypee.jacob@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(27, '2025-0746', 'Jhon Loyd', 'D', 'Macapuno', 'jhon.loyd.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(28, '2025-0672', 'Paul Tristan', 'V', 'Madla', 'paul.tristan.madla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(29, '2025-0594', 'Marlex', 'L', 'Mendoza', 'marlex.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(30, '2025-0649', 'Ron-Ron', '', 'Montero', 'ronron.montero@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(31, '2025-0757', 'John Lord', 'J', 'Moreno', 'john.lord.moreno@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(32, '2025-0686', 'Johnwin', 'A', 'Pastor', 'johnwin.pastor@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(33, '2025-0606', 'Jhon Jake', '', 'Perez', 'jhon.jake.perez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(34, '2025-0692', 'John Kenneth', '', 'Perez', 'john.kenneth.perez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(35, '2025-0534', 'Khim', 'M', 'Tejada', 'khim.tejada@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 1, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(36, '2025-0784', 'Mary Ann', 'B', 'Asi', 'mary.ann.asi@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(37, '2025-0797', 'Marydith', 'L', 'Atienza', 'marydith.atienza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(38, '2025-0745', 'Charisma', 'M', 'Banila', 'charisma.banila@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(39, '2025-0658', 'Myka', 'S', 'Braza', 'myka.braza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(40, '2025-0676', 'Rhealyne', 'C', 'Cardona', 'rhealyne.cardona@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(41, '2025-0758', 'Danica Bea', 'T', 'Castillo', 'danica.bea.castillo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(42, '2025-0793', 'Marra Jane', 'V', 'Cleofe', 'marra.jane.cleofe@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(43, '2025-0637', 'Jocelyn', 'T', 'De Guzman', 'jocelyn.deguzman@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(44, '2025-0790', 'Anna Nicole', '', 'De Leon', 'anna.nicole.deleon@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(45, '2025-0778', 'Shane', 'M', 'Dudas', 'shane.dudas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(46, '2025-0754', 'Analyn', 'M', 'Fajardo', 'analyn.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(47, '2025-0668', 'Zean Dane', 'A', 'Falcutila', 'zean.dane.falcutila@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(48, '2025-0755', 'Sharmaine', 'G', 'Fonte', 'sharmaine.fonte@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(49, '2025-0756', 'Crystal', 'E', 'Gagote', 'crystal.gagote@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(50, '2025-0667', 'Janel', 'M', 'Garcia', 'janel.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(51, '2025-0800', 'Aleah', 'G', 'Gida', 'aleah.gida@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(52, '2025-0786', 'Bhea Jane', 'Y', 'Gillado', 'bhea.jane.gillado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(53, '2025-0805', 'Mae', 'M', 'Hernandez', 'mae.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(55, '2025-0656', 'Arian Bello', '', 'Maculit', 'arian.bello.maculit@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(56, '2025-0771', 'Mikee', 'M', 'Manay', 'mikee.manay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(57, '2025-0763', 'Lorain B', '', 'Medina', 'lorain.b.medina@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(58, '2025-0767', 'Lovely Joy', 'A', 'Mercado', 'lovely.joy.mercado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(59, '2025-0772', 'Romelyn', 'M', 'Mongcog', 'romelyn.mongcog@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(60, '2025-0699', 'Lleyn Angela', 'J', 'Olympia', 'lleyn.angela.olympia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(61, '2025-0766', 'Althea', 'A', 'Paala', 'althea.paala@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(62, '2025-0770', 'Ivy Kristine', 'A', 'Petilo', 'ivy.kristine.petilo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(63, '2025-0789', 'Irish Catherine', 'M', 'Ramos', 'irish.catherine.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(64, '2025-0796', 'Rubilyn', 'V', 'Roxas', 'rubilyn.roxas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(65, '2025-0718', 'Marie Bernadette', 'S', 'Tolentino', 'marie.bernadette.tolentino@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(66, '2025-0643', 'Wyncel', 'A', 'Tolentino', 'wyncel.tolentino@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(67, '2025-0629', 'Felicity', 'O', 'Villegas', 'felicity.villegas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(68, '2025-0705', 'Danilo R. Jr', '', 'Cabiles', 'danilo.r.jr.cabiles@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(69, '2025-0726', 'Aldrin', 'L', 'Carable', 'aldrin.carable@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(70, '2025-0743', 'Daniel', 'A', 'Franco', 'daniel.franco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(71, '2025-0636', 'Jarred', 'L', 'Gomez', 'jarred.gomez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(72, '2025-0785', 'Jairus', 'M', 'Macuha', 'jairus.macuha@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(73, '2025-0801', 'Mel Gabriel', 'N', 'Magat', 'mel.gabriel.magat@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(74, '2025-0762', 'Erwin', 'M', 'Tejedor', 'erwin.tejedor@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(75, '2025-0747', 'Brix Matthew', '', 'Velasco', 'brix.matthew.velasco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 2, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(76, '2025-0617', 'K-Ann', 'E', 'Abela', 'kann.abela@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(77, '2025-0733', 'Shane Ashley', 'C', 'Abendan', 'shane.ashley.abendan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(78, '2025-0619', 'Hanna', 'N', 'Aborde', 'hanna.aborde@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(79, '2025-0765', 'Rysa Mae', 'G', 'Alfante', 'rysa.mae.alfante@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(80, '2025-0809', 'Jeny', 'M', 'Amado', 'jeny.amado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(81, '2025-0680', 'Jonah Trisha', 'D', 'Asi', 'jonah.trisha.asi@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(82, '2025-0646', 'Jhovelyn', 'G', 'Bacay', 'jhovelyn.bacay@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(83, '2025-0679', 'Alexa Jane', '', 'Bon', 'alexa.jane.bon@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(84, '2025-0783', 'Lorraine', 'D', 'Bonado', 'lorraine.bonado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(85, '2025-0638', 'Shiella Mae', 'A', 'Bonifacio', 'shiella.mae.bonifacio@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(86, '2025-0711', 'Claren', 'I', 'Carable', 'claren.carable@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(87, '2025-0727', 'Prences Angel', 'L', 'Consigo', 'prences.angel.consigo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(88, '2025-0742', 'Jamhyca', 'C', 'De Chavez', 'jamhyca.dechavez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(89, '2025-0673', 'Nicole', 'P', 'Defeo', 'nicole.defeo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(90, '2025-0722', 'Sophia Angela', 'M', 'Delos Reyes', 'sophia.angela.delosreyes@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(91, '2025-0612', 'Romelyn', '', 'Elida', 'romelyn.elida@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(92, '2025-0611', 'Christina Sofia Lie', 'D', 'Enriquez', 'christina.sofia.lie.enriquez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(93, '2025-0688', 'Elayca Mae', 'E', 'Fajardo', 'elayca.mae.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(94, '2025-0657', 'Ailla', 'F', 'Fajura', 'ailla.fajura@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(95, '2025-0618', 'Judith', 'B', 'Fallarna', 'judith.fallarna@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(96, '2025-0654', 'Jenelyn', 'R', 'Fonte', 'jenelyn.fonte@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(97, '2025-0713', 'Katrice', 'I', 'Garcia', 'katrice.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(98, '2025-0737', 'Shalemar', 'M', 'Geroleo', 'shalemar.geroleo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(99, '2025-0655', 'Edlyn', 'M', 'Hernandez', 'edlyn.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(100, '2025-0633', 'Angela', 'T', 'Lotho', 'angela.lotho@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(101, '2025-0808', 'Remz Ann Escarlet', 'G', 'Macapuno', 'remz.ann.escarlet.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(102, '2025-0609', 'Leslie', 'B', 'Melgar', 'leslie.melgar@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(103, '2025-0729', 'Camille', 'B', 'Milambiling', 'camille.milambiling@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(104, '2025-0710', 'Erica Mae', 'B', 'Motol', 'erica.mae.motol@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(105, '2025-0728', 'Ma. Teresa', 'S', 'Obando', 'ma.teresa.obando@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(106, '2025-0647', 'Argel', 'B', 'Ocampo', 'argel.ocampo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(107, '2025-0779', 'Jea Francine', '', 'Rivera', 'jea.francine.rivera@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(108, '2025-0788', 'Ashly Nicole', '', 'Rana', 'ashly.nicole.rana@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(109, '2025-0741', 'Aimie Jane', 'M', 'Reyes', 'aimie.jane.reyes@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(110, '2025-0734', 'Rhenelyn', 'A', 'Sandoval', 'rhenelyn.sandoval@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(111, '2025-0777', 'Nicole', 'S', 'Silva', 'nicole.silva@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(112, '2025-0731', 'Jeane', 'T', 'Sulit', 'jeane.sulit@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(113, '2025-0723', 'Pauleen', 'H', 'Villaruel', 'pauleen.villaruel@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(114, '2025-0806', 'Megan Michaela', 'M', 'Visaya', 'megan.michaela.visaya@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(115, '2025-0684', 'Rodel', '', 'Arenas', 'rodel.arenas@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(116, '2025-0690', 'Rexner', 'M', 'Eguillon', 'rexner.eguillon@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(117, '2025-0815', 'Reymart', 'P', 'Elmido', 'reymart.elmido@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(119, '2025-0627', 'Kervin', 'B', 'Garachico', 'kervin.garachico@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(120, '2025-0865', 'Zyris', 'A', 'Guavez', 'zyris.guavez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(121, '2025-0740', 'Marjun A', '', 'Linayao', 'marjun.a.linayao@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(122, '2025-0660', 'John Lloyd', '', 'Macapuno', 'john.lloyd.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(123, '2025-0732', 'Helbert', 'F', 'Maulion', 'helbert.maulion@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(124, '2025-0645', 'Dindo', 'S', 'Tolentino', 'dindo.tolentino@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 3, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(125, '2025-0621', 'Novelyn', 'D', 'Albufera', 'novelyn.albufera@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(126, '2025-0775', 'Angela', 'F', 'Aldea', 'angela.aldea@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(127, '2025-0601', 'Maria Fe', 'C', 'Aldovino', 'maria.fe.aldovino@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(128, '2025-0661', 'Aizel', 'M', 'Alvarez', 'aizel.alvarez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(129, '2025-0752', 'Sherilyn', 'T', 'Anyayahan', 'sherilyn.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(130, '2025-0623', 'Mika Dean', '', 'Buadilla', 'mika.dean.buadilla@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(131, '2025-0669', 'Daniela Faye', '', 'Cabiles', 'daniela.faye.cabiles@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(132, '2025-0599', 'Prinses Gabriela', 'Q', 'Calaolao', 'prinses.gabriela.calaolao@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(133, '2025-0719', 'Deah Angella S', '', 'Carpo', 'deah.angella.s.carpo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(135, '2025-0802', 'Jedidiah', 'C', 'Gelena', 'jedidiah.gelena@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(136, '2025-0664', 'Aleyah Janelle', 'B', 'Jara', 'aleyah.janelle.jara@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(137, '2025-0720', 'Charese', 'M', 'Jolo', 'charese.jolo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(138, '2025-0682', 'Janice', 'G', 'Lugatic', 'janice.lugatic@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(139, '2025-0739', 'Abegail', '', 'Malogueño', 'abegail.malogueo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(140, '2025-0708', 'Ericca', 'A', 'Marquez', 'ericca.marquez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(141, '2025-0748', 'Arien', 'M', 'Montesa', 'arien.montesa@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(142, '2025-0653', 'Jasmine', 'Q', 'Nuestro', 'jasmine.nuestro@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(143, '2025-0738', 'Nicole', 'G', 'Ola', 'nicole.ola@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(144, '2025-0628', 'Alyssa Mae', 'M', 'Quintia', 'alyssa.mae.quintia@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(145, '2025-0774', 'Jona Marie', 'G', 'Romero', 'jona.marie.romero@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(146, '2025-0634', 'Marbhel', 'H', 'Rucio', 'marbhel.rucio@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(147, '2025-0814', 'Lovely', 'K', 'Torres', 'lovely.torres@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(148, '2025-0620', 'Rexon', 'E', 'Abanilla', 'rexon.abanilla@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(149, '2025-0791', 'Ramfel', 'H', 'Azucena', 'ramfel.azucena@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(150, '2025-0632', 'Jeverson', 'M', 'Bersoto', 'jeverson.bersoto@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(151, '2025-0626', 'Shervin Jeral', 'M', 'Castro', 'shervin.jeral.castro@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(152, '2025-0652', 'Daniel', 'D', 'De Ade', 'daniel.deade@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(153, '2025-0782', 'Dave Ruzzele', 'D', 'Despa', 'dave.ruzzele.despa@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(154, '2025-0696', 'Alexander', 'R', 'Ducado', 'alexander.ducado@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(155, '2025-0595', 'Uranus', 'R', 'Evangelista', 'uranus.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(156, '2025-0697', 'Joshua', 'M', 'Gabon', 'joshua.gabon@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(157, '2025-0681', 'John Andrew', 'R', 'Gavilan', 'john.andrew.gavilan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(158, '2025-0715', 'Mc Lenard', 'A', 'Gibo', 'mc.lenard.gibo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(159, '2025-0716', 'Dan Kian', 'A', 'Hatulan', 'dan.kian.hatulan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(160, '2025-0803', 'Benjamin Jr. D', '', 'Hernandez', 'benjamin.jr.d.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(161, '2025-0753', 'Renz', 'F', 'Hernandez', 'renz.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(162, '2025-0662', 'Ralph Adriane', 'D', 'Javier', 'ralph.adriane.javier@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(163, '2025-0598', 'Andrew', 'M', 'Laredo', 'andrew.laredo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(164, '2025-0663', 'Janryx', 'S', 'Las Pinas', 'janryx.laspinas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(165, '2025-0735', 'Bricks', 'M', 'Lindero', 'bricks.lindero@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(166, '2025-0639', 'Luigi', 'B', 'Lomio', 'luigi.lomio@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(167, '2025-0596', 'John Lemuel', 'O', 'Macalindol', 'john.lemuel.macalindol@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(168, '2025-0781', 'Jandy', 'S', 'Macapuno', 'jandy.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(169, '2025-0693', 'Cedrick', 'M', 'Mandia', 'cedrick.mandia@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(170, '2025-0650', 'Eric John', 'C', 'Marinduque', 'eric.john.marinduque@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(171, '2025-0730', 'Jimrex', 'M', 'Mayano', 'jimrex.mayano@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(172, '2025-0624', 'Hedyen', 'C', 'Mendoza', 'hedyen.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(173, '2025-0625', 'Mark Angelo', 'E', 'Montevirgen', 'mark.angelo.montevirgen@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(174, '2025-0651', 'JM', 'B', 'Nas', 'jm.nas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(175, '2025-0725', 'Vhon Jerick O', '', 'Ornos', 'vhon.jerick.o.ornos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(176, '2025-0659', 'Carl Justine', 'D', 'Padua', 'carl.justine.padua@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(177, '2025-0600', 'Patrick Lanz', '', 'Paz', 'patrick.lanz.paz@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(178, '2025-0622', 'Mark Justin', 'C', 'Pecolados', 'mark.justin.pecolados@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(179, '2025-0764', 'Tristan Jay', 'M', 'Plata', 'tristan.jay.plata@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(180, '2025-0776', 'Jude Michael', '', 'Somera', 'jude.michael.somera@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(181, '2025-0695', 'Philip Jhon', 'N', 'Tabor', 'philip.jhon.tabor@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(182, '2025-0597', 'Ivan Lester', 'D', 'Ylagan', 'ivan.lester.ylagan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 4, '1', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(183, '2024-0513', 'Kiana Jane', 'P', 'Añonuevo', 'kiana.jane.aonuevo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(184, '2024-0514', 'Kyla', '', 'Anonuevo', 'kyla.anonuevo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(185, '2024-0569', 'Katrice', 'F', 'Antipasado', 'katrice.antipasado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(186, '2024-0591', 'Regine', '', 'Antipasado', 'regine.antipasado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(187, '2024-0550', 'Juneth', 'H', 'Baliday', 'juneth.baliday@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(188, '2024-0546', 'Gielysa', 'C', 'Concha', 'gielysa.concha@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(189, '2024-0506', 'Maecelle', 'V', 'Fiedalan', 'maecelle.fiedalan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(190, '2024-0508', 'Lara Mae', 'E', 'Garcia', 'lara.mae.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(191, '2024-0459', 'Jade', 'S', 'Garing', 'jade.garing@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(192, '2024-0446', 'Rica', 'D', 'Glodo', 'rica.glodo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(193, '2024-0549', 'Danica Mae', 'N', 'Hornilla', 'danica.mae.hornilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(194, '2024-0473', 'Jenny', 'F', 'Idea', 'jenny.idea@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(195, '2024-0487', 'Roma', 'L', 'Mendoza', 'roma.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(196, '2024-0535', 'Evangeline', 'V', 'Mojica', 'evangeline.mojica@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(197, '2024-0570', 'Carla', 'G', 'Nineria', 'carla.nineria@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(198, '2024-0516', 'Kyla', 'G', 'Oliveria', 'kyla.oliveria@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(199, '2024-0457', 'Mikayla', 'M', 'Paala', 'mikayla.paala@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(200, '2024-0442', 'Necilyn', 'B', 'Ramos', 'necilyn.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(201, '2024-0469', 'Mischell', 'U', 'Velasquez', 'mischell.velasquez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(202, '2024-0539', 'Emerson', 'M', 'Adarlo', 'emerson.adarlo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(203, '2024-0491', 'Shim Andrian', 'L', 'Adarlo', 'shim.andrian.adarlo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(205, '2024-0485', 'Cedrick', 'C', 'Cardova', 'cedrick.cardova@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(206, '2024-0477', 'John Paul', 'M', 'De Lemos', 'john.paul.delemos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(207, '2024-0489', 'Reymar', 'G', 'Faeldonia', 'reymar.faeldonia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(208, '2024-0500', 'John Ray', 'A', 'Fegidero', 'john.ray.fegidero@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(209, '2024-0488', 'John Lester', 'C', 'Gaba', 'john.lester.gaba@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(210, '2024-0475', 'Antonio Gabriel', 'A', 'Francisco', 'antonio.gabriel.francisco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(211, '2024-0345', 'karl Andrew', 'R', 'Hardin', 'karl.andrew.hardin@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(212, '2024-0499', 'Prince', 'L', 'Geneta', 'prince.geneta@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(213, '2024-0495', 'John Reign', 'A', 'Laredo', 'john.reign.laredo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(214, '2024-0490', 'Mc Ryan', '', 'Masangkay', 'mc.ryan.masangkay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(215, '2025-0592', 'Aaron Vincent', 'R', 'Manalo', 'aaron.vincent.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(216, '2024-0494', 'Great', 'B', 'Mendoza', 'great.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(217, '2024-0497', 'Jhon Marc', 'D', 'Oliveria', 'jhon.marc.oliveria@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(218, '2024-0455', 'Kevin', 'G', 'Rucio', 'kevin.rucio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 5, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(219, '2024-0445', 'Arhizza Sheena', 'R', 'Abanilla', 'arhizza.sheena.abanilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(220, '2024-0503', 'Carla Andrea', 'C', 'Azucena', 'carla.andrea.azucena@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(221, '2024-0548', 'Angel', 'D', 'Cason', 'angel.cason@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(222, '2024-0461', 'KC May', 'A', 'De Guzman', 'kc.may.deguzman@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(223, '2024-0531', 'Francene', '', 'Delos Santos', 'francene.delossantos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(224, '2024-0470', 'Shane Ayessa', 'L', 'Elio', 'shane.ayessa.elio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(225, '2024-0502', 'Maria Angela', 'B', 'Garcia', 'maria.angela.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(226, '2024-0466', 'Shane Mary', 'C', 'Gardoce', 'shane.mary.gardoce@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(227, '2024-0441', 'Janah', 'M', 'Glor', 'janah.glor@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(228, '2024-0476', 'Catherine', 'R', 'Gomez', 'catherine.gomez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(229, '2024-0554', 'April Joy', '', 'Llamoso', 'april.joy.llamoso@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(230, '2024-0440', 'Irene', 'Y', 'Loto', 'irene.loto@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(231, '2024-0463', 'Angela', 'M', 'Lumanglas', 'angela.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(232, '2024-0464', 'Michelle Micah', 'M', 'Lumanglas', 'michelle.micah.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(233, '2024-0545', 'Febelyn', 'M', 'Magboo', 'febelyn.magboo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(234, '2024-0458', 'Chelo Rose', 'P', 'Marasigan', 'chelo.rose.marasigan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(235, '2024-0456', 'Joana Marie', 'L', 'Paala', 'joana.marie.paala@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(236, '2024-0538', 'Maria Irene', 'T', 'Pasado', 'maria.irene.pasado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(237, '2024-0563', 'Danica', '', 'Pederio', 'danica.pederio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(238, '2024-0444', 'Angela Clariss', 'P', 'Teves', 'angela.clariss.teves@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(239, '2024-0454', 'Zairene', 'R', 'Undaloc', 'zairene.undaloc@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(240, '2024-0449', 'John Ivan', 'P', 'Cuasay', 'john.ivan.cuasay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(241, '2024-0505', 'Bert', 'B', 'Ferrera', 'bert.ferrera@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(242, '2024-0450', 'Rickson', 'C', 'Ferry', 'rickson.ferry@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(243, '2024-0555', 'John Mariol', 'L', 'Fransisco', 'john.mariol.fransisco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(244, '2024-0530', 'Allan', 'Y', 'Loto', 'allan.loto@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(245, '2024-0401', 'Jhon Kenneth', 'S', 'Obando', 'jhon.kenneth.obando@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(246, '2024-0462', 'Rodel', 'T', 'Roldan', 'rodel.roldan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 6, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(247, '2024-0358', 'Ashlyn Kieth', 'V', 'Abanilla', 'ashlyn.kieth.abanilla@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(248, '2024-0352', 'Patricia Mae', 'M', 'Agoncillo', 'patricia.mae.agoncillo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(249, '2024-0378', 'Benelyn', 'D', 'Aguho', 'benelyn.aguho@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(250, '2024-0504', 'Lynse', 'C', 'Albufera', 'lynse.albufera@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(251, '2024-0521', 'Lara Mae', 'M', 'Altamia', 'lara.mae.altamia@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(252, '2024-0379', 'Crislyn', 'M', 'Anyayahan', 'crislyn.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(253, '2024-0360', 'Rocel Liegh', 'L', 'Arañez', 'rocel.liegh.araez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(254, '2024-0372', 'Katrice Allaine', 'A', 'Atienza', 'katrice.allaine.atienza@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(255, '2024-0354', 'Maica', 'C', 'Bacal', 'maica.bacal@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(256, '2024-0347', 'Cherylyn', 'C', 'Bacsa', 'cherylyn.bacsa@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL);
INSERT INTO `students` (`id`, `student_id`, `first_name`, `middle_name`, `last_name`, `email`, `contact_number`, `address`, `department`, `section_id`, `yearlevel`, `year_level`, `avatar`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(257, '2024-0364', 'Realyn', 'M', 'Bercasi', 'realyn.bercasi@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(258, '2024-0355', 'Elyza', 'M', 'Buquis', 'elyza.buquis@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(260, '2024-0474', 'Kim Ashley Nicole', 'M', 'Caringal', 'kim.ashley.nicole.caringal@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(261, '2024-0351', 'Shane', 'B', 'Dalisay', 'shane.dalisay@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(262, '2024-0369', 'Mariel', 'V', 'Delos Santos', 'mariel.delossantos@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(263, '2024-0520', 'Angel', 'G', 'Dimoampo', 'angel.dimoampo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(264, '2024-0374', 'Kristine', 'B', 'Dris', 'kristine.dris@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(265, '2024-0367', 'Rexlyn Joy', 'M', 'Eguillon', 'rexlyn.joy.eguillon@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(266, '2024-0363', 'Maricar', 'A', 'Evangelista', 'maricar.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(267, '2024-0388', 'Chariz', 'M', 'Fajardo', 'chariz.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(268, '2024-0366', 'Hazel Ann', 'B', 'Feudo', 'hazel.ann.feudo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(269, '2024-0385', 'Marie Joy', 'C', 'Gado', 'marie.joy.gado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(270, '2024-0371', 'Leah', 'M', 'Galit', 'leah.galit@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(271, '2024-0507', 'Aiexa Danielle', 'A', 'Guira', 'aiexa.danielle.guira@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(272, '2024-0375', 'Andrea Mae', 'M', 'Hernandez', 'andrea.mae.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(273, '2024-0501', 'Eslley Ann', 'T', 'Hernandez', 'eslley.ann.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(274, '2024-0376', 'Jazleen', '', 'Llamoso', 'jazleen.llamoso@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(275, '2024-0368', 'Joan Kate', 'G', 'Lomio', 'joan.kate.lomio@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(276, '2024-0391', 'Kriselle Ann', 'T', 'Mabuti', 'kriselle.ann.mabuti@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(277, '2024-0387', 'Angel Rose', 'S', 'Mascarinas', 'angel.rose.mascarinas@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(278, '2024-0587', 'Hannah', 'A', 'Melgar', 'hannah.melgar@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(279, '2024-0586', 'Rexy Mae', 'D', 'Mingo', 'rexy.mae.mingo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(280, '2024-0349', 'Precious Nicole', 'N', 'Moya', 'precious.nicole.moya@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(281, '2024-0377', 'Cherese Gelyn', 'C', 'Nao', 'cherese.gelyn.nao@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(282, '2024-0384', 'Margie', 'N', 'Nuñez', 'margie.nuez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(283, '2024-0350', 'Hazel Ann', 'F', 'Panganiban', 'hazel.ann.panganiban@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(284, '2024-0568', 'Angela', '', 'Papasin', 'angela.papasin@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(285, '2024-0359', 'Jasmine', 'A', 'Prangue', 'jasmine.prangue@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(286, '2024-0380', 'Jeyzelle', 'G', 'Rellora', 'jeyzelle.rellora@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(287, '2024-0264', 'Katrina T', '', 'Rufino', 'katrina.t.rufino@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(288, '2024-0382', 'Niña Zyrene', 'R', 'Sanchez', 'nia.zyrene.sanchez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(289, '2024-0509', 'Edcel Jane', 'B', 'Santillan', 'edcel.jane.santillan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(290, '2024-0451', 'Mary Joy', 'M', 'Sara', 'mary.joy.sara@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(291, '2024-0453', 'Cynthia', '', 'Torres', 'cynthia.torres@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(292, '2024-0556', 'Jolie', 'L', 'Tugmin', 'jolie.tugmin@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(293, '2024-0356', 'Lesley Ann', 'M', 'Villanueva', 'lesley.ann.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(294, '2024-0365', 'Lany', 'G', 'Ylagan', 'lany.ylagan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(295, '2024-0373', 'Marvin', 'M', 'Caraig', 'marvin.caraig@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(296, '2024-0557', 'Denniel', 'C', 'Delos Santos', 'denniel.delossantos@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(297, '2024-0389', 'Alex', 'T', 'Magsisi', 'alex.magsisi@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(298, '2024-0525', 'Jan Carlo', 'G', 'Manalo', 'jan.carlo.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(299, '2024-0386', 'AJ', 'M', 'Masangkay', 'aj.masangkay@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(300, '2024-0480', 'John Paul', 'M', 'Roldan', 'john.paul.roldan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(301, '2024-0523', 'Ronald', '', 'Tañada', 'ronald.taada@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(302, '2024-0492', 'D-Jay', 'G', 'Teriompo', 'djay.teriompo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 7, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(303, '2025-0816', 'Marsha Lhee', 'G', 'Azucena', 'marsha.lhee.azucena@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(304, '2024-0438', 'Melsan', 'G', 'Aday', 'melsan.aday@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(305, '2024-0405', 'Jonice', 'P', 'Alturas', 'jonice.alturas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(306, '2024-0411', 'Precious', 'S', 'Apil', 'precious.apil@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(307, '2024-0418', 'Ludelyn', 'T', 'Belbes', 'ludelyn.belbes@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(308, '2024-0424', 'Princess Hazel', 'D', 'Cabasi', 'princess.hazel.cabasi@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(309, '2024-0342', 'Charlaine', 'M', 'De Belen', 'charlaine.debelen@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(310, '2024-0437', 'Arjean Joy', 'S', 'De Castro', 'arjean.joy.decastro@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(311, '2024-0343', 'Precious Cindy', 'G', 'De Guzman', 'precious.cindy.deguzman@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(312, '2024-0404', 'Marina', 'M', 'De Luzon', 'marina.deluzon@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(313, '2024-0417', 'Nesvita', 'V', 'Dorias', 'nesvita.dorias@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(315, '2024-0432', 'Stella Rey', 'A', 'Flores', 'stella.rey.flores@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(316, '2024-0567', 'Arlene', 'S', 'Gaba', 'arlene.gaba@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(317, '2024-0422', 'Jay-Ann', 'G', 'Jamilla', 'jayann.jamilla@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(318, '2024-0416', 'Mikaela Joy', 'M', 'Layson', 'mikaela.joy.layson@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(319, '2024-0427', 'Christine Joy', 'A', 'Lomio', 'christine.joy.lomio@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(320, '2024-0544', 'Ariane', 'M', 'Magboo', 'ariane.magboo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(321, '2024-0415', 'Nerissa', 'R', 'Magsisi', 'nerissa.magsisi@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(322, '2024-0472', 'Keycel Joy', 'M', 'Manalo', 'keycel.joy.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(323, '2024-0412', 'Grace Cell', 'G', 'Manibo', 'grace.cell.manibo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(324, '2024-0571', 'Lovelyn', 'A', 'Marcos', 'lovelyn.marcos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(325, '2024-0314', 'Shenna Marie', 'P', 'Obando', 'shenna.marie.obando@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(326, '2024-0348', 'Myzell', 'U', 'Ramos', 'myzell.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(327, '2024-0582', 'Shella Mae', 'T', 'Ramos', 'shella.mae.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(328, '2024-0426', 'Desiree', 'G', 'Raymundo', 'desiree.raymundo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(329, '2023-0433', 'Romelyn', 'A', 'Rocha', 'romelyn.rocha@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(330, '2023-0519', 'John Michael', '', 'Bacsa', 'john.michael.bacsa@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(331, '2024-0043', 'John Kenneth Joseph', 'G', 'Balansag', 'john.kenneth.joseph.balansag@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(332, '2024-0398', 'Raphael', 'M', 'Bugayong', 'raphael.bugayong@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(333, '2024-0572', 'Mark Jayson', 'D', 'Bunag', 'mark.jayson.bunag@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(334, '2024-0561', 'Alvin', 'M', 'Corona', 'alvin.corona@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(335, '2023-0407', 'Mark Janssen', 'C', 'Cueto', 'mark.janssen.cueto@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(336, '2023-0447', 'Charles Darwin', 'S', 'Dimailig', 'charles.darwin.dimailig@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(338, '2024-0413', 'Airon', 'R', 'Evangelista', 'airon.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(339, '2024-0517', 'Gino', 'L', 'Genabe', 'gino.genabe@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(340, '2024-0420', 'Miklo', 'M', 'Lumanglas', 'miklo.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(341, '2023-0151', 'Ramcil', 'M', 'Macapuno', 'ramcil.macapuno@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(342, '2024-0395', 'Florence', 'R', 'Macalelong', 'florence.macalelong@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(343, '2023-0465', 'Patrick', 'T', 'Matanguihan', 'patrick.matanguihan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(344, '2024-0478', 'Dranzel', 'L', 'Miranda', 'dranzel.miranda@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(345, '2024-0394', 'Carlo', 'G', 'Mondragon', 'carlo.mondragon@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(346, '2024-0410', 'John Rexcel', 'E', 'Montianto', 'john.rexcel.montianto@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(347, '2024-0428', 'Christian', 'M', 'Moreno', 'christian.moreno@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(348, '2024-0393', 'Amiel Geronne', 'M', 'Pantua', 'amiel.geronne.pantua@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(349, '2024-0392', 'James Lorence', 'C', 'Paradijas', 'james.lorence.paradijas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(350, '2024-0436', 'Jhezreel', 'P', 'Pastorfide', 'jhezreel.pastorfide@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(351, '2024-0578', 'Matt Raphael', 'G', 'Reyes', 'matt.raphael.reyes@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(352, '2024-0580', 'Merwin', 'D', 'Santos', 'merwin.santos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(353, '2024-0423', 'Benjamin Jr.', 'D', 'Sarvida', 'benjamin.jr..sarvida@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(354, '2024-0408', 'Jerus', 'B', 'Savariz', 'jerus.savariz@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(355, '2024-0406', 'Gerson', 'C', 'Urdanza', 'gerson.urdanza@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(356, '2024-0397', 'Jyrus', 'M', 'Ylagan', 'jyrus.ylagan@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 8, '2', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(357, '2023-0304', 'Jonah Rhyza', 'N', 'Anyayahan', 'jonah.rhyza.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(358, '2023-0337', 'Leica', 'M', 'Banila', 'leica.banila@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(359, '2023-0327', 'Juvylyn', 'G', 'Basa', 'juvylyn.basa@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(360, '2022-0088', 'Rashele', 'M', 'Delgaco', 'rashele.delgaco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(361, '2023-0288', 'Cristal Jean', 'D', 'De Chusa', 'cristal.jean.dechusa@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(362, '2023-0305', 'Jaime Elizabeth', 'L', 'Evora', 'jaime.elizabeth.evora@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(363, '2023-0317', 'Jeanlyn', 'B', 'Garcia', 'jeanlyn.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(364, '2023-0161', 'Baby Anh Marie', 'M', 'Godoy', 'baby.anh.marie.godoy@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(365, '2023-0169', 'Herjane', 'F', 'Gozar', 'herjane.gozar@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(366, '2023-0200', 'Zyra', 'M', 'Gutierrez', 'zyra.gutierrez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(367, '2023-0251', 'Angielene', 'C', 'Landicho', 'angielene.landicho@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(368, '2023-0298', 'Laila', 'A', 'Limun', 'laila.limun@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(369, '2023-0244', 'Jennie Vee', 'P', 'Lopez', 'jennie.vee.lopez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(370, '2023-0215', 'Judy Ann', 'M', 'Madrigal', 'judy.ann.madrigal@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(371, '2023-0285', 'Maan', 'M', 'Masangkay', 'maan.masangkay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(372, '2023-0225', 'Genesis Mae', 'M', 'Mendoza', 'genesis.mae.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(373, '2023-0224', 'Marian', 'L', 'Mendoza', 'marian.mendoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(374, '2023-0173', 'Lailin', 'S', 'Obando', 'lailin.obando@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(375, '2023-0303', 'Kyla', 'G', 'Rucio', 'kyla.rucio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(376, '2023-0241', 'Lyn', 'C', 'Velasquez', 'lyn.velasquez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(377, '2023-0336', 'Jhon Jerald', 'P', 'Acojedo', 'jhon.jerald.acojedo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(378, '2023-0345', 'Sherwin', 'T', 'Calibot', 'sherwin.calibot@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(379, '2023-0233', 'Joriz Cezar', 'M', 'Collado', 'joriz.cezar.collado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(380, '2023-1080', 'Mark Lee', 'C', 'Dalay', 'mark.lee.dalay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(381, '2023-0239', 'Adrian', 'C', 'Dilao', 'adrian.dilao@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(382, '2023-0167', 'Mc Lowell', 'F', 'Fabellon', 'mc.lowell.fabellon@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(383, '2023-0177', 'John Paul', 'M', 'Fernandez', 'john.paul.fernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(384, '2023-0249', 'Mark Lyndon', 'L', 'Fransisco', 'mark.lyndon.fransisco@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(385, '2023-0243', 'Kian Vash', 'N', 'Gale', 'kian.vash.gale@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(386, '2023-0332', 'Michael', 'B', 'Magat', 'michael.magat@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(387, '2023-0308', 'John Khim', 'J', 'Moreno', 'john.khim.moreno@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(388, '2023-0255', 'Jayson', 'A', 'Ramos', 'jayson.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(389, '2023-0322', 'Joel', 'B', 'Villena', 'joel.villena@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 9, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(390, '2023-0248', 'Jazzle Irish', 'M', 'Cudiamat', 'jazzle.irish.cudiamat@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(391, '2023-0240', 'Jenny', 'M', 'Fajardo', 'jenny.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(392, '2023-0299', 'Mary Joy', 'D', 'Sim', 'mary.joy.sim@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(393, '2023-0309', 'Jordan', 'V', 'Abeleda', 'jordan.abeleda@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(394, '2023-0150', 'Ralf Jenvher', 'V', 'Atienza', 'ralf.jenvher.atienza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(395, '2023-0284', 'Mon Andrei', 'M', 'Bae', 'mon.andrei.bae@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(396, '2023-0261', 'John Mark', 'M', 'Balmes', 'john.mark.balmes@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(397, '2023-0209', 'John Russel', 'G', 'Bolaños', 'john.russel.bolaos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(398, '2023-0166', 'Justine James', 'A', 'Dela Cruz', 'justine.james.delacruz@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(399, '2023-0313', 'Carl John', 'M', 'Evangelista', 'carl.john.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(400, '2023-0274', 'Mon Lester', 'B', 'Faner', 'mon.lester.faner@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(401, '2023-0159', 'John Paul', '', 'Freyra', 'john.paul.freyra@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(402, '2023-0258', 'Ryan', 'I', 'Garcia', 'ryan.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(403, '2023-0223', 'Jeshler Clifford', 'M', 'Gervacio', 'jeshler.clifford.gervacio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(404, '2023-0333', 'Melvic John', 'A', 'Magsino', 'melvic.john.magsino@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(405, '2023-0213', 'Jerome', 'B', 'Mauro', 'jerome.mauro@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(406, '2023-0279', 'Jundell', 'M', 'Morales', 'jundell.morales@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(407, '2023-0171', 'Adrian', 'R', 'Pampilo', 'adrian.pampilo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(408, '2023-0300', 'John Carl', 'C', 'Pedragoza', 'john.carl.pedragoza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(409, '2023-0295', 'King', 'C', 'Saranillo', 'king.saranillo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(410, '2023-0260', 'Jhon Laurence', 'D', 'Victoriano', 'jhon.laurence.victoriano@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 10, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(413, '2023-0210', 'Janelle', 'R', 'Absin', 'janelle.absin@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(414, '2023-0188', 'Jan Ashley', 'R', 'Bonado', 'jan.ashley.bonado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(415, '2023-0202', 'Robelyn', 'D', 'Bonado', 'robelyn.bonado@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(417, '2023-0253', 'Princes', 'A', 'Capote', 'princes.capote@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(418, '2023-0228', 'Joann', 'M', 'Carandan', 'joann.carandan@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(419, '2023-0272', 'Christine Rose', 'F', 'Catapang', 'christine.rose.catapang@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(420, '2023-0192', 'Arlyn', 'P', 'Corona', 'arlyn.corona@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(421, '2023-0185', 'Stacy Anne', 'G', 'Cortez', 'stacy.anne.cortez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(422, '2023-0199', '', '', 'De Claro Alexa Jane C.', '.declaroalexajanec.@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(423, '2023-0266', 'Angel Ann', 'M', 'De Lara', 'angel.ann.delara@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(424, '2023-0172', 'Lorebel', 'A', 'De Leon', 'lorebel.deleon@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(425, '2023-0257', 'Rocelyn', 'P', 'Dela Rosa', 'rocelyn.delarosa@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(426, '2023-0256', 'Ronalyn Paulita', '', 'Dela Rosa', 'ronalyn.paulita.delarosa@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(427, '2023-0137', 'Krisnah Joy', 'V', 'Dorias', 'krisnah.joy.dorias@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(428, '2023-0287', 'Ayessa Jhoy', 'M', 'Gaba', 'ayessa.jhoy.gaba@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(429, '2023-0193', 'Margie', 'R', 'Gatilo', 'margie.gatilo@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(430, '2023-0296', 'Jasmine', 'C', 'Gayao', 'jasmine.gayao@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(431, '2023-0197', 'Mikaela M', '', 'Hernandez', 'mikaela.m.hernandez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(432, '2023-0189', 'Vanessa Nicole', '', 'Latoga', 'vanessa.nicole.latoga@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(433, '2023-0262', 'Alwena', 'A', 'Madrigal', 'alwena.madrigal@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(434, '2023-0191', 'Maria Eliza', 'T', 'Magsisi', 'maria.eliza.magsisi@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(435, '2023-0227', 'Carla Joy', 'L', 'Matira', 'carla.joy.matira@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(436, '2023-0163', 'Allysa Mae', 'A', 'Mirasol', 'allysa.mae.mirasol@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(437, '2023-0247', 'Manilyn', 'G', 'Narca', 'manilyn.narca@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(438, '2023-0211', 'Sharah Mae', 'P', 'Ojales', 'sharah.mae.ojales@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(439, '2023-0340', 'Geselle', 'C', 'Rivas', 'geselle.rivas@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(440, '2023-0184', 'Angel Joy', 'A', 'Sanchez', 'angel.joy.sanchez@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(441, '2023-0341', 'Jamaica Rose', 'M', 'Sarabia', 'jamaica.rose.sarabia@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(442, '2023-0194', 'Nicole', 'A', 'Villafranca', 'nicole.villafranca@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(443, '2023-0203', 'Jennylyn', 'T', 'Villanueva', 'jennylyn.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(444, '2023-0277', 'John Lloyd David', 'M', 'Amido', 'john.lloyd.david.amido@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(445, '2023-0290', 'Reniel', 'L', 'Borja', 'reniel.borja@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(446, '2023-0179', 'John Carlo', 'G', 'Chiquito', 'john.carlo.chiquito@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(447, '2023-0301', 'Justin', 'S', 'Como', 'justin.como@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(448, '2023-0236', 'Moises', 'G', 'Delos Santos', 'moises.delossantos@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(449, '2023-0226', 'Philip', 'F', 'Garcia', 'philip.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(450, '2023-0182', 'Bryan', 'A', 'Peñaescosa', 'bryan.peaescosa@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(451, '2023-0297', 'John Rick', 'F', 'Ramos', 'john.rick.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BPA', 11, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(453, '2023-0220', 'Rezlyn Jhoy', 'S', 'Aguba', 'rezlyn.jhoy.aguba@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(454, '2023-0153', 'Lyzel', 'G', 'Bool', 'lyzel.bool@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(455, '2023-0219', 'Jesca Mae', 'M', 'Chavez', 'jesca.mae.chavez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(456, '2023-0270', 'Hiedie', 'H', 'Claus', 'hiedie.claus@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(458, '2023-0155', 'KC', 'D', 'Dela Roca', 'kc.delaroca@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(459, '2023-0154', 'Bea', 'A', 'Fajardo', 'bea.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(460, '2023-0320', 'Sherlyn', '', 'Festin', 'sherlyn.festin@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(461, '2023-0204', 'Clarissa', 'B', 'Feudo', 'clarissa.feudo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(462, '2023-0156', 'Irish Karyl', 'G', 'Magcamit', 'irish.karyl.magcamit@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(463, '2023-0216', 'Cristine', 'S', 'Manalo', 'cristine.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(464, '2023-0331', 'Geraldine', 'G', 'Manalo', 'geraldine.manalo@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(465, '2023-0198', 'Shiloh', 'G', 'Manhic', 'shiloh.manhic@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(466, '2023-0242', 'Shylyn', '', 'Mansalapus', 'shylyn.mansalapus@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(467, '2023-0291', 'Irish May Roselle', 'C', 'Nao', 'irish.may.roselle.nao@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(468, '2023-0208', 'Paulyn Grace', '', 'Perez', 'paulyn.grace.perez@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(469, '2023-0181', 'Shane', 'T', 'Ramos', 'shane.ramos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(470, '2023-0566', 'Andrea Chel', 'D', 'Rivera', 'andrea.chel.rivera@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(471, '2023-0344', 'Angel Bellie', 'G', 'Vargas', 'angel.bellie.vargas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(472, '2023-0221', 'Jamaica Mickaela', 'Y', 'Villena', 'jamaica.mickaela.villena@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(473, '2023-0268', 'Monaliza', 'F', 'Waing', 'monaliza.waing@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(474, '2023-0157', 'Jay', 'T', 'Aguilar', 'jay.aguilar@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(475, '2023-0263', 'Ken Celwyn', 'R', 'Algaba', 'ken.celwyn.algaba@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(476, '2023-0273', 'Mark Lester', 'M', 'Baes', 'mark.lester.baes@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(477, '2023-0293', 'John Albert', 'C', 'Bastida', 'john.albert.bastida@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(478, '2023-0218', 'Vitoel', 'G', 'Curatcha', 'vitoel.curatcha@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(479, '2023-0286', 'Karl Marion', 'R', 'De Leon', 'karl.marion.deleon@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(480, '2023-0212', 'Renzie Carl', 'C', 'Escaro', 'renzie.carl.escaro@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(481, '2023-0196', 'Nathaniel', 'C', 'Falcunaya', 'nathaniel.falcunaya@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(482, '2023-0292', 'Kyzer', 'A', 'Gonda', 'kyzer.gonda@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(483, '2023-0283', 'John Dexter', '', 'Gonzales', 'john.dexter.gonzales@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(484, '2023-0319', 'Reniel', 'B', 'Jara', 'reniel.jara@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(485, '2023-0158', 'Steven Angelo', '', 'Legayada', 'steven.angelo.legayada@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(486, '2023-0152', 'Angelo', 'M', 'Lumanglas', 'angelo.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(487, '2023-0214', 'Jhon Lester', 'M', 'Madrigal', 'jhon.lester.madrigal@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(488, '2023-0162', 'Rhaven', 'G', 'Magmanlac', 'rhaven.magmanlac@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(489, '2023-0195', 'Jumyr', 'M', 'Moreno', 'jumyr.moreno@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(490, '2023-0176', 'Dan Lloyd', 'B', 'Paala', 'dan.lloyd.paala@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(491, '2023-0206', 'Patrick James', 'V', 'Romasanta', 'patrick.james.romasanta@colegiodenaujan.edu.ph', 'N/A', NULL, 'BSIS', 12, '3rd Year', '1st Year', 'https://ui-avatars.com/api/?name=Patrick+James+U+Romasanta&amp;background=ffd700&amp;color=333&amp;size=40', 'active', '2026-02-22 22:29:58', '2026-03-06 19:27:43', NULL),
(492, '2023-0186', 'Jereck', 'M', 'Roxas', 'jereck.roxas@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(493, '2023-0217', 'Jan Denmark', 'C', 'Santos', 'jan.denmark.santos@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(494, '2023-0267', 'John Paolo', 'N', 'Torralba', 'john.paolo.torralba@colegiodenaujan.edu.ph', NULL, NULL, 'BSIS', 12, '3', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(495, '2022-0079', 'Dianne Christine Joy', 'A', 'Alulod', 'dianne.christine.joy.alulod@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(496, '2022-0080', 'Rechel', 'R', 'Arenas', 'rechel.arenas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(497, '2022-0081', 'Allyna', 'A', 'Atienza', 'allyna.atienza@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(498, '2022-0130', 'Angela', 'A', 'Bonilla', 'angela.bonilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(499, '2022-0082', 'Aira', 'F', 'Cabulao', 'aira.cabulao@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(500, '2022-0124', 'Janice', 'C', 'Cadacio', 'janice.cadacio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(501, '2022-0083', 'Maries', 'D', 'Cantos', 'maries.cantos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(502, '2022-0084', 'Veronica', 'C', 'Cantos', 'veronica.cantos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(503, '2022-0139', 'Diana', 'G', 'Caringal', 'diana.caringal@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(504, '2022-0085', 'Lorebeth', 'C', 'Casapao', 'lorebeth.casapao@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(505, '2022-0086', 'Carla Jane', 'G', 'Chiquito', 'carla.jane.chiquito@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(506, '2022-0089', 'Melody', 'T', 'Enriquez', 'melody.enriquez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(507, '2022-0090', 'Maricon', 'A', 'Evangelista', 'maricon.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(508, '2022-0091', 'Mary Ann', 'D', 'Fajardo', 'mary.ann.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(509, '2022-0092', 'Kaecy', 'F', 'Ferry', 'kaecy.ferry@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(510, '2022-0140', 'Zybel', 'V', 'Garan', 'zybel.garan@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(511, '2022-0118', 'IC Pamela', 'M', 'Gutierrez', 'ic.pamela.gutierrez@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(512, '2022-0096', 'Jane Monica', 'P', 'Mansalapus', 'jane.monica.mansalapus@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(513, '2022-0097', 'Hanna Yesha Mae', 'D', 'Mercado', 'hanna.yesha.mae.mercado@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(514, '2022-0098', 'Abegail', 'D', 'Moong', 'abegail.moong@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL);
INSERT INTO `students` (`id`, `student_id`, `first_name`, `middle_name`, `last_name`, `email`, `contact_number`, `address`, `department`, `section_id`, `yearlevel`, `year_level`, `avatar`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(515, '2022-0125', 'Laiza Marie', 'M', 'Pole', 'laiza.marie.pole@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(516, '2022-0142', 'Jarryfel', 'N', 'Tembrevilla', 'jarryfel.tembrevilla@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(517, '2022-0136', 'Jay Mark', 'G', 'Avelino', 'jay.mark.avelino@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(518, '2022-0072', 'Jairus', 'A', 'Cabales', 'jairus.cabales@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(519, '2022-0075', 'Jleo Nhico Mari', 'M', 'Mazo', 'jleo.nhico.mari.mazo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(520, '2022-0076', 'Mark Cyrel', 'F', 'Panganiban', 'mark.cyrel.panganiban@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(521, '2022-0117', 'Bernabe Dave', 'F', 'Solas', 'bernabe.dave.solas@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(522, '2022-0078', 'Mark June', 'G', 'Villena', 'mark.june.villena@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 13, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(523, '2022-0122', 'Nhicel', 'M', 'Bueno', 'nhicel.bueno@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(524, '2022-0135', 'Dianne Mae', 'R', 'Cezar', 'dianne.mae.cezar@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(525, '2022-0147', 'Princess Joy', 'P', 'De Castro', 'princess.joy.decastro@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(526, '2022-0141', 'Shiela Mae', 'M', 'Fajardo', 'shiela.mae.fajardo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(527, '2022-0115', 'Shiela Marie', 'B', 'Garcia', 'shiela.marie.garcia@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(528, '2022-0129', 'Jessa', 'M', 'Geneta', 'jessa.geneta@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(529, '2022-0094', 'Jee Anne', 'R', 'Llamoso', 'jee.anne.llamoso@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(530, '2022-0123', 'Princess Jenille', 'A', 'Santos', 'princess.jenille.santos@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(531, '2022-0099', 'Von Lester', 'R', 'Algaba', 'von.lester.algaba@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(532, '2022-0100', 'John Aaron', 'M', 'Aniel', 'john.aaron.aniel@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(533, '2022-0101', 'Keil John', 'C', 'Antenor', 'keil.john.antenor@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(534, '2022-0102', 'Mark Joshua', 'M', 'Bacay', 'mark.joshua.bacay@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(535, '2022-0128', 'Michael', 'A', 'De Guzman', 'michael.deguzman@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(536, '2022-0107', 'Christian', '', 'Delda', 'christian.delda@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(537, '2022-0108', 'Lloyd', 'A', 'Evangelista', 'lloyd.evangelista@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(538, '2022-0073', 'Samson', 'L', 'Fulgencio', 'samson.fulgencio@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(540, '2022-0145', 'John Dragan', 'B', 'Gardoce', 'john.dragan.gardoce@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(541, '2022-0127', 'John Elmer', '', 'Gonzales', 'john.elmer.gonzales@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(542, '2022-0144', 'Mark Vender', 'N', 'Muhi', 'mark.vender.muhi@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(543, '2022-0112', 'Marc Paulo', 'B', 'Relano', 'marc.paulo.relano@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(544, '2022-0113', 'Cee Jey', 'G', 'Rellora', 'cee.jey.rellora@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(545, '2022-0134', 'Franklin', 'R', 'Salcedo', 'franklin.salcedo@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(546, '2022-0120', 'Russel', 'I', 'Sason', 'russel.sason@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(547, '2022-0132', 'John Paul', 'D', 'Teves', 'john.paul.teves@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(548, '2022-0131', 'John Xavier', 'A', 'Villanueva', 'john.xavier.villanueva@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL),
(549, '2022-0114', 'Reinier Aron', 'L', 'Visayana', 'reinier.aron.visayana@colegiodenaujan.edu.ph', NULL, NULL, 'BTVTED', 14, '4', '1st Year', NULL, 'active', '2026-02-22 22:29:58', '2026-02-24 09:51:29', NULL);

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
) ENGINE=MyISAM AUTO_INCREMENT=55 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

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
(54, 3053, '2023-0206', 'Login', 'User logged in: 2023-0206 (Role: user)', '::1', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0', '2026-03-10 04:13:22');

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
) ENGINE=MyISAM AUTO_INCREMENT=3112 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `email`, `google_id`, `facebook_id`, `profile_picture`, `password`, `role`, `full_name`, `student_id`, `is_active`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(3018, '2023-0219', 'jesca.mae.chavez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jesca Mae Chavez', '2023-0219', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3016, '2023-0220', 'rezlyn.jhoy.aguba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rezlyn Jhoy Aguba', '2023-0220', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3017, '2023-0153', 'lyzel.bool@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lyzel Bool', '2023-0153', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3015, '2023-0297', 'john.rick.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Rick Ramos', '2023-0297', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3013, '2023-0226', 'philip.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Philip Garcia', '2023-0226', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3014, '2023-0182', 'bryan.peaescosa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Bryan Peñaescosa', '2023-0182', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3011, '2023-0301', 'justin.como@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Justin Como', '2023-0301', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3012, '2023-0236', 'moises.delossantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Moises Delos Santos', '2023-0236', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3010, '2023-0179', 'john.carlo.chiquito@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Carlo Chiquito', '2023-0179', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3009, '2023-0290', 'reniel.borja@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Reniel Borja', '2023-0290', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3008, '2023-0277', 'john.lloyd.david.amido@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Lloyd David Amido', '2023-0277', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3007, '2023-0203', 'jennylyn.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jennylyn Villanueva', '2023-0203', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3006, '2023-0194', 'nicole.villafranca@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Nicole Villafranca', '2023-0194', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3005, '2023-0341', 'jamaica.rose.sarabia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jamaica Rose Sarabia', '2023-0341', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3004, '2023-0184', 'angel.joy.sanchez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angel Joy Sanchez', '2023-0184', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3003, '2023-0340', 'geselle.rivas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Geselle Rivas', '2023-0340', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3002, '2023-0211', 'sharah.mae.ojales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Sharah Mae Ojales', '2023-0211', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3001, '2023-0247', 'manilyn.narca@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Manilyn Narca', '2023-0247', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3000, '2023-0163', 'allysa.mae.mirasol@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Allysa Mae Mirasol', '2023-0163', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2999, '2023-0227', 'carla.joy.matira@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Carla Joy Matira', '2023-0227', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2998, '2023-0191', 'maria.eliza.magsisi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maria Eliza Magsisi', '2023-0191', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2997, '2023-0262', 'alwena.madrigal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Alwena Madrigal', '2023-0262', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2996, '2023-0189', 'vanessa.nicole.latoga@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Vanessa Nicole Latoga', '2023-0189', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2995, '2023-0197', 'mikaela.m.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mikaela M Hernandez', '2023-0197', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2994, '2023-0296', 'jasmine.gayao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jasmine Gayao', '2023-0296', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2993, '2023-0193', 'margie.gatilo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Margie Gatilo', '2023-0193', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2992, '2023-0287', 'ayessa.jhoy.gaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ayessa Jhoy Gaba', '2023-0287', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2991, '2023-0137', 'krisnah.joy.dorias@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Krisnah Joy Dorias', '2023-0137', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2990, '2023-0256', 'ronalyn.paulita.delarosa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ronalyn Paulita Dela Rosa', '2023-0256', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2989, '2023-0257', 'rocelyn.delarosa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rocelyn Dela Rosa', '2023-0257', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2988, '2023-0172', 'lorebel.deleon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lorebel De Leon', '2023-0172', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2987, '2023-0266', 'angel.ann.delara@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angel Ann De Lara', '2023-0266', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2986, '2023-0199', '.declaroalexajanec.@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'De Claro Alexa Jane C.', '2023-0199', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2985, '2023-0185', 'stacy.anne.cortez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Stacy Anne Cortez', '2023-0185', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2984, '2023-0192', 'arlyn.corona@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Arlyn Corona', '2023-0192', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2983, '2023-0272', 'christine.rose.catapang@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Christine Rose Catapang', '2023-0272', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2982, '2023-0228', 'joann.carandan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Joann Carandan', '2023-0228', 0, 'active', '2026-02-24 02:12:16', '2026-02-24 13:47:20', NULL),
(2981, '2023-0253', 'princes.capote@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Princes Capote', '2023-0253', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2980, '2023-0202', 'robelyn.bonado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Robelyn Bonado', '2023-0202', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2979, '2023-0188', 'jan.ashley.bonado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jan Ashley Bonado', '2023-0188', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2978, '2023-0210', 'janelle.absin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Janelle Absin', '2023-0210', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2977, '2023-0260', 'jhon.laurence.victoriano@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhon Laurence Victoriano', '2023-0260', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2976, '2023-0295', 'king.saranillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'King Saranillo', '2023-0295', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2975, '2023-0300', 'john.carl.pedragoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Carl Pedragoza', '2023-0300', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2974, '2023-0171', 'adrian.pampilo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Adrian Pampilo', '2023-0171', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2973, '2023-0279', 'jundell.morales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jundell Morales', '2023-0279', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2972, '2023-0213', 'jerome.mauro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jerome Mauro', '2023-0213', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2971, '2023-0333', 'melvic.john.magsino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Melvic John Magsino', '2023-0333', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2970, '2023-0223', 'jeshler.clifford.gervacio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jeshler Clifford Gervacio', '2023-0223', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2969, '2023-0258', 'ryan.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ryan Garcia', '2023-0258', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2968, '2023-0159', 'john.paul.freyra@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Paul Freyra', '2023-0159', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2967, '2023-0274', 'mon.lester.faner@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mon Lester Faner', '2023-0274', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2966, '2023-0313', 'carl.john.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Carl John Evangelista', '2023-0313', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2965, '2023-0166', 'justine.james.delacruz@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Justine James Dela Cruz', '2023-0166', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2964, '2023-0209', 'john.russel.bolaos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Russel Bolaños', '2023-0209', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2963, '2023-0261', 'john.mark.balmes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Mark Balmes', '2023-0261', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2962, '2023-0284', 'mon.andrei.bae@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mon Andrei Bae', '2023-0284', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2961, '2023-0150', 'ralf.jenvher.atienza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ralf Jenvher Atienza', '2023-0150', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2960, '2023-0309', 'jordan.abeleda@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jordan Abeleda', '2023-0309', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2959, '2023-0299', 'mary.joy.sim@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mary Joy Sim', '2023-0299', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2958, '2023-0240', 'jenny.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jenny Fajardo', '2023-0240', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2957, '2023-0248', 'jazzle.irish.cudiamat@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jazzle Irish Cudiamat', '2023-0248', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2956, '2023-0322', 'joel.villena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Joel Villena', '2023-0322', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2955, '2023-0255', 'jayson.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jayson Ramos', '2023-0255', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2954, '2023-0308', 'john.khim.moreno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Khim Moreno', '2023-0308', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2953, '2023-0332', 'michael.magat@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Michael Magat', '2023-0332', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2952, '2023-0243', 'kian.vash.gale@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kian Vash Gale', '2023-0243', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2951, '2023-0249', 'mark.lyndon.fransisco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Lyndon Fransisco', '2023-0249', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2950, '2023-0177', 'john.paul.fernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Paul Fernandez', '2023-0177', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2949, '2023-0167', 'mc.lowell.fabellon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mc Lowell Fabellon', '2023-0167', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2948, '2023-0239', 'adrian.dilao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Adrian Dilao', '2023-0239', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2947, '2023-1080', 'mark.lee.dalay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Lee Dalay', '2023-1080', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2946, '2023-0233', 'joriz.cezar.collado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Joriz Cezar Collado', '2023-0233', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2945, '2023-0345', 'sherwin.calibot@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Sherwin Calibot', '2023-0345', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2944, '2023-0336', 'jhon.jerald.acojedo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhon Jerald Acojedo', '2023-0336', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2943, '2023-0241', 'lyn.velasquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lyn Velasquez', '2023-0241', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2942, '2023-0303', 'kyla.rucio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kyla Rucio', '2023-0303', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2941, '2023-0173', 'lailin.obando@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lailin Obando', '2023-0173', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2940, '2023-0224', 'marian.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marian Mendoza', '2023-0224', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2939, '2023-0225', 'genesis.mae.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Genesis Mae Mendoza', '2023-0225', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2938, '2023-0285', 'maan.masangkay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maan Masangkay', '2023-0285', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2937, '2023-0215', 'judy.ann.madrigal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Judy Ann Madrigal', '2023-0215', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2936, '2023-0244', 'jennie.vee.lopez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jennie Vee Lopez', '2023-0244', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2935, '2023-0298', 'laila.limun@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Laila Limun', '2023-0298', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2934, '2023-0251', 'angielene.landicho@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angielene Landicho', '2023-0251', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2933, '2023-0200', 'zyra.gutierrez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Zyra Gutierrez', '2023-0200', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2932, '2023-0169', 'herjane.gozar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Herjane Gozar', '2023-0169', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2931, '2023-0161', 'baby.anh.marie.godoy@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Baby Anh Marie Godoy', '2023-0161', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2930, '2023-0317', 'jeanlyn.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jeanlyn Garcia', '2023-0317', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2929, '2023-0305', 'jaime.elizabeth.evora@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jaime Elizabeth Evora', '2023-0305', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2928, '2023-0288', 'cristal.jean.dechusa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Cristal Jean De Chusa', '2023-0288', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2927, '2022-0088', 'rashele.delgaco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rashele Delgaco', '2022-0088', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2926, '2023-0327', 'juvylyn.basa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Juvylyn Basa', '2023-0327', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2925, '2023-0337', 'leica.banila@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Leica Banila', '2023-0337', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2924, '2023-0304', 'jonah.rhyza.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jonah Rhyza Anyayahan', '2023-0304', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2923, '2024-0397', 'jyrus.ylagan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jyrus Ylagan', '2024-0397', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2922, '2024-0406', 'gerson.urdanza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Gerson Urdanza', '2024-0406', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2921, '2024-0408', 'jerus.savariz@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jerus Savariz', '2024-0408', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2920, '2024-0423', 'benjamin.jr..sarvida@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Benjamin Jr. Sarvida', '2024-0423', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2919, '2024-0580', 'merwin.santos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Merwin Santos', '2024-0580', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2918, '2024-0578', 'matt.raphael.reyes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Matt Raphael Reyes', '2024-0578', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2917, '2024-0436', 'jhezreel.pastorfide@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhezreel Pastorfide', '2024-0436', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2916, '2024-0392', 'james.lorence.paradijas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'James Lorence Paradijas', '2024-0392', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2915, '2024-0393', 'amiel.geronne.pantua@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Amiel Geronne Pantua', '2024-0393', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2914, '2024-0428', 'christian.moreno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Christian Moreno', '2024-0428', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2913, '2024-0410', 'john.rexcel.montianto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Rexcel Montianto', '2024-0410', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2912, '2024-0394', 'carlo.mondragon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Carlo Mondragon', '2024-0394', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2911, '2024-0478', 'dranzel.miranda@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Dranzel Miranda', '2024-0478', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2910, '2023-0465', 'patrick.matanguihan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Patrick Matanguihan', '2023-0465', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2909, '2024-0395', 'florence.macalelong@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Florence Macalelong', '2024-0395', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2908, '2023-0151', 'ramcil.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ramcil Macapuno', '2023-0151', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2907, '2024-0420', 'miklo.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Miklo Lumanglas', '2024-0420', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2906, '2024-0517', 'gino.genabe@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Gino Genabe', '2024-0517', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2905, '2024-0413', 'airon.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Airon Evangelista', '2024-0413', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2904, '2023-0447', 'charles.darwin.dimailig@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Charles Darwin Dimailig', '2023-0447', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2903, '2023-0407', 'mark.janssen.cueto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Janssen Cueto', '2023-0407', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2902, '2024-0561', 'alvin.corona@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Alvin Corona', '2024-0561', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2901, '2024-0572', 'mark.jayson.bunag@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Jayson Bunag', '2024-0572', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2900, '2024-0398', 'raphael.bugayong@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Raphael Bugayong', '2024-0398', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2899, '2024-0043', 'john.kenneth.joseph.balansag@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Kenneth Joseph Balansag', '2024-0043', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2898, '2023-0519', 'john.michael.bacsa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Michael Bacsa', '2023-0519', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2897, '2023-0433', 'romelyn.rocha@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Romelyn Rocha', '2023-0433', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2896, '2024-0426', 'desiree.raymundo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Desiree Raymundo', '2024-0426', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2895, '2024-0582', 'shella.mae.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shella Mae Ramos', '2024-0582', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2894, '2024-0348', 'myzell.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Myzell Ramos', '2024-0348', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2893, '2024-0314', 'shenna.marie.obando@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shenna Marie Obando', '2024-0314', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2892, '2024-0571', 'lovelyn.marcos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lovelyn Marcos', '2024-0571', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2891, '2024-0412', 'grace.cell.manibo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Grace Cell Manibo', '2024-0412', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2890, '2024-0472', 'keycel.joy.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Keycel Joy Manalo', '2024-0472', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2889, '2024-0415', 'nerissa.magsisi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Nerissa Magsisi', '2024-0415', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2888, '2024-0544', 'ariane.magboo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ariane Magboo', '2024-0544', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2887, '2024-0427', 'christine.joy.lomio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Christine Joy Lomio', '2024-0427', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2886, '2024-0416', 'mikaela.joy.layson@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mikaela Joy Layson', '2024-0416', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2885, '2024-0422', 'jayann.jamilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jay-Ann Jamilla', '2024-0422', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2884, '2024-0567', 'arlene.gaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Arlene Gaba', '2024-0567', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2883, '2024-0432', 'stella.rey.flores@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Stella Rey Flores', '2024-0432', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2882, '2024-0417', 'nesvita.dorias@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Nesvita Dorias', '2024-0417', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2881, '2024-0404', 'marina.deluzon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marina De Luzon', '2024-0404', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2880, '2024-0343', 'precious.cindy.deguzman@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Precious Cindy De Guzman', '2024-0343', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2879, '2024-0437', 'arjean.joy.decastro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Arjean Joy De Castro', '2024-0437', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2878, '2024-0342', 'charlaine.debelen@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Charlaine De Belen', '2024-0342', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2877, '2024-0424', 'princess.hazel.cabasi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Princess Hazel Cabasi', '2024-0424', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2876, '2024-0418', 'ludelyn.belbes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ludelyn Belbes', '2024-0418', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2875, '2024-0411', 'precious.apil@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Precious Apil', '2024-0411', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2874, '2024-0405', 'jonice.alturas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jonice Alturas', '2024-0405', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2873, '2024-0438', 'melsan.aday@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Melsan Aday', '2024-0438', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2872, '2025-0816', 'marsha.lhee.azucena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marsha Lhee Azucena', '2025-0816', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2871, '2024-0492', 'djay.teriompo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'D-Jay Teriompo', '2024-0492', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2870, '2024-0523', 'ronald.taada@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ronald Tañada', '2024-0523', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2869, '2024-0480', 'john.paul.roldan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Paul Roldan', '2024-0480', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2868, '2024-0386', 'aj.masangkay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'AJ Masangkay', '2024-0386', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2867, '2024-0525', 'jan.carlo.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jan Carlo Manalo', '2024-0525', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2866, '2024-0389', 'alex.magsisi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Alex Magsisi', '2024-0389', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2865, '2024-0557', 'denniel.delossantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Denniel Delos Santos', '2024-0557', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2864, '2024-0373', 'marvin.caraig@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marvin Caraig', '2024-0373', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2863, '2024-0365', 'lany.ylagan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lany Ylagan', '2024-0365', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2862, '2024-0356', 'lesley.ann.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lesley Ann Villanueva', '2024-0356', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2861, '2024-0556', 'jolie.tugmin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jolie Tugmin', '2024-0556', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2860, '2024-0453', 'cynthia.torres@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Cynthia Torres', '2024-0453', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2859, '2024-0451', 'mary.joy.sara@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mary Joy Sara', '2024-0451', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2858, '2024-0509', 'edcel.jane.santillan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Edcel Jane Santillan', '2024-0509', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2857, '2024-0382', 'nia.zyrene.sanchez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Niña Zyrene Sanchez', '2024-0382', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2856, '2024-0264', 'katrina.t.rufino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Katrina T Rufino', '2024-0264', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2855, '2024-0380', 'jeyzelle.rellora@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jeyzelle Rellora', '2024-0380', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2854, '2024-0359', 'jasmine.prangue@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jasmine Prangue', '2024-0359', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2853, '2024-0568', 'angela.papasin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angela Papasin', '2024-0568', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2852, '2024-0350', 'hazel.ann.panganiban@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Hazel Ann Panganiban', '2024-0350', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2851, '2024-0384', 'margie.nuez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Margie Nuñez', '2024-0384', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2850, '2024-0377', 'cherese.gelyn.nao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Cherese Gelyn Nao', '2024-0377', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2849, '2024-0349', 'precious.nicole.moya@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Precious Nicole Moya', '2024-0349', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2848, '2024-0586', 'rexy.mae.mingo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rexy Mae Mingo', '2024-0586', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2847, '2024-0587', 'hannah.melgar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Hannah Melgar', '2024-0587', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2846, '2024-0387', 'angel.rose.mascarinas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angel Rose Mascarinas', '2024-0387', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2845, '2024-0391', 'kriselle.ann.mabuti@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kriselle Ann Mabuti', '2024-0391', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2844, '2024-0368', 'joan.kate.lomio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Joan Kate Lomio', '2024-0368', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2843, '2024-0376', 'jazleen.llamoso@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jazleen Llamoso', '2024-0376', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2842, '2024-0501', 'eslley.ann.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Eslley Ann Hernandez', '2024-0501', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2841, '2024-0375', 'andrea.mae.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Andrea Mae Hernandez', '2024-0375', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2840, '2024-0507', 'aiexa.danielle.guira@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Aiexa Danielle Guira', '2024-0507', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2839, '2024-0371', 'leah.galit@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Leah Galit', '2024-0371', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2838, '2024-0385', 'marie.joy.gado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marie Joy Gado', '2024-0385', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2837, '2024-0366', 'hazel.ann.feudo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Hazel Ann Feudo', '2024-0366', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2836, '2024-0388', 'chariz.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Chariz Fajardo', '2024-0388', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2835, '2024-0363', 'maricar.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maricar Evangelista', '2024-0363', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2834, '2024-0367', 'rexlyn.joy.eguillon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rexlyn Joy Eguillon', '2024-0367', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2833, '2024-0374', 'kristine.dris@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kristine Dris', '2024-0374', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2832, '2024-0520', 'angel.dimoampo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angel Dimoampo', '2024-0520', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2831, '2024-0369', 'mariel.delossantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mariel Delos Santos', '2024-0369', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2830, '2024-0351', 'shane.dalisay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shane Dalisay', '2024-0351', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2829, '2024-0474', 'kim.ashley.nicole.caringal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kim Ashley Nicole Caringal', '2024-0474', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2828, '2024-0355', 'elyza.buquis@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Elyza Buquis', '2024-0355', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2827, '2024-0364', 'realyn.bercasi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Realyn Bercasi', '2024-0364', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2826, '2024-0347', 'cherylyn.bacsa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Cherylyn Bacsa', '2024-0347', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2825, '2024-0354', 'maica.bacal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maica Bacal', '2024-0354', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2824, '2024-0372', 'katrice.allaine.atienza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Katrice Allaine Atienza', '2024-0372', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2823, '2024-0360', 'rocel.liegh.araez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rocel Liegh Arañez', '2024-0360', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2822, '2024-0379', 'crislyn.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Crislyn Anyayahan', '2024-0379', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2821, '2024-0521', 'lara.mae.altamia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lara Mae Altamia', '2024-0521', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL);
INSERT INTO `users` (`id`, `username`, `email`, `google_id`, `facebook_id`, `profile_picture`, `password`, `role`, `full_name`, `student_id`, `is_active`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(2820, '2024-0504', 'lynse.albufera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lynse Albufera', '2024-0504', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2819, '2024-0378', 'benelyn.aguho@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Benelyn Aguho', '2024-0378', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2818, '2024-0352', 'patricia.mae.agoncillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Patricia Mae Agoncillo', '2024-0352', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2817, '2024-0358', 'ashlyn.kieth.abanilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ashlyn Kieth Abanilla', '2024-0358', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2816, '2024-0462', 'rodel.roldan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rodel Roldan', '2024-0462', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2815, '2024-0401', 'jhon.kenneth.obando@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhon Kenneth Obando', '2024-0401', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2814, '2024-0530', 'allan.loto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Allan Loto', '2024-0530', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2813, '2024-0555', 'john.mariol.fransisco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Mariol Fransisco', '2024-0555', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2812, '2024-0450', 'rickson.ferry@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rickson Ferry', '2024-0450', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2811, '2024-0505', 'bert.ferrera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Bert Ferrera', '2024-0505', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2810, '2024-0449', 'john.ivan.cuasay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Ivan Cuasay', '2024-0449', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2809, '2024-0454', 'zairene.undaloc@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Zairene Undaloc', '2024-0454', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2808, '2024-0444', 'angela.clariss.teves@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angela Clariss Teves', '2024-0444', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2807, '2024-0563', 'danica.pederio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Danica Pederio', '2024-0563', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2806, '2024-0538', 'maria.irene.pasado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maria Irene Pasado', '2024-0538', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2805, '2024-0456', 'joana.marie.paala@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Joana Marie Paala', '2024-0456', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2804, '2024-0458', 'chelo.rose.marasigan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Chelo Rose Marasigan', '2024-0458', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2803, '2024-0545', 'febelyn.magboo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Febelyn Magboo', '2024-0545', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2802, '2024-0464', 'michelle.micah.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Michelle Micah Lumanglas', '2024-0464', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2801, '2024-0463', 'angela.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angela Lumanglas', '2024-0463', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2800, '2024-0440', 'irene.loto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Irene Loto', '2024-0440', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2799, '2024-0554', 'april.joy.llamoso@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'April Joy Llamoso', '2024-0554', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2798, '2024-0476', 'catherine.gomez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Catherine Gomez', '2024-0476', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2797, '2024-0441', 'janah.glor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Janah Glor', '2024-0441', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2796, '2024-0466', 'shane.mary.gardoce@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shane Mary Gardoce', '2024-0466', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2795, '2024-0502', 'maria.angela.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maria Angela Garcia', '2024-0502', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2794, '2024-0470', 'shane.ayessa.elio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shane Ayessa Elio', '2024-0470', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2793, '2024-0531', 'francene.delossantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Francene Delos Santos', '2024-0531', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2792, '2024-0461', 'kc.may.deguzman@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'KC May De Guzman', '2024-0461', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2791, '2024-0548', 'angel.cason@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angel Cason', '2024-0548', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2790, '2024-0503', 'carla.andrea.azucena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Carla Andrea Azucena', '2024-0503', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2789, '2024-0445', 'arhizza.sheena.abanilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Arhizza Sheena Abanilla', '2024-0445', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2788, '2024-0455', 'kevin.rucio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kevin Rucio', '2024-0455', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2787, '2024-0497', 'jhon.marc.oliveria@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhon Marc Oliveria', '2024-0497', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2786, '2024-0494', 'great.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Great Mendoza', '2024-0494', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2785, '2025-0592', 'aaron.vincent.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Aaron Vincent Manalo', '2025-0592', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2784, '2024-0490', 'mc.ryan.masangkay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mc Ryan Masangkay', '2024-0490', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2783, '2024-0495', 'john.reign.laredo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Reign Laredo', '2024-0495', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2782, '2024-0499', 'prince.geneta@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Prince Geneta', '2024-0499', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2781, '2024-0345', 'karl.andrew.hardin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'karl Andrew Hardin', '2024-0345', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2780, '2024-0475', 'antonio.gabriel.francisco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Antonio Gabriel Francisco', '2024-0475', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2779, '2024-0488', 'john.lester.gaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Lester Gaba', '2024-0488', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2778, '2024-0500', 'john.ray.fegidero@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Ray Fegidero', '2024-0500', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2777, '2024-0489', 'reymar.faeldonia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Reymar Faeldonia', '2024-0489', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2776, '2024-0477', 'john.paul.delemos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Paul De Lemos', '2024-0477', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2775, '2024-0485', 'cedrick.cardova@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Cedrick Cardova', '2024-0485', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2774, '2024-0491', 'shim.andrian.adarlo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shim Andrian Adarlo', '2024-0491', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2773, '2024-0539', 'emerson.adarlo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Emerson Adarlo', '2024-0539', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2772, '2024-0469', 'mischell.velasquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mischell Velasquez', '2024-0469', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2771, '2024-0442', 'necilyn.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Necilyn Ramos', '2024-0442', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2770, '2024-0457', 'mikayla.paala@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mikayla Paala', '2024-0457', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2769, '2024-0516', 'kyla.oliveria@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kyla Oliveria', '2024-0516', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2768, '2024-0570', 'carla.nineria@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Carla Nineria', '2024-0570', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2767, '2024-0535', 'evangeline.mojica@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Evangeline Mojica', '2024-0535', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2766, '2024-0487', 'roma.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Roma Mendoza', '2024-0487', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2765, '2024-0473', 'jenny.idea@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jenny Idea', '2024-0473', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2764, '2024-0549', 'danica.mae.hornilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Danica Mae Hornilla', '2024-0549', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2763, '2024-0446', 'rica.glodo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rica Glodo', '2024-0446', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2762, '2024-0459', 'jade.garing@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jade Garing', '2024-0459', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2761, '2024-0508', 'lara.mae.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lara Mae Garcia', '2024-0508', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2760, '2024-0506', 'maecelle.fiedalan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maecelle Fiedalan', '2024-0506', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2759, '2024-0546', 'gielysa.concha@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Gielysa Concha', '2024-0546', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2758, '2024-0550', 'juneth.baliday@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Juneth Baliday', '2024-0550', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2757, '2024-0591', 'regine.antipasado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Regine Antipasado', '2024-0591', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2756, '2024-0569', 'katrice.antipasado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Katrice Antipasado', '2024-0569', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2755, '2024-0514', 'kyla.anonuevo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kyla Anonuevo', '2024-0514', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2754, '2024-0513', 'kiana.jane.aonuevo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kiana Jane Añonuevo', '2024-0513', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2753, '2025-0597', 'ivan.lester.ylagan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ivan Lester Ylagan', '2025-0597', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2752, '2025-0695', 'philip.jhon.tabor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Philip Jhon Tabor', '2025-0695', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2751, '2025-0776', 'jude.michael.somera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jude Michael Somera', '2025-0776', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2750, '2025-0764', 'tristan.jay.plata@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Tristan Jay Plata', '2025-0764', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2749, '2025-0622', 'mark.justin.pecolados@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Justin Pecolados', '2025-0622', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2748, '2025-0600', 'patrick.lanz.paz@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Patrick Lanz Paz', '2025-0600', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2747, '2025-0659', 'carl.justine.padua@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Carl Justine Padua', '2025-0659', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2746, '2025-0725', 'vhon.jerick.o.ornos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Vhon Jerick O Ornos', '2025-0725', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2745, '2025-0651', 'jm.nas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'JM Nas', '2025-0651', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2744, '2025-0625', 'mark.angelo.montevirgen@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Angelo Montevirgen', '2025-0625', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2743, '2025-0624', 'hedyen.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Hedyen Mendoza', '2025-0624', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2742, '2025-0730', 'jimrex.mayano@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jimrex Mayano', '2025-0730', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2741, '2025-0650', 'eric.john.marinduque@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Eric John Marinduque', '2025-0650', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2740, '2025-0693', 'cedrick.mandia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Cedrick Mandia', '2025-0693', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2739, '2025-0781', 'jandy.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jandy Macapuno', '2025-0781', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2738, '2025-0596', 'john.lemuel.macalindol@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Lemuel Macalindol', '2025-0596', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2737, '2025-0639', 'luigi.lomio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Luigi Lomio', '2025-0639', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2736, '2025-0735', 'bricks.lindero@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Bricks Lindero', '2025-0735', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2735, '2025-0663', 'janryx.laspinas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Janryx Las Pinas', '2025-0663', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2734, '2025-0598', 'andrew.laredo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Andrew Laredo', '2025-0598', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2733, '2025-0662', 'ralph.adriane.javier@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ralph Adriane Javier', '2025-0662', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2732, '2025-0753', 'renz.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Renz Hernandez', '2025-0753', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2731, '2025-0803', 'benjamin.jr.d.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Benjamin Jr. D Hernandez', '2025-0803', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2730, '2025-0716', 'dan.kian.hatulan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Dan Kian Hatulan', '2025-0716', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2729, '2025-0715', 'mc.lenard.gibo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mc Lenard Gibo', '2025-0715', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2728, '2025-0681', 'john.andrew.gavilan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Andrew Gavilan', '2025-0681', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2727, '2025-0697', 'joshua.gabon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Joshua Gabon', '2025-0697', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2726, '2025-0595', 'uranus.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Uranus Evangelista', '2025-0595', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2725, '2025-0696', 'alexander.ducado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Alexander Ducado', '2025-0696', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2724, '2025-0782', 'dave.ruzzele.despa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Dave Ruzzele Despa', '2025-0782', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2723, '2025-0652', 'daniel.deade@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Daniel De Ade', '2025-0652', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2722, '2025-0626', 'shervin.jeral.castro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shervin Jeral Castro', '2025-0626', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2721, '2025-0632', 'jeverson.bersoto@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jeverson Bersoto', '2025-0632', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2720, '2025-0791', 'ramfel.azucena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ramfel Azucena', '2025-0791', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2719, '2025-0620', 'rexon.abanilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rexon Abanilla', '2025-0620', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2718, '2025-0814', 'lovely.torres@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lovely Torres', '2025-0814', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2717, '2025-0634', 'marbhel.rucio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marbhel Rucio', '2025-0634', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2716, '2025-0774', 'jona.marie.romero@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jona Marie Romero', '2025-0774', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2715, '2025-0628', 'alyssa.mae.quintia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Alyssa Mae Quintia', '2025-0628', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2714, '2025-0738', 'nicole.ola@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Nicole Ola', '2025-0738', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2713, '2025-0653', 'jasmine.nuestro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jasmine Nuestro', '2025-0653', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2712, '2025-0748', 'arien.montesa@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Arien Montesa', '2025-0748', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2711, '2025-0708', 'ericca.marquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ericca Marquez', '2025-0708', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2710, '2025-0739', 'abegail.malogueo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Abegail Malogueño', '2025-0739', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2709, '2025-0682', 'janice.lugatic@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Janice Lugatic', '2025-0682', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2708, '2025-0720', 'charese.jolo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Charese Jolo', '2025-0720', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2707, '2025-0664', 'aleyah.janelle.jara@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Aleyah Janelle Jara', '2025-0664', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2706, '2025-0802', 'jedidiah.gelena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jedidiah Gelena', '2025-0802', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2705, '2025-0719', 'deah.angella.s.carpo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Deah Angella S Carpo', '2025-0719', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2704, '2025-0599', 'prinses.gabriela.calaolao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Prinses Gabriela Calaolao', '2025-0599', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2703, '2025-0669', 'daniela.faye.cabiles@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Daniela Faye Cabiles', '2025-0669', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2702, '2025-0623', 'mika.dean.buadilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mika Dean Buadilla', '2025-0623', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2701, '2025-0752', 'sherilyn.anyayahan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Sherilyn Anyayahan', '2025-0752', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2700, '2025-0661', 'aizel.alvarez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Aizel Alvarez', '2025-0661', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2699, '2025-0601', 'maria.fe.aldovino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maria Fe Aldovino', '2025-0601', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2698, '2025-0775', 'angela.aldea@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angela Aldea', '2025-0775', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2697, '2025-0621', 'novelyn.albufera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Novelyn Albufera', '2025-0621', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2696, '2025-0645', 'dindo.tolentino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Dindo Tolentino', '2025-0645', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2695, '2025-0732', 'helbert.maulion@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Helbert Maulion', '2025-0732', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2694, '2025-0660', 'john.lloyd.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Lloyd Macapuno', '2025-0660', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2693, '2025-0740', 'marjun.a.linayao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marjun A Linayao', '2025-0740', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2692, '2025-0865', 'zyris.guavez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Zyris Guavez', '2025-0865', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2691, '2025-0627', 'kervin.garachico@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kervin Garachico', '2025-0627', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2690, '2025-0815', 'reymart.elmido@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Reymart Elmido', '2025-0815', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2689, '2025-0690', 'rexner.eguillon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rexner Eguillon', '2025-0690', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2688, '2025-0684', 'rodel.arenas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rodel Arenas', '2025-0684', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2687, '2025-0806', 'megan.michaela.visaya@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Megan Michaela Visaya', '2025-0806', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2686, '2025-0723', 'pauleen.villaruel@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Pauleen Villaruel', '2025-0723', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2685, '2025-0731', 'jeane.sulit@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jeane Sulit', '2025-0731', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2684, '2025-0777', 'nicole.silva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Nicole Silva', '2025-0777', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2683, '2025-0734', 'rhenelyn.sandoval@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rhenelyn Sandoval', '2025-0734', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2682, '2025-0741', 'aimie.jane.reyes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Aimie Jane Reyes', '2025-0741', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2681, '2025-0788', 'ashly.nicole.rana@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ashly Nicole Rana', '2025-0788', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2680, '2025-0779', 'jea.francine.rivera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jea Francine Rivera', '2025-0779', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2679, '2025-0647', 'argel.ocampo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Argel Ocampo', '2025-0647', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2678, '2025-0728', 'ma.teresa.obando@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ma. Teresa Obando', '2025-0728', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2677, '2025-0710', 'erica.mae.motol@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Erica Mae Motol', '2025-0710', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2676, '2025-0729', 'camille.milambiling@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Camille Milambiling', '2025-0729', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2675, '2025-0609', 'leslie.melgar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Leslie Melgar', '2025-0609', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2674, '2025-0808', 'remz.ann.escarlet.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Remz Ann Escarlet Macapuno', '2025-0808', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2673, '2025-0633', 'angela.lotho@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angela Lotho', '2025-0633', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2672, '2025-0655', 'edlyn.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Edlyn Hernandez', '2025-0655', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2671, '2025-0737', 'shalemar.geroleo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shalemar Geroleo', '2025-0737', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2670, '2025-0713', 'katrice.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Katrice Garcia', '2025-0713', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2669, '2025-0654', 'jenelyn.fonte@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jenelyn Fonte', '2025-0654', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2668, '2025-0618', 'judith.fallarna@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Judith Fallarna', '2025-0618', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2667, '2025-0657', 'ailla.fajura@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ailla Fajura', '2025-0657', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2666, '2025-0688', 'elayca.mae.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Elayca Mae Fajardo', '2025-0688', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2665, '2025-0611', 'christina.sofia.lie.enriquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Christina Sofia Lie Enriquez', '2025-0611', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2664, '2025-0612', 'romelyn.elida@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Romelyn Elida', '2025-0612', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2663, '2025-0722', 'sophia.angela.delosreyes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Sophia Angela Delos Reyes', '2025-0722', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2662, '2025-0673', 'nicole.defeo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Nicole Defeo', '2025-0673', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2661, '2025-0742', 'jamhyca.dechavez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jamhyca De Chavez', '2025-0742', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2660, '2025-0727', 'prences.angel.consigo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Prences Angel Consigo', '2025-0727', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2659, '2025-0711', 'claren.carable@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Claren Carable', '2025-0711', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2658, '2025-0638', 'shiella.mae.bonifacio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shiella Mae Bonifacio', '2025-0638', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2657, '2025-0783', 'lorraine.bonado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lorraine Bonado', '2025-0783', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2656, '2025-0679', 'alexa.jane.bon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Alexa Jane Bon', '2025-0679', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2655, '2025-0646', 'jhovelyn.bacay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhovelyn Bacay', '2025-0646', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2654, '2025-0680', 'jonah.trisha.asi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jonah Trisha Asi', '2025-0680', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2653, '2025-0809', 'jeny.amado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jeny Amado', '2025-0809', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2652, '2025-0765', 'rysa.mae.alfante@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rysa Mae Alfante', '2025-0765', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2651, '2025-0619', 'hanna.aborde@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Hanna Aborde', '2025-0619', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2650, '2025-0733', 'shane.ashley.abendan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shane Ashley Abendan', '2025-0733', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2649, '2025-0617', 'kann.abela@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'K-Ann Abela', '2025-0617', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2648, '2025-0747', 'brix.matthew.velasco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Brix Matthew Velasco', '2025-0747', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2647, '2025-0762', 'erwin.tejedor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Erwin Tejedor', '2025-0762', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2646, '2025-0801', 'mel.gabriel.magat@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mel Gabriel Magat', '2025-0801', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2645, '2025-0785', 'jairus.macuha@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jairus Macuha', '2025-0785', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2644, '2025-0636', 'jarred.gomez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jarred Gomez', '2025-0636', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2643, '2025-0743', 'daniel.franco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Daniel Franco', '2025-0743', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2642, '2025-0726', 'aldrin.carable@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Aldrin Carable', '2025-0726', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2641, '2025-0705', 'danilo.r.jr.cabiles@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Danilo R. Jr Cabiles', '2025-0705', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2640, '2025-0629', 'felicity.villegas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Felicity Villegas', '2025-0629', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2639, '2025-0643', 'wyncel.tolentino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Wyncel Tolentino', '2025-0643', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2638, '2025-0718', 'marie.bernadette.tolentino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marie Bernadette Tolentino', '2025-0718', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2637, '2025-0796', 'rubilyn.roxas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rubilyn Roxas', '2025-0796', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2636, '2025-0789', 'irish.catherine.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Irish Catherine Ramos', '2025-0789', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2635, '2025-0770', 'ivy.kristine.petilo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ivy Kristine Petilo', '2025-0770', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2634, '2025-0766', 'althea.paala@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Althea Paala', '2025-0766', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2633, '2025-0699', 'lleyn.angela.olympia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lleyn Angela Olympia', '2025-0699', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2632, '2025-0772', 'romelyn.mongcog@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Romelyn Mongcog', '2025-0772', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2631, '2025-0767', 'lovely.joy.mercado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lovely Joy Mercado', '2025-0767', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2630, '2025-0763', 'lorain.b.medina@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lorain B Medina', '2025-0763', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2629, '2025-0771', 'mikee.manay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mikee Manay', '2025-0771', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2628, '2025-0656', 'arian.bello.maculit@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Arian Bello Maculit', '2025-0656', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2627, '2025-0805', 'mae.hernandez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mae Hernandez', '2025-0805', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2626, '2025-0786', 'bhea.jane.gillado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Bhea Jane Gillado', '2025-0786', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2625, '2025-0800', 'aleah.gida@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Aleah Gida', '2025-0800', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2624, '2025-0667', 'janel.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Janel Garcia', '2025-0667', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2623, '2025-0756', 'crystal.gagote@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Crystal Gagote', '2025-0756', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2622, '2025-0755', 'sharmaine.fonte@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Sharmaine Fonte', '2025-0755', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL);
INSERT INTO `users` (`id`, `username`, `email`, `google_id`, `facebook_id`, `profile_picture`, `password`, `role`, `full_name`, `student_id`, `is_active`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(2621, '2025-0668', 'zean.dane.falcutila@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Zean Dane Falcutila', '2025-0668', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2620, '2025-0754', 'analyn.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Analyn Fajardo', '2025-0754', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2619, '2025-0778', 'shane.dudas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shane Dudas', '2025-0778', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2618, '2025-0790', 'anna.nicole.deleon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Anna Nicole De Leon', '2025-0790', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2617, '2025-0637', 'jocelyn.deguzman@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jocelyn De Guzman', '2025-0637', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2616, '2025-0793', 'marra.jane.cleofe@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marra Jane Cleofe', '2025-0793', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2615, '2025-0758', 'danica.bea.castillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Danica Bea Castillo', '2025-0758', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2614, '2025-0676', 'rhealyne.cardona@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rhealyne Cardona', '2025-0676', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2613, '2025-0658', 'myka.braza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Myka Braza', '2025-0658', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2612, '2025-0745', 'charisma.banila@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Charisma Banila', '2025-0745', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2611, '2025-0797', 'marydith.atienza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marydith Atienza', '2025-0797', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2610, '2025-0784', 'mary.ann.asi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mary Ann Asi', '2025-0784', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2609, '2025-0534', 'khim.tejada@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Khim Tejada', '2025-0534', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2608, '2025-0692', 'john.kenneth.perez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Kenneth Perez', '2025-0692', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2607, '2025-0606', 'jhon.jake.perez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhon Jake Perez', '2025-0606', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2606, '2025-0686', 'johnwin.pastor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Johnwin Pastor', '2025-0686', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2605, '2025-0757', 'john.lord.moreno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Lord Moreno', '2025-0757', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2604, '2025-0649', 'ronron.montero@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ron-Ron Montero', '2025-0649', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2603, '2025-0594', 'marlex.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marlex Mendoza', '2025-0594', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2602, '2025-0672', 'paul.tristan.madla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Paul Tristan Madla', '2025-0672', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2601, '2025-0746', 'jhon.loyd.macapuno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhon Loyd Macapuno', '2025-0746', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2600, '2025-0794', 'jaypee.jacob@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jaypee Jacob', '2025-0794', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2599, '2025-0795', 'edward.john.holgado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Edward John Holgado', '2025-0795', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2598, '2025-0603', 'bobby.jr..godoy@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Bobby Jr. Godoy', '2025-0603', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2597, '2025-0593', 'jared.gasic@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jared Gasic', '2025-0593', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2596, '2025-0363', 'jhake.perillo.garan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhake Perillo Garan', '2025-0363', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2595, '2025-0602', 'mark.angelo.riza.francisco@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Angelo Riza Francisco', '2025-0602', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2594, '2025-0703', 'mark.neil.fajil@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Neil Fajil', '2025-0703', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2583, '2025-0761', 'ana.marie.quimora@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ana Marie Quimora', '2025-0761', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2584, '2025-0707', 'camille.tordecilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Camille Tordecilla', '2025-0707', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2585, '2025-0630', 'jonalyn.untalan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jonalyn Untalan', '2025-0630', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2586, '2025-0810', 'lyra.mae.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lyra Mae Villanueva', '2025-0810', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2587, '2025-0608', 'rhaizza.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rhaizza Villanueva', '2025-0608', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2588, '2025-0687', 'john.philip.montillana.batarlo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Philip Montillana Batarlo', '2025-0687', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2589, '2025-0807', 'ace.romar.castillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ace Romar Castillo', '2025-0807', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2590, '2025-0773', 'john.lloyd.castillo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Lloyd Castillo', '2025-0773', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2591, '2025-0616', 'jericho.delmundo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jericho Del Mundo', '2025-0616', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2592, '2025-0799', 'khyn.delosreyes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Khyn Delos Reyes', '2025-0799', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2593, '2025-0604', 'gian.dominic.riza.dudas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Gian Dominic Riza Dudas', '2025-0604', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3053, '2023-0206', 'patrick.james.romasanta@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$10$M55A.dIw8kb.X.uBFXznL.vzMHNgLhXwslJQTYVs01LHLcpI/OXRq', 'user', 'Patrick James Romasanta', '2023-0206', 1, 'active', '2026-02-24 02:12:16', '2026-03-08 02:40:37', NULL),
(3052, '2023-0176', 'dan.lloyd.paala@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Dan Lloyd Paala', '2023-0176', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3051, '2023-0195', 'jumyr.moreno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jumyr Moreno', '2023-0195', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3050, '2023-0162', 'rhaven.magmanlac@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rhaven Magmanlac', '2023-0162', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3049, '2023-0214', 'jhon.lester.madrigal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jhon Lester Madrigal', '2023-0214', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3048, '2023-0152', 'angelo.lumanglas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angelo Lumanglas', '2023-0152', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3047, '2023-0158', 'steven.angelo.legayada@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Steven Angelo Legayada', '2023-0158', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3046, '2023-0319', 'reniel.jara@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Reniel Jara', '2023-0319', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3045, '2023-0283', 'john.dexter.gonzales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Dexter Gonzales', '2023-0283', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3044, '2023-0292', 'kyzer.gonda@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kyzer Gonda', '2023-0292', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3043, '2023-0196', 'nathaniel.falcunaya@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Nathaniel Falcunaya', '2023-0196', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3042, '2023-0212', 'renzie.carl.escaro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Renzie Carl Escaro', '2023-0212', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3041, '2023-0286', 'karl.marion.deleon@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Karl Marion De Leon', '2023-0286', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3040, '2023-0218', 'vitoel.curatcha@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Vitoel Curatcha', '2023-0218', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3039, '2023-0293', 'john.albert.bastida@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Albert Bastida', '2023-0293', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3038, '2023-0273', 'mark.lester.baes@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Lester Baes', '2023-0273', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3037, '2023-0263', 'ken.celwyn.algaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ken Celwyn Algaba', '2023-0263', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3036, '2023-0157', 'jay.aguilar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jay Aguilar', '2023-0157', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3035, '2023-0268', 'monaliza.waing@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Monaliza Waing', '2023-0268', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3034, '2023-0221', 'jamaica.mickaela.villena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jamaica Mickaela Villena', '2023-0221', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3033, '2023-0344', 'angel.bellie.vargas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angel Bellie Vargas', '2023-0344', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3032, '2023-0566', 'andrea.chel.rivera@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Andrea Chel Rivera', '2023-0566', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3031, '2023-0181', 'shane.ramos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shane Ramos', '2023-0181', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3030, '2023-0208', 'paulyn.grace.perez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Paulyn Grace Perez', '2023-0208', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3029, '2023-0291', 'irish.may.roselle.nao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Irish May Roselle Nao', '2023-0291', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3028, '2023-0242', 'shylyn.mansalapus@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shylyn Mansalapus', '2023-0242', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3027, '2023-0198', 'shiloh.manhic@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shiloh Manhic', '2023-0198', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3026, '2023-0331', 'geraldine.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Geraldine Manalo', '2023-0331', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3025, '2023-0216', 'cristine.manalo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Cristine Manalo', '2023-0216', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3024, '2023-0156', 'irish.karyl.magcamit@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Irish Karyl Magcamit', '2023-0156', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3023, '2023-0204', 'clarissa.feudo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Clarissa Feudo', '2023-0204', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3022, '2023-0320', 'sherlyn.festin@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Sherlyn Festin', '2023-0320', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3021, '2023-0154', 'bea.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Bea Fajardo', '2023-0154', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3020, '2023-0155', 'kc.delaroca@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'KC Dela Roca', '2023-0155', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3019, '2023-0270', 'hiedie.claus@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Hiedie Claus', '2023-0270', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2582, '2025-0792', 'ashley.mendoza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Ashley Mendoza', '2025-0792', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2581, '2025-0704', 'keana.marquinez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Keana Marquinez', '2025-0704', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2580, '2025-0607', 'amaya.maibo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Amaya Mañibo', '2025-0607', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2579, '2025-0706', 'kylyn.jacob@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kylyn Jacob', '2025-0706', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2578, '2025-0714', 'kyla.jacob@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kyla Jacob', '2025-0714', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2577, '2025-0631', 'jasmine.gelena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jasmine Gelena', '2025-0631', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2576, '2025-0812', 'althea.nicole.shane.dudas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Althea Nicole Shane Dudas', '2025-0812', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2575, '2025-0760', 'jerlyn.aday@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jerlyn Aday', '2025-0760', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(2573, '111', 'ventiletos@gmail.com', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', '1 1', '2023-0206', 1, 'active', '2026-02-22 20:28:47', '2026-02-24 02:07:34', NULL),
(2574, '1', 'admin@gmail.com', NULL, NULL, NULL, '$2y$10$hBNUdr9u8zu.f7zVAUNYG.l7a8lKrpIZeEBZsEjkWYOYNEmDjARDe', 'admin', 'test', '1111', 0, 'archived', '2026-02-24 01:05:02', '2026-02-24 14:09:45', '2026-02-24 06:09:45'),
(2572, 'adminOsas@colegio.edu', 'adminOsas@gmail.com', NULL, NULL, NULL, '$2y$10$Dez.fBRnI1D4rgiSGoPgDeg4HGJtolHkjbnuZdaV9ziDVt.ra2Q1y', 'admin', 'adminOsas@colegio.edu', '2023-0206', 1, 'active', '2026-02-22 20:25:51', '2026-03-08 01:05:19', NULL),
(3054, '2023-0186', 'jereck.roxas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jereck Roxas', '2023-0186', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3055, '2023-0217', 'jan.denmark.santos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jan Denmark Santos', '2023-0217', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3056, '2023-0267', 'john.paolo.torralba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Paolo Torralba', '2023-0267', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3057, '2022-0079', 'dianne.christine.joy.alulod@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Dianne Christine Joy Alulod', '2022-0079', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3058, '2022-0080', 'rechel.arenas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Rechel Arenas', '2022-0080', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3059, '2022-0081', 'allyna.atienza@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Allyna Atienza', '2022-0081', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3060, '2022-0130', 'angela.bonilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Angela Bonilla', '2022-0130', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3061, '2022-0082', 'aira.cabulao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Aira Cabulao', '2022-0082', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3062, '2022-0124', 'janice.cadacio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Janice Cadacio', '2022-0124', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3063, '2022-0083', 'maries.cantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maries Cantos', '2022-0083', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3064, '2022-0084', 'veronica.cantos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Veronica Cantos', '2022-0084', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3065, '2022-0139', 'diana.caringal@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Diana Caringal', '2022-0139', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3066, '2022-0085', 'lorebeth.casapao@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lorebeth Casapao', '2022-0085', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3067, '2022-0086', 'carla.jane.chiquito@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Carla Jane Chiquito', '2022-0086', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3068, '2022-0089', 'melody.enriquez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Melody Enriquez', '2022-0089', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3069, '2022-0090', 'maricon.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Maricon Evangelista', '2022-0090', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3070, '2022-0091', 'mary.ann.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mary Ann Fajardo', '2022-0091', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3071, '2022-0092', 'kaecy.ferry@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Kaecy Ferry', '2022-0092', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3072, '2022-0140', 'zybel.garan@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Zybel Garan', '2022-0140', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3073, '2022-0118', 'ic.pamela.gutierrez@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'IC Pamela Gutierrez', '2022-0118', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3074, '2022-0096', 'jane.monica.mansalapus@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jane Monica Mansalapus', '2022-0096', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3075, '2022-0097', 'hanna.yesha.mae.mercado@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Hanna Yesha Mae Mercado', '2022-0097', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3076, '2022-0098', 'abegail.moong@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Abegail Moong', '2022-0098', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3077, '2022-0125', 'laiza.marie.pole@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Laiza Marie Pole', '2022-0125', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3078, '2022-0142', 'jarryfel.tembrevilla@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jarryfel Tembrevilla', '2022-0142', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3079, '2022-0136', 'jay.mark.avelino@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jay Mark Avelino', '2022-0136', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3080, '2022-0072', 'jairus.cabales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jairus Cabales', '2022-0072', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3081, '2022-0075', 'jleo.nhico.mari.mazo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jleo Nhico Mari Mazo', '2022-0075', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3082, '2022-0076', 'mark.cyrel.panganiban@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Cyrel Panganiban', '2022-0076', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3083, '2022-0117', 'bernabe.dave.solas@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Bernabe Dave Solas', '2022-0117', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3084, '2022-0078', 'mark.june.villena@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark June Villena', '2022-0078', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3085, '2022-0122', 'nhicel.bueno@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Nhicel Bueno', '2022-0122', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3086, '2022-0135', 'dianne.mae.cezar@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Dianne Mae Cezar', '2022-0135', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3087, '2022-0147', 'princess.joy.decastro@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Princess Joy De Castro', '2022-0147', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3088, '2022-0141', 'shiela.mae.fajardo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shiela Mae Fajardo', '2022-0141', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3089, '2022-0115', 'shiela.marie.garcia@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Shiela Marie Garcia', '2022-0115', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3090, '2022-0129', 'jessa.geneta@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jessa Geneta', '2022-0129', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3091, '2022-0094', 'jee.anne.llamoso@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Jee Anne Llamoso', '2022-0094', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3092, '2022-0123', 'princess.jenille.santos@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Princess Jenille Santos', '2022-0123', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3093, '2022-0099', 'von.lester.algaba@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Von Lester Algaba', '2022-0099', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3094, '2022-0100', 'john.aaron.aniel@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Aaron Aniel', '2022-0100', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3095, '2022-0101', 'keil.john.antenor@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Keil John Antenor', '2022-0101', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3096, '2022-0102', 'mark.joshua.bacay@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Joshua Bacay', '2022-0102', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3097, '2022-0128', 'michael.deguzman@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Michael De Guzman', '2022-0128', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3098, '2022-0107', 'christian.delda@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Christian Delda', '2022-0107', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3099, '2022-0108', 'lloyd.evangelista@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Lloyd Evangelista', '2022-0108', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3100, '2022-0073', 'samson.fulgencio@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Samson Fulgencio', '2022-0073', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3101, '2022-0145', 'john.dragan.gardoce@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Dragan Gardoce', '2022-0145', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3102, '2022-0127', 'john.elmer.gonzales@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Elmer Gonzales', '2022-0127', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3103, '2022-0144', 'mark.vender.muhi@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Mark Vender Muhi', '2022-0144', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3104, '2022-0112', 'marc.paulo.relano@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Marc Paulo Relano', '2022-0112', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3105, '2022-0113', 'cee.jey.rellora@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Cee Jey Rellora', '2022-0113', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3106, '2022-0134', 'franklin.salcedo@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Franklin Salcedo', '2022-0134', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3107, '2022-0120', 'russel.sason@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Russel Sason', '2022-0120', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3108, '2022-0132', 'john.paul.teves@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Paul Teves', '2022-0132', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3109, '2022-0131', 'john.xavier.villanueva@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'John Xavier Villanueva', '2022-0131', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3110, '2022-0114', 'reinier.aron.visayana@colegiodenaujan.edu.ph', NULL, NULL, NULL, '$2y$12$95ivuxDsbXnvq.o.nhD8W.c8CWA9LpLQvO/7ThprttW8qa6WPh2oy', 'user', 'Reinier Aron Visayana', '2022-0114', 1, 'active', '2026-02-24 02:12:16', '2026-02-24 02:12:16', NULL),
(3111, 'test1', 'geraldinegaran70@gmail.com', NULL, NULL, NULL, '$2y$10$tCEmQ8UneG8IcZxBlnOABuqpuhQhSGH4NURKZRUzPYvy9xIXg8VLy', 'user', 'test', '1212', 1, 'active', '2026-02-26 04:51:21', '2026-03-08 00:38:20', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `violations`
--

DROP TABLE IF EXISTS `violations`;
CREATE TABLE IF NOT EXISTS `violations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `case_id` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `student_id` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `violation_type_id` int NOT NULL,
  `violation_level_id` int NOT NULL,
  `department` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `section` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `violation_date` date NOT NULL,
  `violation_time` time NOT NULL,
  `location` enum('gate_1','gate_2','classroom','library','cafeteria','gym','others') COLLATE utf8mb4_unicode_ci NOT NULL,
  `reported_by` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `status` enum('permitted','warning','disciplinary','resolved') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'warning',
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
) ENGINE=InnoDB AUTO_INCREMENT=101 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `violations`
--

INSERT INTO `violations` (`id`, `case_id`, `student_id`, `violation_type_id`, `violation_level_id`, `department`, `section`, `violation_date`, `violation_time`, `location`, `reported_by`, `notes`, `status`, `attachments`, `created_at`, `updated_at`, `deleted_at`, `is_archived`, `is_read`) VALUES
(97, 'VIOL-2026-001', '2023-0206', 3, 13, 'Bachelor of Science in Information Systems', '12', '2026-03-08', '11:14:00', 'gate_2', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-07 19:15:04', '2026-03-08 03:15:04', NULL, 0, 0),
(98, 'VIOL-2026-002', '2023-0206', 3, 14, 'Bachelor of Science in Information Systems', '12', '2026-03-08', '12:16:00', 'gate_1', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-07 20:16:29', '2026-03-08 04:16:29', NULL, 0, 0),
(99, 'VIOL-2026-003', '2023-0206', 1, 1, 'Bachelor of Science in Information Systems', '12', '2026-03-08', '12:26:00', 'gate_2', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-08 04:27:06', '2026-03-08 04:27:06', NULL, 0, 0),
(100, 'VIOL-2026-004', '2023-0206', 2, 7, 'Bachelor of Science in Information Systems', '12', '2026-03-08', '12:31:00', 'gate_2', 'adminOsas@colegio.edu', NULL, 'permitted', NULL, '2026-03-08 04:31:57', '2026-03-08 04:31:57', NULL, 0, 0);

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
