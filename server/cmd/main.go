package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"

	"github.com/joho/godotenv"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/conn"
)

var (
	configPath = flag.String("config", ".env", "Path to the config file")
)

type config struct {
	PgHost           string
	PgPort           int
	PgUser           string
	PgPassword       string
	PgDatabase       string
	Port             int
	CertPath         string
	KeyPath          string
	DataPath         string
	ClientExportPath string
	AdminPassword    string
}

func loadConfig() *config {
	cfg := &config{
		PgHost:           os.Getenv("PG_HOST"),
		PgPort:           5432,
		PgUser:           os.Getenv("PG_USER"),
		PgPassword:       os.Getenv("PG_PASSWORD"),
		PgDatabase:       os.Getenv("PG_DATABASE"),
		Port:             43200,
		DataPath:         coalescePaths(os.Getenv("DATA_PATH"), "data", "."),
		CertPath:         coalescePaths(os.Getenv("CERT_PATH"), "certs/cert.pem"),
		KeyPath:          coalescePaths(os.Getenv("KEY_PATH"), "certs/key.pem"),
		ClientExportPath: coalescePaths(os.Getenv("CLIENT_EXPORT_PATH"), "../exports/web"),
		AdminPassword:    os.Getenv("ADMIN_PASSWORD"),
	}

	port, err := strconv.Atoi(os.Getenv("PG_PORT"))
	if err != nil {
		log.Printf("Error parsing PG_PORT, using %d", cfg.PgPort)
	} else {
		cfg.PgPort = port
	}

	port, err = strconv.Atoi(os.Getenv("PORT"))
	if err != nil {
		log.Printf("Error parsing PORT, using %d", cfg.Port)
		return cfg
	}
	cfg.Port = port
	return cfg
}

func coalescePaths(fallbacks ...string) string {
	for i, path := range fallbacks {
		if _, err := os.Stat(path); os.IsNotExist(err) {
			message := fmt.Sprintf("File/folder not found at %s", path)
			if i < len(fallbacks)-1 {
				log.Printf("%s - going to try %s", message, fallbacks[i+1])
			} else {
				log.Printf("%s - no more fallbacks to try", message)
			}
		} else {
			log.Printf("File/folder found at %s", path)
			return path
		}
	}
	return ""
}

func main() {
	flag.Parse()
	err := godotenv.Load(*configPath)
	cfg := loadConfig()
	if err != nil {
		log.Printf("Error loading config file, defaulting to %+v", cfg)
	}

	pgConnString := fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
		cfg.PgHost, cfg.PgPort, cfg.PgUser, cfg.PgPassword, cfg.PgDatabase,
	)
	hub := central.NewHub(cfg.DataPath, pgConnString)

	// Define handler for WebSocket connections
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		hub.Serve(conn.NewWebSocketClient, w, r)
	})

	// Define handler for serving the HTML5 export
	if _, err := os.Stat(cfg.ClientExportPath); err != nil {
		if !os.IsNotExist(err) {
			log.Fatalf("Error checking for HTML5 export: %v", err)
		}
	} else {
		log.Printf("Serving HTML5 export from %s", cfg.ClientExportPath)
		http.Handle("/", addHeaders(http.StripPrefix("/", http.FileServer(http.Dir(cfg.ClientExportPath)))))
	}

	// Start the server
	go hub.Run(cfg.AdminPassword)
	addr := fmt.Sprintf(":%d", cfg.Port)

	log.Printf("Starting server on %s", addr)

	log.Printf("Using cert at %s and key at %s", cfg.CertPath, cfg.KeyPath)
	err = http.ListenAndServeTLS(addr, cfg.CertPath, cfg.KeyPath, nil)

	if err != nil {
		log.Printf("No certificate found (%v), starting server without TLS", err)
		err = http.ListenAndServe(addr, nil)
		if err != nil {
			log.Fatalf("Failed to start server: %v", err)
		}
	}
}

// Add headers required for the HTML5 export to work with shared array buffers
func addHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
		w.Header().Set("Cross-Origin-Embedder-Policy", "require-corp")
		next.ServeHTTP(w, r)
	})
}
