import type { Config } from "tailwindcss"

const config = {
    darkMode: "class",
    content: [
        './pages/**/*.{ts,tsx}',
        './components/**/*.{ts,tsx}',
        './app/**/*.{ts,tsx}',
        './src/**/*.{ts,tsx}',
    ],
    prefix: "",
    theme: {
        container: {
            center: true,
            padding: "2rem",
            screens: {
                "2xl": "1400px",
            },
        },
        extend: {
            colors: {
                border: "var(--border)",
                input: "var(--input)",
                ring: "var(--ring)",
                background: "var(--bg)",
                foreground: "var(--text)",
                primary: {
                    DEFAULT: "var(--primary)",
                    foreground: "var(--text)",
                },
                secondary: {
                    DEFAULT: "var(--secondary)",
                    foreground: "var(--text)",
                },
                destructive: {
                    DEFAULT: "var(--accent)",
                    foreground: "var(--text)",
                },
                muted: {
                    DEFAULT: "var(--text-muted)",
                    foreground: "var(--text-dim)",
                },
                accent: {
                    DEFAULT: "var(--accent)",
                    foreground: "var(--text)",
                },
                popover: {
                    DEFAULT: "var(--bg-card)",
                    foreground: "var(--text)",
                },
                card: {
                    DEFAULT: "var(--bg-card)",
                    foreground: "var(--text)",
                },
            },
            borderRadius: {
                lg: "0.5rem",
                md: "calc(0.5rem - 2px)",
                sm: "calc(0.5rem - 4px)",
            },
            keyframes: {
                "accordion-down": {
                    from: { height: "0" },
                    to: { height: "var(--radix-accordion-content-height)" },
                },
                "accordion-up": {
                    from: { height: "var(--radix-accordion-content-height)" },
                    to: { height: "0" },
                },
            },
            animation: {
                "accordion-down": "accordion-down 0.2s ease-out",
                "accordion-up": "accordion-up 0.2s ease-out",
            },
        },
    },
    plugins: [require("tailwindcss-animate")],
} satisfies Config

export default config
