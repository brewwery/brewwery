import type { Config } from "tailwindcss";

export default {
  darkMode: ["class"],
  content: ["./index.html", "./src/renderer/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        border: "hsl(220 12% 18%)",
        background: "hsl(220 13% 9%)",
        foreground: "hsl(38 22% 92%)",
        muted: "hsl(220 10% 13%)",
        "muted-foreground": "hsl(220 9% 62%)",
        accent: "hsl(39 96% 52%)",
        "accent-foreground": "hsl(32 95% 8%)"
      },
      fontFamily: {
        sans: ["Inter", "ui-sans-serif", "system-ui", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "sans-serif"]
      },
      boxShadow: {
        panel: "0 16px 50px rgb(0 0 0 / 0.28)"
      }
    }
  },
  plugins: []
} satisfies Config;
