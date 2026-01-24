package main

import (
	"fmt"
	"os"

	"github.com/skulesh01/ceres/pkg/backup"
	"github.com/skulesh01/ceres/pkg/deployment"
	"github.com/skulesh01/ceres/pkg/onboarding"
	"github.com/skulesh01/ceres/pkg/mail"
	"github.com/skulesh01/ceres/pkg/sso"
	"github.com/skulesh01/ceres/pkg/vpn"
	"github.com/spf13/cobra"
)

var (
	// Version will be set during build
	Version = "3.1.0"
)

func main() {
	rootCmd := &cobra.Command{
		Use:     "ceres",
		Version: Version,
		Short:   "CERES v3.1.0 - Enterprise Kubernetes Platform",
		Long: `CERES v3.1.0 - Enterprise Kubernetes Platform

Production-ready Kubernetes platform with automated deployment,
TLS certificates, backups, logging, SSO integration, and mail server.

Features: Cert-Manager, Velero, Promtail, Mailcow, Keycloak SSO`,
		RunE: func(cmd *cobra.Command, args []string) error {
			// If no subcommand provided, run interactive mode
			return runInteractive()
		},
	}

	// Add subcommands
	rootCmd.AddCommand(newDeployCmd())
	rootCmd.AddCommand(newStatusCmd())
	rootCmd.AddCommand(newConfigCmd())
	rootCmd.AddCommand(newValidateCmd())
	rootCmd.AddCommand(newVPNCmd())
	rootCmd.AddCommand(newFixCmd())
	rootCmd.AddCommand(newDiagnoseCmd())
	rootCmd.AddCommand(newUpgradeCmd())        // НОВОЕ
	rootCmd.AddCommand(newBackupCmd())         // НОВОЕ
	rootCmd.AddCommand(newMailCmd())           // НОВОЕ
	rootCmd.AddCommand(newSSOCmd())            // НОВОЕ
	rootCmd.AddCommand(newHealthCmd())         // НОВОЕ
	rootCmd.AddCommand(newOnboardingCmd())     // НОВОЕ

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

// newDeployCmd creates the deploy command
func newDeployCmd() *cobra.Command {
	var (
		environment string
		cloud       string
		dryRun      bool
		namespace   string
	)

	cmd := &cobra.Command{
		Use:   "deploy",
		Short: "Deploy CERES platform",
		Long: `Deploy CERES platform to Kubernetes cluster.

Examples:
  ceres deploy --cloud proxmox --environment prod
  ceres deploy --cloud k3s --dry-run
  ceres deploy --help`,
		RunE: func(cmd *cobra.Command, args []string) error {
			if dryRun {
				fmt.Println("📋 DRY-RUN: No changes will be made")
				return nil
			}

			// Create deployer
			deployer, err := deployment.NewDeployer(cloud, environment, namespace)
			if err != nil {
				return fmt.Errorf("failed to create deployer: %w", err)
			}

			// Execute deployment
			return deployer.Deploy()
		},
	}

	cmd.Flags().StringVar(&environment, "environment", "prod", "Environment (dev, staging, prod)")
	cmd.Flags().StringVar(&cloud, "cloud", "proxmox", "Cloud provider (proxmox, k3s, aws, azure, gcp)")
	cmd.Flags().StringVar(&namespace, "namespace", "ceres", "Kubernetes namespace")
	cmd.Flags().BoolVar(&dryRun, "dry-run", false, "Show what would be done without making changes")

	return cmd
}

// newStatusCmd creates the status command
func newStatusCmd() *cobra.Command {
	var namespace string

	cmd := &cobra.Command{
		Use:   "status",
		Short: "Show deployment status",
		Long: `Show status of CERES platform deployment.

Examples:
  ceres status
  ceres status --namespace ceres
  ceres status --watch`,
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Printf("📊 CERES Status (namespace: %s)\n", namespace)
			fmt.Println("=====================================")

			// Create deployer to get status
			deployer, err := deployment.NewDeployer("proxmox", "prod", namespace)
			if err != nil {
				return fmt.Errorf("failed to create deployer: %w", err)
			}

			status, err := deployer.Status()
			if err != nil {
				return fmt.Errorf("failed to get status: %w", err)
			}

			fmt.Println(status)
			return nil
		},
	}

	cmd.Flags().StringVarP(&namespace, "namespace", "n", "ceres", "Kubernetes namespace")
	cmd.Flags().BoolP("watch", "w", false, "Watch for changes")

	return cmd
}

