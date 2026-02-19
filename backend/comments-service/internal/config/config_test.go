
package config

import (
	"os"
	"testing"
)

func TestLoad(t *testing.T) {
	// Set test environment variables
	os.Setenv("APP_NAME", "test-service")
	os.Setenv("DB_HOST", "testdb")
	os.Setenv("DB_PORT", "5555")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Failed to load config: %v", err)
	}

	if cfg.App.Name != "test-service" {
		t.Errorf("Expected app name 'test-service', got '%s'", cfg.App.Name)
	}

	if cfg.Database.Host != "testdb" {
		t.Errorf("Expected db host 'testdb', got '%s'", cfg.Database.Host)
	}

	if cfg.Database.Port != 5555 {
		t.Errorf("Expected db port 5555, got %d", cfg.Database.Port)
	}

	// Clean up
	os.Unsetenv("APP_NAME")
	os.Unsetenv("DB_HOST")
	os.Unsetenv("DB_PORT")
}

func TestDatabaseDSN(t *testing.T) {
	cfg := &Config{
		Database: DatabaseConfig{
			Host:     "localhost",
			Port:     5432,
			User:     "testuser",
			Password: "testpass",
			DBName:   "testdb",
			SSLMode:  "disable",
		},
	}

	expected := "host=localhost port=5432 user=testuser password=testpass dbname=testdb sslmode=disable"
	actual := cfg.DatabaseDSN()

	if actual != expected {
		t.Errorf("Expected DSN '%s', got '%s'", expected, actual)
	}
}
