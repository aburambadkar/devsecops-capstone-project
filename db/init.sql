CREATE DATABASE IF NOT EXISTS inventory;
USE inventory;

CREATE TABLE IF NOT EXISTS tools (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(255) NOT NULL
);

INSERT INTO tools (name, category) VALUES ('Docker', 'Containerization');
INSERT INTO tools (name, category) VALUES ('GitHub Actions', 'CI/CD');
INSERT INTO tools (name, category) VALUES ('Trivy', 'Security');