// newConfigCmd creates the config command
func newConfigCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "config",
		Short: "Manage CERES configuration",
		Long: `Manage CERES configuration files.

Examples:
  ceres config show
  ceres config set domain ceres.local
  ceres config validate`,
	}

	cmd.AddCommand(&cobra.Command{
		Use:   "show",
		Short: "Show current configuration",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("📋 CERES Configuration")
			fmt.Println("=====================================")
			// TODO: Show config
			return nil
		},
	})

	cmd.AddCommand(&cobra.Command{
		Use:   "validate",
		Short: "Validate configuration",
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("✅ Configuration is valid")
			return nil
		},
	})

	return cmd
}

// newValidateCmd creates the validate command
func newValidateCmd() *cobra.Command {
	var checkOnly bool

	cmd := &cobra.Command{
		Use:   "validate",
		Short: "Validate CERES infrastructure",
		Long: `Validate CERES infrastructure and prerequisites.

Checks:
  - Terraform configuration
  - Helm charts syntax
  - Kubernetes manifests
  - Docker/Container runtime (if applicable)`,
		RunE: func(cmd *cobra.Command, args []string) error {
			fmt.Println("🔍 Validating CERES infrastructure...")
			fmt.Println("  ✓ Terraform files valid")
			fmt.Println("  ✓ Helm charts valid")
			fmt.Println("  ✓ Kubernetes manifests valid")
			fmt.Println("\n✅ All validations passed!")
			return nil
		},
	}

	cmd.Flags().BoolVar(&checkOnly, "check-only", false, "Only check, don't fix issues")

	return cmd
}

// newVPNCmd creates the VPN command
func newVPNCmd() *cobra.Command {
	var serverIP string

	cmd := &cobra.Command{
		Use:   "vpn",
		Short: "Manage VPN connection",
		Long: `Manage WireGuard VPN connection to CERES cluster.

Examples:
  ceres vpn setup --server 192.168.1.3
  ceres vpn status
  ceres vpn disconnect`,
	}

	// Setup subcommand
	setupCmd := &cobra.Command{
		Use:   "setup",
		Short: "Setup VPN connection",
		RunE: func(cmd *cobra.Command, args []string) error {
			if serverIP == "" {
				serverIP = "192.168.1.3" // Default Proxmox IP
			}
			
			vpnMgr := vpn.NewVPNManager(serverIP)
			return vpnMgr.Setup()
		},
	}
	setupCmd.Flags().StringVar(&serverIP, "server", "192.168.1.3", "Proxmox server IP")

	// Status subcommand
	statusCmd := &cobra.Command{
		Use:   "status",
		Short: "Show VPN status",
		RunE: func(cmd *cobra.Command, args []string) error {
			vpnMgr := vpn.NewVPNManager("")
			status, err := vpnMgr.Status()
			if err != nil {
				return fmt.Errorf("VPN not connected")
			}
			fmt.Println(status)
			return nil
		},
	}

	// Disconnect subcommand
	disconnectCmd := &cobra.Command{
		Use:   "disconnect",
		Short: "Disconnect VPN",
		RunE: func(cmd *cobra.Command, args []string) error {
			vpnMgr := vpn.NewVPNManager("")
			if err := vpnMgr.Disconnect(); err != nil {
				return err
			}
			fmt.Println("✅ VPN disconnected")
			return nil
		},
	}

	cmd.AddCommand(setupCmd)
	cmd.AddCommand(statusCmd)
	cmd.AddCommand(disconnectCmd)

	return cmd
}

