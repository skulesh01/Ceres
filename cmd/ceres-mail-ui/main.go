package main

import (
	"log"
	"os"
	"strings"

	"github.com/skulesh01/ceres/pkg/ui"
)

func main() {
	listen := strings.TrimSpace(os.Getenv("CERES_UI_LISTEN"))
	if listen == "" {
		listen = ":8090"
	}

	s := &ui.Server{
		ListenAddr: listen,
		ConfigPath: strings.TrimSpace(os.Getenv("CERES_UI_CONFIG")),
		BasicUser:  strings.TrimSpace(os.Getenv("CERES_UI_BASIC_USER")),
		BasicPass:  strings.TrimSpace(os.Getenv("CERES_UI_BASIC_PASS")),
	}

	log.Printf("CERES Mail UI listening on %s", listen)
	if err := s.Run(); err != nil {
		log.Fatal(err)
	}
}
