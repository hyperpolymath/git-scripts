import {defineConfig} from "vite"

export default defineConfig({
  resolve: {
    preserveSymlinks: true
  },
  server: {
    port: 5174,
    strictPort: true,
    proxy: {
      "/api": {
        target: "http://127.0.0.1:4077",
        changeOrigin: true
      }
    }
  }
})
