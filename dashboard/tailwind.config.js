/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./Components/**/*.razor",
    "./wwwroot/**/*.html"
  ],
  theme: {
    extend: {}
  },
  plugins: [require("daisyui")],
  daisyui: {
    themes: ["corporate", "business"],
    darkTheme: "business"
  }
};
