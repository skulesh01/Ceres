package helm

import (
	"fmt"
	"os/exec"
	"strings"
)

// Client represents Helm client
type Client struct {
	namespace string
}

// NewClient creates new Helm client
func NewClient(namespace string) *Client {
	return &Client{
		namespace: namespace,
	}
}

// AddRepo adds a Helm repository
func (c *Client) AddRepo(name, url string) error {
	cmd := exec.Command("helm", "repo", "add", name, url)
	output, err := cmd.CombinedOutput()
	if err != nil {
		if strings.Contains(string(output), "already exists") {
			fmt.Printf("  ✓ Repo %s already exists\n", name)
			return nil
		}
		return fmt.Errorf("failed to add repo: %w\nOutput: %s", err, string(output))
	}
	fmt.Printf("  ✓ Repo %s added\n", name)
	return nil
}

// UpdateRepos updates all Helm repositories
func (c *Client) UpdateRepos() error {
	cmd := exec.Command("helm", "repo", "update")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to update repos: %w\nOutput: %s", err, string(output))
	}
	fmt.Println("  ✓ Repositories updated")
	return nil
}

// InstallChart installs a Helm chart
func (c *Client) InstallChart(release, chart string, values map[string]string) error {
	args := []string{"install", release, chart, "-n", c.namespace, "--create-namespace"}
	
	for key, val := range values {
		args = append(args, "--set", fmt.Sprintf("%s=%s", key, val))
	}

	cmd := exec.Command("helm", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		if strings.Contains(string(output), "already exists") {
			fmt.Printf("  ✓ Release %s already exists\n", release)
			return nil
		}
		return fmt.Errorf("failed to install chart: %w\nOutput: %s", err, string(output))
	}
	fmt.Printf("  ✓ %s installed\n", release)
	return nil
}

// UpgradeChart upgrades a Helm chart
func (c *Client) UpgradeChart(release, chart string, values map[string]string) error {
	args := []string{"upgrade", "--install", release, chart, "-n", c.namespace}
	
	for key, val := range values {
		args = append(args, "--set", fmt.Sprintf("%s=%s", key, val))
	}

	cmd := exec.Command("helm", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to upgrade chart: %w\nOutput: %s", err, string(output))
	}
	fmt.Printf("  ✓ %s upgraded\n", release)
	return nil
}

// UninstallChart uninstalls a Helm chart
func (c *Client) UninstallChart(release string) error {
	cmd := exec.Command("helm", "uninstall", release, "-n", c.namespace)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to uninstall chart: %w\nOutput: %s", err, string(output))
	}
	fmt.Printf("  ✓ %s uninstalled\n", release)
	return nil
}

// ListReleases lists all Helm releases
func (c *Client) ListReleases() ([]Release, error) {
	cmd := exec.Command("helm", "list", "-n", c.namespace, "-o", "json")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("failed to list releases: %w\nOutput: %s", err, string(output))
	}

	// For now, return mock data
	// TODO: Parse JSON output
	releases := []Release{
		{Name: "postgresql", Chart: "bitnami/postgresql", Status: "deployed"},
		{Name: "redis", Chart: "bitnami/redis", Status: "deployed"},
	}
	return releases, nil
}

// Release represents a Helm release
type Release struct {
	Name   string
	Chart  string
	Status string
}
