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

type Config struct {
	From       string `json:"from"`
	To         string `json:"to"`
	Subject    string `json:"subject"`
	Body       string `json:"body"`
	VPNEndpoint string `json:"vpnEndpoint"`
	VPNPort    int    `json:"vpnPort"`
	IncludeCA  bool   `json:"includeCA"`
	IncludeVPN bool   `json:"includeVPN"`
}

type Server struct {
	ListenAddr string
	ConfigPath string
	BasicUser  string
	BasicPass  string
}

func (s *Server) Run() error {
	if strings.TrimSpace(s.ListenAddr) == "" {
		s.ListenAddr = ":8090"
	}
	if strings.TrimSpace(s.BasicUser) == "" || strings.TrimSpace(s.BasicPass) == "" {
		return fmt.Errorf("basic auth is required: set CERES_UI_BASIC_USER and CERES_UI_BASIC_PASS")
	}

	cfg, _ := s.loadConfig()
	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("/", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		s.renderIndex(w, r, cfg, "")
	}))

	mux.HandleFunc("/send", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		if err := r.ParseForm(); err != nil {
			s.renderIndex(w, r, cfg, fmt.Sprintf("Ошибка формы: %v", err))
			return
		}

		formCfg := cfg
		formCfg.From = strings.TrimSpace(r.FormValue("from"))
		formCfg.To = strings.TrimSpace(r.FormValue("to"))
		formCfg.Subject = strings.TrimSpace(r.FormValue("subject"))
		formCfg.Body = r.FormValue("body")
		formCfg.VPNEndpoint = strings.TrimSpace(r.FormValue("vpnEndpoint"))
		formCfg.VPNPort = atoiDefault(r.FormValue("vpnPort"), 51820)
		formCfg.IncludeCA = r.FormValue("includeCA") == "on"
		formCfg.IncludeVPN = r.FormValue("includeVPN") == "on"

		recipients := splitCSV(formCfg.To)
		if len(recipients) == 0 {
			s.renderIndex(w, r, formCfg, "Укажите получателя (To)")
			return
		}
		if formCfg.IncludeVPN && strings.TrimSpace(formCfg.VPNEndpoint) == "" {
			s.renderIndex(w, r, formCfg, "Для VPN укажите VPN Endpoint")
			return
		}

		atts := []mail.Attachment{}
		if formCfg.IncludeCA {
			ca, err := tls.ReadPEMFromKubernetesTLSSecret("cert-manager", "ceres-root-ca")
			if err != nil {
				s.renderIndex(w, r, formCfg, fmt.Sprintf("Не удалось получить CA из кластера: %v", err))
				return
			}
			atts = append(atts, mail.Attachment{Filename: "ceres-root-ca.crt", ContentType: "application/x-x509-ca-cert", Data: ca})
		}

		if formCfg.IncludeVPN {
			cfgBytes, err := vpn.CreateClientConfig(formCfg.VPNEndpoint, formCfg.VPNPort, "")
			if err != nil {
				s.renderIndex(w, r, formCfg, fmt.Sprintf("Не удалось создать VPN конфиг: %v", err))
				return
			}
			atts = append(atts, mail.Attachment{Filename: "ceres-vpn.conf", ContentType: "text/plain", Data: cfgBytes})
		}

		mailMgr := mail.NewManager()
		oldFrom := os.Getenv("CERES_MAIL_FROM")
		if strings.TrimSpace(formCfg.From) != "" {
			_ = os.Setenv("CERES_MAIL_FROM", formCfg.From)
			defer func() { _ = os.Setenv("CERES_MAIL_FROM", oldFrom) }()
		}
		if err := mailMgr.SendEmail(recipients, formCfg.Subject, formCfg.Body, atts); err != nil {
			s.renderIndex(w, r, formCfg, fmt.Sprintf("Ошибка отправки: %v", err))
			return
		}

		s.renderIndex(w, r, formCfg, "✅ Письмо отправлено")
	}))

	mux.HandleFunc("/settings", s.withAuth(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			if err := r.ParseForm(); err != nil {
				s.renderSettings(w, r, cfg, fmt.Sprintf("Ошибка формы: %v", err))
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
			if err := s.saveConfig(cfg); err != nil {
				s.renderSettings(w, r, cfg, fmt.Sprintf("Не удалось сохранить: %v", err))
				return
			}
			http.Redirect(w, r, "/", http.StatusSeeOther)
			return
		}
		s.renderSettings(w, r, cfg, "")
	}))

	srv := &http.Server{
		Addr:              s.ListenAddr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}
	return srv.ListenAndServe()
}

