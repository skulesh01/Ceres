package onboarding

import (
	"bytes"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"strings"
	"time"
)

type KeycloakClient struct {
	baseURL      string
	realm        string
	adminRealm   string
	adminUser    string
	adminPass    string
	httpClient   *http.Client
	accessToken  string
	tokenExpires time.Time
}

type KeycloakUser struct {
	ID              string              `json:"id,omitempty"`
	Username        string              `json:"username"`
	Enabled         bool                `json:"enabled"`
	Email           string              `json:"email,omitempty"`
	EmailVerified   bool                `json:"emailVerified,omitempty"`
	FirstName       string              `json:"firstName,omitempty"`
	LastName        string              `json:"lastName,omitempty"`
	RequiredActions []string            `json:"requiredActions,omitempty"`
	Attributes      map[string][]string `json:"attributes,omitempty"`
}

func NewKeycloakClient(baseURL, realm, adminUser, adminPass string, insecureTLS bool) *KeycloakClient {
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.TLSClientConfig = &tls.Config{InsecureSkipVerify: insecureTLS}

	return &KeycloakClient{
		baseURL:    strings.TrimRight(baseURL, "/"),
		realm:      realm,
		adminRealm: "master",
		adminUser:  adminUser,
		adminPass:  adminPass,
		httpClient: &http.Client{Transport: transport, Timeout: 30 * time.Second},
	}
}

func (c *KeycloakClient) ensureToken() error {
	if c.accessToken != "" && time.Now().Before(c.tokenExpires.Add(-30*time.Second)) {
		return nil
	}

	tokenURL := fmt.Sprintf("%s/realms/%s/protocol/openid-connect/token", c.baseURL, c.adminRealm)
	form := url.Values{}
	form.Set("grant_type", "password")
	form.Set("client_id", "admin-cli")
	form.Set("username", c.adminUser)
	form.Set("password", c.adminPass)

	req, err := http.NewRequest(http.MethodPost, tokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("keycloak token request failed: %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return fmt.Errorf("failed to parse token response: %w", err)
	}
	if tokenResp.AccessToken == "" {
		return errors.New("keycloak token response missing access_token")
	}

	c.accessToken = tokenResp.AccessToken
	c.tokenExpires = time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second)
	return nil
}

func (c *KeycloakClient) doJSON(method, urlStr string, requestBody any, responseBody any) error {
	if err := c.ensureToken(); err != nil {
		return err
	}

	var bodyReader io.Reader
	if requestBody != nil {
		b, err := json.Marshal(requestBody)
		if err != nil {
			return err
		}
		bodyReader = bytes.NewReader(b)
	}

	req, err := http.NewRequest(method, urlStr, bodyReader)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.accessToken)
	if requestBody != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	respBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("keycloak request failed: %s: %s", resp.Status, strings.TrimSpace(string(respBytes)))
	}

	if responseBody != nil && len(respBytes) > 0 {
		if err := json.Unmarshal(respBytes, responseBody); err != nil {
			return fmt.Errorf("failed to decode response: %w", err)
		}
	}

	return nil
}

func (c *KeycloakClient) FindUserByUsername(username string) (*KeycloakUser, error) {
	query := url.Values{}
	query.Set("username", username)
	query.Set("exact", "true")
	listURL := fmt.Sprintf("%s/admin/realms/%s/users?%s", c.baseURL, c.realm, query.Encode())

	var users []KeycloakUser
	if err := c.doJSON(http.MethodGet, listURL, nil, &users); err != nil {
		return nil, err
	}
	if len(users) == 0 {
		return nil, nil
	}
	return &users[0], nil
}

func (c *KeycloakClient) CreateUser(user KeycloakUser) (string, error) {
	createURL := fmt.Sprintf("%s/admin/realms/%s/users", c.baseURL, c.realm)

	if err := c.ensureToken(); err != nil {
		return "", err
	}

	b, err := json.Marshal(user)
	if err != nil {
		return "", err
	}
	req, err := http.NewRequest(http.MethodPost, createURL, bytes.NewReader(b))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+c.accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBytes, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusCreated {
		return "", fmt.Errorf("keycloak create user failed: %s: %s", resp.Status, strings.TrimSpace(string(respBytes)))
	}

	location := resp.Header.Get("Location")
	if location == "" {
		// Some deployments omit Location; fall back to lookup.
		created, err := c.FindUserByUsername(user.Username)
		if err != nil {
			return "", err
		}
		if created == nil || created.ID == "" {
			return "", errors.New("user created but id not retrievable")
		}
		return created.ID, nil
	}

	parts := strings.Split(strings.TrimRight(location, "/"), "/")
	return parts[len(parts)-1], nil
}

func (c *KeycloakClient) SendExecuteActionsEmail(userID string, actions []string, redirectURI string, lifespanSeconds int) error {
	if len(actions) == 0 {
		return errors.New("actions must not be empty")
	}

	endpoint := fmt.Sprintf("%s/admin/realms/%s/users/%s/execute-actions-email", c.baseURL, c.realm, userID)
	query := url.Values{}
	if redirectURI != "" {
		query.Set("redirect_uri", redirectURI)
	}
	if lifespanSeconds > 0 {
		query.Set("lifespan", fmt.Sprintf("%d", lifespanSeconds))
	}
	if encoded := query.Encode(); encoded != "" {
		endpoint += "?" + encoded
	}

	return c.doJSON(http.MethodPut, endpoint, actions, nil)
}


func getK8sSecretValue(namespace, name, key string) (string, error) {
	// Reads a secret key value using kubectl.
	// Expected to run from an admin host where kubectl is configured.
	jsonPath := fmt.Sprintf("jsonpath={.data.%s}", key)
	cmd := exec.Command("kubectl", "get", "secret", name, "-n", namespace, "-o", jsonPath)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("kubectl get secret %s/%s failed: %w\n%s", namespace, name, err, strings.TrimSpace(string(out)))
	}
	enc := strings.TrimSpace(string(out))
	if enc == "" {
		return "", fmt.Errorf("secret %s/%s key %s is empty", namespace, name, key)
	}
	b, err := base64.StdEncoding.DecodeString(enc)
	if err != nil {
		return "", fmt.Errorf("failed to base64-decode secret %s/%s key %s: %w", namespace, name, key, err)
	}
	return string(b), nil
}

func DefaultKeycloakAdminCreds() (adminUser, adminPass string, err error) {
	adminUser = strings.TrimSpace(os.Getenv("CERES_KEYCLOAK_ADMIN"))
	if adminUser == "" {
		adminUser = "admin"
	}
	adminPass = strings.TrimSpace(os.Getenv("CERES_KEYCLOAK_ADMIN_PASSWORD"))
	if adminPass == "" {
		adminPass = strings.TrimSpace(os.Getenv("KEYCLOAK_ADMIN_PASSWORD"))
	}
	if adminPass == "" {
		// Best-effort: read from k8s secret used by our manifests.
		adminPass, err = getK8sSecretValue("ceres", "keycloak-secret", "admin-password")
		if err != nil {
			return adminUser, "", fmt.Errorf("keycloak admin password not provided; set CERES_KEYCLOAK_ADMIN_PASSWORD or ensure secret ceres/keycloak-secret exists: %w", err)
		}
	}
	return adminUser, adminPass, nil
}
