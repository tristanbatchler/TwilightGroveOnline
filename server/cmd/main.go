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
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/central/items"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/conn"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/objs"
	"github.com/tristanbatchler/TwilightGroveOnline/server/internal/states"
	"github.com/tristanbatchler/TwilightGroveOnline/server/pkg/ds"
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

	// Add an NPC to the game
	addNpcWithDialogue(hub, 1, 18, 5, "Rickert", 48, 0, []string{
		"Have you seen my friends? I went to find some wood for the fire and now they are all gone.",
		"I'm Rickert. What's your name?",
		"Well met! If you see any of my friends, please tell them I'm looking for them.",
	})

	// Add an NPC merchant to the game
	// Don't really need to store the shop inventory in the DB. If the server is restarted, stocks will replenish, that's OK
	mudShop := ds.NewInventory()
	mudShop.AddItem(*items.Logs, 100)
	mudShop.AddItem(*items.BronzeHatchet, 10)
	addNpcMerchant(hub, 1, 25, -1, "Mud", 112, 0, mudShop)

	// Add another merchant
	dezzickShop := ds.NewInventory()
	dezzickShop.AddItem(*items.Rocks, 100)
	dezzickShop.AddItem(*items.BronzePickaxe, 10)
	addNpcMerchant(hub, 2, 2, 4, "Dezzick", 32, 0, dezzickShop)

	// Add a dog
	addNpcWithDialogue(hub, 1, 22, 10, "Gus", 40, 8, []string{"Woof!"})

	// Merchant selling faerie dust
	oldManShop := ds.NewInventory()
	oldManShop.AddItem(*items.FaerieDust, 100)
	addNpcMerchant(hub, 3, -6, 1, "Old man", 72, 0, oldManShop)

	// Actually start the server
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

// Add an NPC merchant to the game
func addNpcMerchant(hub *central.Hub, levelId, x, y int32, name string, spriteRegionX int32, spriteRegionY int32, shop *ds.Inventory) {
	dummyClient, err := conn.NewDummyClient(hub, &states.NpcMerchant{
		LevelId: levelId,
		Actor:   objs.NewActor(levelId, x, y, name, spriteRegionX, spriteRegionY, 0),
		Shop:    shop,
	})
	if err != nil {
		log.Fatalf("Error creating dummy client: %v", err)
	}
	hub.RegisterChan <- dummyClient
	log.Printf("Added %s to the game", name)
}

// Add an NPC with lines to the game
func addNpcWithDialogue(hub *central.Hub, levelId, x, y int32, name string, spriteRegionX int32, spriteRegionY int32, dialogue []string) {
	dummyClient, err := conn.NewDummyClient(hub, &states.NpcWithDialogue{
		LevelId:  levelId,
		Actor:    objs.NewActor(levelId, x, y, name, spriteRegionX, spriteRegionY, 0),
		Dialogue: dialogue,
	})
	if err != nil {
		log.Fatalf("Error creating dummy client: %v", err)
	}
	hub.RegisterChan <- dummyClient
	log.Printf("Added %s to the game", name)
}