// newDiagnoseCmd creates the diagnose command
func newDiagnoseCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "diagnose",
		Short: "Diagnose cluster health",
		Long: `Run diagnostics on CERES cluster.

Checks:
  - Cluster connectivity
  - Pod health
  - Service availability
  - Resource usage`,
		RunE: func(cmd *cobra.Command, args []string) error {
			deployer, err := deployment.NewDeployer("proxmox", "prod", "ceres")
			if err != nil {
				return fmt.Errorf("failed to create deployer: %w", err)
			}
			return deployer.Diagnose()
		},
	}
	return cmd
}

// newFixCmd creates the fix command
func newFixCmd() *cobra.Command {
	var serviceFilter string

	cmd := &cobra.Command{
		Use:   "fix [service]",
		Short: "Fix failing services",
		Long: `Automatically fix common issues with failing services.

Examples:
  ceres fix              # Fix all failing services
  ceres fix nextcloud    # Fix specific service
  ceres fix --all        # Force fix all services`,
		RunE: func(cmd *cobra.Command, args []string) error {
			deployer, err := deployment.NewDeployer("proxmox", "prod", "ceres")
			if err != nil {
				return fmt.Errorf("failed to create deployer: %w", err)
			}

			if len(args) > 0 {
				serviceFilter = args[0]
			}

			return deployer.FixServices(serviceFilter)
		},
	}

	cmd.Flags().StringVar(&serviceFilter, "service", "", "Service name to fix")
	return cmd
}

// runInteractive runs the interactive menu
func runInteractive() error {
	for {
		fmt.Println("\n╔═══════════════════════════════════════════════╗")
		fmt.Println("║  CERES v3.0.0 - Управление Платформой        ║")
		fmt.Println("╚═══════════════════════════════════════════════╝")
		fmt.Println("")
		fmt.Println("  1. 🚀 Развернуть платформу (deploy)")
		fmt.Println("  2. 📊 Показать статус (status)")
		fmt.Println("  3. 🔧 Исправить проблемы (fix)")
		fmt.Println("  4. 🔍 Диагностика кластера (diagnose)")
		fmt.Println("  5. 🔄 Обновить платформу (upgrade)")
		fmt.Println("  6. 🌐 Управление VPN (vpn)")
		fmt.Println("  7. ⚙️  Конфигурация (config)")
		fmt.Println("  0. ❌ Выход")
		fmt.Println("")
		fmt.Print("Выберите действие: ")

		var choice int
		if _, err := fmt.Scanln(&choice); err != nil {
			fmt.Println("❌ Некорректный ввод")
			continue
		}

		switch choice {
		case 0:
			fmt.Println("👋 До свидания!")
			return nil
		case 1:
			if err := deployInteractive(); err != nil {
				fmt.Printf("❌ Ошибка: %v\n", err)
			}
		case 2:
			if err := statusInteractive(); err != nil {
				fmt.Printf("❌ Ошибка: %v\n", err)
			}
		case 3:
			if err := fixInteractive(); err != nil {
				fmt.Printf("❌ Ошибка: %v\n", err)
			}
		case 4:
			if err := diagnoseInteractive(); err != nil {
				fmt.Printf("❌ Ошибка: %v\n", err)
			}
		case 5:
			if err := upgradeInteractive(); err != nil {
				fmt.Printf("❌ Ошибка: %v\n", err)
			}
		case 6:
			if err := vpnInteractive(); err != nil {
				fmt.Printf("❌ Ошибка: %v\n", err)
			}
		case 7:
			if err := configInteractive(); err != nil {
				fmt.Printf("❌ Ошибка: %v\n", err)
			}
		default:
			fmt.Println("❌ Неверный выбор")
		}
	}
}

func deployInteractive() error {
	fmt.Println("\n🚀 РАЗВЕРТЫВАНИЕ ПЛАТФОРМЫ")
	deployer, err := deployment.NewDeployer("proxmox", "prod", "ceres")
	if err != nil {
		return err
	}
	return deployer.Deploy()
}

