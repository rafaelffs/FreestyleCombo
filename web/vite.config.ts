import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    proxy: {
      '/api': 'http://localhost:5050',
      // ShareController builds its own redirect/OG-tag URLs from the
      // request's Host header. Vite's string-shorthand proxy defaults to
      // changeOrigin: true, which rewrites Host to the target (5050) before
      // it reaches the API — so ShareController would see "localhost:5050"
      // instead of this dev server's actual "localhost:5173" and generate
      // a redirect to a port nothing serves the SPA on. changeOrigin: false
      // preserves the original Host so it self-references correctly, same
      // as production nginx's explicit `proxy_set_header Host $host`.
      '/share': { target: 'http://localhost:5050', changeOrigin: false },
    },
  },
})
