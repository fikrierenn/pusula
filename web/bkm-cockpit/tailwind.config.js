/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        darkbg: '#070A11',
        darkcard: 'rgba(17, 24, 39, 0.75)',
        gold: {
          400: '#FBBF24',
          500: '#F59E0B',
        },
        teal: {
          400: '#2DD4BF',
          500: '#14B8A6',
        }
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        display: ['Outfit', 'sans-serif'],
      }
    },
  },
  plugins: [],
}