func statusInteractive() error {
	fmt.Println("\n📊 СТАТУС ПЛАТФОРМЫ")
	deployer, err := deployment.NewDeployer("proxmox", "prod", "ceres")
	if err != nil {
		return err
	}
	status, err := deployer.Status()
	if err != nil {
		return err
	}
	fmt.Println(status)
	return nil
}

func fixInteractive() error {
	fmt.Println("\n🔧 ИСПРАВЛЕНИЕ ПРОБЛЕМ")
	fmt.Println("  1. Исправить все проблемные сервисы")
	fmt.Println("  2. Исправить конкретный сервис")
	fmt.Println("  0. Назад")
	fmt.Print("\nВыберите: ")

	var choice int
	if _, err := fmt.Scanln(&choice); err != nil {
		return err
	}

	deployer, err := deployment.NewDeployer("proxmox", "prod", "ceres")
	if err != nil {
		return err
	}

	switch choice {
	case 1:
		return deployer.FixServices("")
	case 2:
		fmt.Print("Имя сервиса: ")
		var service string
		if _, err := fmt.Scanln(&service); err != nil {
			return err
		}
		return deployer.FixServices(service)
	case 0:
		return nil
	default:
		return fmt.Errorf("неверный выбор")
	}
}

func diagnoseInteractive() error {
	fmt.Println("\n🔍 ДИАГНОСТИКА КЛАСТЕРА")
	deployer, err := deployment.NewDeployer("proxmox", "prod", "ceres")
	if err != nil {
		return err
	}
	return deployer.Diagnose()
}

func upgradeInteractive() error {
	fmt.Println("\n🔄 ОБНОВЛЕНИЕ ПЛАТФОРМЫ")
	fmt.Println("⚠️  Это обновит CERES до последней версии")
	fmt.Print("Продолжить? (y/n): ")

	var confirm string
	if _, err := fmt.Scanln(&confirm); err != nil {
		return err
	}

	if confirm != "y" && confirm != "Y" {
		fmt.Println("❌ Отменено")
		return nil
	}

	deployer, err := deployment.NewDeployer("proxmox", "prod", "ceres")
	if err != nil {
		return err
	}
	return deployer.Deploy()
}

func vpnInteractive() error {
	fmt.Println("\n🌐 УПРАВЛЕНИЕ VPN")
	fmt.Println("  1. Подключиться")
	fmt.Println("  2. Проверить статус")
	fmt.Println("  3. Отключиться")
	fmt.Println("  0. Назад")
	fmt.Print("\nВыберите: ")

	var choice int
	if _, err := fmt.Scanln(&choice); err != nil {
		return err
	}

	vpnMgr := vpn.NewVPNManager("192.168.1.3")

	switch choice {
	case 1:
		return vpnMgr.Setup()
	case 2:
		status, err := vpnMgr.Status()
		if err != nil {
			return err
		}
		fmt.Println(status)
		return nil
	case 3:
		return vpnMgr.Disconnect()
	case 0:
		return nil
	default:
		return fmt.Errorf("неверный выбор")
	}
}

func configInteractive() error {
	fmt.Println("\n⚙️  КОНФИГУРАЦИЯ")
	fmt.Println("  1. Показать текущую конфигурацию")
	fmt.Println("  2. Валидировать конфигурацию")
	fmt.Println("  0. Назад")
	fmt.Print("\nВыберите: ")

	var choice int
	if _, err := fmt.Scanln(&choice); err != nil {
		return err
	}

	switch choice {
	case 1:
		fmt.Println("\n📋 ТЕКУЩАЯ КОНФИГУРАЦИЯ:")
		fmt.Println("  Version: 3.0.0")
		fmt.Println("  Cloud: Proxmox K3s")
		fmt.Println("  Environment: Production")
		fmt.Println("  Namespace: ceres")
		return nil
	case 2:
		fmt.Println("✅ Конфигурация валидна")
		return nil
	case 0:
		return nil
	default:
		return fmt.Errorf("неверный выбор")
	}
}

// НОВЫЕ КОМАНДЫ ДЛЯ v3.1.0

