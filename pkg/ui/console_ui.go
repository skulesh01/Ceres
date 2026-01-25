package ui

import (
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/skulesh01/ceres/pkg/mail"
	"github.com/skulesh01/ceres/pkg/tls"
	"github.com/skulesh01/ceres/pkg/vpn"
)

type ConsoleConfig struct {
	Cloud       string `json:"cloud"`
	Environment string `json:"environment"`
	Namespace   string `json:"namespace"`

	From        string `json:"from"`
	To          string `json:"to"`
	Subject     string `json:"subject"`
	Body        string `json:"body"`
	VPNEndpoint string `json:"vpnEndpoint"`
	VPNPort     int    `json:"vpnPort"`
	IncludeCA   bool   `json:"includeCA"`
	IncludeVPN  bool   `json:"includeVPN"`
}

type ConsoleServer struct {
	ListenAddr string
	ConfigPath string
	BasicUser  string
	BasicPass  string
	WorkDir    string
	Jobs       *JobManager
}

func (s *ConsoleServer) Run() error {
	if strings.TrimSpace(s.ListenAddr) == "" {
		s.ListenAddr = ":8091"
	}
	if strings.TrimSpace(s.BasicUser) == "" || strings.TrimSpace(s.BasicPass) == "" {
		return fmt.Errorf("basic auth is required: set CERES_UI_BASIC_USER and CERES_UI_BASIC_PASS")
	}
	if s.Jobs == nil {
		s.Jobs = NewJobManager()
	}

	cfg, _ := s.loadConfig()
	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("/", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		cfg, _ = s.loadConfig()
		flash := strings.TrimSpace(r.URL.Query().Get("flash"))
		s.render(w, consoleHTML, map[string]any{"Cfg": cfg, "Jobs": s.Jobs.List(), "Flash": flash})
	}))

	mux.HandleFunc("/settings", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		cfg, _ = s.loadConfig()
		if r.Method == http.MethodPost {
			if err := r.ParseForm(); err != nil {
				s.render(w, settingsHTMLConsole, map[string]any{"Cfg": cfg, "Flash": fmt.Sprintf("Ошибка формы: %v", err)})
				return
			}
			cfg.Cloud = strings.TrimSpace(r.FormValue("cloud"))
			cfg.Environment = strings.TrimSpace(r.FormValue("environment"))
			cfg.Namespace = strings.TrimSpace(r.FormValue("namespace"))
			cfg.From = strings.TrimSpace(r.FormValue("from"))
			cfg.To = strings.TrimSpace(r.FormValue("to"))
			cfg.Subject = strings.TrimSpace(r.FormValue("subject"))
			cfg.Body = r.FormValue("body")
			cfg.VPNEndpoint = strings.TrimSpace(r.FormValue("vpnEndpoint"))
			cfg.VPNPort = atoiDefault(r.FormValue("vpnPort"), 51820)
			cfg.IncludeCA = r.FormValue("includeCA") == "on"
			cfg.IncludeVPN = r.FormValue("includeVPN") == "on"
			if cfg.Cloud == "" {
				cfg.Cloud = "k3s"
			}
			if cfg.Environment == "" {
				cfg.Environment = "prod"
			}
			if cfg.Namespace == "" {
				cfg.Namespace = "ceres"
			}
			if err := s.saveConfig(cfg); err != nil {
				s.render(w, settingsHTMLConsole, map[string]any{"Cfg": cfg, "Flash": fmt.Sprintf("Не удалось сохранить: %v", err)})
				return
			}
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		s.render(w, settingsHTMLConsole, map[string]any{"Cfg": cfg, "Flash": ""})
	}))

	mux.HandleFunc("/run/deploy", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		cfg, _ = s.loadConfig()
		confirm := strings.TrimSpace(r.FormValue("confirm"))
		if confirm != "DEPLOY" {
			s.render(w, consoleHTML, map[string]any{"Cfg": cfg, "Jobs": s.Jobs.List(), "Flash": "Для запуска введите DEPLOY в подтверждение"})
			return
		}

		j := s.startCeresJob("ceres deploy", "deploy", "--cloud", cfg.Cloud, "--environment", cfg.Environment, "--namespace", cfg.Namespace)
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/status", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		cfg, _ = s.loadConfig()
		j := s.startCeresJob("ceres status", "status", "--namespace", cfg.Namespace)
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	// Ops pages
	mux.HandleFunc("/ops", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		flash := strings.TrimSpace(r.URL.Query().Get("flash"))
		s.render(w, opsHTML, map[string]any{"Jobs": s.Jobs.List(), "Flash": flash})
	}))

	mux.HandleFunc("/run/health", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/ops", http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres health", "health")
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/diagnose", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/ops", http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres diagnose", "diagnose")
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/fix", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/ops", http.StatusSeeOther)
			return
		}
		_ = r.ParseForm()
		svc := strings.TrimSpace(r.FormValue("service"))
		args := []string{"fix"}
		if svc != "" {
			args = append(args, svc)
		}
		j := s.startCeresJob("ceres fix", args...)
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/upgrade", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/ops", http.StatusSeeOther)
			return
		}
		_ = r.ParseForm()
		confirm := strings.TrimSpace(r.FormValue("confirm"))
		if confirm != "UPGRADE" {
			http.Redirect(w, r, "/ops?flash="+urlQueryEscape("Для upgrade введите UPGRADE"), http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres upgrade", "upgrade")
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	// SSO pages
	mux.HandleFunc("/sso", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		flash := strings.TrimSpace(r.URL.Query().Get("flash"))
		s.render(w, ssoHTML, map[string]any{"Flash": flash, "Jobs": s.Jobs.List()})
	}))

	mux.HandleFunc("/run/sso-status", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/sso", http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres sso status", "sso", "status")
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/sso-install", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/sso", http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres sso install", "sso", "install")
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/sso-integrate-all", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/sso", http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres sso integrate-all", "sso", "integrate-all")
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/sso-integrate", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/sso", http.StatusSeeOther)
			return
		}
		_ = r.ParseForm()
		svc := strings.TrimSpace(r.FormValue("service"))
		if svc == "" {
			http.Redirect(w, r, "/sso?flash="+urlQueryEscape("Укажите service"), http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres sso integrate", "sso", "integrate", svc)
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	// Backup pages
	mux.HandleFunc("/backup", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		flash := strings.TrimSpace(r.URL.Query().Get("flash"))
		s.render(w, backupHTML, map[string]any{"Flash": flash, "Jobs": s.Jobs.List()})
	}))

	mux.HandleFunc("/run/backup-list", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/backup", http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres backup list", "backup", "list")
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/backup-create", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/backup", http.StatusSeeOther)
			return
		}
		_ = r.ParseForm()
		name := strings.TrimSpace(r.FormValue("name"))
		args := []string{"backup", "create"}
		if name != "" {
			args = append(args, name)
		}
		j := s.startCeresJob("ceres backup create", args...)
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/run/backup-restore", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/backup", http.StatusSeeOther)
			return
		}
		_ = r.ParseForm()
		name := strings.TrimSpace(r.FormValue("name"))
		confirm := strings.TrimSpace(r.FormValue("confirm"))
		if name == "" {
			http.Redirect(w, r, "/backup?flash="+urlQueryEscape("Укажите имя backup"), http.StatusSeeOther)
			return
		}
		if confirm != "RESTORE" {
			http.Redirect(w, r, "/backup?flash="+urlQueryEscape("Для restore введите RESTORE"), http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres backup restore", "backup", "restore", name)
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/mail", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		cfg, _ = s.loadConfig()
		if r.Method == http.MethodPost {
			if err := r.ParseForm(); err != nil {
				s.render(w, mailHTMLConsole, map[string]any{"Cfg": cfg, "Flash": fmt.Sprintf("Ошибка формы: %v", err)})
				return
			}

			cfg.From = strings.TrimSpace(r.FormValue("from"))
			cfg.To = strings.TrimSpace(r.FormValue("to"))
			cfg.Subject = strings.TrimSpace(r.FormValue("subject"))
			cfg.Body = r.FormValue("body")
			cfg.VPNEndpoint = strings.TrimSpace(r.FormValue("vpnEndpoint"))
			cfg.VPNPort = atoiDefault(r.FormValue("vpnPort"), 51820)
			cfg.IncludeCA = r.FormValue("includeCA") == "on"
			cfg.IncludeVPN = r.FormValue("includeVPN") == "on"

			recipients := splitCSV(cfg.To)
			if len(recipients) == 0 {
				s.render(w, mailHTMLConsole, map[string]any{"Cfg": cfg, "Flash": "Укажите To"})
				return
			}

			atts := []mail.Attachment{}
			if cfg.IncludeCA {
				ca, err := tls.ReadPEMFromKubernetesTLSSecret("cert-manager", "ceres-root-ca")
				if err != nil {
					s.render(w, mailHTMLConsole, map[string]any{"Cfg": cfg, "Flash": fmt.Sprintf("CA из кластера: %v", err)})
					return
				}
				atts = append(atts, mail.Attachment{Filename: "ceres-root-ca.crt", ContentType: "application/x-x509-ca-cert", Data: ca})
			}
			if cfg.IncludeVPN {
				if strings.TrimSpace(cfg.VPNEndpoint) == "" {
					s.render(w, mailHTMLConsole, map[string]any{"Cfg": cfg, "Flash": "Для VPN укажите VPN Endpoint"})
					return
				}
				vpnCfg, err := vpn.CreateClientConfig(cfg.VPNEndpoint, cfg.VPNPort, "")
				if err != nil {
					s.render(w, mailHTMLConsole, map[string]any{"Cfg": cfg, "Flash": fmt.Sprintf("VPN конфиг: %v", err)})
					return
				}
				atts = append(atts, mail.Attachment{Filename: "ceres-vpn.conf", ContentType: "text/plain", Data: vpnCfg})
			}

			mailMgr := mail.NewManager()
			oldFrom := os.Getenv("CERES_MAIL_FROM")
			if cfg.From != "" {
				_ = os.Setenv("CERES_MAIL_FROM", cfg.From)
				defer func() { _ = os.Setenv("CERES_MAIL_FROM", oldFrom) }()
			}
			if err := mailMgr.SendEmail(recipients, cfg.Subject, cfg.Body, atts); err != nil {
				s.render(w, mailHTMLConsole, map[string]any{"Cfg": cfg, "Flash": fmt.Sprintf("Ошибка отправки: %v", err)})
				return
			}

			_ = s.saveConfig(cfg)
			s.render(w, mailHTMLConsole, map[string]any{"Cfg": cfg, "Flash": "✅ Отправлено"})
			return
		}

		s.render(w, mailHTMLConsole, map[string]any{"Cfg": cfg, "Flash": ""})
	}))

	mux.HandleFunc("/run/mail-status", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/mail", http.StatusSeeOther)
			return
		}
		j := s.startCeresJob("ceres mail status", "mail", "status")
		http.Redirect(w, r, "/jobs/"+j.ID, http.StatusSeeOther)
	}))

	mux.HandleFunc("/jobs/", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		id := strings.TrimPrefix(r.URL.Path, "/jobs/")
		if id == "" {
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		j, ok := s.Jobs.Get(id)
		if !ok {
			http.NotFound(w, r)
			return
		}
		s.render(w, jobHTML, map[string]any{"Job": j})
	}))

	srv := &http.Server{Addr: s.ListenAddr, Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	return srv.ListenAndServe()
}

