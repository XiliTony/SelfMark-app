CREATE TABLE `plugin` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(50) COLLATE utf8mb4_0900_bin NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `description` VARCHAR(500) NULL,
    `sort` INT NOT NULL DEFAULT 0,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_plugin_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_plugin` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `user_id` BIGINT NOT NULL,
    `plugin_id` BIGINT NOT NULL,
    `config` JSON NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_plugin` (`user_id`, `plugin_id`),
    KEY `idx_user` (`user_id`),
    CONSTRAINT `chk_user_plugin_config_object` CHECK (JSON_TYPE(`config`) = 'OBJECT'),
    CONSTRAINT `chk_user_plugin_enabled` CHECK (`enabled` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