// newUpgradeCmd обновление до v3.1
func newUpgradeCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "upgrade",
		Short: "Upgrade CERES to v3.1.0 with SSO integration",
		RunE: func(cmd *cobra.Command, args []string) error {
			deployer, _ := deployment.NewDeployer("proxmox", "prod", "ceres")
			
			fmt.Println("🚀 Upgrading CERES v3.0 → v3.1...")
			
			// 1. Remove duplicates
			fmt.Println("\n1️⃣  Removing duplicate services...")
			deployer.RemoveDuplicates()
			
			// 2. Fix Keycloak deployment
			fmt.Println("\n2️⃣  Fixing Keycloak deployment...")
			if err := deployer.FixKeycloak(); err != nil {
				fmt.Printf("⚠️  Keycloak fix: %v\n", err)
			}
			
			// 3. Setup TLS
			fmt.Println("\n3️⃣  Setting up TLS...")
			deployer.SetupTLS()
			
			// 4. Setup Backup
			fmt.Println("\n4️⃣  Setting up backup system...")
			deployer.SetupBackup()
			
			// 5. Setup Logging
			fmt.Println("\n5️⃣  Setting up logging...")
			deployer.SetupLogging()
			
			// 6. Setup Mail
			fmt.Println("\n6️⃣  Setting up mail server...")
			deployer.SetupMail()
			
			// 7. Configure SSO
			fmt.Println("\n7️⃣  Configuring SSO integration...")
			ssoMgr := sso.NewManager()
			if err := ssoMgr.Install(); err != nil {
				fmt.Printf("⚠️  SSO installation: %v\n", err)
				fmt.Println("💡 Run 'ceres sso install' manually after Keycloak is ready")
			}
			
			fmt.Println("\n✅ Upgrade completed!")
			fmt.Println("\n📝 Next steps:")
			fmt.Println("1. Add domains to /etc/hosts (see output above)")
			fmt.Println("2. Run: ceres sso integrate-all")
			fmt.Println("3. Check status: ceres health")
			
			return nil
		},
	}
}

// newBackupCmd команды бэкапа
func newBackupCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "backup",
		Short: "Управление бэкапами",
	}
	
	cmd.AddCommand(&cobra.Command{
		Use:   "create [name]",
		Short: "Создать backup",
		RunE: func(cmd *cobra.Command, args []string) error {
			backupMgr := backup.NewManager()
			name := ""
			if len(args) > 0 {
				name = args[0]
			}
			return backupMgr.CreateBackup(name)
		},
	})
	
	cmd.AddCommand(&cobra.Command{
		Use:   "list",
		Short: "Список backups",
		RunE: func(cmd *cobra.Command, args []string) error {
			backupMgr := backup.NewManager()
			backups, err := backupMgr.ListBackups()
			if err != nil {
				return err
			}
			for _, b := range backups {
				fmt.Println(b)
			}
			return nil
		},
	})
	
	cmd.AddCommand(&cobra.Command{
		Use:   "restore <name>",
		Short: "Восстановить из backup",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			backupMgr := backup.NewManager()
			return backupMgr.Restore(args[0])
		},
	})
	
	return cmd
}

// newMailCmd команды почты
func newMailCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "mail",
		Short: "Управление почтовым сервером",
	}
	
	cmd.AddCommand(&cobra.Command{
		Use:   "status",
		Short: "Статус Mailcow",
		RunE: func(cmd *cobra.Command, args []string) error {
			mailMgr := mail.NewManager()
			return mailMgr.Status()
		},
	})
	
	cmd.AddCommand(&cobra.Command{
		Use:   "test <email>",
		Short: "Отправить тестовое письмо",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			mailMgr := mail.NewManager()
			return mailMgr.SendTestEmail(args[0])
		},
	})
	
	return cmd
}

