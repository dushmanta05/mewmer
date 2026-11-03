<script lang="ts">
  import { onMount } from 'svelte';

  interface Sticker {
    id: string;
    packId: string;
    imageUrl: string;
    emojis?: string[];
    isAnimated: boolean;
  }

  interface PackData {
    id: string;
    title: string;
    publisher: string;
    trayImageUrl: string;
    isAnimated: boolean;
    isPublic: boolean;
    downloadsCount: number;
    createdAt: string;
    stickers: Sticker[];
  }

  let { packId = '' }: { packId?: string } = $props();

  let pack = $state<PackData | null>(null);
  let isLoading = $state(true);
  let errorMessage = $state('');
  let activeSticker = $state<Sticker | null>(null);
  let actionNotice = $state('');

  function showToast(msg: string) {
    actionNotice = msg;
    setTimeout(() => {
      actionNotice = '';
    }, 4000);
  }

  async function fetchPack() {
    isLoading = true;
    errorMessage = '';
    try {
      const id = packId || window.location.pathname.split('/').filter(Boolean).pop() || '';
      if (!id) {
        throw new Error('No pack identifier specified');
      }

      const res = await fetch(`/api/v1/packs/${id}`);
      if (!res.ok) {
        throw new Error(res.status === 404 ? 'Sticker pack not found' : 'Failed to load sticker pack');
      }

      const data: PackData = await res.json();
      pack = data;
    } catch (err: unknown) {
      errorMessage = err instanceof Error ? err.message : 'Error fetching sticker pack';
    } finally {
      isLoading = false;
    }
  }

  onMount(() => {
    fetchPack();
  });

  async function shareSticker(sticker: Sticker) {
    try {
      const res = await fetch(sticker.imageUrl);
      const blob = await res.blob();
      const file = new File([blob], 'mewmer_sticker.webp', { type: 'image/webp' });

      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        await navigator.share({
          files: [file],
          title: pack?.title || 'Mewmer Sticker',
          text: `Check out this sticker from ${pack?.title || 'Mewmer'}`,
        });
        showToast('Sticker shared to WhatsApp!');
      } else {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `sticker_${sticker.id}.webp`;
        a.click();
        URL.revokeObjectURL(url);
        showToast('Downloaded sticker WebP file');
      }
    } catch {
      showToast('Could not share sticker directly');
    }
  }

  async function copySticker(sticker: Sticker) {
    try {
      const res = await fetch(sticker.imageUrl);
      const blob = await res.blob();
      await navigator.clipboard.write([
        new ClipboardItem({ 'image/webp': blob }),
      ]);
      showToast('Copied sticker to clipboard! Paste directly into WhatsApp Web.');
    } catch {
      showToast('Clipboard copy failed. Try downloading instead.');
    }
  }

  async function sharePackLink() {
    const url = window.location.href;
    if (navigator.share) {
      try {
        await navigator.share({
          title: pack?.title || 'Mewmer Sticker Pack',
          text: `Check out the "${pack?.title}" sticker pack on Mewmer!`,
          url,
        });
        return;
      } catch {}
    }

    try {
      await navigator.clipboard.writeText(url);
      showToast('Pack link copied to clipboard!');
    } catch {
      showToast('Failed to copy link');
    }
  }
</script>

