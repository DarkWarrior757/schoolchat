import { useEffect, useState } from 'react';
import type { ThemeMode } from '@/types';

const STORAGE_KEY = 'schoolchat-theme';

function getSystemDark(): boolean {
  return window.matchMedia('(prefers-color-scheme: dark)').matches;
}

function applyTheme(mode: ThemeMode) {
  const isDark = mode === 'dark' || (mode === 'system' && getSystemDark());
  const root = document.documentElement;
  if (isDark) {
    root.classList.add('dark-mode');
    root.classList.remove('light-mode');
    root.style.setProperty('color-scheme', 'dark');
  } else {
    root.classList.add('light-mode');
    root.classList.remove('dark-mode');
    root.style.setProperty('color-scheme', 'light');
  }
}

export function useTheme() {
  const [theme, setThemeState] = useState<ThemeMode>(() => {
    const stored = localStorage.getItem(STORAGE_KEY) as ThemeMode | null;
    return stored || 'dark';
  });

  useEffect(() => {
    applyTheme(theme);
    localStorage.setItem(STORAGE_KEY, theme);
  }, [theme]);

  useEffect(() => {
    if (theme !== 'system') return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = () => applyTheme('system');
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, [theme]);

  const setTheme = (mode: ThemeMode) => setThemeState(mode);

  return { theme, setTheme };
}
