package main

import (
	"errors"
	"log"
	"net/http"
	"os"
	"time"
)

type Config struct {
	Addr    string        `json:"addr"`
	Timeout time.Duration `json:"timeout"`
	Root    string        `json:"root"`
}

func loadConfig() Config {
	addr := os.Getenv("SHOP_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}
	return Config{Addr: addr, Timeout: 15 * time.Second, Root: "./public"}
}

func main() {
	cfg := loadConfig()
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	mux.Handle("/static/", http.FileServer(http.Dir(cfg.Root)))
	srv := &http.Server{Addr: cfg.Addr, Handler: mux, ReadTimeout: cfg.Timeout}
	log.Printf("listening on %s", cfg.Addr)
	if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}
