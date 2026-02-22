-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1:3306
-- Generation Time: Feb 22, 2026 at 01:24 PM
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
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `announcements`
--

INSERT INTO `announcements` (`id`, `title`, `message`, `type`, `status`, `created_by`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'System Maintenance', 'The system will undergo maintenance tonight at 10 PM.', '', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 18:03:17', NULL),
(2, 'Enrollment Open', 'Enrollment for the next semester is now open.', 'info', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 18:03:25', NULL),
(3, 'Holiday Notice', 'Classes are suspended due to a public holiday.', 'info', 'active', 2, '2025-12-15 16:25:36', '2025-12-15 18:03:35', NULL),
(4, 'Exam Schedule', 'The final exam schedule has been posted.', '', 'archived', 2, '2025-12-15 16:25:36', '2026-01-08 20:55:52', NULL),
(5, 'Server Downtime', 'Temporary server downtime may occur this weekend.', 'warning', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(6, 'New Policy Update', 'Please review the updated student handbook.', 'info', 'active', 3, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(7, 'Payment Deadline', 'Tuition payment deadline is on Friday.', 'warning', 'active', 3, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(8, 'Library Closed', 'The library will be closed for renovation.', '', 'active', 2, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(9, 'Seminar Announcement', 'A leadership seminar will be held in the auditorium.', '', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(10, 'System Upgrade', 'New system features have been deployed.', 'info', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(11, 'Network Issue', 'Some users may experience network interruptions.', 'warning', '', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(12, 'Sports Fest', 'Annual sports fest starts next week.', '', 'active', 2, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(13, 'ID Registration', 'Student ID registration is ongoing.', 'info', 'active', 3, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(14, 'Class Resumption', 'Classes will resume on Monday.', 'info', 'active', 2, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(15, 'Fire Drill', 'A campus-wide fire drill will be conducted.', '', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(16, 'Parking Advisory', 'Limited parking slots available today.', 'warning', 'active', 3, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(17, 'System Bug Fix', 'Reported bugs have been fixed.', '', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(18, 'Workshop Invite', 'Join the career development workshop.', '', 'active', 2, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(19, 'Account Security', 'Enable two-factor authentication for security.', 'warning', 'active', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL),
(20, 'Announcement Test', 'This is a test announcement record.', 'info', '', 1, '2025-12-15 16:25:36', '2025-12-15 16:25:36', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `dashcontents`
--

DROP TABLE IF EXISTS `dashcontents`;
CREATE TABLE IF NOT EXISTS `dashcontents` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `content_type` enum('tip','guideline','statistic','announcement','widget') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'tip',
  `target_audience` enum('admin','user','both') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'both',
  `status` enum('active','inactive') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active',
  `display_order` int NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `dashcontents_status_index` (`status`),
  KEY `dashcontents_target_audience_index` (`target_audience`),
  KEY `dashcontents_display_order_index` (`display_order`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
(1, 'Computer Science', 'CS', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(2, 'Business Administration', 'BA', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(3, 'Nursing', 'NUR', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(4, 'Bachelor of Science in Information System', 'BSIS', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(5, 'Welding and Fabrication Technology', 'WFT', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(6, 'Bachelor of Technical-Vocational Education and Training', 'BTVTEd', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(7, 'BS Information Technology', 'BSIT', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(8, 'BS Computer Science', 'BSCS', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(9, 'BS Business Administration', 'BSBA', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(10, 'BS Nursing', 'BSN', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(11, 'Bachelor of Elementary Education', 'BEED', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(12, 'Bachelor of Secondary Education', 'BSED', NULL, NULL, 'active', '2025-12-14 09:38:55', NULL, NULL),
(13, 'BSIT', 'IT-001', NULL, NULL, 'active', '2026-02-05 02:56:49', NULL, NULL),
(14, 'BSIT', 'BSIS-1', NULL, NULL, 'active', '2026-02-15 07:08:47', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `email_configs`
--

DROP TABLE IF EXISTS `email_configs`;
CREATE TABLE IF NOT EXISTS `email_configs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `smtp_host` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `smtp_port` int NOT NULL,
  `smtp_username` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `smtp_password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `from_email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `from_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `is_default` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_email_configs_active` (`is_active`),
  KEY `idx_email_configs_default` (`is_default`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `email_configs`
--

INSERT INTO `email_configs` (`id`, `name`, `smtp_host`, `smtp_port`, `smtp_username`, `smtp_password`, `from_email`, `from_name`, `is_active`, `is_default`, `created_at`, `updated_at`) VALUES
(1, 'OSAS Primary Gmail', 'smtp.gmail.com', 587, 'belugaw6@gmail.com', 'chrqrylpqhrtqytl', 'belugaw6@gmail.com', 'OSAS', 1, 1, '2026-02-04 21:42:49', '2026-02-04 21:42:49');

-- --------------------------------------------------------

--
-- Table structure for table `failed_jobs`
--

DROP TABLE IF EXISTS `failed_jobs`;
CREATE TABLE IF NOT EXISTS `failed_jobs` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `connection` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `queue` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `exception` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
CREATE TABLE IF NOT EXISTS `migrations` (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `migrations`
--

INSERT INTO `migrations` (`id`, `migration`, `batch`) VALUES
(1, '2014_10_12_000000_create_users_table', 1),
(2, '2014_10_12_100000_create_password_resets_table', 2),
(3, '2019_08_19_000000_create_failed_jobs_table', 3),
(4, '2019_12_14_000001_create_personal_access_tokens_table', 4),
(5, '2026_01_12_143205_create_departments_table', 5),
(6, '2026_01_12_143215_create_sections_table', 5),
(7, '2026_01_12_143226_create_students_table', 5),
(8, '2026_01_12_143236_create_violations_table', 5),
(9, '2026_01_12_143246_create_announcements_table', 5),
(10, '2026_01_12_143255_create_reports_table', 5),
(11, '2026_01_12_143305_create_dashcontents_table', 5),
(12, '2026_01_12_143325_create_settings_table', 5),
(13, '2026_01_12_143905_add_fields_to_users_table', 5),
(15, '2026_01_12_144409_add_soft_deletes_to_tables', 6),
(16, '2026_01_13_021322_add_custom_fields_to_users_table', 7);

-- --------------------------------------------------------

--
-- Table structure for table `otps`
--

DROP TABLE IF EXISTS `otps`;
CREATE TABLE IF NOT EXISTS `otps` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` varchar(6) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` datetime NOT NULL,
  `used` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `pending_data` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_otps_email` (`email`),
  KEY `idx_otps_code` (`code`),
  KEY `idx_otps_expires` (`expires_at`)
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
-- Table structure for table `personal_access_tokens`
--

DROP TABLE IF EXISTS `personal_access_tokens`;
CREATE TABLE IF NOT EXISTS `personal_access_tokens` (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `tokenable_id` bigint UNSIGNED NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `abilities` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `reports`
--

INSERT INTO `reports` (`id`, `report_id`, `student_id`, `student_name`, `student_contact`, `department`, `department_code`, `section`, `section_id`, `yearlevel`, `uniform_count`, `footwear_count`, `no_id_count`, `total_violations`, `status`, `last_violation_date`, `report_period_start`, `report_period_end`, `generated_at`, `updated_at`, `deleted_at`) VALUES
(4, 'R008', '2023-0195', 'Jumyr Manalo Moreno', '+639099999999', 'Bachelor of Elementary Education', 'BEED', 'BEED-2B', 24, '1st Year', 0, 1, 0, 1, 'permitted', '2026-02-18', '2026-02-18', '2026-02-18', '2026-02-15 12:56:26', '2026-02-20 18:30:40', NULL),
(5, 'R009', '2023-006', 'Patrick Vital Romasanta', '0998913495', 'BS Business Administration', 'BSBA', 'BSBA-1B', 14, '3rd Year', 0, 2, 0, 2, 'permitted', '2026-02-22', '2026-02-18', '2026-02-22', '2026-02-15 12:56:26', '2026-02-22 20:09:08', NULL),
(6, 'R004', '2024-004', 'Anna Marie Rodriguez', '+63 945 678 9012', 'BS Business Administration', 'BSBA', 'BSIT-1A', 1, '1st Year', 0, 1, 0, 1, 'permitted', '2026-02-14', '2026-02-14', '2026-02-14', '2026-02-15 12:56:26', NULL, NULL),
(7, 'R001', '2024-001', 'John Michael Doe', '+63 912 345 6789', 'Bachelor of Elementary Education', 'BEED', 'BEED-1B', 22, '1st Year', 1, 1, 0, 2, 'warning', '2026-02-22', '2026-02-18', '2026-02-22', '2026-02-15 12:56:26', '2026-02-22 20:09:08', NULL);

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
) ENGINE=InnoDB AUTO_INCREMENT=273 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `report_recommendations`
--

INSERT INTO `report_recommendations` (`id`, `report_id`, `recommendation`, `priority`, `created_at`) VALUES
(264, 4, 'Remind student about dress code policies', 'low', '2026-02-22 21:22:39'),
(265, 4, 'Monitor compliance for 2 weeks', 'low', '2026-02-22 21:22:39'),
(266, 5, 'Remind student about dress code policies', 'medium', '2026-02-22 21:22:39'),
(267, 5, 'Monitor compliance for 2 weeks', 'medium', '2026-02-22 21:22:39'),
(268, 6, 'Remind student about dress code policies', 'low', '2026-02-22 21:22:39'),
(269, 6, 'Monitor compliance for 2 weeks', 'low', '2026-02-22 21:22:39'),
(270, 7, 'Issue written warning', 'medium', '2026-02-22 21:22:39'),
(271, 7, 'Monitor uniform compliance', 'medium', '2026-02-22 21:22:39'),
(272, 7, 'Schedule follow-up meeting', 'medium', '2026-02-22 21:22:39');

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
) ENGINE=InnoDB AUTO_INCREMENT=184 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `report_violations`
--

INSERT INTO `report_violations` (`id`, `report_id`, `violation_id`, `violation_type`, `violation_level`, `violation_date`, `violation_time`, `status`, `notes`, `created_at`) VALUES
(179, 4, 82, 'Improper Footwear', 'Permitted 1', '2026-02-18', '12:57:00', 'permitted', 'tulog', '2026-02-22 21:22:39'),
(180, 5, 83, 'Improper Footwear', 'Permitted 1', '2026-02-18', '12:58:00', 'permitted', 'nag lalakad', '2026-02-22 21:22:39'),
(181, 7, 84, 'Improper Footwear', 'Permitted 1', '2026-02-18', '13:10:00', 'permitted', 'm k', '2026-02-22 21:22:39'),
(182, 5, 85, 'Improper Footwear', 'Permitted 2', '2026-02-22', '20:04:00', 'permitted', NULL, '2026-02-22 21:22:39'),
(183, 7, 86, 'Improper Uniform', 'Permitted 1', '2026-02-22', '12:09:00', 'warning', 'Test sync 1771762148', '2026-02-22 21:22:39');

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
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sections`
--

INSERT INTO `sections` (`id`, `section_name`, `section_code`, `department_id`, `academic_year`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, 'BSIT First Year Section A', 'BSIT-1A', 7, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(2, 'BSIT First Year Section B', 'BSIT-1B', 7, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(3, 'BSIT Second Year Section A', 'BSIT-2A', 7, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(4, 'BSIT Second Year Section B', 'BSIT-2B', 7, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(5, 'BSIT Third Year Section A', 'BSIT-3A', 7, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(6, 'BSIT Third Year Section B', 'BSIT-3B', 7, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(7, 'BSIT Fourth Year Section A', 'BSIT-4A', 7, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(8, 'BSIT Fourth Year Section B', 'BSIT-4B', 7, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(9, 'BSCS First Year Section A', 'BSCS-1A', 8, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(10, 'BSCS First Year Section B', 'BSCS-1B', 8, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(11, 'BSCS Second Year Section A', 'BSCS-2A', 8, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(12, 'BSCS Second Year Section B', 'BSCS-2B', 8, '2024-2025', 'active', '2025-12-14 09:38:55', NULL, NULL),
(13, 'BSBA First Year Section A', 'BSBA-1A', 9, '2024-2025', 'archived', '2025-12-14 09:38:56', '2025-12-14 14:19:24', NULL),
(14, 'BSBA First Year Section B', 'BSBA-1B', 9, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(15, 'BSBA Second Year Section A', 'BSBA-2A', 9, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(16, 'BSBA Second Year Section B', 'BSBA-2B', 9, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(17, 'BSN First Year Section A', 'BSN-1A', 10, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(18, 'BSN First Year Section B', 'BSN-1B', 10, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(19, 'BSN Second Year Section A', 'BSN-2A', 10, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(20, 'BSN Second Year Section B', 'BSN-2B', 10, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(21, 'BEED First Year Section A', 'BEED-1A', 11, '2024-2025', 'active', '2025-12-14 09:38:56', '2025-12-16 06:18:21', NULL),
(22, 'BEED First Year Section B', 'BEED-1B', 11, '2024-2025', 'archived', '2025-12-14 09:38:56', '2025-12-15 03:24:29', NULL),
(23, 'BEED Second Year Section A', 'BEED-2A', 11, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(24, 'BEED Second Year Section B', 'BEED-2B', 11, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(25, 'BSED First Year Section A', 'BSED-1A', 12, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(26, 'BSED First Year Section B', 'BSED-1B', 12, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(27, 'BSED Second Year Section A', 'BSED-2A', 12, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(28, 'BSED Second Year Section B', 'BSED-2B', 12, '2024-2025', 'active', '2025-12-14 09:38:56', NULL, NULL),
(29, 'BSIS-1', 'BSIS-1', 14, '2024-2025', 'active', '2026-02-15 07:10:28', NULL, NULL);

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
(36, 'last_monthly_reset', '2026-02', 'string', 'system', 'Last month when the violations were archived', 0, '2026-02-15 11:26:48', NULL);

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
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `students`
--

INSERT INTO `students` (`id`, `student_id`, `first_name`, `middle_name`, `last_name`, `email`, `contact_number`, `address`, `department`, `section_id`, `yearlevel`, `year_level`, `avatar`, `status`, `created_at`, `updated_at`, `deleted_at`) VALUES
(1, '2024-001', 'John', 'Michael', 'Doe', 'john.doe@student.edu', '+63 912 345 6789', '123 Main Street, Quezon City', 'BEED', 22, '1st Year', '1st Year', 'assets/img/students/student_1765729847_693ee637d33c3.png', 'active', '2025-12-14 09:38:56', '2026-01-23 09:52:21', NULL),
(2, '2024-002', 'Maria', 'Clara', 'Santos', 'maria.santos@student.edu', '+63 923 456 7890', '456 Oak Avenue, Manila', 'BSIT', 2, '1st Year', '1st Year', NULL, 'archived', '2025-12-14 09:38:56', '2026-01-23 09:56:14', NULL),
(3, '2024-003', 'Robert', 'James', 'Chen', 'robert.chen@student.edu', '+63 934 567 8901', '789 Pine Road, Makati', 'BEED', 23, NULL, '1st Year', 'app/assets/img/students/student_1765759118_693f588eaae14.jpg', 'archived', '2025-12-14 09:38:56', '2025-12-15 10:03:53', NULL),
(4, '2024-004', 'Anna', 'Marie', 'Rodriguez', 'anna.rodriguez@student.edu', '+63 945 678 9012', '321 Elm Street, Pasig', 'BSBA', 1, '1st Year', '1st Year', NULL, 'active', '2025-12-14 09:38:56', '2026-01-23 09:52:21', NULL),
(5, '2024-005', 'Michael', 'Anthony', 'Garcia', 'michael.garcia@student.edu', '+63 956 789 0123', '654 Maple Drive, Taguig', 'BSIT', 5, NULL, '1st Year', NULL, 'archived', '2025-12-14 09:38:56', '2026-01-08 17:21:10', NULL),
(6, '2023-0206', 'Christian', 'Manalo', 'Moreno', 'morenojumyr0@gmail.com', '+639099999999', 'Street 6', 'BSIT', 4, NULL, '1st Year', 'assets/img/students/student_1765706780_693e8c1c7aec5.jpg', 'archived', '2025-12-14 18:06:20', '2025-12-14 21:57:00', NULL),
(7, '2023-02065', 'Christian', 'Manalo', 'Moreno', 'morenojumyrw0@gmail.com', '+639099999999', 'Street 6', 'BEED', 22, NULL, '1st Year', 'assets/img/students/student_1765724438_693ed11651a2e.webp', 'archived', '2025-12-14 15:00:38', '2025-12-14 15:19:11', NULL),
(8, '2023-0195', 'Jumyr', 'Manalo', 'Moreno', 'morenochristian20051225@gmail.com', '+639099999999', 'Street 6', 'BEED', 24, '1st Year', '1st Year', 'app/assets/img/students/student_1765788746_693fcc4a4ee38.jpg', 'active', '2025-12-15 08:52:26', '2026-01-23 09:52:21', NULL),
(9, '2023-006', 'Patrick', 'Vital', 'Romasanta', 'patrickmontero833@gmail.com', '0998913495', 'San Antnoio Naujan Oriental Mindoro', 'BSBA', 14, '3rd Year', '1st Year', NULL, 'active', '2026-02-05 09:50:20', NULL, NULL),
(10, '2024-0206', 'Patrick', 'Vital', 'Romasanta', 'patric@gmail.com', '09989134594', 'San Antonio', 'BSIS-1', 29, '1st Year', '1st Year', NULL, 'active', '2026-02-15 07:12:15', NULL, NULL);

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
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_users_google_id` (`google_id`(250)),
  KEY `idx_users_facebook_id` (`facebook_id`(250))
) ENGINE=MyISAM AUTO_INCREMENT=2035 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `username`, `email`, `google_id`, `facebook_id`, `profile_picture`, `password`, `role`, `full_name`, `student_id`, `is_active`, `created_at`, `updated_at`) VALUES
(2029, 'admin_demo@colegio.edu', 'ventiletos12@gmail.com', NULL, NULL, 'public/uploads/profile_pictures/7bb7d2f5bddaa424c4149800cd7a0b71.jpeg', '$2y$10$kU9Ogkvn9uNfMntp22rek.DITkCGnFmnsQPvX7z/I8WSbXGwcX6fq', 'admin', 'osas_system cdn', '2023-006', 1, '2026-02-11 00:03:09', '2026-02-22 03:46:32'),
(3, 'student', 'student@example.com', NULL, NULL, NULL, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'user', 'John Doe', '2024-001', 1, '2025-10-14 02:46:08', '2025-10-14 02:46:08'),
(4, 'test_student', 'test@example.com', NULL, NULL, NULL, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'user', 'Jane Smith', '2024-002', 1, '2025-10-14 02:46:08', '2025-10-14 02:46:08'),
(2023, 'jumyr', 'morenojumyr0@gmail.com', NULL, NULL, NULL, '$2y$10$166a7LG0mS7E.HOwr2wqhuuF.PkU8LcVCa3tRuhIZsY7YKqfk3Hau', 'admin', 'Jumyr Moreno', '2023-0195', 1, '2025-10-14 03:21:09', '2025-12-27 00:40:09'),
(2024, 'jumyrrr', 'morenojumfyr0@gmail.com', NULL, NULL, NULL, '$2y$10$mOc68KLw6GdJ7WMsWODp8.E06FHP.09CCrNpZE0e9d7iw7TBti7rS', 'user', 'Christian Moreno', '2023-0206', 1, '2026-01-08 12:27:54', '2026-01-12 11:24:59'),
(2025, 'hihihihi', 'morenojumyr099@gmail.com', NULL, NULL, NULL, '$2y$10$h79f5X6OmqFfq3mOSmwBIe.7jkkdW8RESunP3Pl7t4qpJw63xzUmS', 'user', 'Christian Moreno', '2023-0195', 1, '2026-01-09 03:30:51', '2026-01-12 09:36:41'),
(2028, 'pat', 'patrickmontero@gmail.com', NULL, NULL, NULL, '$2y$10$nJi/snmyWcfFMZ/uIqXEjOGi3iNcFan9BYt49f9O9.A9FiRw4NY5a', 'admin', 'patrick Romasanta', '2024-001', 1, '2026-02-07 13:24:58', '2026-02-07 13:25:19'),
(2030, 'user', 'user@gmail.com', NULL, NULL, NULL, '$2y$10$56B.cIef4Sv26CyqVAZ8Me5mVh0f.dKPVUcIdU8Lfqx5t2Ql8WY/a', 'user', 'osas_system Romasanta', '2024-001', 1, '2026-02-15 05:49:34', '2026-02-15 05:49:34'),
(2031, 'root', 'patrickmontero833@gmail.com', NULL, NULL, NULL, '$2y$10$2UKRKuyEjjwfVT31Fbwmaewj4VvU20wJ7wWyApwqtI7.4pduFK9tG', 'user', 'patrick romasata', '2024-001', 1, '2026-02-18 05:08:56', '2026-02-18 05:08:56');

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
) ENGINE=InnoDB AUTO_INCREMENT=87 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `violations`
--

INSERT INTO `violations` (`id`, `case_id`, `student_id`, `violation_type_id`, `violation_level_id`, `department`, `section`, `violation_date`, `violation_time`, `location`, `reported_by`, `notes`, `status`, `attachments`, `created_at`, `updated_at`, `deleted_at`, `is_archived`, `is_read`) VALUES
(82, 'VIOL-2026-001', '2023-0195', 3, 13, 'Bachelor of Elementary Education', '24', '2026-02-18', '12:57:00', 'gate_1', 'Admin', 'tulog', 'permitted', NULL, '2026-02-17 20:58:36', '2026-02-18 04:58:36', NULL, 0, 0),
(83, 'VIOL-2026-002', '2023-006', 3, 13, 'BS Business Administration', '14', '2026-02-18', '12:58:00', 'gate_2', 'Admin', 'nag lalakad', 'permitted', NULL, '2026-02-17 20:59:02', '2026-02-18 04:59:02', NULL, 0, 0),
(84, 'VIOL-2026-003', '2024-001', 3, 13, 'Bachelor of Elementary Education', '22', '2026-02-18', '13:10:00', 'gate_2', 'mn', 'm k', 'permitted', NULL, '2026-02-17 21:10:33', '2026-02-18 05:10:33', NULL, 0, 0),
(85, 'VIOL-2026-004', '2023-006', 3, 14, 'BS Business Administration', '14', '2026-02-22', '20:04:00', 'gate_1', 'scadasd', NULL, 'permitted', NULL, '2026-02-22 04:04:36', '2026-02-22 12:04:36', NULL, 0, 0),
(86, 'VIOL-2026-005', '2024-001', 1, 1, 'Bachelor of Elementary Education', '22', '2026-02-22', '12:09:00', '', 'Test Script', 'Test sync 1771762148', 'warning', NULL, '2026-02-22 04:09:08', '2026-02-22 12:09:08', NULL, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `violation_history`
--

DROP TABLE IF EXISTS `violation_history`;
CREATE TABLE IF NOT EXISTS `violation_history` (
  `id` int NOT NULL AUTO_INCREMENT,
  `student_violation_level_id` int NOT NULL,
  `student_id` varchar(50) NOT NULL,
  `violation_type` varchar(50) NOT NULL,
  `previous_level` varchar(50) DEFAULT NULL,
  `new_level` varchar(50) NOT NULL,
  `violation_date` date NOT NULL,
  `violation_time` time NOT NULL,
  `location` varchar(50) NOT NULL,
  `reported_by` varchar(100) NOT NULL,
  `notes` text,
  `case_id` varchar(50) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_student_violation_level_id` (`student_violation_level_id`),
  KEY `idx_student_id` (`student_id`),
  KEY `idx_violation_type` (`violation_type`),
  KEY `idx_violation_date` (`violation_date`),
  KEY `idx_case_id` (`case_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

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
-- Constraints for table `violation_history`
--
ALTER TABLE `violation_history`
  ADD CONSTRAINT `fk_violation_history_level_id` FOREIGN KEY (`student_violation_level_id`) REFERENCES `student_violation_levels` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `violation_levels`
--
ALTER TABLE `violation_levels`
  ADD CONSTRAINT `fk_violation_levels_type` FOREIGN KEY (`violation_type_id`) REFERENCES `violation_types` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
