/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        primary: '#006600',      // Kenyan green
        secondary: '#FFB300',    // Warm gold
        accent: '#C62828',       // Soft red
        background: '#FAFAFA',
        surface: '#FFFFFF',
        text: '#212121',
        textSecondary: '#757575',
        success: '#4CAF50',
        error: '#F44336',
      },
    },
  },
  plugins: [],
}
