package main

import (
	"log"
	"os"
	"strings"

	"github.com/skulesh01/ceres/pkg/ui"
)

func main() {
	listen := strings.TrimSpace(os.Getenv("CERES_CONSOLE_LISTEN"))
	if listen == "" {
		listen = ":8091"
	}

	s := &ui.ConsoleServer{
		ListenAddr: listen,
		ConfigPath: strings.TrimSpace(os.Getenv("CERES_CONSOLE_CONFIG")),
		BasicUser:  strings.TrimSpace(os.Getenv("CERES_UI_BASIC_USER")),
		BasicPass:  strings.TrimSpace(os.Getenv("CERES_UI_BASIC_PASS")),
		WorkDir:    strings.TrimSpace(os.Getenv("CERES_ROOT")),
		Jobs:       ui.NewJobManager(),
	}

	log.Printf("CERES Console listening on %s", listen)
	if err := s.Run(); err != nil {
		log.Fatal(err)
	}
}
