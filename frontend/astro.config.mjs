import { defineConfig } from 'astro/config';
import svelte from '@astrojs/svelte';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  server: {
    port: 3031,
    host: true,
  },
  vite: {
    server: {
      proxy: {
        '/api': {
          target: 'http://localhost:3030',
          changeOrigin: true,
        },
        '/uploads': {
          target: 'http://localhost:3030',
          changeOrigin: true,
        },
      },
    },
  },
  integrations: [
    svelte(),
    tailwind({
      applyBaseStyles: false,
    }),
  ],
});
