-- CNCToleQuotation - Schéma de base de données
-- Compatible MariaDB 10.11+ / MySQL 8.0+
-- Encodage : utf8mb4

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS cnctolequotation
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE cnctolequotation;

-- -----------------------------------------------------
-- Table : api_tokens
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS api_tokens (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  token_hash    CHAR(64) NOT NULL UNIQUE,          -- SHA-256
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  rate_limit    INT UNSIGNED NOT NULL DEFAULT 60,  -- req/min
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_used_at  DATETIME NULL,
  INDEX idx_token_hash (token_hash),
  INDEX idx_active (is_active)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Table : materials
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS materials (
  id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code              VARCHAR(50) NOT NULL UNIQUE,   -- ex: AL6061, SS316, S235
  name              VARCHAR(150) NOT NULL,
  category          ENUM('metal','plastic','other') NOT NULL DEFAULT 'metal',
  density_kg_m3     DECIMAL(10,2) NOT NULL,        -- kg/m³
  price_per_kg      DECIMAL(10,4) NOT NULL,        -- €/kg
  machinability     DECIMAL(5,2) NOT NULL DEFAULT 1.0, -- facteur (1.0 = aluminium)
  is_active         TINYINT(1) NOT NULL DEFAULT 1,
  created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Table : config (paramètres globaux)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS config (
  `key`         VARCHAR(100) NOT NULL PRIMARY KEY,
  `value`       TEXT NOT NULL,
  description   VARCHAR(255) NULL,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Table : quotes (historique des cotations)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS quotes (
  id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  uuid                CHAR(36) NOT NULL UNIQUE,
  api_token_id        INT UNSIGNED NULL,
  original_filename   VARCHAR(255) NOT NULL,
  file_hash           CHAR(64) NOT NULL,           -- SHA-256 du fichier
  technology          ENUM('cnc_milling','cnc_turning','sheet_metal') NOT NULL DEFAULT 'cnc_milling',
  material_id         INT UNSIGNED NULL,
  quantity            INT UNSIGNED NOT NULL DEFAULT 1,
  -- Features géométriques
  volume_mm3          DECIMAL(18,3) NULL,
  surface_mm2         DECIMAL(18,3) NULL,
  bbox_x_mm           DECIMAL(12,3) NULL,
  bbox_y_mm           DECIMAL(12,3) NULL,
  bbox_z_mm           DECIMAL(12,3) NULL,
  removed_volume_mm3  DECIMAL(18,3) NULL,
  min_internal_radius_mm DECIMAL(10,4) NULL,
  max_pocket_depth_mm DECIMAL(12,3) NULL,
  face_count          INT UNSIGNED NULL,
  hole_count          INT UNSIGNED NULL,
  estimated_setups    TINYINT UNSIGNED NULL,
  -- Résultats
  estimated_time_min  DECIMAL(10,2) NULL,          -- temps ML
  material_cost       DECIMAL(12,4) NULL,
  machining_cost      DECIMAL(12,4) NULL,
  setup_cost          DECIMAL(12,4) NULL,
  finish_cost         DECIMAL(12,4) NULL,
  unit_price          DECIMAL(12,4) NULL,
  total_price         DECIMAL(12,4) NULL,
  confidence_score    DECIMAL(5,4) NULL,           -- 0.0000 à 1.0000
  dfm_alerts          JSON NULL,
  model_version       VARCHAR(20) NULL,
  status              ENUM('pending','success','error','manual') NOT NULL DEFAULT 'pending',
  error_message       TEXT NULL,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (api_token_id) REFERENCES api_tokens(id) ON DELETE SET NULL,
  FOREIGN KEY (material_id) REFERENCES materials(id) ON DELETE SET NULL,
  INDEX idx_uuid (uuid),
  INDEX idx_created (created_at),
  INDEX idx_status (status)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Table : learning_history (données d'entraînement)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS learning_history (
  id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  quote_id            BIGINT UNSIGNED NULL,        -- lien optionnel vers une cotation
  original_filename   VARCHAR(255) NULL,
  file_hash           CHAR(64) NULL,
  technology          ENUM('cnc_milling','cnc_turning','sheet_metal') NOT NULL,
  material_code       VARCHAR(50) NOT NULL,
  quantity            INT UNSIGNED NOT NULL DEFAULT 1,
  -- Features
  volume_mm3          DECIMAL(18,3) NOT NULL,
  surface_mm2         DECIMAL(18,3) NOT NULL,
  bbox_x_mm           DECIMAL(12,3) NOT NULL,
  bbox_y_mm           DECIMAL(12,3) NOT NULL,
  bbox_z_mm           DECIMAL(12,3) NOT NULL,
  removed_volume_mm3  DECIMAL(18,3) NOT NULL,
  min_internal_radius_mm DECIMAL(10,4) NOT NULL,
  max_pocket_depth_mm DECIMAL(12,3) NOT NULL,
  face_count          INT UNSIGNED NOT NULL,
  hole_count          INT UNSIGNED NOT NULL,
  estimated_setups    TINYINT UNSIGNED NOT NULL,
  -- Valeurs réelles (label)
  real_time_min       DECIMAL(10,2) NOT NULL,      -- temps réel mesuré
  real_unit_price     DECIMAL(12,4) NOT NULL,      -- prix réel facturé
  notes               TEXT NULL,
  is_validated        TINYINT(1) NOT NULL DEFAULT 0,
  created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE SET NULL,
  INDEX idx_validated (is_validated),
  INDEX idx_material (material_code)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Table : ml_models
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS ml_models (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  version         VARCHAR(20) NOT NULL UNIQUE,     -- ex: v1.0.0, v1.1.0
  file_path       VARCHAR(255) NOT NULL,           -- chemin relatif dans data/models/
  algorithm       VARCHAR(50) NOT NULL DEFAULT 'lightgbm',
  train_samples   INT UNSIGNED NOT NULL,
  mae_time        DECIMAL(10,4) NULL,              -- Mean Absolute Error temps
  rmse_time       DECIMAL(10,4) NULL,
  r2_time         DECIMAL(8,6) NULL,
  mae_price       DECIMAL(10,4) NULL,
  rmse_price      DECIMAL(10,4) NULL,
  r2_price        DECIMAL(8,6) NULL,
  is_active       TINYINT(1) NOT NULL DEFAULT 0,
  trained_at      DATETIME NOT NULL,
  notes           TEXT NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_active (is_active)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- Données initiales
-- -----------------------------------------------------

INSERT INTO materials (code, name, category, density_kg_m3, price_per_kg, machinability) VALUES
('AL6061',   'Aluminium 6061-T6',      'metal', 2700.00,  4.50, 1.00),
('AL7075',   'Aluminium 7075-T6',      'metal', 2810.00,  7.80, 0.85),
('S235',     'Acier S235 / A36',       'metal', 7850.00,  1.20, 0.45),
('SS304',    'Inox 304',               'metal', 8000.00,  4.80, 0.30),
('SS316',    'Inox 316L',              'metal', 8000.00,  6.50, 0.25),
('TI6AL4V',  'Titane Ti-6Al-4V',       'metal', 4430.00, 45.00, 0.15),
('POM',      'POM / Delrin',           'plastic', 1410.00, 5.50, 1.20),
('PA6',      'Nylon PA6',              'plastic', 1140.00, 4.20, 1.10),
('PEEK',     'PEEK',                   'plastic', 1320.00, 85.00, 0.60);

INSERT INTO config (`key`, `value`, description) VALUES
('hourly_rate_3axis',     '45.00',  'Taux horaire machine 3 axes (€/h)'),
('hourly_rate_5axis',     '75.00',  'Taux horaire machine 5 axes (€/h)'),
('setup_cost_per_setup',  '25.00',  'Coût fixe par setup (€)'),
('default_margin_pct',    '25.00',  'Marge par défaut (%)'),
('max_upload_size_mb',    '50',     'Taille max fichier upload (Mo)'),
('geometry_timeout_sec',  '120',    'Timeout analyse géométrique (s)'),
('ml_timeout_sec',        '30',     'Timeout prédiction ML (s)'),
('default_model_version', 'v0.1.0', 'Version du modèle ML actif');

-- Token de démonstration (hash SHA-256 de "demo-token-change-me")
-- En production, générer de vrais tokens via l'interface admin
INSERT INTO api_tokens (name, token_hash, is_active) VALUES
('Demo Token', SHA2('demo-token-change-me', 256), 1);

SET FOREIGN_KEY_CHECKS = 1;
