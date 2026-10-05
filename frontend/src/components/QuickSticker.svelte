<script lang="ts">
  import { onMount } from 'svelte';

  let canvas: HTMLCanvasElement;
  let topText = $state('ME SEEING');
  let bottomText = $state('THIS STICKER');
  let loadedImg: HTMLImageElement | null = null;
  let isSharing = $state(false);
  let feedback = $state('');

  const templates = [
    { name: '😼 Smug Cat', url: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=512&auto=format&fit=crop&q=80' },
    { name: '🐶 Surprised Dog', url: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=512&auto=format&fit=crop&q=80' },
    { name: '😎 Cool Cat', url: 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=512&auto=format&fit=crop&q=80' },
    { name: '🐹 Shocked', url: 'https://images.unsplash.com/photo-1425082661705-1834bfd09dca?w=512&auto=format&fit=crop&q=80' },
  ];

  function render() {
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, 512, 512);

    if (loadedImg && loadedImg.complete) {
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

      const dx = (512 - dw) / 2;
      const dy = (512 - dh) / 2;

      ctx.drawImage(loadedImg, dx, dy, dw, dh);
    }

    ctx.textAlign = 'center';
    ctx.font = '900 44px Impact, "Arial Black", sans-serif';
    ctx.fillStyle = '#FFFFFF';
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 6;
    ctx.lineJoin = 'round';

    if (topText.trim()) {
      ctx.strokeText(topText.toUpperCase(), 256, 64);
      ctx.fillText(topText.toUpperCase(), 256, 64);
    }

    if (bottomText.trim()) {
      ctx.strokeText(bottomText.toUpperCase(), 256, 480);
      ctx.fillText(bottomText.toUpperCase(), 256, 480);
    }
  }

  function loadTemplate(url: string) {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      loadedImg = img;
      render();
    };
    img.src = url;
  }

  function onFileSelected(e: Event) {
    const input = e.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      if (event.target?.result) {
        loadTemplate(event.target.result as string);
      }
    };
    reader.readAsDataURL(file);
  }

  $effect(() => {
    const _ = [topText, bottomText];
    render();
  });

  onMount(() => {
    loadTemplate(templates[0].url);
  });

  async function getWebpBlob(): Promise<Blob | null> {
    return new Promise((resolve) => {
      canvas.toBlob((b) => resolve(b), 'image/webp', 0.85);
    });
  }

  async function shareDirectToWhatsApp() {
    isSharing = true;
    try {
      const blob = await getWebpBlob();
      if (!blob) return;

      const file = new File([blob], 'mewmer-sticker.webp', { type: 'image/webp' });

      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        await navigator.share({
          files: [file],
          title: 'Mewmer Sticker',
          text: 'Made with Mewmer'
        });
        showMsg('Sticker sent! Tap ⭐ "Add to Favorites" in WhatsApp to keep it.');
      } else {
        await downloadWebp();
        showMsg('Downloaded 512x512 WebP! Drag or send directly to any WhatsApp chat.');
      }
    } catch (err) {
      if ((err as Error).name !== 'AbortError') {
        await downloadWebp();
      }
    } finally {
      isSharing = false;
    }
  }

  async function downloadWebp() {
    const blob = await getWebpBlob();
    if (!blob) return;
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `sticker_${Date.now()}.webp`;
    a.click();
    URL.revokeObjectURL(url);
    showMsg('Sticker downloaded as 512x512 WebP!');
  }

  async function copySticker() {
    try {
      const blob = await new Promise<Blob | null>((resolve) =>
        canvas.toBlob((b) => resolve(b), 'image/png')
      );
      if (!blob) return;

      await navigator.clipboard.write([new ClipboardItem({ 'image/png': blob })]);
      showMsg('Copied to clipboard! Paste directly into WhatsApp Web.');
    } catch {
      await downloadWebp();
    }
  }

  function showMsg(text: string) {
    feedback = text;
    setTimeout(() => {
      feedback = '';
    }, 4500);
  }
</script>