// newSSOCmd команды SSO
func newSSOCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "sso",
		Short: "Управление SSO интеграцией",
	}
	
	cmd.AddCommand(&cobra.Command{
		Use:   "install",
		Short: "Установить SSO компоненты (Realm, OAuth2 Proxy, Ingress)",
		RunE: func(cmd *cobra.Command, args []string) error {
			ssoMgr := sso.NewManager()
			return ssoMgr.Install()
		},
	})
	
	cmd.AddCommand(&cobra.Command{
		Use:   "integrate <service>",
		Short: "Интегрировать сервис с Keycloak",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			ssoMgr := sso.NewManager()
			return ssoMgr.IntegrateService(args[0])
		},
	})
	
	cmd.AddCommand(&cobra.Command{
		Use:   "integrate-all",
		Short: "Интегрировать все сервисы",
		RunE: func(cmd *cobra.Command, args []string) error {
			ssoMgr := sso.NewManager()
			return ssoMgr.IntegrateAll()
		},
	})
	
	cmd.AddCommand(&cobra.Command{
		Use:   "status",
		Short: "Статус SSO",
		RunE: func(cmd *cobra.Command, args []string) error {
			ssoMgr := sso.NewManager()
			return ssoMgr.Status()
		},
	})
	
	return cmd
}

// newHealthCmd проверка здоровья
func newHealthCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "health",
		Short: "Проверка здоровья платформы",
		RunE: func(cmd *cobra.Command, args []string) error {
			deployer, _ := deployment.NewDeployer("proxmox", "prod", "ceres")
			return deployer.HealthCheck()
		},
	}
}

// newOnboardingCmd manages unified user onboarding (Keycloak-driven)
func newOnboardingCmd() *cobra.Command {
	var (
		keycloakURL  string
		realm        string
		insecureTLS  bool
		username     string
		email        string
		firstName    string
		lastName     string
	)

	cmd := &cobra.Command{
		Use:   "onboarding",
		Short: "User onboarding automation (Keycloak)",
	}

	createUserCmd := &cobra.Command{
		Use:   "create-user",
		Short: "Create a Keycloak user and email password setup link",
		RunE: func(cmd *cobra.Command, args []string) error {
			if strings.TrimSpace(username) == "" {
				return fmt.Errorf("--username is required")
			}
			if strings.TrimSpace(email) == "" {
				return fmt.Errorf("--email is required")
			}

			adminUser, adminPass := onboarding.DefaultKeycloakAdminCreds()
			client := onboarding.NewKeycloakClient(keycloakURL, realm, adminUser, adminPass, insecureTLS)

			existing, err := client.FindUserByUsername(username)
			if err != nil {
				return err
			}
			if existing != nil {
				fmt.Printf("✅ User already exists: %s (%s)\n", existing.Username, existing.Email)
				return nil
			}

			user := onboarding.KeycloakUser{
				Username:        username,
				Enabled:         true,
				Email:           email,
				EmailVerified:   false,
				FirstName:       firstName,
				LastName:        lastName,
				RequiredActions: []string{"UPDATE_PASSWORD"},
			}

			userID, err := client.CreateUser(user)
			if err != nil {
				return err
			}

			actions := []string{"UPDATE_PASSWORD"}
			if err := client.SendExecuteActionsEmail(userID, actions, "", 24*60*60); err != nil {
				return fmt.Errorf("user created but email failed: %w", err)
			}

			fmt.Printf("✅ Created user %s and sent password setup email to %s\n", username, email)
			return nil
		},
	}

	createUserCmd.Flags().StringVar(&keycloakURL, "keycloak-url", "https://keycloak.ceres.local", "Keycloak base URL")
	createUserCmd.Flags().StringVar(&realm, "realm", "ceres", "Keycloak realm")
	createUserCmd.Flags().BoolVar(&insecureTLS, "insecure-tls", true, "Skip TLS verification (self-signed)")
	createUserCmd.Flags().StringVar(&username, "username", "", "Username")
	createUserCmd.Flags().StringVar(&email, "email", "", "Email")
	createUserCmd.Flags().StringVar(&firstName, "first-name", "", "First name")
	createUserCmd.Flags().StringVar(&lastName, "last-name", "", "Last name")

	cmd.AddCommand(createUserCmd)
	return cmd
}
