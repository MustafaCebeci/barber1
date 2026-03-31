-- -----------------------------------------------------
-- barber_db2 - Rebuild Script (Consistency-focused)
-- -----------------------------------------------------

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DROP SCHEMA IF EXISTS `barber_db2`;
CREATE SCHEMA IF NOT EXISTS `barber_db2` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `barber_db2`;

-- -----------------------------------------------------
-- admins (platform admins)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `admins` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(50) NOT NULL,
  `email` VARCHAR(255) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_admins_username` (`username`),
  UNIQUE KEY `uq_admins_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- businesses (settings merged here)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `businesses` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `slug` VARCHAR(120) NOT NULL,
  `name` VARCHAR(200) NOT NULL,
  `phone` VARCHAR(30) NULL DEFAULT NULL,
  `address` VARCHAR(500) NULL DEFAULT NULL,
  `city` VARCHAR(80) NULL DEFAULT NULL,
  `district` VARCHAR(80) NULL DEFAULT NULL,
  `description` TEXT NULL DEFAULT NULL,
  `settings_json` JSON NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_businesses_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- branches
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `branches` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_id` BIGINT UNSIGNED NOT NULL,
  `name` VARCHAR(200) NOT NULL,
  `phone` VARCHAR(30) NULL DEFAULT NULL,
  `address` VARCHAR(500) NULL DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_branches_business` (`business_id`),
  UNIQUE KEY `uq_branches_id_business` (`id`, `business_id`),
  CONSTRAINT `fk_branches_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- customers (is_active added)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `customers` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `phone` VARCHAR(20) NOT NULL,
  `display_name` VARCHAR(120) NULL DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_customers_phone` (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- services
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `services` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_id` BIGINT UNSIGNED NOT NULL,
  `name` VARCHAR(200) NOT NULL,
  `duration_minutes` SMALLINT UNSIGNED NOT NULL,
  `price_cents` INT UNSIGNED NULL DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_services_business` (`business_id`),
  UNIQUE KEY `uq_services_id_business` (`id`, `business_id`),
  CONSTRAINT `fk_services_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- staff
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `staff` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_id` BIGINT UNSIGNED NOT NULL,
  `branch_id` BIGINT UNSIGNED NULL DEFAULT NULL,
  `full_name` VARCHAR(200) NOT NULL,
  `phone` VARCHAR(30) NULL DEFAULT NULL,
  `image` VARCHAR(500) NULL DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_staff_business` (`business_id`),
  KEY `idx_staff_branch` (`branch_id`),
  UNIQUE KEY `uq_staff_id_business` (`id`, `business_id`),
  CONSTRAINT `fk_staff_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_staff_branch`
    FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- appointments (service snapshot + composite FKs; branch FK RESTRICT)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `appointments` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_id` BIGINT UNSIGNED NOT NULL,
  `branch_id` BIGINT UNSIGNED NULL DEFAULT NULL,
  `staff_id` BIGINT UNSIGNED NOT NULL,
  `service_id` BIGINT UNSIGNED NOT NULL,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `start_at` DATETIME NOT NULL,
  `end_at` DATETIME NOT NULL,

  `service_name_snapshot` VARCHAR(200) NOT NULL,
  `service_duration_minutes_snapshot` SMALLINT UNSIGNED NOT NULL,
  `service_price_cents_snapshot` INT UNSIGNED NULL DEFAULT NULL,

  `status` ENUM('confirmed','cancelled','no_show','completed') NOT NULL DEFAULT 'confirmed',
  `cancelled_by` ENUM('customer','staff','system') NULL DEFAULT NULL,
  `cancel_reason` VARCHAR(250) NULL DEFAULT NULL,
  `customer_note` VARCHAR(500) NULL DEFAULT NULL,
  `staff_note` VARCHAR(500) NULL DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  `active_lock` TINYINT GENERATED ALWAYS AS (
    (CASE WHEN (`status` = _utf8mb4'confirmed') THEN 1 ELSE NULL END)
  ) STORED,

  PRIMARY KEY (`id`),

  UNIQUE KEY `uq_appt_id_business` (`id`, `business_id`),

  KEY `idx_appt_business_time` (`business_id`, `start_at`),
  KEY `idx_appt_staff_time` (`staff_id`, `start_at`),
  KEY `idx_appt_customer_time` (`customer_id`, `start_at`),

  CONSTRAINT `fk_appt_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_appt_customer`
    FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`)
    ON DELETE RESTRICT,

  CONSTRAINT `fk_appt_staff_business`
    FOREIGN KEY (`staff_id`, `business_id`) REFERENCES `staff` (`id`, `business_id`)
    ON DELETE RESTRICT,

  CONSTRAINT `fk_appt_service_business`
    FOREIGN KEY (`service_id`, `business_id`) REFERENCES `services` (`id`, `business_id`)
    ON DELETE RESTRICT,

  CONSTRAINT `fk_appt_branch_business`
    FOREIGN KEY (`branch_id`, `business_id`) REFERENCES `branches` (`id`, `business_id`)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- appointment_slots (business_id added + composite FKs)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `appointment_slots` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_id` BIGINT UNSIGNED NOT NULL,
  `appointment_id` BIGINT UNSIGNED NOT NULL,
  `staff_id` BIGINT UNSIGNED NOT NULL,
  `slot_time` DATETIME NOT NULL,

  PRIMARY KEY (`id`),

  UNIQUE KEY `uq_staff_slot` (`staff_id`, `slot_time`),
  KEY `idx_slots_appt` (`appointment_id`),
  KEY `idx_slots_business_time` (`business_id`, `slot_time`),

  CONSTRAINT `fk_slots_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_slots_appt_business`
    FOREIGN KEY (`appointment_id`, `business_id`) REFERENCES `appointments` (`id`, `business_id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_slots_staff_business`
    FOREIGN KEY (`staff_id`, `business_id`) REFERENCES `staff` (`id`, `business_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- appointment_status_history
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `appointment_status_history` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `appointment_id` BIGINT UNSIGNED NOT NULL,
  `old_status` ENUM('confirmed','cancelled','no_show','completed') NOT NULL,
  `new_status` ENUM('confirmed','cancelled','no_show','completed') NOT NULL,
  `changed_by` ENUM('customer','staff','system') NOT NULL,
  `note` VARCHAR(250) NULL DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_hist_appt` (`appointment_id`, `created_at`),

  CONSTRAINT `fk_hist_appt`
    FOREIGN KEY (`appointment_id`) REFERENCES `appointments` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- branch_accounts (is_admin bool + composite FKs; staff FK RESTRICT)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `branch_accounts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `branch_id` BIGINT UNSIGNED NOT NULL,
  `staff_id` BIGINT UNSIGNED NULL DEFAULT NULL,
  `business_id` BIGINT UNSIGNED NOT NULL,
  `email` VARCHAR(255) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL,
  `is_admin` TINYINT(1) NOT NULL DEFAULT 0,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `last_login_at` DATETIME NULL DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  UNIQUE KEY `uq_branch_account` (`branch_id`),
  UNIQUE KEY `uq_branch_account_email` (`email`),
  UNIQUE KEY `ux_branch_accounts_staff_id` (`staff_id`),

  KEY `idx_branch_accounts_business` (`business_id`),

  CONSTRAINT `fk_branch_account_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_branch_account_branch_business`
    FOREIGN KEY (`branch_id`, `business_id`) REFERENCES `branches` (`id`, `business_id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_branch_accounts_staff_business`
    FOREIGN KEY (`staff_id`, `business_id`) REFERENCES `staff` (`id`, `business_id`)
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- customer_business_flags
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `customer_business_flags` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_id` BIGINT UNSIGNED NOT NULL,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `no_show_count` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `is_blacklisted` TINYINT(1) NOT NULL DEFAULT 0,
  `blacklisted_at` DATETIME NULL DEFAULT NULL,
  `note` VARCHAR(500) NULL DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  UNIQUE KEY `uq_flags_business_customer` (`business_id`, `customer_id`),
  KEY `idx_flags_blacklist` (`business_id`, `is_blacklisted`),
  KEY `idx_flags_customer` (`customer_id`),

  CONSTRAINT `fk_flags_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_flags_customer`
    FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- otp_codes
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `otp_codes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_type` ENUM('branch_account','customer') NOT NULL,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `channel` ENUM('email','sms') NOT NULL,
  `destination` VARCHAR(190) NOT NULL,
  `code_hash` CHAR(64) NOT NULL,
  `expires_at` DATETIME NOT NULL,
  `used` TINYINT(1) NOT NULL DEFAULT 0,
  `used_at` DATETIME NULL DEFAULT NULL,
  `try_count` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  KEY `idx_user_latest` (`user_type`, `user_id`, `id`),
  KEY `idx_exp` (`expires_at`),
  KEY `idx_used` (`used`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- sms_messages
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `sms_messages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `business_id` BIGINT UNSIGNED NOT NULL,
  `appointment_id` BIGINT UNSIGNED NULL DEFAULT NULL,
  `to_phone` VARCHAR(20) NOT NULL,
  `type` ENUM('reminder','otp','other') NOT NULL DEFAULT 'reminder',
  `body` VARCHAR(800) NOT NULL,
  `provider` VARCHAR(60) NULL DEFAULT NULL,
  `status` ENUM('queued','sent','failed','cancelled') NOT NULL DEFAULT 'queued',
  `provider_msg_id` VARCHAR(120) NULL DEFAULT NULL,
  `error_message` VARCHAR(300) NULL DEFAULT NULL,
  `scheduled_at` DATETIME NOT NULL,
  `sent_at` DATETIME NULL DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  KEY `idx_sms_queue` (`status`, `scheduled_at`),
  KEY `idx_sms_business` (`business_id`, `scheduled_at`),
  KEY `idx_sms_appt` (`appointment_id`),

  CONSTRAINT `fk_sms_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_sms_appt`
    FOREIGN KEY (`appointment_id`) REFERENCES `appointments` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------
-- staff_services (business_id added + composite FKs)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `staff_services` (
  `business_id` BIGINT UNSIGNED NOT NULL,
  `staff_id` BIGINT UNSIGNED NOT NULL,
  `service_id` BIGINT UNSIGNED NOT NULL,

  PRIMARY KEY (`business_id`, `staff_id`, `service_id`),

  KEY `idx_staff_services_service` (`service_id`),

  CONSTRAINT `fk_staff_services_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_staff_services_staff_business`
    FOREIGN KEY (`staff_id`, `business_id`) REFERENCES `staff` (`id`, `business_id`)
    ON DELETE CASCADE,

  CONSTRAINT `fk_staff_services_service_business`
    FOREIGN KEY (`service_id`, `business_id`) REFERENCES `services` (`id`, `business_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -----------------------------------------------------
-- branch_closures (branch closed periods; admin-only managed)
-- Append this to the END of your rebuild script
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `branch_closures` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

  `business_id` BIGINT UNSIGNED NOT NULL,
  `branch_id` BIGINT UNSIGNED NOT NULL,

  `start_at` DATETIME NOT NULL,
  `end_at` DATETIME NOT NULL,

  `is_all_day` TINYINT(1) NOT NULL DEFAULT 1,
  `status` ENUM('active','cancelled') NOT NULL DEFAULT 'active',

  `reason` VARCHAR(250) NULL DEFAULT NULL,
  `note` VARCHAR(500) NULL DEFAULT NULL,

  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),

  -- Lookup/availability checks
  KEY `idx_branch_closures_branch_time` (`branch_id`, `start_at`, `end_at`),
  KEY `idx_branch_closures_business_time` (`business_id`, `start_at`),
  KEY `idx_branch_closures_status` (`status`, `start_at`),

  -- Core tenant FK
  CONSTRAINT `fk_branch_closures_business`
    FOREIGN KEY (`business_id`) REFERENCES `businesses` (`id`)
    ON DELETE CASCADE,

  -- Strong consistency: closure must match branch + business
  CONSTRAINT `fk_branch_closures_branch_business`
    FOREIGN KEY (`branch_id`, `business_id`) REFERENCES `branches` (`id`, `business_id`)
    ON DELETE CASCADE,

  -- basic sanity (MySQL 8+ enforces CHECK; older may parse but not enforce)
  CONSTRAINT `chk_branch_closures_time`
    CHECK (`end_at` > `start_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
