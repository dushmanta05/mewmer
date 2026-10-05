package processor

import (
	"context"
	"fmt"
	"log"
	"os/exec"
	"time"

	"github.com/dushmanta05/mewmer/server/internal/models"
)

type WorkerPool struct {
	jobsChan   chan models.ProcessingJob
	maxWorkers int
}

func NewWorkerPool(maxWorkers int, queueSize int) *WorkerPool {
	return &WorkerPool{
		jobsChan:   make(chan models.ProcessingJob, queueSize),
		maxWorkers: maxWorkers,
	}
}

func (wp *WorkerPool) Start(ctx context.Context) {
	log.Printf("🚀 Starting FFmpeg worker pool with %d concurrent workers", wp.maxWorkers)
	for i := 1; i <= wp.maxWorkers; i++ {
		go wp.worker(ctx, i)
	}
}

func (wp *WorkerPool) Enqueue(job models.ProcessingJob) error {
	select {
	case wp.jobsChan <- job:
		return nil
	default:
		return fmt.Errorf("conversion queue is full, please try again shortly")
	}
}

func (wp *WorkerPool) worker(ctx context.Context, id int) {
	for {
		select {
		case <-ctx.Done():
			return
		case job := <-wp.jobsChan:
			log.Printf("[Worker %d] Processing media %s -> %s", id, job.InputPath, job.OutputPath)
			err := ConvertToWhatsAppWebP(ctx, job.InputPath, job.OutputPath, job.IsAnimated)
			if job.ErrChan != nil {
				job.ErrChan <- err
			}
			if err != nil {
				log.Printf("[Worker %d] Conversion error: %v", id, err)
			} else {
				log.Printf("[Worker %d] Conversion completed successfully!", id)
			}
		}
	}
}

// ConvertToWhatsAppWebP runs FFmpeg to produce strict 512x512 WhatsApp-compliant WebP files
func ConvertToWhatsAppWebP(ctx context.Context, inputPath, outputPath string, isAnimated bool) error {
	// Timeout after 30 seconds to prevent rogue files from hanging
	ctxTimeout, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	var args []string

	if isAnimated {
		// WhatsApp Animated WebP rules:
		// 512x512 padded to aspect ratio with transparency, <= 500KB, max 20fps, looped
		args = []string{
			"-y",
			"-i", inputPath,
			"-t", "5", // Max 5 seconds
			"-vf", "scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000,fps=18",
			"-vcodec", "libwebp",
			"-lossless", "0",
			"-compression_level", "4",
			"-q:v", "65",
			"-loop", "0",
			"-an",
			"-vsync", "0",
			outputPath,
		}
	} else {
		// Static image conversion
		args = []string{
			"-y",
			"-i", inputPath,
			"-vf", "scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000",
			"-vcodec", "libwebp",
			"-lossless", "0",
			"-q:v", "80",
			outputPath,
		}
	}

	cmd := exec.CommandContext(ctxTimeout, "ffmpeg", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg failed: %s: %w", string(out), err)
	}

	return nil
}
