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
  type InteractionMode = 'none' | 'move-layer' | 'rotate-layer' | 'scale-layer' | 'pan-image';

  let canvas = $state<HTMLCanvasElement | null>(null);
  let imageSource = $state<string | null>(null);
  let loadedImg: HTMLImageElement | null = null;
  let imgNaturalWidth = $state(800);
  let imgNaturalHeight = $state(600);

  let isAnimatedGif = $state(false);
  let currentGifFile = $state<File | null>(null);

  let aspectRatio = $state<AspectRatio>('free');
  let cropX = $state(0);
  let cropY = $state(0);
  let cropW = $state(800);
  let cropH = $state(600);
  let outputWidth = $state(800);
  let outputHeight = $state(600);
  let lockOutputAspect = $state(true);

  let showWatermark = $state(true);
  let watermarkStyle = $state<'text-only' | 'glassy'>('text-only');
  let watermarkPosition = $state<'bottom-right' | 'bottom-left' | 'top-right'>('bottom-right');
  let watermarkOpacity = $state(0.55);

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

  let interactionMode = $state<InteractionMode>('none');
  let panStartX = 0;
  let panStartY = 0;
  let panStartCropX = 0;
  let panStartCropY = 0;
  let startScaleDist = 1;
  let startLayerScale = 1;

  const sampleTemplates = [
    { name: 'Landscape Cat', url: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=1200&auto=format&fit=crop&q=80', isGif: false },
    { name: 'Square Doge', url: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800&auto=format&fit=crop&q=80', isGif: false },
    { name: 'Animated Cat (GIF)', url: 'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif', isGif: true },
  ];

  function renderCanvas() {
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    canvas.width = Math.max(32, cropW);
    canvas.height = Math.max(32, cropH);

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    if (!isAnimatedGif && loadedImg && loadedImg.complete) {
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
        ctx.setLineDash([]);

        const stemLen = 26 * scaleFactor;
        const handleR = 13 * scaleFactor;
        const rotY = -boxH / 2 - stemLen;

        ctx.beginPath();
        ctx.moveTo(0, -boxH / 2);
        ctx.lineTo(0, rotY);
        ctx.strokeStyle = '#8B5CF6';
        ctx.lineWidth = 1.5 * scaleFactor;
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(0, rotY, handleR, 0, Math.PI * 2);
        ctx.fillStyle = '#8B5CF6';
        ctx.fill();
        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 1.5 * scaleFactor;
        ctx.stroke();

        ctx.font = `${Math.round(11 * scaleFactor)}px system-ui, sans-serif`;
        ctx.fillStyle = '#FFFFFF';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('🔄', 0, rotY);

        const scaleHandleX = boxW / 2;
        const scaleHandleY = boxH / 2;
        const scaleHandleR = 12 * scaleFactor;

        ctx.beginPath();
        ctx.arc(scaleHandleX, scaleHandleY, scaleHandleR, 0, Math.PI * 2);
        ctx.fillStyle = '#8B5CF6';
        ctx.fill();
        ctx.strokeStyle = '#FFFFFF';
        ctx.lineWidth = 1.5 * scaleFactor;
        ctx.stroke();

        ctx.font = `${Math.round(10 * scaleFactor)}px system-ui, sans-serif`;
        ctx.fillStyle = '#FFFFFF';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('⤡', scaleHandleX, scaleHandleY);
      }

      ctx.restore();
    }

    if (showWatermark) {
      ctx.save();
      const scaleRef = canvas.width / 600;
      const fontSize = Math.max(11, Math.round(13 * scaleRef));
      ctx.font = `600 ${fontSize}px Inter, system-ui, sans-serif`;

      const text = 'mewmer.com';
      const metrics = ctx.measureText(text);
      const padX = 8 * scaleRef;
      const padY = 4 * scaleRef;
      const w = metrics.width + (watermarkStyle === 'glassy' ? padX * 2 : 0);
      const h = fontSize + (watermarkStyle === 'glassy' ? padY * 2 : 0);
      const margin = 14 * scaleRef;

      let bx = canvas.width - margin - w;
      let by = canvas.height - margin - h;
      if (watermarkPosition === 'bottom-left') {
        bx = margin;
        by = canvas.height - margin - h;
      } else if (watermarkPosition === 'top-right') {
        bx = canvas.width - margin - w;
        by = margin;
      }

      if (watermarkStyle === 'glassy') {
        ctx.fillStyle = `rgba(11, 15, 23, ${watermarkOpacity * 0.4})`;
        ctx.strokeStyle = `rgba(255, 255, 255, ${watermarkOpacity * 0.22})`;
        ctx.lineWidth = 1;
        ctx.beginPath();
        if (ctx.roundRect) {
          ctx.roundRect(bx, by, w, h, 6 * scaleRef);
        } else {
          ctx.rect(bx, by, w, h);
        }
        ctx.fill();
        ctx.stroke();

        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = `rgba(255, 255, 255, ${watermarkOpacity})`;
        ctx.fillText(text, bx + w / 2, by + h / 2);
      } else {
        ctx.shadowColor = 'rgba(0, 0, 0, 0.75)';
        ctx.shadowBlur = 4 * scaleRef;
        ctx.shadowOffsetX = 1 * scaleRef;
        ctx.shadowOffsetY = 1 * scaleRef;

        ctx.textAlign = 'left';
        ctx.textBaseline = 'top';
        ctx.fillStyle = `rgba(255, 255, 255, ${watermarkOpacity})`;
        ctx.fillText(text, bx, by);
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

  function loadImage(src: string, isGif = false) {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      loadedImg = img;
      imageSource = src;
      isAnimatedGif = isGif;
      imgNaturalWidth = img.naturalWidth || 800;
      imgNaturalHeight = img.naturalHeight || 600;
      cropX = 0;
      cropY = 0;
      cropW = imgNaturalWidth;
      cropH = imgNaturalHeight;
      outputWidth = imgNaturalWidth;
      outputHeight = imgNaturalHeight;
      aspectRatio = 'free';
      renderCanvas();
    };
    img.src = src;
  }

  function handleFileUpload(e: Event) {
    const target = e.target as HTMLInputElement;
    const file = target.files?.[0];
    if (!file) return;

    const isGif = file.type === 'image/gif' || file.name.toLowerCase().endsWith('.gif');
    if (isGif) {
      currentGifFile = file;
      isAnimatedGif = true;
    } else {
      currentGifFile = null;
      isAnimatedGif = false;
    }

    const reader = new FileReader();
    reader.onload = (event) => {
      if (event.target?.result) {
        loadImage(event.target.result as string, isGif);
      }
    };
    reader.readAsDataURL(file);
  }

  function onCanvasPointerDown(e: PointerEvent) {
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const canvasX = ((e.clientX - rect.left) / rect.width) * canvas.width;
    const canvasY = ((e.clientY - rect.top) / rect.height) * canvas.height;
    const scaleFactor = canvas.width / 600;

    if (selectedLayer) {
      const posX = (selectedLayer.x / 100) * canvas.width;
      const posY = (selectedLayer.y / 100) * canvas.height;
      const dx = canvasX - posX;
      const dy = canvasY - posY;
      const rad = (-selectedLayer.rotation * Math.PI) / 180;
      const localX = dx * Math.cos(rad) - dy * Math.sin(rad);
      const localY = dx * Math.sin(rad) + dy * Math.cos(rad);

      const actualFontSize = Math.max(12, Math.round(selectedLayer.fontSize * selectedLayer.scale * scaleFactor));
      const ctx = canvas.getContext('2d');
      const textToDraw = selectedLayer.useCaps ? selectedLayer.text.toUpperCase() : selectedLayer.text;
      let textW = 100 * scaleFactor;
      if (ctx) {
        ctx.font = `900 ${actualFontSize}px ${selectedLayer.fontFamily}, Impact, sans-serif`;
        textW = ctx.measureText(textToDraw).width;
      }
      const pad = 12 * scaleFactor;
      const boxW = textW + pad * 2;
      const boxH = actualFontSize + pad;

      const stemLen = 26 * scaleFactor;
      const handleR = 14 * scaleFactor;
      const rotHandleDist = Math.hypot(localX - 0, localY - (-boxH / 2 - stemLen));
      if (rotHandleDist <= handleR * 1.6) {
        interactionMode = 'rotate-layer';
        (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
        return;
      }

      const scaleHandleDist = Math.hypot(localX - boxW / 2, localY - boxH / 2);
      if (scaleHandleDist <= handleR * 1.6) {
        interactionMode = 'scale-layer';
        startScaleDist = Math.hypot(dx, dy);
        startLayerScale = selectedLayer.scale;
        (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
        return;
      }

      if (Math.abs(localX) <= boxW / 2 && Math.abs(localY) <= boxH / 2) {
        interactionMode = 'move-layer';
        (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
        return;
      }
    }

    let hitLayer: TextLayer | null = null;
    for (let i = textLayers.length - 1; i >= 0; i--) {
      const l = textLayers[i];
      const posX = (l.x / 100) * canvas.width;
      const posY = (l.y / 100) * canvas.height;
      const dist = Math.hypot(canvasX - posX, canvasY - posY);
      if (dist < 36 * scaleFactor) {
        hitLayer = l;
        break;
      }
    }

    if (hitLayer) {
      selectedLayerId = hitLayer.id;
      interactionMode = 'move-layer';
      (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
      renderCanvas();
      return;
    }

    interactionMode = 'pan-image';
    panStartX = e.clientX;
    panStartY = e.clientY;
    panStartCropX = cropX;
    panStartCropY = cropY;
    selectedLayerId = null;
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    renderCanvas();
  }

  function onCanvasPointerMove(e: PointerEvent) {
    if (interactionMode === 'none' || !canvas) return;
    const rect = canvas.getBoundingClientRect();
    const canvasX = ((e.clientX - rect.left) / rect.width) * canvas.width;
    const canvasY = ((e.clientY - rect.top) / rect.height) * canvas.height;

    if (interactionMode === 'rotate-layer' && selectedLayer) {
      const posX = (selectedLayer.x / 100) * canvas.width;
      const posY = (selectedLayer.y / 100) * canvas.height;
      const dx = canvasX - posX;
      const dy = canvasY - posY;
      const angleRad = Math.atan2(dy, dx);
      const angleDeg = Math.round((angleRad * 180) / Math.PI) + 90;
      selectedLayer.rotation = ((angleDeg + 180) % 360) - 180;
      renderCanvas();
    } else if (interactionMode === 'scale-layer' && selectedLayer) {
      const posX = (selectedLayer.x / 100) * canvas.width;
      const posY = (selectedLayer.y / 100) * canvas.height;
      const currentDist = Math.hypot(canvasX - posX, canvasY - posY);
      const newScale = Math.max(0.3, Math.min(3.5, (currentDist / Math.max(1, startScaleDist)) * startLayerScale));
      selectedLayer.scale = Math.round(newScale * 100) / 100;
      renderCanvas();
    } else if (interactionMode === 'move-layer' && selectedLayer) {
      const xPercent = Math.max(2, Math.min(98, (canvasX / canvas.width) * 100));
      const yPercent = Math.max(2, Math.min(98, (canvasY / canvas.height) * 100));
      selectedLayer.x = Math.round(xPercent * 10) / 10;
      selectedLayer.y = Math.round(yPercent * 10) / 10;
      renderCanvas();
    } else if (interactionMode === 'pan-image') {
      if (cropW < imgNaturalWidth || cropH < imgNaturalHeight) {
        const scale = cropW / rect.width;
        const deltaX = (e.clientX - panStartX) * scale;
        const deltaY = (e.clientY - panStartY) * scale;
        cropX = Math.max(0, Math.min(imgNaturalWidth - cropW, panStartCropX - deltaX));
        cropY = Math.max(0, Math.min(imgNaturalHeight - cropH, panStartCropY - deltaY));
        renderCanvas();
      }
    }
  }

  function onCanvasPointerUp(e: PointerEvent) {
    if (interactionMode !== 'none') {
      interactionMode = 'none';
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

    if (showWatermark) {
      ctx.save();
      const scaleRef = offscreen.width / 600;
      const fontSize = Math.max(11, Math.round(13 * scaleRef));
      ctx.font = `600 ${fontSize}px Inter, system-ui, sans-serif`;

      const text = 'mewmer.com';
      const metrics = ctx.measureText(text);
      const padX = 8 * scaleRef;
      const padY = 4 * scaleRef;
      const w = metrics.width + (watermarkStyle === 'glassy' ? padX * 2 : 0);
      const h = fontSize + (watermarkStyle === 'glassy' ? padY * 2 : 0);
      const margin = 14 * scaleRef;

      let bx = offscreen.width - margin - w;
      let by = offscreen.height - margin - h;
      if (watermarkPosition === 'bottom-left') {
        bx = margin;
        by = offscreen.height - margin - h;
      } else if (watermarkPosition === 'top-right') {
        bx = offscreen.width - margin - w;
        by = margin;
      }

      if (watermarkStyle === 'glassy') {
        ctx.fillStyle = `rgba(11, 15, 23, ${watermarkOpacity * 0.4})`;
        ctx.strokeStyle = `rgba(255, 255, 255, ${watermarkOpacity * 0.22})`;
        ctx.lineWidth = 1;
        ctx.beginPath();
        if (ctx.roundRect) {
          ctx.roundRect(bx, by, w, h, 6 * scaleRef);
        } else {
          ctx.rect(bx, by, w, h);
        }
        ctx.fill();
        ctx.stroke();

        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = `rgba(255, 255, 255, ${watermarkOpacity})`;
        ctx.fillText(text, bx + w / 2, by + h / 2);
      } else {
        ctx.shadowColor = 'rgba(0, 0, 0, 0.75)';
        ctx.shadowBlur = 4 * scaleRef;
        ctx.shadowOffsetX = 1 * scaleRef;
        ctx.shadowOffsetY = 1 * scaleRef;

        ctx.textAlign = 'left';
        ctx.textBaseline = 'top';
        ctx.fillStyle = `rgba(255, 255, 255, ${watermarkOpacity})`;
        ctx.fillText(text, bx, by);
      }

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
      if (isAnimatedGif && exportFormat === 'webp' && currentGifFile) {
        showNotice('Processing animated GIF crop via worker pool...');
        const formData = new FormData();
        formData.append('media', currentGifFile);
        formData.append('cropX', Math.round(cropX).toString());
        formData.append('cropY', Math.round(cropY).toString());
        formData.append('cropW', Math.round(cropW).toString());
        formData.append('cropH', Math.round(cropH).toString());
        formData.append('outW', Math.round(outputWidth).toString());
        formData.append('outH', Math.round(outputHeight).toString());

        const res = await fetch('/api/v1/stickers/process-animated', {
          method: 'POST',
          body: formData,
        });

        if (!res.ok) {
          throw new Error('Server conversion failed');
        }

        const data = await res.json();
        const a = document.createElement('a');
        a.href = data.imageUrl;
        a.download = `mewmer_animated_${outputWidth}x${outputHeight}_${Date.now()}.webp`;
        a.click();
        showNotice(`Downloaded cropped animated WebP!`);
        return;
      }

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

      if (showWatermark) {
        ctx.save();
        const scaleRef = offscreen.width / 600;
        const fontSize = Math.max(11, Math.round(13 * scaleRef));
        ctx.font = `600 ${fontSize}px Inter, system-ui, sans-serif`;

        const text = 'mewmer.com';
        const metrics = ctx.measureText(text);
        const padX = 8 * scaleRef;
        const padY = 4 * scaleRef;
        const w = metrics.width + (watermarkStyle === 'glassy' ? padX * 2 : 0);
        const h = fontSize + (watermarkStyle === 'glassy' ? padY * 2 : 0);
        const margin = 14 * scaleRef;

        let bx = offscreen.width - margin - w;
        let by = offscreen.height - margin - h;
        if (watermarkPosition === 'bottom-left') {
          bx = margin;
          by = offscreen.height - margin - h;
        } else if (watermarkPosition === 'top-right') {
          bx = offscreen.width - margin - w;
          by = margin;
        }

        if (watermarkStyle === 'glassy') {
          ctx.fillStyle = `rgba(11, 15, 23, ${watermarkOpacity * 0.4})`;
          ctx.strokeStyle = `rgba(255, 255, 255, ${watermarkOpacity * 0.22})`;
          ctx.lineWidth = 1;
          ctx.beginPath();
          if (ctx.roundRect) {
            ctx.roundRect(bx, by, w, h, 6 * scaleRef);
          } else {
            ctx.rect(bx, by, w, h);
          }
          ctx.fill();
          ctx.stroke();

          ctx.textAlign = 'center';
          ctx.textBaseline = 'middle';
          ctx.fillStyle = `rgba(255, 255, 255, ${watermarkOpacity})`;
          ctx.fillText(text, bx + w / 2, by + h / 2);
        } else {
          ctx.shadowColor = 'rgba(0, 0, 0, 0.75)';
          ctx.shadowBlur = 4 * scaleRef;
          ctx.shadowOffsetX = 1 * scaleRef;
          ctx.shadowOffsetY = 1 * scaleRef;

          ctx.textAlign = 'left';
          ctx.textBaseline = 'top';
          ctx.fillStyle = `rgba(255, 255, 255, ${watermarkOpacity})`;
          ctx.fillText(text, bx, by);
        }

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
    loadImage(sampleTemplates[0].url, sampleTemplates[0].isGif);
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
        <div
          class="relative max-w-full max-h-[54vh] sm:max-h-[60vh] flex items-center justify-center overflow-hidden rounded shadow"
          style="aspect-ratio: {cropW} / {cropH}; width: 100%;"
        >
          {#if isAnimatedGif && imageSource}
            <img
              src={imageSource}
              alt="Animated GIF Preview"
              class="absolute inset-0 w-full h-full object-cover pointer-events-none"
              style="object-position: {((cropX + cropW / 2) / Math.max(1, imgNaturalWidth)) * 100}% {((cropY + cropH / 2) / Math.max(1, imgNaturalHeight)) * 100}%;"
            />
          {/if}

          <canvas
            bind:this={canvas}
            class="relative z-10 w-full h-full object-contain touch-none select-none {interactionMode === 'pan-image' ? 'cursor-grabbing' : (cropW < imgNaturalWidth || cropH < imgNaturalHeight ? 'cursor-grab' : 'cursor-default')}"
            onpointerdown={onCanvasPointerDown}
            onpointermove={onCanvasPointerMove}
            onpointerup={onCanvasPointerUp}
            onpointercancel={onCanvasPointerUp}
          ></canvas>
        </div>

        <span class="absolute top-3 left-3 px-2 py-1 text-[11px] font-mono font-medium rounded-md bg-dark-bg/85 backdrop-blur border border-dark-border text-slate-300">
          {outputWidth} × {outputHeight} px {isAnimatedGif ? '• 🎬 GIF' : ''}
        </span>

        {#if selectedLayer}
          <span class="absolute top-3 right-3 px-2 py-1 text-[11px] font-sans font-medium rounded-md bg-brand-500/20 backdrop-blur border border-brand-500/40 text-brand-300">
            🔄 Drag top handle to rotate • ⤡ Drag corner to resize
          </span>
        {:else if cropW < imgNaturalWidth || cropH < imgNaturalHeight}
          <span class="absolute top-3 right-3 px-2 py-1 text-[11px] font-sans font-medium rounded-md bg-dark-bg/85 backdrop-blur border border-dark-border text-slate-400">
            🖐️ Drag image to adjust framing
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
          {#if isExporting}
            <span class="animate-spin">⏳</span>
            <span>Processing...</span>
          {:else}
            <span>💾</span>
            <span>Download {exportFormat.toUpperCase()} ({outputWidth} × {outputHeight})</span>
          {/if}
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
            Change Image or GIF
          </label>
          <div class="flex items-center gap-2">
            <label class="flex-1 cursor-pointer py-2.5 px-3 rounded-xl border border-dashed border-brand-500/40 hover:border-brand-500 bg-brand-500/5 hover:bg-brand-500/10 text-center text-xs font-medium text-brand-300 transition-colors">
              <span>📁 Upload Photo or GIF</span>
              <input type="file" accept="image/*,.gif" class="hidden" onchange={handleFileUpload} />
            </label>
          </div>

          <div class="flex items-center gap-2 pt-1 flex-wrap">
            <span class="text-xs text-dark-muted">Or try:</span>
            {#each sampleTemplates as template}
              <button
                type="button"
                onclick={() => loadImage(template.url, template.isGif)}
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
              WebP {isAnimatedGif ? '(Animated)' : ''}
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

        <div class="pt-3 border-t border-dark-border space-y-3">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold text-slate-300 uppercase tracking-wider flex items-center gap-1.5">
              <span>🏷️</span>
              <span>mewmer.com Watermark</span>
            </span>
            <button
              type="button"
              onclick={() => { showWatermark = !showWatermark; renderCanvas(); }}
              class="text-xs font-medium px-2 py-0.5 rounded border transition-colors {showWatermark ? 'bg-brand-500/20 border-brand-500/40 text-brand-300' : 'bg-dark-bg border-dark-border text-slate-500'}"
            >
              {showWatermark ? 'Enabled' : 'Disabled'}
            </button>
          </div>

          {#if showWatermark}
            <div class="space-y-2.5">
              <div class="flex items-center gap-2">
                <span class="text-xs text-dark-muted shrink-0">Style:</span>
                <button
                  type="button"
                  onclick={() => { watermarkStyle = 'text-only'; renderCanvas(); }}
                  class="text-xs px-2.5 py-1 rounded-lg border transition-colors {watermarkStyle === 'text-only' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400'}"
                >
                  Text Only (No background)
                </button>
                <button
                  type="button"
                  onclick={() => { watermarkStyle = 'glassy'; renderCanvas(); }}
                  class="text-xs px-2.5 py-1 rounded-lg border transition-colors {watermarkStyle === 'glassy' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400'}"
                >
                  Glassy Pill
                </button>
              </div>

              <div class="flex items-center gap-2">
                <span class="text-xs text-dark-muted shrink-0">Position:</span>
                <button
                  type="button"
                  onclick={() => { watermarkPosition = 'bottom-right'; renderCanvas(); }}
                  class="text-xs px-2 py-1 rounded-lg border transition-colors {watermarkPosition === 'bottom-right' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400'}"
                >
                  Bottom Right
                </button>
                <button
                  type="button"
                  onclick={() => { watermarkPosition = 'bottom-left'; renderCanvas(); }}
                  class="text-xs px-2 py-1 rounded-lg border transition-colors {watermarkPosition === 'bottom-left' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400'}"
                >
                  Bottom Left
                </button>
                <button
                  type="button"
                  onclick={() => { watermarkPosition = 'top-right'; renderCanvas(); }}
                  class="text-xs px-2 py-1 rounded-lg border transition-colors {watermarkPosition === 'top-right' ? 'bg-brand-500/20 border-brand-500 text-brand-200' : 'bg-dark-bg border-dark-border text-slate-400'}"
                >
                  Top Right
                </button>
              </div>

              <div class="flex items-center justify-between pt-1">
                <span class="text-xs text-dark-muted">Opacity ({Math.round(watermarkOpacity * 100)}%)</span>
                <input
                  type="range"
                  min="0.25"
                  max="0.85"
                  step="0.05"
                  bind:value={watermarkOpacity}
                  oninput={() => renderCanvas()}
                  class="w-36 accent-brand-500"
                />
              </div>
            </div>
          {/if}
        </div>

        <div class="p-3 rounded-xl bg-dark-bg border border-dark-border space-y-2">
          <div class="flex items-center justify-between text-xs">
            <span class="text-dark-muted">Resolution:</span>
            <span class="font-mono font-bold text-white">{outputWidth} × {outputHeight} px</span>
          </div>
          <div class="flex items-center justify-between text-xs">
            <span class="text-dark-muted">Format:</span>
            <span class="font-mono font-bold text-brand-300">
              {exportFormat.toUpperCase()} {isAnimatedGif && exportFormat === 'webp' ? '(Looping Animated)' : ''}
            </span>
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
            {#if isExporting}
              <span class="animate-spin">⏳</span>
              <span>Processing...</span>
            {:else}
              <span>💾</span>
              <span>Download {exportFormat.toUpperCase()}</span>
            {/if}
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