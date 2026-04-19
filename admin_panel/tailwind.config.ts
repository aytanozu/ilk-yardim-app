import type { Config } from 'tailwindcss';

// Clinical Pulse tokens — mirrors lib/core/theme/app_colors.dart
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#b7102a',
          container: '#db313f',
          fixed: '#ffdad8',
        },
        onprimary: '#ffffff',
        secondary: {
          DEFAULT: '#485f84',
          container: '#bbd3fd',
        },
        onsecondary: '#ffffff',
        tertiary: {
          DEFAULT: '#006860',
          container: '#008379',
        },
        ontertiary: '#ffffff',
        surface: {
          DEFAULT: '#f3fcf0',
          low: '#edf6ea',
          lowest: '#ffffff',
          high: '#e2ebdf',
          highest: '#dce5d9',
          inverse: '#2a322b',
        },
        onsurface: {
          DEFAULT: '#161d16',
          variant: '#5b403f',
        },
        severity: {
          critical: '#b7102a',
          serious: '#e8a33c',
          minor: '#006860',
        },
        error: '#ba1a1a',
        onerror: '#ffffff',
      },
      borderRadius: {
        xl: '24px',
      },
      fontFamily: {
        sans: [
          'Inter',
          'ui-sans-serif',
          'system-ui',
          '-apple-system',
          'Segoe UI',
          'Roboto',
          'sans-serif',
        ],
      },
      boxShadow: {
        ambient: '0 4px 24px -2px rgba(22, 29, 22, 0.06)',
      },
    },
  },
  plugins: [],
} satisfies Config;
