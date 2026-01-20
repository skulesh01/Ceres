package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Config represents CERES configuration
type Config struct {
	Platform Platform `yaml:"platform"`
	Cloud    Cloud    `yaml:"cloud"`
	Services Services `yaml:"services"`
}

// Platform configuration
type Platform struct {
	Name        string `yaml:"name"`
	Version     string `yaml:"version"`
	Domain      string `yaml:"domain"`
	Environment string `yaml:"environment"`
}

// Cloud configuration
type Cloud struct {
	Provider string `yaml:"provider"` // aws, azure, gcp
	Region   string `yaml:"region"`
	Project  string `yaml:"project"`
}

// Services configuration
type Services struct {
	PostgreSQL PostgreSQL `yaml:"postgresql"`
	Redis      Redis      `yaml:"redis"`
	Keycloak   Service    `yaml:"keycloak"`
	GitLab     Service    `yaml:"gitlab"`
}

// PostgreSQL configuration
type PostgreSQL struct {
	Enabled  bool   `yaml:"enabled"`
	Version  string `yaml:"version"`
	Database string `yaml:"database"`
}

// Redis configuration
type Redis struct {
	Enabled bool   `yaml:"enabled"`
	Version string `yaml:"version"`
}

// Service generic configuration
type Service struct {
	Enabled bool   `yaml:"enabled"`
	Replicas int   `yaml:"replicas"`
}

// DefaultConfig returns default CERES configuration
func DefaultConfig() Config {
	return Config{
		Platform: Platform{
			Name:        "CERES",
			Version:     "3.0.0",
			Domain:      "ceres.local",
			Environment: "production",
		},
		Cloud: Cloud{
			Provider: "aws",
			Region:   "eu-west-1",
		},
		Services: Services{
			PostgreSQL: PostgreSQL{
				Enabled:  true,
				Version:  "16",
				Database: "ceres",
			},
			Redis: Redis{
				Enabled: true,
				Version: "7.0",
			},
			Keycloak: Service{
				Enabled:  true,
				Replicas: 3,
			},
			GitLab: Service{
				Enabled:  true,
				Replicas: 1,
			},
		},
	}
}

// LoadConfig loads configuration from file
func LoadConfig(path string) (Config, error) {
	config := DefaultConfig()

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			// Return default config if file doesn't exist
			return config, nil
		}
		return config, fmt.Errorf("failed to read config file: %w", err)
	}

	if err := yaml.Unmarshal(data, &config); err != nil {
		return config, fmt.Errorf("failed to parse config file: %w", err)
	}

	return config, nil
}

// SaveConfig saves configuration to file
func (c *Config) SaveConfig(path string) error {
	// Ensure directory exists
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Marshal config to YAML
	data, err := yaml.Marshal(c)
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	// Write to file
	if err := os.WriteFile(path, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// Validate validates configuration
func (c *Config) Validate() error {
	if c.Platform.Name == "" {
		return fmt.Errorf("platform name is required")
	}
	if c.Platform.Domain == "" {
		return fmt.Errorf("platform domain is required")
	}
	if c.Cloud.Provider == "" {
		return fmt.Errorf("cloud provider is required")
	}
	if c.Cloud.Region == "" {
		return fmt.Errorf("cloud region is required")
	}
	return nil
}
