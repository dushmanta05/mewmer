<script lang="ts">
  import { onMount } from 'svelte';

  // State variables
  let canvas: HTMLCanvasElement;
  let imageSource = $state<string | null>(null);
  let topText = $state('WHEN CODE WORKS');
  let bottomText = $state('ON FIRST TRY');
  let fontSize = $state(42);
  let textColor = $state('#FFFFFF');
  let strokeColor = $state('#000000');
  let strokeWidth = $state(6);
  let fontFamily = $state('Impact');
  let imageScale = $state(1);
  let imageOffsetX = $state(0);
  let imageOffsetY = $state(0);
  let isExporting = $state(false);
  let exportSuccessMsg = $state('');

  // Sample templates to kickstart immediately
  const sampleTemplates = [
    { name: 'Cat Smile', url: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=512&auto=format&fit=crop&q=80' },
    { name: 'Surprised Dog', url: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=512&auto=format&fit=crop&q=80' },
    { name: 'Cool Cat', url: 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=512&auto=format&fit=crop&q=80' }
  ];

  let loadedImg: HTMLImageElement | null = null;

  function renderCanvas() {
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Clear 512x512 canvas with transparent background
    ctx.clearRect(0, 0, 512, 512);

    if (loadedImg && loadedImg.complete) {
      // Calculate aspect ratio fit
      const iw = loadedImg.width;
      const ih = loadedImg.height;
      const aspect = iw / ih;

      let dw = 512;
      let dh = 512;

      if (aspect > 1) {
        dh = 512 / aspect;
      } else {
        dw = 512 * aspect;
      }

      dw *= imageScale;
      dh *= imageScale;

      const dx = (512 - dw) / 2 + imageOffsetX;
      const dy = (512 - dh) / 2 + imageOffsetY;

      ctx.drawImage(loadedImg, dx, dy, dw, dh);
    }

    // Render captions
    ctx.textAlign = 'center';
    ctx.font = `900 ${fontSize}px ${fontFamily}, Impact, sans-serif`;
    ctx.fillStyle = textColor;
    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = strokeWidth;
    ctx.lineJoin = 'round';

    // Top text
    if (topText.trim()) {
      ctx.strokeText(topText.toUpperCase(), 256, fontSize + 20);
      ctx.fillText(topText.toUpperCase(), 256, fontSize + 20);
    }

    // Bottom text
    if (bottomText.trim()) {
      ctx.strokeText(bottomText.toUpperCase(), 256, 512 - 25);
      ctx.fillText(bottomText.toUpperCase(), 256, 512 - 25);
    }
  }

  function loadImage(src: string) {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      loadedImg = img;
      imageSource = src;
      renderCanvas();
    };
    img.src = src;
  }

  function handleFileUpload(e: Event) {
    const target = e.target as HTMLInputElement;
    const file = target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      if (event.target?.result) {
        loadImage(event.target.result as string);
      }
    };
    reader.readAsDataURL(file);
  }

  // Effect to re-render whenever state changes
  $effect(() => {
    // depend on reactive variables
    const _ = [topText, bottomText, fontSize, textColor, strokeColor, strokeWidth, fontFamily, imageScale, imageOffsetX, imageOffsetY];
    renderCanvas();
  });

  onMount(() => {
    loadImage(sampleTemplates[0].url);
  });

  async function getWebpBlob(): Promise<Blob | null> {
    return new Promise((resolve) => {
      canvas.toBlob(
        (blob) => resolve(blob),
        'image/webp',
        0.85
      );
    });
  }

  async function downloadSticker() {
    const blob = await getWebpBlob();
    if (!blob) return;

    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `mewmer_sticker_${Date.now()}.webp`;
    a.click();
    URL.revokeObjectURL(url);
    showNotice('Downloaded 512x512 WebP sticker!');
  }

  async function copyToClipboard() {
    try {
      const blob = await new Promise<Blob | null>((resolve) =>
        canvas.toBlob((b) => resolve(b), 'image/png')
      );
      if (!blob) return;

      await navigator.clipboard.write([
        new ClipboardItem({ 'image/png': blob })
      ]);
      showNotice('Sticker copied to clipboard! Paste directly into WhatsApp Web.');
    } catch (err) {
      showNotice('Copy failed. Try downloading the WebP instead.');
    }
  }

  async function shareToWhatsApp() {
    isExporting = true;
    try {
      const blob = await getWebpBlob();
      if (!blob) return;

      const file = new File([blob], 'mewmer_sticker.webp', { type: 'image/webp' });

      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        await navigator.share({
          files: [file],
          title: 'Mewmer Sticker',
          text: 'Made with Mewmer'
        });
        showNotice('Sticker shared! In WhatsApp chat, tap "Add to Favorites" to keep it forever.');
      } else {
        // Fallback for desktop: download and inform
        await downloadSticker();
        showNotice('Downloaded WebP sticker! Drag it directly into any WhatsApp chat.');
      }
    } catch (err) {
      console.error(err);
    } finally {
      isExporting = false;
    }
  }

  function showNotice(msg: string) {
    exportSuccessMsg = msg;
    setTimeout(() => {
      exportSuccessMsg = '';
    }, 4500);
  }
