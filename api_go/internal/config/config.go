package config

import (
	"fmt"
	"os"
	"time"
)

type Config struct {
	AppEnv string
	HTTPAddr string
	DatabaseURL string
	ReadHeaderTimeout time.Duration
	ReadTimeout time.Duration
	WriteTimeout time.Duration
	IdleTimeout time.Duration
	ShutdownTimeout time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		AppEnv: env("APP_ENV", "development"),
		HTTPAddr: env("HTTP_ADDR", ":8080"),
		DatabaseURL: os.Getenv("DATABASE_URL"),
	}
	var err error
	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}
	fields := []struct{name string; target *time.Duration; fallback string}{
		{"READ_HEADER_TIMEOUT", &cfg.ReadHeaderTimeout, "5s"},
		{"READ_TIMEOUT", &cfg.ReadTimeout, "10s"},
		{"WRITE_TIMEOUT", &cfg.WriteTimeout, "15s"},
		{"IDLE_TIMEOUT", &cfg.IdleTimeout, "60s"},
		{"SHUTDOWN_TIMEOUT", &cfg.ShutdownTimeout, "10s"},
	}
	for _, f := range fields {
		*f.target, err = time.ParseDuration(env(f.name, f.fallback))
		if err != nil || *f.target <= 0 {
			return Config{}, fmt.Errorf("invalid %s duration", f.name)
		}
	}
	return cfg, nil
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" { return value }
	return fallback
}