<div class="w-full bg-dark-card/90 backdrop-blur-md border border-dark-border rounded-3xl p-5 sm:p-7 shadow-2xl">
  <div class="grid grid-cols-1 lg:grid-cols-12 gap-6 items-center">
    <div class="lg:col-span-5 flex flex-col items-center">
      <div
        class="relative w-full max-w-[340px] aspect-square rounded-2xl overflow-hidden border border-dark-border shadow-inner flex items-center justify-center"
        style="background-image: linear-gradient(45deg, #0B0F17 25%, transparent 25%), linear-gradient(-45deg, #0B0F17 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #0B0F17 75%), linear-gradient(-45deg, transparent 75%, #0B0F17 75%); background-size: 16px 16px; background-position: 0 0, 0 8px, 8px -8px, -8px 0px; background-color: #131B2E;"
      >
        <canvas
          bind:this={canvas}
          width="512"
          height="512"
          class="w-full h-full object-contain pointer-events-none"
        ></canvas>

        <span class="absolute top-2.5 left-2.5 px-2 py-0.5 text-[10px] font-mono rounded bg-dark-bg/80 border border-dark-border text-slate-300">
          512×512 WebP
        </span>
      </div>
    </div>

    <div class="lg:col-span-7 flex flex-col justify-between space-y-4">
      <div>
        <div class="flex items-center justify-between">
          <span class="text-xs font-bold uppercase tracking-wider text-brand-400">⚡ Quick Sticker Maker</span>
          <a href="/create" class="text-xs text-slate-400 hover:text-white transition-colors underline decoration-dark-border underline-offset-4">
            Open Advanced Studio →
          </a>
        </div>
        <h2 class="text-xl sm:text-2xl font-bold font-display text-white mt-1">
          Make & Share to WhatsApp Chat
        </h2>
      </div>

      <div class="space-y-2">
        <span class="text-xs font-medium text-slate-400">1. Pick an image or upload your own:</span>
        <div class="flex flex-wrap items-center gap-2">
          {#each templates as t}
            <button
              type="button"
              onclick={() => loadTemplate(t.url)}
              class="text-xs px-2.5 py-1.5 rounded-lg bg-dark-bg border border-dark-border hover:border-brand-500 hover:text-white text-slate-300 transition-colors"
            >
              {t.name}
            </button>
          {/each}
          <label class="text-xs px-3 py-1.5 rounded-lg bg-brand-500/15 border border-brand-500/30 text-brand-300 hover:bg-brand-500/25 cursor-pointer transition-colors">
            <span>+ Upload Photo</span>
            <input type="file" accept="image/*" class="hidden" onchange={onFileSelected} />
          </label>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-[11px] font-semibold text-slate-400 uppercase mb-1">Top Caption</label>
          <input
            type="text"
            bind:value={topText}
            placeholder="Top text..."
            class="w-full px-3 py-2 rounded-xl bg-dark-bg border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white placeholder-slate-500"
          />
        </div>
        <div>
          <label class="block text-[11px] font-semibold text-slate-400 uppercase mb-1">Bottom Caption</label>
          <input
            type="text"
            bind:value={bottomText}
            placeholder="Bottom text..."
            class="w-full px-3 py-2 rounded-xl bg-dark-bg border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white placeholder-slate-500"
          />
        </div>
      </div>

      <div class="pt-2 flex flex-col sm:flex-row items-center gap-3">
        <button
          onclick={shareDirectToWhatsApp}
          disabled={isSharing}
          class="w-full sm:flex-1 py-3 px-5 rounded-xl bg-whatsapp hover:bg-whatsapp-hover active:scale-[0.98] text-white font-bold text-sm flex items-center justify-center gap-2 shadow-lg shadow-whatsapp/25 transition-all"
        >
          <span class="text-lg">💬</span>
          <span>Share to WhatsApp Chat</span>
        </button>

        <div class="flex items-center gap-2 w-full sm:w-auto">
          <button
            onclick={downloadWebp}
            class="flex-1 sm:flex-initial py-3 px-3.5 rounded-xl bg-dark-bg hover:bg-slate-800 border border-dark-border text-slate-200 font-semibold text-xs flex items-center justify-center gap-1.5 transition-colors"
          >
            <span>💾</span>
            <span>WebP</span>
          </button>
          <button
            onclick={copySticker}
            class="flex-1 sm:flex-initial py-3 px-3.5 rounded-xl bg-dark-bg hover:bg-slate-800 border border-dark-border text-slate-200 font-semibold text-xs flex items-center justify-center gap-1.5 transition-colors"
          >
            <span>📋</span>
            <span>Copy</span>
          </button>
        </div>
      </div>

      {#if feedback}
        <div class="p-2.5 rounded-xl bg-brand-500/20 border border-brand-500/40 text-brand-200 text-xs text-center font-medium">
          {feedback}
        </div>
      {/if}
    </div>
  </div>
</div>