</script>

<div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
  <!-- Left Side: Interactive 512x512 Canvas Preview -->
  <div class="lg:col-span-6 flex flex-col items-center">
    <div class="w-full max-w-[512px] bg-dark-card border border-dark-border rounded-2xl p-4 shadow-2xl">
      <!-- Checkerboard transparency background container -->
      <div
        class="relative w-full aspect-square rounded-xl overflow-hidden border border-dark-border/80 flex items-center justify-center"
        style="background-image: linear-gradient(45deg, #111827 25%, transparent 25%), linear-gradient(-45deg, #111827 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #111827 75%), linear-gradient(-45deg, transparent 75%, #111827 75%); background-size: 20px 20px; background-position: 0 0, 0 10px, 10px -10px, -10px 0px; background-color: #0B0F17;"
      >
        <canvas
          bind:this={canvas}
          width="512"
          height="512"
          class="w-full h-full object-contain"
        ></canvas>

        <span class="absolute top-3 left-3 px-2 py-1 text-[11px] font-mono font-medium rounded-md bg-dark-bg/80 backdrop-blur border border-dark-border text-slate-300">
          512 × 512 WebP (WhatsApp Compliant)
        </span>
      </div>

      <!-- Action Buttons -->
      <div class="mt-4 flex flex-col gap-2.5">
        <button
          onclick={shareToWhatsApp}
          disabled={isExporting}
          class="w-full py-3 px-4 rounded-xl bg-whatsapp hover:bg-whatsapp-hover active:scale-[0.99] text-white font-bold text-sm flex items-center justify-center gap-2 shadow-lg shadow-whatsapp/20 transition-all duration-200"
        >
          <span class="text-lg">💬</span>
          <span>Send Single Sticker to WhatsApp</span>
        </button>

        <div class="grid grid-cols-2 gap-2">
          <button
            onclick={downloadSticker}
            class="py-2.5 px-3 rounded-xl bg-dark-border hover:bg-slate-700 text-slate-200 font-semibold text-xs flex items-center justify-center gap-2 transition-colors"
          >
            <span>💾</span>
            <span>Download .WebP</span>
          </button>
          <button
            onclick={copyToClipboard}
            class="py-2.5 px-3 rounded-xl bg-dark-border hover:bg-slate-700 text-slate-200 font-semibold text-xs flex items-center justify-center gap-2 transition-colors"
          >
            <span>📋</span>
            <span>Copy to Clipboard</span>
          </button>
        </div>
      </div>

      <!-- Live Notification Banner -->
      {#if exportSuccessMsg}
        <div class="mt-3 p-3 rounded-xl bg-brand-500/20 border border-brand-500/40 text-brand-200 text-xs text-center animate-fade-in">
          {exportSuccessMsg}
        </div>
      {/if}
    </div>
  </div>

  <!-- Right Side: Customization Controls -->
  <div class="lg:col-span-6 bg-dark-card border border-dark-border rounded-2xl p-6 shadow-xl space-y-6">
    <div>
      <h3 class="text-lg font-bold text-white flex items-center gap-2">
        <span>🎨</span>
        <span>Sticker Studio</span>
      </h3>
      <p class="text-xs text-dark-muted mt-1">
        Generated 100% locally in your browser for zero latency and instant high-res export.
      </p>
    </div>

    <!-- Image Upload & Preset selector -->
    <div class="space-y-3">
      <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider">
        Choose Image / GIF
      </label>
      <div class="flex items-center gap-3">
        <label class="flex-1 cursor-pointer py-2.5 px-4 rounded-xl border border-dashed border-brand-500/40 hover:border-brand-500 bg-brand-500/5 hover:bg-brand-500/10 text-center text-xs font-medium text-brand-300 transition-colors">
          <span>📁 Upload from device</span>
          <input type="file" accept="image/*,.gif" class="hidden" onchange={handleFileUpload} />
        </label>
      </div>

      <!-- Quick sample presets -->
      <div class="flex items-center gap-2 pt-1">
        <span class="text-xs text-dark-muted">Or try:</span>
        {#each sampleTemplates as template}
          <button
            type="button"
            onclick={() => loadImage(template.url)}
            class="text-xs px-2.5 py-1 rounded-lg bg-dark-bg border border-dark-border text-slate-300 hover:text-white hover:border-brand-500 transition-colors"
          >
            {template.name}
          </button>
        {/each}
      </div>
    </div>

    <!-- Text Captions -->
    <div class="space-y-4 pt-2 border-t border-dark-border">
      <div>
        <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
          Top Caption
        </label>
        <input
          type="text"
          bind:value={topText}
          placeholder="TOP TEXT..."
          class="w-full px-3.5 py-2.5 rounded-xl bg-dark-bg border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white placeholder-slate-500"
        />
      </div>

      <div>
        <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
          Bottom Caption
        </label>
        <input
          type="text"
          bind:value={bottomText}
          placeholder="BOTTOM TEXT..."
          class="w-full px-3.5 py-2.5 rounded-xl bg-dark-bg border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white placeholder-slate-500"
        />
      </div>
    </div>

    <!-- Typography & Styling Adjustments -->
    <div class="grid grid-cols-2 gap-4 pt-2 border-t border-dark-border">
      <div>
        <label class="block text-xs font-semibold text-slate-300 mb-1.5">Font Size ({fontSize}px)</label>
        <input
          type="range"
          min="20"
          max="80"
          bind:value={fontSize}
          class="w-full accent-brand-500"
        />
      </div>

      <div>
        <label class="block text-xs font-semibold text-slate-300 mb-1.5">Image Zoom</label>
        <input
          type="range"
          min="0.5"
          max="2"
          step="0.05"
          bind:value={imageScale}
          class="w-full accent-brand-500"
        />
      </div>

      <div>
        <label class="block text-xs font-semibold text-slate-300 mb-1.5">Text Color</label>
        <div class="flex items-center gap-2">
          <input
            type="color"
            bind:value={textColor}
            class="w-8 h-8 rounded-lg cursor-pointer bg-transparent border-0"
          />
          <span class="text-xs font-mono text-slate-400">{textColor}</span>
        </div>
      </div>

      <div>
        <label class="block text-xs font-semibold text-slate-300 mb-1.5">Outline Color</label>
        <div class="flex items-center gap-2">
          <input
            type="color"
            bind:value={strokeColor}
            class="w-8 h-8 rounded-lg cursor-pointer bg-transparent border-0"
          />
          <span class="text-xs font-mono text-slate-400">{strokeColor}</span>
        </div>
      </div>
    </div>
  </div>
</div>