func (s *ConsoleServer) startCeresJob(name string, args ...string) *Job {
	cmd := []string{"go", "run", "./cmd/ceres"}
	cmd = append(cmd, args...)
	return s.Jobs.Start(name, cmd, s.workdir(), os.Environ())
}

func (s *ConsoleServer) workdir() string {
	wd := strings.TrimSpace(s.WorkDir)
	if wd != "" {
		return wd
	}
	if v := strings.TrimSpace(os.Getenv("CERES_ROOT")); v != "" {
		return v
	}
	if cwd, err := os.Getwd(); err == nil {
		return cwd
	}
	return ""
}

func (s *ConsoleServer) configFile() string {
	p := strings.TrimSpace(s.ConfigPath)
	if p != "" {
		return p
	}
	return "/var/lib/ceres-ui/console.json"
}

func (s *ConsoleServer) loadConfig() (ConsoleConfig, error) {
	cfg := ConsoleConfig{
		Cloud:       envOr("CERES_UI_CLOUD", "k3s"),
		Environment: envOr("CERES_UI_ENV", "prod"),
		Namespace:   envOr("CERES_UI_NAMESPACE", "ceres"),
		From:        envOr("CERES_UI_FROM", "admin@ceres.local"),
		To:          envOr("CERES_UI_TO", ""),
		Subject:     envOr("CERES_UI_SUBJECT", "CERES: VPN + сертификат"),
		Body:        envOr("CERES_UI_BODY", "Здравствуйте!\n\nВо вложении:\n1) CERES Root CA сертификат\n2) WireGuard конфигурация\n\n"),
		VPNEndpoint: envOr("CERES_UI_VPN_ENDPOINT", "192.168.1.3"),
		VPNPort:     atoiDefault(os.Getenv("CERES_UI_VPN_PORT"), 51820),
		IncludeCA:   true,
		IncludeVPN:  true,
	}

	b, err := os.ReadFile(s.configFile())
	if err != nil {
		return cfg, err
	}
	_ = json.Unmarshal(b, &cfg)
	if cfg.Cloud == "" {
		cfg.Cloud = "k3s"
	}
	if cfg.Environment == "" {
		cfg.Environment = "prod"
	}
	if cfg.Namespace == "" {
		cfg.Namespace = "ceres"
	}
	if cfg.VPNPort == 0 {
		cfg.VPNPort = 51820
	}
	return cfg, nil
}

