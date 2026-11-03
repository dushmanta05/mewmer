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
			err := ProcessMedia(ctx, job)
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

func ProcessMedia(ctx context.Context, job models.ProcessingJob) error {
	ctxTimeout, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	var filter string
	outW := job.OutW
	outH := job.OutH
	if outW <= 0 {
		outW = job.CropW
	}
	if outH <= 0 {
		outH = job.CropH
	}

	if job.CropW > 0 && job.CropH > 0 {
		filter = fmt.Sprintf("crop=%d:%d:%d:%d,scale=%d:%d,fps=18", job.CropW, job.CropH, job.CropX, job.CropY, outW, outH)
	} else if job.IsAnimated {
		filter = "scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000,fps=18"
	} else {
		filter = "scale=512:512:force_original_aspect_ratio=decrease,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000"
	}

	var args []string

	if job.IsAnimated {
		args = []string{
			"-y",
			"-i", job.InputPath,
			"-t", "6",
			"-vf", filter,
			"-vcodec", "libwebp",
			"-lossless", "0",
			"-compression_level", "4",
			"-q:v", "65",
			"-loop", "0",
			"-an",
			"-vsync", "0",
			job.OutputPath,
		}
	} else {
		args = []string{
			"-y",
			"-i", job.InputPath,
			"-vf", filter,
			"-vcodec", "libwebp",
			"-lossless", "0",
			"-q:v", "80",
			job.OutputPath,
		}
	}

	cmd := exec.CommandContext(ctxTimeout, "ffmpeg", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg failed: %s: %w", string(out), err)
	}

	return nil
}

func ConvertToWhatsAppWebP(ctx context.Context, inputPath, outputPath string, isAnimated bool) error {
	return ProcessMedia(ctx, models.ProcessingJob{
		InputPath:  inputPath,
		OutputPath: outputPath,
		IsAnimated: isAnimated,
	})
}
