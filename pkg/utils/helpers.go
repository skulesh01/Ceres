package utils

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// ExecuteCommand executes shell command
func ExecuteCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("command failed: %w", err)
	}
	return nil
}

// FileExists checks if file exists
func FileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// DirExists checks if directory exists
func DirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

// GetProjectRoot returns the project root directory
func GetProjectRoot() (string, error) {
	// Look for infrastructure directory as marker
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for {
		if DirExists(filepath.Join(cwd, "infrastructure")) &&
			DirExists(filepath.Join(cwd, "cmd")) {
			return cwd, nil
		}

		parent := filepath.Dir(cwd)
		if parent == cwd {
			break
		}
		cwd = parent
	}

	return "", fmt.Errorf("project root not found")
}

// GetConfigPath returns the configuration file path
func GetConfigPath() string {
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, ".ceres", "config.yaml")
}
