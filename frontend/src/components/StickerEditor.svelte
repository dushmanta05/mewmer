<script lang="ts">
  import { onMount } from 'svelte';

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
  let showSafeMargin = $state(true);
  let showBrandMark = $state(true);
  let brandPosition = $state<'bottom-right' | 'bottom-left' | 'top-right'>('bottom-right');
  let useTransparentPadding = $state(true);
  let isExporting = $state(false);
  let isPublishing = $state(false);
  let showPublishModal = $state(false);
  let packTitle = $state('My Sticker Pack');
  let packPublisher = $state('Anonymous · mewmer.com');
  let exportSuccessMsg = $state('');

  let isDragging = false;
  let dragStartX = 0;
  let dragStartY = 0;
  let startOffsetX = 0;
  let startOffsetY = 0;

  function onPointerDown(e: PointerEvent) {
    if (!loadedImg) return;
    isDragging = true;
    dragStartX = e.clientX;
    dragStartY = e.clientY;
    startOffsetX = imageOffsetX;
    startOffsetY = imageOffsetY;
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  }

  function onPointerMove(e: PointerEvent) {
    if (!isDragging) return;
    const dx = e.clientX - dragStartX;
    const dy = e.clientY - dragStartY;
    const scaleFactor = 512 / (canvas?.clientWidth || 512);
    imageOffsetX = startOffsetX + dx * scaleFactor;
    imageOffsetY = startOffsetY + dy * scaleFactor;
  }

  function onPointerUp(e: PointerEvent) {
    if (isDragging) {
      isDragging = false;
      try {
        (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
      } catch {}
    }
  }

  function resetFraming() {
    imageScale = 1;
    imageOffsetX = 0;
    imageOffsetY = 0;
  }

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

    ctx.clearRect(0, 0, 512, 512);

    if (loadedImg && loadedImg.complete) {
      if (!useTransparentPadding) {
        ctx.save();
        ctx.filter = 'blur(16px)';
        ctx.drawImage(loadedImg, -20, -20, 552, 552);
        ctx.fillStyle = 'rgba(0, 0, 0, 0.35)';
        ctx.fillRect(0, 0, 512, 512);
        ctx.restore();
      }

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

    ctx.textAlign = 'center';
    ctx.font = `900 ${fontSize}px ${fontFamily}, Impact, sans-serif`;
    ctx.fillStyle = textColor;
    ctx.strokeStyle = strokeColor;
    ctx.lineWidth = strokeWidth;
    ctx.lineJoin = 'round';

    if (topText.trim()) {
      ctx.strokeText(topText.toUpperCase(), 256, fontSize + 20);
      ctx.fillText(topText.toUpperCase(), 256, fontSize + 20);
    }

    if (bottomText.trim()) {
      ctx.strokeText(bottomText.toUpperCase(), 256, 512 - 25);
      ctx.fillText(bottomText.toUpperCase(), 256, 512 - 25);
    }

    if (showBrandMark) {
      ctx.save();
      const brandFontSize = 13;
      ctx.font = `700 ${brandFontSize}px Inter, system-ui, sans-serif`;
      const brandText = 'mewmer.com';
      const textWidth = ctx.measureText(brandText).width;
      const padX = 8;
      const badgeHeight = 24;
      const badgeWidth = textWidth + padX * 2 + 16;

      let bx = 512 - 20 - badgeWidth;
      let by = 512 - 20 - badgeHeight;

      if (brandPosition === 'bottom-left') {
        bx = 20;
        by = 512 - 20 - badgeHeight;
      } else if (brandPosition === 'top-right') {
        bx = 512 - 20 - badgeWidth;
        by = 20;
      }

      ctx.fillStyle = 'rgba(11, 15, 23, 0.85)';
      ctx.strokeStyle = 'rgba(139, 92, 246, 0.45)';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      if (ctx.roundRect) {
        ctx.roundRect(bx, by, badgeWidth, badgeHeight, 6);
      } else {
        ctx.rect(bx, by, badgeWidth, badgeHeight);
      }
      ctx.fill();
      ctx.stroke();

      ctx.font = '12px system-ui, sans-serif';
      ctx.textBaseline = 'middle';
      ctx.fillText('🐱', bx + 6, by + badgeHeight / 2);

      ctx.font = `700 ${brandFontSize}px Inter, system-ui, sans-serif`;
      ctx.fillStyle = '#DDD6FE';
      ctx.textAlign = 'left';
      ctx.fillText(brandText, bx + 22, by + badgeHeight / 2);
      ctx.restore();
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

  $effect(() => {
    const _ = [
      topText,
      bottomText,
      fontSize,
      textColor,
      strokeColor,
      strokeWidth,
      fontFamily,
      imageScale,
      imageOffsetX,
      imageOffsetY,
      showBrandMark,
      brandPosition,
      useTransparentPadding,
    ];
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
    } catch {
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
        await downloadSticker();
        showNotice('Downloaded WebP sticker! Drag it directly into any WhatsApp chat.');
      }
    } catch {
      await downloadSticker();
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

  async function publishPack() {
    isPublishing = true;
    try {
      const blob = await getWebpBlob();
      if (!blob) throw new Error('Failed to generate sticker image');

      const formData = new FormData();
      formData.append('sticker', blob, 'sticker.webp');

      const uploadRes = await fetch('/api/v1/stickers/upload', {
        method: 'POST',
        body: formData,
      });

      if (!uploadRes.ok) {
        throw new Error('Upload failed');
      }

      const uploadData = await uploadRes.json();
      const stickerUrl = uploadData.imageUrl;

      const packRes = await fetch('/api/v1/packs', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: packTitle || 'Mewmer Sticker',
          publisher: packPublisher || 'Creator · mewmer.com',
          trayImageUrl: stickerUrl,
          stickerUrls: [stickerUrl],
          isAnimated: false,
          isPublic: true,
        }),
      });

      if (!packRes.ok) {
        throw new Error('Failed to create sticker pack');
      }

      const packData = await packRes.json();
      showPublishModal = false;
      showNotice(`Sticker pack created! Opening /packs/${packData.id}...`);
      setTimeout(() => {
        window.location.href = `/packs/${packData.id}`;
      }, 1000);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Error creating pack';
      showNotice(`Failed to save pack: ${msg}`);
    } finally {
      isPublishing = false;
    }
  }
</script>

<div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
  <div class="lg:col-span-6 flex flex-col items-center">
    <div class="w-full max-w-[512px] bg-dark-card border border-dark-border rounded-2xl p-4 shadow-2xl">
      <div
        class="relative w-full aspect-square rounded-xl overflow-hidden border border-dark-border/80 flex items-center justify-center"
        style="background-image: linear-gradient(45deg, #111827 25%, transparent 25%), linear-gradient(-45deg, #111827 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #111827 75%), linear-gradient(-45deg, transparent 75%, #111827 75%); background-size: 20px 20px; background-position: 0 0, 0 10px, 10px -10px, -10px 0px; background-color: #0B0F17;"
      >
        <canvas
          bind:this={canvas}
          width="512"
          height="512"
          class="w-full h-full object-contain cursor-grab active:cursor-grabbing touch-none select-none"
          onpointerdown={onPointerDown}
          onpointermove={onPointerMove}
          onpointerup={onPointerUp}
          onpointercancel={onPointerUp}
        ></canvas>

        {#if showSafeMargin}
          <div class="pointer-events-none absolute inset-4 border border-dashed border-brand-400/60 rounded-xl flex items-start justify-between p-2">
            <span class="text-[10px] font-mono text-brand-300 bg-dark-bg/85 px-1.5 py-0.5 rounded border border-brand-500/30">
              16px Safe Margin
            </span>
          </div>
        {/if}

        <span class="absolute top-3 left-3 px-2 py-1 text-[11px] font-mono font-medium rounded-md bg-dark-bg/80 backdrop-blur border border-dark-border text-slate-300">
          512 × 512 WebP
        </span>
      </div>

      <div class="mt-3 flex items-center justify-between gap-2 px-1">
        <div class="flex items-center gap-1.5">
          <button
            type="button"
            onclick={() => showSafeMargin = !showSafeMargin}
            class="px-2.5 py-1 rounded-lg text-[11px] font-medium border transition-colors {showSafeMargin ? 'bg-brand-500/20 border-brand-500/40 text-brand-300' : 'bg-dark-bg border-dark-border text-slate-400'}"
          >
            Safe Zone (16px)
          </button>
          <button
            type="button"
            onclick={() => useTransparentPadding = !useTransparentPadding}
            class="px-2.5 py-1 rounded-lg text-[11px] font-medium border transition-colors {useTransparentPadding ? 'bg-brand-500/20 border-brand-500/40 text-brand-300' : 'bg-dark-bg border-dark-border text-slate-400'}"
          >
            {useTransparentPadding ? 'Transparent' : 'Blur BG'}
          </button>
        </div>

        {#if imageScale !== 1 || imageOffsetX !== 0 || imageOffsetY !== 0}
          <button
            type="button"
            onclick={resetFraming}
            class="text-[11px] font-medium text-amber-400 hover:text-amber-300 transition-colors"
          >
            Reset Framing
          </button>
        {/if}
      </div>

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

        <button
          onclick={() => showPublishModal = true}
          class="w-full py-2.5 px-3 rounded-xl bg-gradient-to-r from-brand-600 to-brand-500 hover:from-brand-500 hover:to-brand-400 text-white font-semibold text-xs flex items-center justify-center gap-2 transition-all shadow-md shadow-brand-500/20"
        >
          <span>📦</span>
          <span>Publish to Sticker Pack</span>
        </button>
      </div>

      {#if showPublishModal}
        <div class="fixed inset-0 z-50 bg-black/75 backdrop-blur-sm flex items-center justify-center p-4">
          <div class="bg-dark-card border border-dark-border rounded-2xl p-6 max-w-md w-full shadow-2xl space-y-4">
            <div class="flex items-center justify-between">
              <h4 class="text-base font-bold text-white flex items-center gap-2">
                <span>📦</span>
                <span>Publish Sticker Pack</span>
              </h4>
              <button
                type="button"
                onclick={() => showPublishModal = false}
                class="text-slate-400 hover:text-white"
              >
                ✕
              </button>
            </div>

            <p class="text-xs text-dark-muted">
              Published packs are shared publicly on Mewmer so anyone can view, download, or share them into WhatsApp.
            </p>

            <div class="space-y-3">
              <div>
                <label class="block text-xs font-semibold text-slate-300 mb-1">Pack Title</label>
                <input
                  type="text"
                  bind:value={packTitle}
                  placeholder="e.g. My Cat Reactions"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-dark-bg border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white"
                />
              </div>

              <div>
                <label class="block text-xs font-semibold text-slate-300 mb-1">Publisher Name</label>
                <input
                  type="text"
                  bind:value={packPublisher}
                  placeholder="e.g. Dushmanta · mewmer.com"
                  class="w-full px-3.5 py-2.5 rounded-xl bg-dark-bg border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white"
                />
              </div>
            </div>

            <div class="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onclick={() => showPublishModal = false}
                class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-300 hover:bg-dark-border"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isPublishing}
                onclick={publishPack}
                class="px-5 py-2 rounded-xl bg-brand-500 hover:bg-brand-400 disabled:opacity-50 text-white font-semibold text-xs flex items-center gap-1.5"
              >
                {#if isPublishing}
                  <span class="animate-spin">⏳</span>
                  <span>Publishing...</span>
                {:else}
                  <span>Publish Pack</span>
                {/if}
              </button>
            </div>
          </div>
        </div>
      {/if}

      {#if exportSuccessMsg}
        <div class="mt-3 p-3 rounded-xl bg-brand-500/20 border border-brand-500/40 text-brand-200 text-xs text-center animate-fade-in">
          {exportSuccessMsg}
        </div>
      {/if}
    </div>
  </div>

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

    <div class="pt-4 border-t border-dark-border space-y-3">
      <div class="flex items-center justify-between">
        <label class="text-xs font-semibold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
          <span>🏷️</span>
          <span>Brand Watermark</span>
        </label>
        <button
          type="button"
          onclick={() => showBrandMark = !showBrandMark}
          class="text-xs font-medium px-2 py-0.5 rounded-lg border transition-colors {showBrandMark ? 'bg-brand-500/20 border-brand-500/40 text-brand-300' : 'bg-dark-bg border-dark-border text-slate-400'}"
        >
          {showBrandMark ? 'Enabled' : 'Disabled'}
        </button>
      </div>

      {#if showBrandMark}
        <div class="flex items-center gap-2">
          <span class="text-xs text-dark-muted">Position:</span>
          <button
            type="button"
            onclick={() => brandPosition = 'bottom-right'}
            class="text-xs px-2.5 py-1 rounded-lg border transition-colors {brandPosition === 'bottom-right' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400'}"
          >
            Bottom Right
          </button>
          <button
            type="button"
            onclick={() => brandPosition = 'bottom-left'}
            class="text-xs px-2.5 py-1 rounded-lg border transition-colors {brandPosition === 'bottom-left' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400'}"
          >
            Bottom Left
          </button>
          <button
            type="button"
            onclick={() => brandPosition = 'top-right'}
            class="text-xs px-2.5 py-1 rounded-lg border transition-colors {brandPosition === 'top-right' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400'}"
          >
            Top Right
          </button>
        </div>
      {/if}
    </div>
  </div>
</div>
