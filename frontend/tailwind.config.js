/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class'],
  content: [
    './app/**/*.{js,ts,jsx,tsx}',
    './src/**/*.{js,ts,jsx,tsx}',
    './components/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        kertas: '#F4F1E9',
        permukaan: '#FBF8F6',
        tinta: '#1C1B17',
        pinus: '#12392F',
        'lampu-struk': '#F0A81E',
        sorot: '#F8E7B8',
        lumut: '#2E7A59',
        bata: '#B9232C',
        background: '#F4F1E9',
        foreground: '#1C1B17',
        border: '#1C1B17',
        input: '#1C1B17',
        ring: '#12392F',
        primary: {
          DEFAULT: '#12392F',
          foreground: '#F4F1E9',
        },
        secondary: {
          DEFAULT: '#F8E7B8',
          foreground: '#1C1B17',
        },
        destructive: {
          DEFAULT: '#B9232C',
          foreground: '#F4F1E9',
        },
      },
      borderRadius: {
        DEFAULT: '4px',
        lg: '4px',
        md: '4px',
        sm: '4px',
      },
      boxShadow: {
        DEFAULT: 'none',
        sm: 'none',
        md: 'none',
        lg: 'none',
        xl: 'none',
        '2xl': 'none',
      },
      fontFamily: {
        sans: ['var(--font-sans)', 'sans-serif'],
        mono: ['var(--font-mono)', 'monospace'],
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
};
