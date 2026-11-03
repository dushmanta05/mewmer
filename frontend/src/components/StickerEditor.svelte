<script lang="ts">
  import { onMount } from 'svelte';

  interface TextLayer {
    id: string;
    text: string;
    x: number;
    y: number;
    fontSize: number;
    scale: number;
    rotation: number;
    color: string;
    strokeColor: string;
    strokeWidth: number;
    fontFamily: string;
    useCaps: boolean;
    isMemeStyle: boolean;
  }

  type AspectRatio = 'free' | '1:1' | '4:3' | '16:9' | '9:16' | '3:4' | 'custom';
  type ExportFormat = 'webp' | 'jpeg' | 'png';
  type ActiveTab = 'crop' | 'text' | 'export';

  let canvas = $state<HTMLCanvasElement | null>(null);
  let imageSource = $state<string | null>(null);
  let loadedImg: HTMLImageElement | null = null;
  let imgNaturalWidth = $state(800);
  let imgNaturalHeight = $state(600);

  let aspectRatio = $state<AspectRatio>('free');
  let cropX = $state(0);
  let cropY = $state(0);
  let cropW = $state(800);
  let cropH = $state(600);
  let outputWidth = $state(800);
  let outputHeight = $state(600);
  let lockOutputAspect = $state(true);

  let textLayers = $state<TextLayer[]>([
    {
      id: 'layer-1',
      text: 'WHEN CODE WORKS',
      x: 50,
      y: 16,
      fontSize: 42,
      scale: 1,
      rotation: 0,
      color: '#FFFFFF',
      strokeColor: '#000000',
      strokeWidth: 6,
      fontFamily: 'Impact',
      useCaps: true,
      isMemeStyle: true,
    },
    {
      id: 'layer-2',
      text: 'ON FIRST TRY',
      x: 50,
      y: 84,
      fontSize: 42,
      scale: 1,
      rotation: 0,
      color: '#FFFFFF',
      strokeColor: '#000000',
      strokeWidth: 6,
      fontFamily: 'Impact',
      useCaps: true,
      isMemeStyle: true,
    },
  ]);

  let selectedLayerId = $state<string | null>('layer-1');
  let activeTab = $state<ActiveTab>('crop');

  let exportFormat = $state<ExportFormat>('webp');
  let exportQuality = $state(0.92);
  let isExporting = $state(false);
  let exportNotice = $state('');

  let isDraggingLayer = false;
  let dragLayerId: string | null = null;

  const sampleTemplates = [
    { name: 'Landscape Cat', url: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=1200&auto=format&fit=crop&q=80' },
    { name: 'Square Doge', url: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800&auto=format&fit=crop&q=80' },
    { name: 'Portrait Kitten', url: 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=800&auto=format&fit=crop&q=80' }
  ];

  function renderCanvas() {
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    canvas.width = Math.max(32, cropW);
    canvas.height = Math.max(32, cropH);

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    if (loadedImg && loadedImg.complete) {
      ctx.drawImage(
        loadedImg,
        cropX,
        cropY,
        cropW,
        cropH,
        0,
        0,
        canvas.width,
        canvas.height
      );
    }

    const scaleFactor = canvas.width / 600;

    for (const layer of textLayers) {
      ctx.save();
      const posX = (layer.x / 100) * canvas.width;
      const posY = (layer.y / 100) * canvas.height;

      ctx.translate(posX, posY);
      ctx.rotate((layer.rotation * Math.PI) / 180);

      const actualFontSize = Math.max(12, Math.round(layer.fontSize * layer.scale * scaleFactor));
      ctx.font = `900 ${actualFontSize}px ${layer.fontFamily}, Impact, sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';

      const textToDraw = layer.useCaps ? layer.text.toUpperCase() : layer.text;

      if (layer.isMemeStyle) {
        ctx.strokeStyle = layer.strokeColor;
        ctx.lineWidth = Math.max(1, Math.round(layer.strokeWidth * scaleFactor));
        ctx.lineJoin = 'round';
        ctx.strokeText(textToDraw, 0, 0);
      }

      ctx.fillStyle = layer.color;
      ctx.fillText(textToDraw, 0, 0);

      if (layer.id === selectedLayerId) {
        const metrics = ctx.measureText(textToDraw);
        const pad = 12 * scaleFactor;
        const boxW = metrics.width + pad * 2;
        const boxH = actualFontSize + pad;

        ctx.strokeStyle = '#8B5CF6';
        ctx.lineWidth = Math.max(1.5, 2 * scaleFactor);
        ctx.setLineDash([6 * scaleFactor, 4 * scaleFactor]);
        ctx.strokeRect(-boxW / 2, -boxH / 2, boxW, boxH);
      }

      ctx.restore();
    }
  }

  function applyAspectRatio(ratio: AspectRatio) {
    aspectRatio = ratio;
    if (!loadedImg) return;

    const nw = loadedImg.naturalWidth;
    const nh = loadedImg.naturalHeight;

    if (ratio === 'free') {
      cropX = 0;
      cropY = 0;
      cropW = nw;
      cropH = nh;
    } else {
      let targetRatio = 1;
      if (ratio === '1:1') targetRatio = 1;
      else if (ratio === '4:3') targetRatio = 4 / 3;
      else if (ratio === '16:9') targetRatio = 16 / 9;
      else if (ratio === '9:16') targetRatio = 9 / 16;
      else if (ratio === '3:4') targetRatio = 3 / 4;

      const imgRatio = nw / nh;
      if (imgRatio > targetRatio) {
        cropH = nh;
        cropW = Math.round(nh * targetRatio);
        cropX = Math.round((nw - cropW) / 2);
        cropY = 0;
      } else {
        cropW = nw;
        cropH = Math.round(nw / targetRatio);
        cropX = 0;
        cropY = Math.round((nh - cropH) / 2);
      }
    }

    outputWidth = cropW;
    outputHeight = cropH;
    renderCanvas();
  }

  function onOutputWidthInput(e: Event) {
    const val = parseInt((e.target as HTMLInputElement).value, 10);
    if (isNaN(val) || val <= 0) return;
    outputWidth = val;
    if (lockOutputAspect && cropW > 0) {
      outputHeight = Math.round((val * cropH) / cropW);
    }
  }

  function onOutputHeightInput(e: Event) {
    const val = parseInt((e.target as HTMLInputElement).value, 10);
    if (isNaN(val) || val <= 0) return;
    outputHeight = val;
    if (lockOutputAspect && cropH > 0) {
      outputWidth = Math.round((val * cropW) / cropH);
    }
  }

  function addTextLayer() {
    const newId = `layer-${Date.now()}`;
    const newLayer: TextLayer = {
      id: newId,
      text: 'NEW CAPTION',
      x: 50,
      y: 50,
      fontSize: 36,
      scale: 1,
      rotation: 0,
      color: '#FFFFFF',
      strokeColor: '#000000',
      strokeWidth: 5,
      fontFamily: 'Impact',
      useCaps: true,
      isMemeStyle: true,
    };
    textLayers = [...textLayers, newLayer];
    selectedLayerId = newId;
    activeTab = 'text';
    renderCanvas();
  }

  function removeTextLayer(id: string) {
    textLayers = textLayers.filter((l) => l.id !== id);
    if (selectedLayerId === id) {
      selectedLayerId = textLayers.length > 0 ? textLayers[0].id : null;
    }
    renderCanvas();
  }

  function loadImage(src: string) {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      loadedImg = img;
      imageSource = src;
      imgNaturalWidth = img.naturalWidth;
      imgNaturalHeight = img.naturalHeight;
      cropX = 0;
      cropY = 0;
      cropW = img.naturalWidth;
      cropH = img.naturalHeight;
      outputWidth = img.naturalWidth;
      outputHeight = img.naturalHeight;
      aspectRatio = 'free';
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

  function onCanvasPointerDown(e: PointerEvent) {
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const clickXPercent = ((e.clientX - rect.left) / rect.width) * 100;
    const clickYPercent = ((e.clientY - rect.top) / rect.height) * 100;

    let hitLayer: TextLayer | null = null;
    for (let i = textLayers.length - 1; i >= 0; i--) {
      const l = textLayers[i];
      const dist = Math.hypot(l.x - clickXPercent, l.y - clickYPercent);
      if (dist < 18) {
        hitLayer = l;
        break;
      }
    }

    if (hitLayer) {
      selectedLayerId = hitLayer.id;
      isDraggingLayer = true;
      dragLayerId = hitLayer.id;
      (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
      renderCanvas();
    } else {
      selectedLayerId = null;
      renderCanvas();
    }
  }

  function onCanvasPointerMove(e: PointerEvent) {
    if (!isDraggingLayer || !dragLayerId || !canvas) return;
    const rect = canvas.getBoundingClientRect();
    const xPercent = Math.max(2, Math.min(98, ((e.clientX - rect.left) / rect.width) * 100));
    const yPercent = Math.max(2, Math.min(98, ((e.clientY - rect.top) / rect.height) * 100));

    textLayers = textLayers.map((l) => {
      if (l.id === dragLayerId) {
        return { ...l, x: Math.round(xPercent * 10) / 10, y: Math.round(yPercent * 10) / 10 };
      }
      return l;
    });
    renderCanvas();
  }

  function onCanvasPointerUp(e: PointerEvent) {
    if (isDraggingLayer) {
      isDraggingLayer = false;
      dragLayerId = null;
      try {
        (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
      } catch {}
    }
  }

  async function getExportBlob(): Promise<Blob | null> {
    const offscreen = document.createElement('canvas');
    offscreen.width = Math.max(32, outputWidth);
    offscreen.height = Math.max(32, outputHeight);
    const ctx = offscreen.getContext('2d');
    if (!ctx || !loadedImg) return null;

    ctx.drawImage(
      loadedImg,
      cropX,
      cropY,
      cropW,
      cropH,
      0,
      0,
      offscreen.width,
      offscreen.height
    );

    const scaleFactor = offscreen.width / 600;

    for (const layer of textLayers) {
      ctx.save();
      const posX = (layer.x / 100) * offscreen.width;
      const posY = (layer.y / 100) * offscreen.height;

      ctx.translate(posX, posY);
      ctx.rotate((layer.rotation * Math.PI) / 180);

      const actualFontSize = Math.max(12, Math.round(layer.fontSize * layer.scale * scaleFactor));
      ctx.font = `900 ${actualFontSize}px ${layer.fontFamily}, Impact, sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';

      const textToDraw = layer.useCaps ? layer.text.toUpperCase() : layer.text;

      if (layer.isMemeStyle) {
        ctx.strokeStyle = layer.strokeColor;
        ctx.lineWidth = Math.max(1, Math.round(layer.strokeWidth * scaleFactor));
        ctx.lineJoin = 'round';
        ctx.strokeText(textToDraw, 0, 0);
      }

      ctx.fillStyle = layer.color;
      ctx.fillText(textToDraw, 0, 0);
      ctx.restore();
    }

    let mimeType = 'image/webp';
    if (exportFormat === 'jpeg') mimeType = 'image/jpeg';
    else if (exportFormat === 'png') mimeType = 'image/png';

    return new Promise((resolve) => {
      offscreen.toBlob(
        (blob) => resolve(blob),
        mimeType,
        exportFormat === 'png' ? undefined : exportQuality
      );
    });
  }

  async function downloadImage() {
    isExporting = true;
    try {
      const blob = await getExportBlob();
      if (!blob) throw new Error('Export failed');

      const ext = exportFormat === 'jpeg' ? 'jpg' : exportFormat;
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `mewmer_${outputWidth}x${outputHeight}_${Date.now()}.${ext}`;
      a.click();
      URL.revokeObjectURL(url);
      showNotice(`Downloaded ${outputWidth}×${outputHeight} ${exportFormat.toUpperCase()}!`);
    } catch {
      showNotice('Failed to export image');
    } finally {
      isExporting = false;
    }
  }

  async function copyToClipboard() {
    try {
      const offscreen = document.createElement('canvas');
      offscreen.width = Math.max(32, outputWidth);
      offscreen.height = Math.max(32, outputHeight);
      const ctx = offscreen.getContext('2d');
      if (!ctx || !loadedImg) return;

      ctx.drawImage(loadedImg, cropX, cropY, cropW, cropH, 0, 0, offscreen.width, offscreen.height);
      const scaleFactor = offscreen.width / 600;

      for (const layer of textLayers) {
        ctx.save();
        const posX = (layer.x / 100) * offscreen.width;
        const posY = (layer.y / 100) * offscreen.height;
        ctx.translate(posX, posY);
        ctx.rotate((layer.rotation * Math.PI) / 180);
        const actualFontSize = Math.max(12, Math.round(layer.fontSize * layer.scale * scaleFactor));
        ctx.font = `900 ${actualFontSize}px ${layer.fontFamily}, Impact, sans-serif`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        const textToDraw = layer.useCaps ? layer.text.toUpperCase() : layer.text;
        if (layer.isMemeStyle) {
          ctx.strokeStyle = layer.strokeColor;
          ctx.lineWidth = Math.max(1, Math.round(layer.strokeWidth * scaleFactor));
          ctx.lineJoin = 'round';
          ctx.strokeText(textToDraw, 0, 0);
        }
        ctx.fillStyle = layer.color;
        ctx.fillText(textToDraw, 0, 0);
        ctx.restore();
      }

      const blob = await new Promise<Blob | null>((resolve) =>
        offscreen.toBlob((b) => resolve(b), 'image/png')
      );
      if (!blob) return;

      await navigator.clipboard.write([
        new ClipboardItem({ 'image/png': blob }),
      ]);
      showNotice('Image copied to clipboard!');
    } catch {
      showNotice('Copy failed. Try downloading instead.');
    }
  }

  function showNotice(msg: string) {
    exportNotice = msg;
    setTimeout(() => {
      exportNotice = '';
    }, 4000);
  }

  onMount(() => {
    loadImage(sampleTemplates[0].url);
  });

  let selectedLayer = $derived(textLayers.find((l) => l.id === selectedLayerId));
</script>

<div class="grid grid-cols-1 lg:grid-cols-12 gap-6 lg:gap-8 items-start">
  <div class="lg:col-span-7 flex flex-col items-center w-full">
    <div class="w-full bg-dark-card border border-dark-border rounded-2xl p-4 sm:p-5 shadow-2xl flex flex-col items-center">
      <div
        class="relative w-full max-h-[58vh] sm:max-h-[64vh] rounded-xl overflow-hidden border border-dark-border/80 flex items-center justify-center bg-dark-bg p-2 select-none"
        style="background-image: linear-gradient(45deg, #111827 25%, transparent 25%), linear-gradient(-45deg, #111827 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #111827 75%), linear-gradient(-45deg, transparent 75%, #111827 75%); background-size: 20px 20px; background-position: 0 0, 0 10px, 10px -10px, -10px 0px; background-color: #0B0F17;"
      >
        <canvas
          bind:this={canvas}
          class="max-w-full max-h-[54vh] sm:max-h-[60vh] object-contain cursor-move touch-none select-none rounded shadow"
          onpointerdown={onCanvasPointerDown}
          onpointermove={onCanvasPointerMove}
          onpointerup={onCanvasPointerUp}
          onpointercancel={onCanvasPointerUp}
        ></canvas>

        <span class="absolute top-3 left-3 px-2 py-1 text-[11px] font-mono font-medium rounded-md bg-dark-bg/85 backdrop-blur border border-dark-border text-slate-300">
          {outputWidth} × {outputHeight} px
        </span>

        {#if selectedLayer}
          <span class="absolute top-3 right-3 px-2 py-1 text-[11px] font-sans font-medium rounded-md bg-brand-500/20 backdrop-blur border border-brand-500/40 text-brand-300">
            Drag to position text
          </span>
        {/if}
      </div>

      <div class="w-full mt-4 flex items-center justify-between text-xs text-dark-muted px-1">
        <span class="flex items-center gap-1.5">
          <span>Source:</span>
          <strong class="text-slate-300 font-mono">{imgNaturalWidth} × {imgNaturalHeight} px</strong>
        </span>
        <span class="flex items-center gap-1.5">
          <span>Crop:</span>
          <strong class="text-brand-300 font-mono">{cropW} × {cropH} px ({aspectRatio.toUpperCase()})</strong>
        </span>
      </div>

      <div class="w-full mt-4 flex flex-col sm:flex-row items-center gap-2.5">
        <button
          onclick={downloadImage}
          disabled={isExporting}
          class="w-full sm:flex-1 py-3 px-4 rounded-xl bg-brand-500 hover:bg-brand-400 active:scale-[0.99] text-white font-bold text-sm flex items-center justify-center gap-2 shadow-lg shadow-brand-500/25 transition-all"
        >
          <span>💾</span>
          <span>Download {exportFormat.toUpperCase()} ({outputWidth} × {outputHeight})</span>
        </button>

        <button
          onclick={copyToClipboard}
          class="w-full sm:w-auto py-3 px-4 rounded-xl bg-dark-border hover:bg-slate-700 text-slate-200 font-semibold text-xs flex items-center justify-center gap-2 transition-colors"
        >
          <span>📋</span>
          <span>Copy Image</span>
        </button>
      </div>

      {#if exportNotice}
        <div class="w-full mt-3 p-3 rounded-xl bg-brand-500/20 border border-brand-500/40 text-brand-200 text-xs text-center animate-fade-in">
          {exportNotice}
        </div>
      {/if}
    </div>
  </div>

  <div class="lg:col-span-5 bg-dark-card border border-dark-border rounded-2xl p-5 sm:p-6 shadow-xl space-y-6 w-full">
    <div class="flex items-center justify-between border-b border-dark-border pb-4">
      <div>
        <h3 class="text-lg font-bold text-white flex items-center gap-2">
          <span>🖼️</span>
          <span>Image & Caption Studio</span>
        </h3>
        <p class="text-xs text-dark-muted mt-0.5">
          Resize, crop to any format, add rotating captions, and export high-res.
        </p>
      </div>
    </div>

    <div class="flex items-center p-1 bg-dark-bg border border-dark-border rounded-xl gap-1">
      <button
        type="button"
        onclick={() => activeTab = 'crop'}
        class="flex-1 py-2 text-xs font-semibold rounded-lg transition-colors flex items-center justify-center gap-1.5 {activeTab === 'crop' ? 'bg-brand-500/20 text-brand-300 border border-brand-500/30' : 'text-slate-400 hover:text-white'}"
      >
        <span>📐</span>
        <span>Crop & Ratio</span>
      </button>

      <button
        type="button"
        onclick={() => activeTab = 'text'}
        class="flex-1 py-2 text-xs font-semibold rounded-lg transition-colors flex items-center justify-center gap-1.5 {activeTab === 'text' ? 'bg-brand-500/20 text-brand-300 border border-brand-500/30' : 'text-slate-400 hover:text-white'}"
      >
        <span>✍️</span>
        <span>Captions ({textLayers.length})</span>
      </button>

      <button
        type="button"
        onclick={() => activeTab = 'export'}
        class="flex-1 py-2 text-xs font-semibold rounded-lg transition-colors flex items-center justify-center gap-1.5 {activeTab === 'export' ? 'bg-brand-500/20 text-brand-300 border border-brand-500/30' : 'text-slate-400 hover:text-white'}"
      >
        <span>⚙️</span>
        <span>Export</span>
      </button>
    </div>

    {#if activeTab === 'crop'}
      <div class="space-y-5 animate-fade-in">
        <div class="space-y-2">
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider">
            Aspect Ratio Presets
          </label>
          <div class="grid grid-cols-3 gap-2">
            <button
              type="button"
              onclick={() => applyAspectRatio('free')}
              class="py-2 px-2.5 rounded-xl border text-xs font-semibold transition-all {aspectRatio === 'free' ? 'bg-brand-500/20 border-brand-500 text-brand-200 shadow-sm' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              Original
            </button>
            <button
              type="button"
              onclick={() => applyAspectRatio('1:1')}
              class="py-2 px-2.5 rounded-xl border text-xs font-semibold transition-all {aspectRatio === '1:1' ? 'bg-brand-500/20 border-brand-500 text-brand-200 shadow-sm' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              1:1 Square
            </button>
            <button
              type="button"
              onclick={() => applyAspectRatio('4:3')}
              class="py-2 px-2.5 rounded-xl border text-xs font-semibold transition-all {aspectRatio === '4:3' ? 'bg-brand-500/20 border-brand-500 text-brand-200 shadow-sm' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              4:3 Standard
            </button>
            <button
              type="button"
              onclick={() => applyAspectRatio('16:9')}
              class="py-2 px-2.5 rounded-xl border text-xs font-semibold transition-all {aspectRatio === '16:9' ? 'bg-brand-500/20 border-brand-500 text-brand-200 shadow-sm' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              16:9 Widescreen
            </button>
            <button
              type="button"
              onclick={() => applyAspectRatio('9:16')}
              class="py-2 px-2.5 rounded-xl border text-xs font-semibold transition-all {aspectRatio === '9:16' ? 'bg-brand-500/20 border-brand-500 text-brand-200 shadow-sm' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              9:16 Story / Reel
            </button>
            <button
              type="button"
              onclick={() => applyAspectRatio('3:4')}
              class="py-2 px-2.5 rounded-xl border text-xs font-semibold transition-all {aspectRatio === '3:4' ? 'bg-brand-500/20 border-brand-500 text-brand-200 shadow-sm' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              3:4 Portrait
            </button>
          </div>
        </div>

        <div class="space-y-3 pt-3 border-t border-dark-border">
          <div class="flex items-center justify-between">
            <label class="text-xs font-semibold text-slate-300 uppercase tracking-wider">
              Output Dimensions (Pixels)
            </label>
            <button
              type="button"
              onclick={() => lockOutputAspect = !lockOutputAspect}
              class="text-xs font-medium px-2 py-0.5 rounded border transition-colors {lockOutputAspect ? 'bg-brand-500/20 border-brand-500/40 text-brand-300' : 'bg-dark-bg border-dark-border text-slate-500'}"
            >
              {lockOutputAspect ? '🔒 Locked Aspect' : '🔓 Free Resize'}
            </button>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <span class="block text-[11px] text-dark-muted mb-1">Width (px)</span>
              <input
                type="number"
                min="32"
                max="8192"
                value={outputWidth}
                oninput={onOutputWidthInput}
                class="w-full px-3 py-2 rounded-xl bg-dark-bg border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white font-mono"
              />
            </div>
            <div>
              <span class="block text-[11px] text-dark-muted mb-1">Height (px)</span>
              <input
                type="number"
                min="32"
                max="8192"
                value={outputHeight}
                oninput={onOutputHeightInput}
                class="w-full px-3 py-2 rounded-xl bg-dark-bg border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white font-mono"
              />
            </div>
          </div>
        </div>

        <div class="space-y-2 pt-3 border-t border-dark-border">
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider">
            Change Image
          </label>
          <div class="flex items-center gap-2">
            <label class="flex-1 cursor-pointer py-2.5 px-3 rounded-xl border border-dashed border-brand-500/40 hover:border-brand-500 bg-brand-500/5 hover:bg-brand-500/10 text-center text-xs font-medium text-brand-300 transition-colors">
              <span>📁 Upload from Device</span>
              <input type="file" accept="image/*" class="hidden" onchange={handleFileUpload} />
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
      </div>
    {:else if activeTab === 'text'}
      <div class="space-y-5 animate-fade-in">
        <div class="flex items-center justify-between">
          <label class="text-xs font-semibold text-slate-300 uppercase tracking-wider">
            Caption Layers ({textLayers.length})
          </label>
          <button
            type="button"
            onclick={addTextLayer}
            class="px-3 py-1.5 rounded-xl bg-brand-500 hover:bg-brand-400 text-white font-semibold text-xs flex items-center gap-1.5 transition-colors shadow-sm"
          >
            <span>+</span>
            <span>Add Caption</span>
          </button>
        </div>

        <div class="space-y-2 max-h-48 overflow-y-auto pr-1">
          {#each textLayers as layer, idx}
            <div
              class="p-2.5 rounded-xl border transition-all flex items-center justify-between gap-3 cursor-pointer {selectedLayerId === layer.id ? 'bg-brand-500/10 border-brand-500' : 'bg-dark-bg border-dark-border hover:border-slate-600'}"
              onclick={() => { selectedLayerId = layer.id; renderCanvas(); }}
            >
              <div class="flex items-center gap-2 min-w-0">
                <span class="text-xs font-mono font-bold text-dark-muted">{idx + 1}</span>
                <span class="text-xs font-semibold text-white truncate max-w-[140px] sm:max-w-[180px]">
                  {layer.text || '(empty)'}
                </span>
                <span class="text-[10px] font-mono text-slate-400 bg-dark-card px-1.5 py-0.5 rounded border border-dark-border">
                  {layer.rotation}°
                </span>
              </div>

              <div class="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  onclick={(e) => { e.stopPropagation(); removeTextLayer(layer.id); }}
                  class="p-1 rounded hover:bg-rose-500/20 text-rose-400 text-xs transition-colors"
                  title="Remove"
                >
                  ✕
                </button>
              </div>
            </div>
          {/each}
        </div>

        {#if selectedLayer}
          <div class="p-4 rounded-xl bg-dark-bg border border-dark-border space-y-4 pt-4">
            <div>
              <span class="block text-xs font-semibold text-slate-300 mb-1">Edit Caption Text</span>
              <input
                type="text"
                bind:value={selectedLayer.text}
                oninput={() => renderCanvas()}
                class="w-full px-3.5 py-2.5 rounded-xl bg-dark-card border border-dark-border focus:border-brand-500 focus:outline-none text-sm text-white"
              />
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <span class="block text-xs font-semibold text-slate-300 mb-1">Font</span>
                <select
                  bind:value={selectedLayer.fontFamily}
                  onchange={() => renderCanvas()}
                  class="w-full px-2.5 py-2 rounded-xl bg-dark-card border border-dark-border text-xs text-white focus:outline-none"
                >
                  <option value="Impact">Impact (Meme)</option>
                  <option value="Inter">Inter (Clean)</option>
                  <option value="Poppins">Poppins (Modern)</option>
                  <option value="Caveat">Caveat (Handwritten)</option>
                </select>
              </div>

              <div>
                <span class="block text-xs font-semibold text-slate-300 mb-1">Base Size ({selectedLayer.fontSize}px)</span>
                <input
                  type="range"
                  min="16"
                  max="90"
                  bind:value={selectedLayer.fontSize}
                  oninput={() => renderCanvas()}
                  class="w-full accent-brand-500"
                />
              </div>
            </div>

            <div class="grid grid-cols-2 gap-3">
              <div>
                <div class="flex items-center justify-between mb-1">
                  <span class="text-xs font-semibold text-slate-300">Rotation ({selectedLayer.rotation}°)</span>
                  {#if selectedLayer.rotation !== 0}
                    <button
                      type="button"
                      onclick={() => { if (selectedLayer) { selectedLayer.rotation = 0; renderCanvas(); } }}
                      class="text-[10px] text-amber-400 hover:underline"
                    >
                      Reset
                    </button>
                  {/if}
                </div>
                <input
                  type="range"
                  min="-180"
                  max="180"
                  bind:value={selectedLayer.rotation}
                  oninput={() => renderCanvas()}
                  class="w-full accent-brand-500"
                />
              </div>

              <div>
                <span class="block text-xs font-semibold text-slate-300 mb-1">Scale ({selectedLayer.scale.toFixed(2)}×)</span>
                <input
                  type="range"
                  min="0.4"
                  max="2.5"
                  step="0.05"
                  bind:value={selectedLayer.scale}
                  oninput={() => renderCanvas()}
                  class="w-full accent-brand-500"
                />
              </div>
            </div>

            <div class="grid grid-cols-2 gap-3 pt-2 border-t border-dark-border">
              <div>
                <span class="block text-xs font-semibold text-slate-300 mb-1">Text Color</span>
                <div class="flex items-center gap-2">
                  <input
                    type="color"
                    bind:value={selectedLayer.color}
                    oninput={() => renderCanvas()}
                    class="w-8 h-8 rounded-lg cursor-pointer bg-transparent border-0"
                  />
                  <span class="text-xs font-mono text-slate-400">{selectedLayer.color}</span>
                </div>
              </div>

              <div>
                <span class="block text-xs font-semibold text-slate-300 mb-1">Outline Color</span>
                <div class="flex items-center gap-2">
                  <input
                    type="color"
                    bind:value={selectedLayer.strokeColor}
                    oninput={() => renderCanvas()}
                    class="w-8 h-8 rounded-lg cursor-pointer bg-transparent border-0"
                  />
                  <span class="text-xs font-mono text-slate-400">{selectedLayer.strokeColor}</span>
                </div>
              </div>
            </div>

            <div class="flex items-center gap-4 pt-1">
              <label class="flex items-center gap-2 text-xs text-slate-300 cursor-pointer">
                <input
                  type="checkbox"
                  bind:checked={selectedLayer.useCaps}
                  onchange={() => renderCanvas()}
                  class="rounded accent-brand-500"
                />
                <span>ALL CAPS</span>
              </label>

              <label class="flex items-center gap-2 text-xs text-slate-300 cursor-pointer">
                <input
                  type="checkbox"
                  bind:checked={selectedLayer.isMemeStyle}
                  onchange={() => renderCanvas()}
                  class="rounded accent-brand-500"
                />
                <span>Bold Outline (Meme Style)</span>
              </label>
            </div>
          </div>
        {/if}
      </div>
    {:else if activeTab === 'export'}
      <div class="space-y-5 animate-fade-in">
        <div class="space-y-2">
          <label class="block text-xs font-semibold text-slate-300 uppercase tracking-wider">
            Format
          </label>
          <div class="grid grid-cols-3 gap-2">
            <button
              type="button"
              onclick={() => exportFormat = 'webp'}
              class="py-2.5 px-3 rounded-xl border text-xs font-bold transition-all {exportFormat === 'webp' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              WebP
            </button>
            <button
              type="button"
              onclick={() => exportFormat = 'jpeg'}
              class="py-2.5 px-3 rounded-xl border text-xs font-bold transition-all {exportFormat === 'jpeg' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              JPG / JPEG
            </button>
            <button
              type="button"
              onclick={() => exportFormat = 'png'}
              class="py-2.5 px-3 rounded-xl border text-xs font-bold transition-all {exportFormat === 'png' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400 hover:text-white'}"
            >
              PNG
            </button>
          </div>
        </div>

        {#if exportFormat !== 'png'}
          <div class="space-y-2 pt-2">
            <div class="flex items-center justify-between">
              <span class="text-xs font-semibold text-slate-300">Compression Quality</span>
              <span class="text-xs font-mono text-brand-300">{Math.round(exportQuality * 100)}%</span>
            </div>
            <input
              type="range"
              min="0.5"
              max="1.0"
              step="0.02"
              bind:value={exportQuality}
              class="w-full accent-brand-500"
            />
          </div>
        {/if}

        <div class="p-3 rounded-xl bg-dark-bg border border-dark-border space-y-2">
          <div class="flex items-center justify-between text-xs">
            <span class="text-dark-muted">Resolution:</span>
            <span class="font-mono font-bold text-white">{outputWidth} × {outputHeight} px</span>
          </div>
          <div class="flex items-center justify-between text-xs">
            <span class="text-dark-muted">Format:</span>
            <span class="font-mono font-bold text-brand-300">{exportFormat.toUpperCase()}</span>
          </div>
          <div class="flex items-center justify-between text-xs">
            <span class="text-dark-muted">Captions included:</span>
            <span class="font-mono text-slate-300">{textLayers.length} text layers</span>
          </div>
        </div>

        <div class="pt-2 flex flex-col gap-2">
          <button
            onclick={downloadImage}
            disabled={isExporting}
            class="w-full py-3 px-4 rounded-xl bg-brand-500 hover:bg-brand-400 active:scale-[0.99] text-white font-bold text-sm flex items-center justify-center gap-2 shadow-lg shadow-brand-500/25 transition-all"
          >
            <span>💾</span>
            <span>Download {exportFormat.toUpperCase()}</span>
          </button>

          <button
            onclick={copyToClipboard}
            class="w-full py-2.5 px-4 rounded-xl bg-dark-border hover:bg-slate-700 text-slate-200 font-semibold text-xs flex items-center justify-center gap-2 transition-colors"
          >
            <span>📋</span>
            <span>Copy Image to Clipboard</span>
          </button>
        </div>
      </div>
    {/if}
  </div>
</div>