func (s *Server) configFile() string {
	p := strings.TrimSpace(s.ConfigPath)
	if p != "" {
		return p
	}
	return "/var/lib/ceres-ui/config.json"
}

func (s *Server) loadConfig() (Config, error) {
	cfg := Config{
		From:        envOr("CERES_UI_FROM", "admin@ceres.local"),
		To:          envOr("CERES_UI_TO", ""),
		Subject:     envOr("CERES_UI_SUBJECT", "CERES: VPN + сертификат"),
		Body:        envOr("CERES_UI_BODY", "Здравствуйте!\n\nВо вложении:\n1) CERES Root CA сертификат (установить в доверенные корневые)\n2) WireGuard конфигурация (импортировать в приложение WireGuard)\n\n"),
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
	if cfg.VPNPort == 0 {
		cfg.VPNPort = 51820
	}
	if cfg.Subject == "" {
		cfg.Subject = "CERES: VPN + сертификат"
	}
	return cfg, nil
}

func (s *Server) saveConfig(cfg Config) error {
	p := s.configFile()
	if err := os.MkdirAll(filepath.Dir(p), 0755); err != nil {
		return err
	}
	b, _ := json.MarshalIndent(cfg, "", "  ")
	return os.WriteFile(p, b, 0600)
}

func (s *Server) withAuth(next http.HandlerFunc) http.HandlerFunc {
	user := strings.TrimSpace(s.BasicUser)
	pass := strings.TrimSpace(s.BasicPass)
	return func(w http.ResponseWriter, r *http.Request) {
		u, p, ok := r.BasicAuth()
		if !ok || subtle.ConstantTimeCompare([]byte(u), []byte(user)) != 1 || subtle.ConstantTimeCompare([]byte(p), []byte(pass)) != 1 {
			w.Header().Set("WWW-Authenticate", `Basic realm="CERES UI"`)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func (s *Server) renderIndex(w http.ResponseWriter, r *http.Request, cfg Config, flash string) {
	tpl := template.Must(template.New("index").Funcs(template.FuncMap{"hasPrefix": strings.HasPrefix}).Parse(indexHTML))
	_ = tpl.Execute(w, map[string]any{"Cfg": cfg, "Flash": flash})
}

func (s *Server) renderSettings(w http.ResponseWriter, r *http.Request, cfg Config, flash string) {
	tpl := template.Must(template.New("settings").Funcs(template.FuncMap{"hasPrefix": strings.HasPrefix}).Parse(settingsHTML))
	_ = tpl.Execute(w, map[string]any{"Cfg": cfg, "Flash": flash})
}

const baseCSS = `
:root{--bg:#0b1220;--card:#0f1a2e;--text:#e6eefc;--muted:#9fb2d1;--accent:#4aa3ff;--bad:#ff6b6b;--ok:#38d996;--border:#22304a;}
*{box-sizing:border-box} body{margin:0;font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Arial; background:linear-gradient(180deg,#08101f,#0b1220); color:var(--text);} 
a{color:var(--accent);text-decoration:none}
.container{max-width:980px;margin:0 auto;padding:24px}
.header{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px}
.h1{font-size:22px;font-weight:700}
.card{background:rgba(15,26,46,.9);border:1px solid var(--border);border-radius:14px;padding:18px;box-shadow:0 10px 24px rgba(0,0,0,.25)}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
label{display:block;font-size:12px;color:var(--muted);margin-bottom:6px}
input,textarea{width:100%;background:#0b152a;color:var(--text);border:1px solid var(--border);border-radius:10px;padding:10px 12px;outline:none}
textarea{min-height:180px;resize:vertical}
.row{margin-bottom:12px}
.actions{display:flex;gap:10px;align-items:center}
.btn{background:var(--accent);border:none;color:#06101f;padding:10px 14px;border-radius:10px;font-weight:700;cursor:pointer}
.btn.secondary{background:transparent;border:1px solid var(--border);color:var(--text)}
.badge{padding:8px 10px;border-radius:10px;border:1px solid var(--border);background:#0b152a;color:var(--muted)}
.flash{margin:12px 0;padding:10px 12px;border-radius:12px;border:1px solid var(--border);background:#0b152a}
.flash.ok{border-color:rgba(56,217,150,.35);color:var(--ok)}
.flash.bad{border-color:rgba(255,107,107,.35);color:var(--bad)}
.small{font-size:12px;color:var(--muted)}
@media (max-width: 860px){.grid{grid-template-columns:1fr}.actions{flex-wrap:wrap}}
`

const indexHTML = `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES Mail UI</title>
<style>` + baseCSS + `</style></head>
<body><div class="container">
  <div class="header">
    <div class="h1">CERES • Рассылка сертификата и VPN</div>
    <div class="actions">
      <a class="badge" href="/settings">Настройки по умолчанию</a>
    </div>
  </div>
  <div class="card">
		{{if .Flash}}<div class="flash {{if hasPrefix .Flash "✅"}}ok{{else}}bad{{end}}">{{.Flash}}</div>{{end}}
    <form method="post" action="/send">
      <div class="grid">
        <div class="row"><label>From</label><input name="from" value="{{.Cfg.From}}" placeholder="admin@ceres.local"></div>
        <div class="row"><label>To (через запятую)</label><input name="to" value="{{.Cfg.To}}" placeholder="user@domain"></div>
      </div>
      <div class="row"><label>Subject</label><input name="subject" value="{{.Cfg.Subject}}"></div>
      <div class="grid">
        <div class="row"><label>VPN Endpoint</label><input name="vpnEndpoint" value="{{.Cfg.VPNEndpoint}}"></div>
        <div class="row"><label>VPN Port</label><input name="vpnPort" value="{{.Cfg.VPNPort}}"></div>
      </div>
      <div class="row"><label>Body</label><textarea name="body">{{.Cfg.Body}}</textarea></div>
      <div class="actions">
        <label class="badge"><input type="checkbox" name="includeCA" {{if .Cfg.IncludeCA}}checked{{end}}> Вложить Root CA</label>
        <label class="badge"><input type="checkbox" name="includeVPN" {{if .Cfg.IncludeVPN}}checked{{end}}> Вложить WireGuard конфиг</label>
        <button class="btn" type="submit">Отправить</button>
        <a class="btn secondary" href="/">Сброс</a>
      </div>
      <div class="small" style="margin-top:10px">Примечание: VPN конфиг содержит приватный ключ (как обычный wg-конфиг). Рассылайте только доверенным адресатам.</div>
    </form>
  </div>
</div>
</body></html>`

const settingsHTML = `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CERES Mail UI Settings</title>
<style>` + baseCSS + `</style></head>
<body><div class="container">
  <div class="header">
    <div class="h1">CERES • Настройки по умолчанию</div>
    <div class="actions"><a class="badge" href="/">← Назад</a></div>
  </div>
  <div class="card">
    {{if .Flash}}<div class="flash bad">{{.Flash}}</div>{{end}}
    <form method="post" action="/settings">
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
        <button class="btn" type="submit">Сохранить</button>
      </div>
    </form>
  </div>
</div>
</body></html>`
