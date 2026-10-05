/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        dark: {
          bg: '#0B0F17',
          card: '#131B2E',
          cardHover: '#1A243D',
          border: '#1F2B48',
          muted: '#64748B',
        },
        brand: {
          50: '#F5F3FF',
          100: '#EDE9FE',
          200: '#DDD6FE',
          300: '#C4B5FD',
          400: '#A78BFA',
          500: '#8B5CF6',
          600: '#7C3AED',
          700: '#6D28D9',
          800: '#5B21B6',
          900: '#4C1D95',
        },
        whatsapp: {
          DEFAULT: '#25D366',
          hover: '#1EBE5D',
          dark: '#075E54',
          light: '#DCF8C6',
        },
        meme: {
          amber: '#F59E0B',
          cyan: '#06B6D4',
          rose: '#F43F5E',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        display: ['Poppins', 'system-ui', 'sans-serif'],
        impact: ['Impact', 'Arial Black', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
