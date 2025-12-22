<?php
/**
 * Database Backup Script for Laravel Docker
 * Creates SQL dump using PHP PDO
 */

// Get environment variables
$host = getenv('DB_HOST') ?: 'mysql';
$database = getenv('DB_DATABASE') ?: 'laravel';
$username = getenv('DB_USERNAME') ?: 'laravel';
$password = getenv('DB_PASSWORD') ?: 'secret';
$backupDir = '/var/www/backups';

// Get output file from argument or generate
$outputFile = $argv[1] ?? $backupDir . '/backup_' . date('Ymd_His') . '.sql';

try {
    // Connect to database
    $pdo = new PDO(
        "mysql:host=$host;dbname=$database;charset=utf8mb4",
        $username,
        $password,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::MYSQL_ATTR_USE_BUFFERED_QUERY => false
        ]
    );

    // Open output file
    $fp = fopen($outputFile, 'w');
    if (!$fp) {
        throw new Exception("Cannot open output file: $outputFile");
    }

    // Write header
    fwrite($fp, "-- MySQL Backup\n");
    fwrite($fp, "-- Generated: " . date('Y-m-d H:i:s') . "\n");
    fwrite($fp, "-- Database: $database\n");
    fwrite($fp, "-- --------------------------------------------------------\n\n");
    fwrite($fp, "SET FOREIGN_KEY_CHECKS=0;\n");
    fwrite($fp, "SET SQL_MODE='NO_AUTO_VALUE_ON_ZERO';\n");
    fwrite($fp, "SET AUTOCOMMIT=0;\n");
    fwrite($fp, "START TRANSACTION;\n\n");

    // Get all tables
    $tables = $pdo->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);

    foreach ($tables as $table) {
        echo "Backing up table: $table\n";
        
        // Drop table statement
        fwrite($fp, "DROP TABLE IF EXISTS `$table`;\n");
        
        // Create table statement
        $createTable = $pdo->query("SHOW CREATE TABLE `$table`")->fetch(PDO::FETCH_ASSOC);
        fwrite($fp, $createTable['Create Table'] . ";\n\n");
        
        // Get row count
        $count = $pdo->query("SELECT COUNT(*) FROM `$table`")->fetchColumn();
        
        if ($count > 0) {
            // Get columns
            $columns = $pdo->query("SHOW COLUMNS FROM `$table`")->fetchAll(PDO::FETCH_COLUMN);
            $columnList = '`' . implode('`, `', $columns) . '`';
            
            // Fetch data in chunks to handle large tables
            $chunkSize = 1000;
            $offset = 0;
            
            while ($offset < $count) {
                $rows = $pdo->query("SELECT * FROM `$table` LIMIT $chunkSize OFFSET $offset")->fetchAll(PDO::FETCH_ASSOC);
                
                if (empty($rows)) break;
                
                $values = [];
                foreach ($rows as $row) {
                    $rowValues = array_map(function($value) use ($pdo) {
                        if ($value === null) return 'NULL';
                        return $pdo->quote($value);
                    }, array_values($row));
                    $values[] = '(' . implode(', ', $rowValues) . ')';
                }
                
                if (!empty($values)) {
                    fwrite($fp, "INSERT INTO `$table` ($columnList) VALUES\n");
                    fwrite($fp, implode(",\n", $values) . ";\n\n");
                }
                
                $offset += $chunkSize;
            }
        }
    }

    // Write footer
    fwrite($fp, "SET FOREIGN_KEY_CHECKS=1;\n");
    fwrite($fp, "COMMIT;\n");
    
    fclose($fp);
    
    $size = filesize($outputFile);
    $sizeFormatted = $size > 1024*1024 
        ? round($size / (1024*1024), 2) . ' MB' 
        : round($size / 1024, 2) . ' KB';
    
    echo "Backup completed: $outputFile ($sizeFormatted)\n";
    exit(0);
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
