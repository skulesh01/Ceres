package config

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// LoadInstanceEnv reads a simple KEY=VALUE env file (like /etc/ceres/ceres.env).
// It supports:
// - blank lines
// - comments starting with '#'
// - optional leading 'export '
// - values optionally wrapped in single/double quotes
func LoadInstanceEnv(path string) (map[string]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open env file: %w", err)
	}
	defer f.Close()

	vars := make(map[string]string)
	s := bufio.NewScanner(f)
	for s.Scan() {
		line := strings.TrimSpace(s.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		line = strings.TrimSpace(strings.TrimPrefix(line, "export "))
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		val = strings.TrimSpace(val)
		if key == "" {
			continue
		}

		// Strip matching quotes
		if len(val) >= 2 {
			if (val[0] == '"' && val[len(val)-1] == '"') || (val[0] == '\'' && val[len(val)-1] == '\'') {
				val = val[1 : len(val)-1]
			}
		}

		vars[key] = val
	}
	if err := s.Err(); err != nil {
		return nil, fmt.Errorf("scan env file: %w", err)
	}
	return vars, nil
}
