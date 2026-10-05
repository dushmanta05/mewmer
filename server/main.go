package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/dushmanta05/mewmer/server/internal/config"
	"github.com/dushmanta05/mewmer/server/internal/database"
	"github.com/dushmanta05/mewmer/server/internal/handlers"
	"github.com/dushmanta05/mewmer/server/internal/processor"
)

func main() {
	cfg := config.Load()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// 1. Initialize PostgreSQL Connection Pool
	db, err := database.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Database connection error: %v", err)
	}
	defer db.Close()

	// 2. Initialize Media Processor Worker Pool
	workerPool := processor.NewWorkerPool(cfg.MaxWorkers, 100)
	workerPool.Start(ctx)

	// 3. Router & Middleware
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))

	// CORS configuration for Astro frontend
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"http://localhost:3031", "http://localhost:4321", "http://localhost:3000", "https://mewmer.com"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	h := handlers.New(cfg, db, workerPool)

	// API Routes
	r.Get("/health", h.Health)

	r.Route("/api/v1", func(r chi.Router) {
		r.Get("/packs", h.ListPacks)
		r.Get("/packs/{id}", h.GetPack)
		r.Post("/packs", h.CreatePack)
		r.Post("/stickers/upload", h.UploadSticker)
		r.Post("/stickers/process-animated", h.ProcessAnimated)
	})

	// Static file server for uploaded/converted stickers
	_ = os.MkdirAll(cfg.StorageDir, 0755)
	workDir, _ := os.Getwd()
	filesDir := http.Dir(fmt.Sprintf("%s/%s", workDir, cfg.StorageDir))
	r.Handle("/uploads/*", http.StripPrefix("/uploads", http.FileServer(filesDir)))

	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	go func() {
		log.Printf(" Mewmer Go Backend running on port :%s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server listen failed: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("Shutting down server gracefully...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("Server forced shutdown: %v", err)
	}
	log.Println("Server gracefully stopped.")
}