<div class="max-w-6xl mx-auto px-4 py-8 space-y-8">
  {#if isLoading}
    <div class="flex flex-col items-center justify-center py-24 space-y-4">
      <div class="w-12 h-12 rounded-full border-4 border-brand-500/30 border-t-brand-500 animate-spin"></div>
      <p class="text-sm font-medium text-slate-400">Loading sticker pack...</p>
    </div>
  {:else if errorMessage || !pack}
    <div class="bg-dark-card border border-dark-border rounded-2xl p-10 text-center max-w-md mx-auto space-y-4">
      <div class="w-14 h-14 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-400 flex items-center justify-center mx-auto text-2xl">
        ⚠️
      </div>
      <h3 class="text-lg font-bold text-white">Pack Not Found</h3>
      <p class="text-xs text-dark-muted">
        {errorMessage || 'The sticker pack you requested does not exist or has been removed.'}
      </p>
      <div class="pt-2">
        <a
          href="/"
          class="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-brand-500 hover:bg-brand-400 text-white text-xs font-semibold transition-colors"
        >
          <span>← Back to Community Packs</span>
        </a>
      </div>
    </div>
  {:else}
    <div class="bg-dark-card border border-dark-border rounded-2xl p-6 sm:p-8 shadow-xl">
      <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
        <div class="flex items-center gap-5">
          <img
            src={pack.trayImageUrl}
            alt={pack.title}
            class="w-20 h-20 sm:w-24 sm:h-24 rounded-2xl object-cover bg-dark-bg border border-dark-border shadow-inner p-1.5"
          />
          <div class="space-y-1.5">
            <div class="flex items-center gap-2.5">
              <h1 class="text-2xl sm:text-3xl font-display font-extrabold text-white tracking-tight">
                {pack.title}
              </h1>
              {#if pack.isAnimated}
                <span class="px-2 py-0.5 rounded-md bg-brand-500/20 border border-brand-500/40 text-brand-300 text-[10px] font-bold uppercase tracking-wider">
                  Animated
                </span>
              {:else}
                <span class="px-2 py-0.5 rounded-md bg-dark-bg border border-dark-border text-slate-400 text-[10px] font-bold uppercase tracking-wider">
                  Static
                </span>
              {/if}
            </div>

            <p class="text-xs text-dark-muted flex items-center gap-2">
              <span>By <strong class="text-slate-300">{pack.publisher}</strong></span>
              <span>•</span>
              <span>{pack.stickers.length} stickers</span>
            </p>
          </div>
        </div>

        <div class="flex flex-wrap sm:flex-nowrap items-center gap-3 w-full sm:w-auto">
          <button
            onclick={sharePackLink}
            class="flex-1 sm:flex-none px-4 py-2.5 rounded-xl bg-dark-border hover:bg-slate-700 text-slate-200 font-semibold text-xs flex items-center justify-center gap-2 transition-colors"
          >
            <span>🔗</span>
            <span>Share Pack</span>
          </button>

          <a
            href="/create"
            class="flex-1 sm:flex-none px-4 py-2.5 rounded-xl bg-brand-500 hover:bg-brand-400 text-white font-semibold text-xs flex items-center justify-center gap-2 transition-colors shadow-lg shadow-brand-500/25"
          >
            <span>✨</span>
            <span>Create Stickers</span>
          </a>
        </div>
      </div>

      <div class="mt-6 p-4 rounded-xl bg-whatsapp/10 border border-whatsapp/25 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
        <div class="flex items-center gap-3">
          <span class="text-2xl">📱</span>
          <div>
            <h4 class="text-xs font-bold text-white">Install into WhatsApp Keyboard Tray</h4>
            <p class="text-[11px] text-slate-300">
              Adding entire sticker packs to WhatsApp requires our native Android/iOS companion app. Single stickers can be sent directly below!
            </p>
          </div>
        </div>
        <a
          href={`mewmer://pack/${pack.id}`}
          class="shrink-0 px-3.5 py-1.5 rounded-lg bg-whatsapp hover:bg-whatsapp-hover text-white text-xs font-bold transition-colors"
        >
          Open in Mewmer App
        </a>
      </div>
    </div>

    {#if actionNotice}
      <div class="p-3 rounded-xl bg-brand-500/20 border border-brand-500/40 text-brand-200 text-xs text-center animate-fade-in">
        {actionNotice}
      </div>
    {/if}

    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-bold text-white flex items-center gap-2">
          <span>Stickers in this Pack</span>
          <span class="text-xs font-mono font-normal text-dark-muted">({pack.stickers.length})</span>
        </h2>
        <span class="text-xs text-dark-muted">Tap any sticker to inspect or share to chat</span>
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
        {#each pack.stickers as sticker}
          <div
            class="group relative bg-dark-card hover:bg-dark-cardHover border border-dark-border hover:border-brand-500/50 rounded-2xl p-3 flex flex-col items-center justify-between transition-all duration-200 aspect-square cursor-pointer"
            onclick={() => activeSticker = sticker}
          >
            <div
              class="w-full h-full rounded-xl flex items-center justify-center overflow-hidden p-2"
              style="background-image: linear-gradient(45deg, #0B0F17 25%, transparent 25%), linear-gradient(-45deg, #0B0F17 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #0B0F17 75%), linear-gradient(-45deg, transparent 75%, #0B0F17 75%); background-size: 16px 16px; background-position: 0 0, 0 8px, 8px -8px, -8px 0px; background-color: #131B2E;"
            >
              <img
                src={sticker.imageUrl}
                alt="Sticker"
                class="max-w-full max-h-full object-contain group-hover:scale-105 transition-transform"
                loading="lazy"
              />
            </div>

            <div class="absolute inset-x-2 bottom-2 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-1.5 p-1 rounded-lg bg-dark-bg/90 backdrop-blur border border-dark-border">
              <button
                type="button"
                onclick={(e) => { e.stopPropagation(); shareSticker(sticker); }}
                class="px-2 py-1 rounded bg-whatsapp text-white text-[10px] font-bold hover:bg-whatsapp-hover"
                title="Send to WhatsApp"
              >
                💬 Send
              </button>
              <button
                type="button"
                onclick={(e) => { e.stopPropagation(); copySticker(sticker); }}
                class="px-2 py-1 rounded bg-dark-border text-slate-200 text-[10px] font-bold hover:bg-slate-700"
                title="Copy"
              >
                📋
              </button>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  {#if activeSticker}
    <div class="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div class="bg-dark-card border border-dark-border rounded-2xl p-6 max-w-sm w-full shadow-2xl space-y-4">
        <div class="flex items-center justify-between">
          <h4 class="text-sm font-bold text-white">Sticker Preview</h4>
          <button
            type="button"
            onclick={() => activeSticker = null}
            class="text-slate-400 hover:text-white"
          >
            ✕
          </button>
        </div>

        <div
          class="w-full aspect-square rounded-xl flex items-center justify-center overflow-hidden border border-dark-border p-4"
          style="background-image: linear-gradient(45deg, #0B0F17 25%, transparent 25%), linear-gradient(-45deg, #0B0F17 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #0B0F17 75%), linear-gradient(-45deg, transparent 75%, #0B0F17 75%); background-size: 16px 16px; background-position: 0 0, 0 8px, 8px -8px, -8px 0px; background-color: #131B2E;"
        >
          <img
            src={activeSticker.imageUrl}
            alt="Sticker Full"
            class="max-w-full max-h-full object-contain"
          />
        </div>

        <div class="space-y-2 pt-2">
          <button
            onclick={() => {
              if (activeSticker) shareSticker(activeSticker);
            }}
            class="w-full py-2.5 px-4 rounded-xl bg-whatsapp hover:bg-whatsapp-hover text-white font-bold text-xs flex items-center justify-center gap-2 shadow-lg shadow-whatsapp/20 transition-all"
          >
            <span>💬</span>
            <span>Send to WhatsApp Chat</span>
          </button>

          <div class="grid grid-cols-2 gap-2">
            <button
              onclick={() => {
                if (activeSticker) copySticker(activeSticker);
              }}
              class="py-2 px-3 rounded-xl bg-dark-border hover:bg-slate-700 text-slate-200 font-semibold text-xs flex items-center justify-center gap-1.5 transition-colors"
            >
              <span>📋</span>
              <span>Copy</span>
            </button>
            <a
              href={activeSticker.imageUrl}
              download="sticker.webp"
              class="py-2 px-3 rounded-xl bg-dark-border hover:bg-slate-700 text-slate-200 font-semibold text-xs flex items-center justify-center gap-1.5 transition-colors"
            >
              <span>💾</span>
              <span>Download</span>
            </a>
          </div>
        </div>
      </div>
    </div>
  {/if}
</div>