func (s *ConsoleServer) saveConfig(cfg ConsoleConfig) error {
	p := s.configFile()
	if err := os.MkdirAll(filepath.Dir(p), 0755); err != nil {
		return err
	}
	b, _ := json.MarshalIndent(cfg, "", "  ")
	return os.WriteFile(p, b, 0600)
}

func (s *ConsoleServer) withAuth(next http.HandlerFunc) http.HandlerFunc {
	user := strings.TrimSpace(s.BasicUser)
	pass := strings.TrimSpace(s.BasicPass)
	return func(w http.ResponseWriter, r *http.Request) {
		u, p, ok := r.BasicAuth()
		if !ok || subtle.ConstantTimeCompare([]byte(u), []byte(user)) != 1 || subtle.ConstantTimeCompare([]byte(p), []byte(pass)) != 1 {
			w.Header().Set("WWW-Authenticate", `Basic realm="CERES Console"`)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func (s *ConsoleServer) render(w http.ResponseWriter, tplText string, data any) {
	tpl := template.Must(template.New("page").Funcs(template.FuncMap{
		"hasPrefix": strings.HasPrefix,
		"join":      strings.Join,
	}).Parse(tplText))
	_ = tpl.Execute(w, data)
}

func urlQueryEscape(s string) string {
	s = strings.ReplaceAll(s, "%", "%25")
	s = strings.ReplaceAll(s, " ", "%20")
	s = strings.ReplaceAll(s, "\n", "%0A")
	s = strings.ReplaceAll(s, "\r", "%0D")
	s = strings.ReplaceAll(s, "\t", "%09")
	s = strings.ReplaceAll(s, "\"", "%22")
	s = strings.ReplaceAll(s, "#", "%23")
	s = strings.ReplaceAll(s, "?", "%3F")
	s = strings.ReplaceAll(s, "&", "%26")
	s = strings.ReplaceAll(s, "+", "%2B")
	return s
}

func splitCSV(v string) []string {
	var out []string
	for _, p := range strings.Split(v, ",") {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func envOr(k, def string) string {
	v := strings.TrimSpace(os.Getenv(k))
	if v == "" {
		return def
	}
	return v
}

func atoiDefault(s string, def int) int {
	s = strings.TrimSpace(s)
	if s == "" {
		return def
	}
	var n int
	_, err := fmt.Sscanf(s, "%d", &n)
	if err != nil || n <= 0 {
		return def
	}
	return n
}

const consoleCSS = `
:root{--bg:#0b1220;--card:#0f1a2e;--text:#e6eefc;--muted:#9fb2d1;--accent:#4aa3ff;--bad:#ff6b6b;--ok:#38d996;--border:#22304a;}
*{box-sizing:border-box} body{margin:0;font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Arial; background:linear-gradient(180deg,#08101f,#0b1220); color:var(--text);} 
a{color:var(--accent);text-decoration:none}
.container{max-width:1100px;margin:0 auto;padding:24px}
.header{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px}
.h1{font-size:22px;font-weight:700}
.card{background:rgba(15,26,46,.9);border:1px solid var(--border);border-radius:14px;padding:18px;box-shadow:0 10px 24px rgba(0,0,0,.25)}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.row{margin-bottom:12px}
label{display:block;font-size:12px;color:var(--muted);margin-bottom:6px}
input,textarea,select{width:100%;background:#0b152a;color:var(--text);border:1px solid var(--border);border-radius:10px;padding:10px 12px;outline:none}
textarea{min-height:160px;resize:vertical}
.actions{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.btn{background:var(--accent);border:none;color:#06101f;padding:10px 14px;border-radius:10px;font-weight:700;cursor:pointer}
.btn.secondary{background:transparent;border:1px solid var(--border);color:var(--text)}
.badge{padding:8px 10px;border-radius:10px;border:1px solid var(--border);background:#0b152a;color:var(--muted)}
.flash{margin:12px 0;padding:10px 12px;border-radius:12px;border:1px solid var(--border);background:#0b152a}
.flash.ok{border-color:rgba(56,217,150,.35);color:var(--ok)}
.flash.bad{border-color:rgba(255,107,107,.35);color:var(--bad)}
.table{width:100%;border-collapse:collapse;margin-top:8px}
.table th,.table td{border-bottom:1px solid var(--border);padding:8px 6px;text-align:left;font-size:13px}
.small{font-size:12px;color:var(--muted)}
pre{white-space:pre-wrap;background:#071022;border:1px solid var(--border);padding:12px;border-radius:12px;overflow:auto}
@media (max-width: 920px){.grid{grid-template-columns:1fr}}
`

const consoleHTML = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES Console</title>
<style>` + consoleCSS + `</style></head><body>
<div class="container">
  <div class="header">
    <div class="h1">CERES Console</div>
    <div class="actions">
      <a class="badge" href="/settings">Настройки</a>
      <a class="badge" href="/mail">Почта / VPN пакет</a>
	  <a class="badge" href="/ops">Ops</a>
	  <a class="badge" href="/sso">SSO</a>
	  <a class="badge" href="/backup">Backup</a>
    </div>
  </div>

  {{if .Flash}}<div class="flash {{if hasPrefix .Flash "✅"}}ok{{else}}bad{{end}}">{{.Flash}}</div>{{end}}

  <div class="grid">
    <div class="card">
      <div class="h1" style="font-size:16px">Деплой / Обновление</div>
      <div class="small">Cloud: <b>{{.Cfg.Cloud}}</b> • Env: <b>{{.Cfg.Environment}}</b> • Namespace: <b>{{.Cfg.Namespace}}</b></div>
      <div class="row" style="margin-top:12px">
        <label>Подтверждение (введите DEPLOY)</label>
        <input name="confirm" form="deployForm" placeholder="DEPLOY">
      </div>
      <div class="actions">
        <form id="deployForm" method="post" action="/run/deploy">
          <input type="hidden" name="confirm" id="confirmHidden">
          <button class="btn" type="submit" onclick="document.getElementById('confirmHidden').value=document.querySelector('input[form=deployForm]').value;">Запустить deploy/reconcile</button>
        </form>
        <form method="post" action="/run/status">
          <button class="btn secondary" type="submit">Снять статус</button>
        </form>
      </div>
      <div class="small" style="margin-top:10px">Кнопка запускает ` + "`go run ./cmd/ceres deploy`" + ` на сервере.</div>
    </div>

    <div class="card">
      <div class="h1" style="font-size:16px">Задачи</div>
      <table class="table">
        <thead><tr><th>ID</th><th>Имя</th><th>Статус</th><th>Начало</th></tr></thead>
        <tbody>
          {{range .Jobs}}
            <tr>
              <td><a href="/jobs/{{.ID}}">{{.ID}}</a></td>
              <td>{{.Name}}</td>
              <td>{{.Status}}</td>
              <td>{{.StartedAt}}</td>
            </tr>
          {{end}}
        </tbody>
      </table>
      <div class="small" style="margin-top:10px">Открой задачу, чтобы посмотреть лог выполнения.</div>
    </div>
  </div>
</div></body></html>`

const opsHTML = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES Ops</title>
<style>` + consoleCSS + `</style></head><body><div class="container">
	<div class="header">
		<div class="h1">Ops</div>
		<div class="actions"><a class="badge" href="/">← Назад</a></div>
	</div>
	{{if .Flash}}<div class="flash bad">{{.Flash}}</div>{{end}}
	<div class="grid">
		<div class="card">
			<div class="h1" style="font-size:16px">Проверки</div>
			<div class="actions" style="margin-top:12px">
				<form method="post" action="/run/health"><button class="btn" type="submit">health</button></form>
				<form method="post" action="/run/diagnose"><button class="btn secondary" type="submit">diagnose</button></form>
			</div>
			<hr style="border:0;border-top:1px solid var(--border);margin:14px 0">
			<div class="h1" style="font-size:16px">Fix</div>
			<form method="post" action="/run/fix">
				<div class="row"><label>Service (пусто = все)</label><input name="service" placeholder="nextcloud"></div>
				<button class="btn" type="submit">fix</button>
			</form>
			<hr style="border:0;border-top:1px solid var(--border);margin:14px 0">
			<div class="h1" style="font-size:16px">Upgrade</div>
			<div class="row"><label>Подтверждение (введите UPGRADE)</label><input name="confirm" form="upgradeForm" placeholder="UPGRADE"></div>
			<form id="upgradeForm" method="post" action="/run/upgrade">
				<input type="hidden" name="confirm" id="upgradeConfirmHidden">
				<button class="btn" type="submit" onclick="document.getElementById('upgradeConfirmHidden').value=document.querySelector('input[form=upgradeForm]').value;">upgrade</button>
			</form>
			<div class="small" style="margin-top:10px">` + "`upgrade`" + ` выполняет сценарий v3.0→v3.1 (может менять много ресурсов).</div>
		</div>

		<div class="card">
			<div class="h1" style="font-size:16px">Задачи</div>
			<table class="table">
				<thead><tr><th>ID</th><th>Имя</th><th>Статус</th></tr></thead>
				<tbody>
					{{range .Jobs}}
						<tr><td><a href="/jobs/{{.ID}}">{{.ID}}</a></td><td>{{.Name}}</td><td>{{.Status}}</td></tr>
					{{end}}
				</tbody>
			</table>
		</div>
	</div>
</div></body></html>`

const ssoHTML = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES SSO</title>
<style>` + consoleCSS + `</style></head><body><div class="container">
	<div class="header"><div class="h1">SSO</div><div class="actions"><a class="badge" href="/">← Назад</a></div></div>
	{{if .Flash}}<div class="flash bad">{{.Flash}}</div>{{end}}
	<div class="grid">
		<div class="card">
			<div class="h1" style="font-size:16px">Команды</div>
			<div class="actions" style="margin-top:12px">
				<form method="post" action="/run/sso-status"><button class="btn secondary" type="submit">status</button></form>
				<form method="post" action="/run/sso-install"><button class="btn" type="submit">install</button></form>
				<form method="post" action="/run/sso-integrate-all"><button class="btn" type="submit">integrate-all</button></form>
			</div>
			<hr style="border:0;border-top:1px solid var(--border);margin:14px 0">
			<form method="post" action="/run/sso-integrate">
				<div class="row"><label>Service</label><input name="service" placeholder="gitlab"></div>
				<button class="btn" type="submit">integrate</button>
			</form>
		</div>
		<div class="card">
			<div class="h1" style="font-size:16px">Задачи</div>
			<table class="table">
				<thead><tr><th>ID</th><th>Имя</th><th>Статус</th></tr></thead>
				<tbody>
					{{range .Jobs}}
						<tr><td><a href="/jobs/{{.ID}}">{{.ID}}</a></td><td>{{.Name}}</td><td>{{.Status}}</td></tr>
					{{end}}
				</tbody>
			</table>
		</div>
	</div>
</div></body></html>`

const backupHTML = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES Backup</title>
<style>` + consoleCSS + `</style></head><body><div class="container">
	<div class="header"><div class="h1">Backup</div><div class="actions"><a class="badge" href="/">← Назад</a></div></div>
	{{if .Flash}}<div class="flash bad">{{.Flash}}</div>{{end}}
	<div class="grid">
		<div class="card">
			<div class="h1" style="font-size:16px">Команды</div>
			<div class="actions" style="margin-top:12px">
				<form method="post" action="/run/backup-list"><button class="btn secondary" type="submit">list</button></form>
			</div>
			<hr style="border:0;border-top:1px solid var(--border);margin:14px 0">
			<form method="post" action="/run/backup-create">
				<div class="row"><label>Create (name optional)</label><input name="name" placeholder="manual-2026-01-25"></div>
				<button class="btn" type="submit">create</button>
			</form>
			<hr style="border:0;border-top:1px solid var(--border);margin:14px 0">
			<form method="post" action="/run/backup-restore">
				<div class="row"><label>Restore name</label><input name="name" placeholder="backup-name"></div>
				<div class="row"><label>Подтверждение (введите RESTORE)</label><input name="confirm" placeholder="RESTORE"></div>
				<button class="btn" type="submit">restore</button>
			</form>
			<div class="small" style="margin-top:10px">Restore потенциально разрушителен — требует подтверждение.</div>
		</div>
		<div class="card">
			<div class="h1" style="font-size:16px">Задачи</div>
			<table class="table">
				<thead><tr><th>ID</th><th>Имя</th><th>Статус</th></tr></thead>
				<tbody>
					{{range .Jobs}}
						<tr><td><a href="/jobs/{{.ID}}">{{.ID}}</a></td><td>{{.Name}}</td><td>{{.Status}}</td></tr>
					{{end}}
				</tbody>
			</table>
		</div>
	</div>
</div></body></html>`

const settingsHTMLConsole = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES Console Settings</title>
<style>` + consoleCSS + `</style></head><body><div class="container">
  <div class="header">
    <div class="h1">Настройки</div>
    <div class="actions"><a class="badge" href="/">← Назад</a></div>
  </div>
  {{if .Flash}}<div class="flash bad">{{.Flash}}</div>{{end}}
  <div class="card">
    <form method="post" action="/settings">
      <div class="grid">
        <div class="row"><label>Cloud</label><select name="cloud"><option {{if eq .Cfg.Cloud "k3s"}}selected{{end}}>k3s</option><option {{if eq .Cfg.Cloud "proxmox"}}selected{{end}}>proxmox</option></select></div>
        <div class="row"><label>Environment</label><input name="environment" value="{{.Cfg.Environment}}"></div>
      </div>
      <div class="row"><label>Namespace</label><input name="namespace" value="{{.Cfg.Namespace}}"></div>
      <hr style="border:0;border-top:1px solid var(--border);margin:14px 0">
      <div class="grid">
        <div class="row"><label>Mail From</label><input name="from" value="{{.Cfg.From}}"></div>
        <div class="row"><label>Mail To (default)</label><input name="to" value="{{.Cfg.To}}"></div>
      </div>
      <div class="row"><label>Subject</label><input name="subject" value="{{.Cfg.Subject}}"></div>
      <div class="grid">
        <div class="row"><label>VPN Endpoint</label><input name="vpnEndpoint" value="{{.Cfg.VPNEndpoint}}"></div>
        <div class="row"><label>VPN Port</label><input name="vpnPort" value="{{.Cfg.VPNPort}}"></div>
      </div>
      <div class="row"><label>Body</label><textarea name="body">{{.Cfg.Body}}</textarea></div>
      <div class="actions">
        <label class="badge"><input type="checkbox" name="includeCA" {{if .Cfg.IncludeCA}}checked{{end}}> Root CA</label>
        <label class="badge"><input type="checkbox" name="includeVPN" {{if .Cfg.IncludeVPN}}checked{{end}}> VPN конфиг</label>
        <button class="btn" type="submit">Сохранить</button>
      </div>
    </form>
  </div>
</div></body></html>`

const mailHTMLConsole = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES Console Mail</title>
<style>` + consoleCSS + `</style></head><body><div class="container">
  <div class="header">
    <div class="h1">Почта / VPN пакет</div>
    <div class="actions"><a class="badge" href="/">← Назад</a></div>
  </div>
  {{if .Flash}}<div class="flash {{if hasPrefix .Flash "✅"}}ok{{else}}bad{{end}}">{{.Flash}}</div>{{end}}
  <div class="card">
    <form method="post" action="/mail">
      <div class="grid">
        <div class="row"><label>From</label><input name="from" value="{{.Cfg.From}}"></div>
        <div class="row"><label>To (через запятую)</label><input name="to" value="{{.Cfg.To}}"></div>
      </div>
      <div class="row"><label>Subject</label><input name="subject" value="{{.Cfg.Subject}}"></div>
      <div class="grid">
        <div class="row"><label>VPN Endpoint</label><input name="vpnEndpoint" value="{{.Cfg.VPNEndpoint}}"></div>
        <div class="row"><label>VPN Port</label><input name="vpnPort" value="{{.Cfg.VPNPort}}"></div>
      </div>
      <div class="row"><label>Body</label><textarea name="body">{{.Cfg.Body}}</textarea></div>
      <div class="actions">
        <label class="badge"><input type="checkbox" name="includeCA" {{if .Cfg.IncludeCA}}checked{{end}}> Root CA</label>
        <label class="badge"><input type="checkbox" name="includeVPN" {{if .Cfg.IncludeVPN}}checked{{end}}> VPN конфиг</label>
        <button class="btn" type="submit">Отправить</button>
        <a class="btn secondary" href="/settings">Настройки</a>
      </div>
			<div class="actions" style="margin-top:10px">
				<form method="post" action="/run/mail-status"><button class="btn secondary" type="submit">mail status</button></form>
			</div>
      <div class="small" style="margin-top:10px">Внимание: VPN конфиг содержит приватный ключ.</div>
    </form>
  </div>
</div></body></html>`

const jobHTML = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES Console Job</title>
{{if eq .Job.Status "running"}}<meta http-equiv="refresh" content="2">{{end}}
<style>` + consoleCSS + `</style></head><body><div class="container">
  <div class="header"><div class="h1">Задача {{.Job.ID}}</div><div class="actions"><a class="badge" href="/">← Назад</a></div></div>
  <div class="card">
    <div class="small">Имя: <b>{{.Job.Name}}</b> • Статус: <b>{{.Job.Status}}</b> • Старт: <b>{{.Job.StartedAt}}</b></div>
		<div class="small" style="margin-top:6px">Команда: <b>{{join .Job.Command " "}}</b></div>
    <pre style="margin-top:12px">{{.Job.Output}}</pre>
  </div>
</div></body></html>`
