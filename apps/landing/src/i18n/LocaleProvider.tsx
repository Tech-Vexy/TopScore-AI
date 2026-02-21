'use client';

import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import en, { type TranslationKey } from './en';
import sw from './sw';

export type Locale = 'en' | 'sw';

const dictionaries: Record<Locale, Record<TranslationKey, string>> = { en, sw };

interface LocaleContextValue {
    locale: Locale;
    setLocale: (l: Locale) => void;
    t: (key: TranslationKey, vars?: Record<string, string>) => string;
}

const LocaleContext = createContext<LocaleContextValue | null>(null);



export function LocaleProvider({ children }: { children: ReactNode }) {
    const [locale, setLocaleState] = useState<Locale>('en');

    // Auto-detect browser language on mount (default: English)
    useEffect(() => {
        try {
            const primary = (navigator.languages?.[0] ?? navigator.language ?? 'en').toLowerCase();
            const detected: Locale = primary.startsWith('sw') ? 'sw' : 'en';
            setLocaleState(detected);
            document.documentElement.lang = detected;
        } catch { /* SSR / unavailable */ }
    }, []);

    const setLocale = useCallback((l: Locale) => {
        setLocaleState(l);
        document.documentElement.lang = l;
    }, []);

    const t = useCallback((key: TranslationKey, vars?: Record<string, string>) => {
        let value = dictionaries[locale][key] ?? key;
        if (vars) {
            for (const [k, v] of Object.entries(vars)) {
                value = value.replace(`{${k}}`, v);
            }
        }
        return value;
    }, [locale]);

    return (
        <LocaleContext.Provider value={{ locale, setLocale, t }}>
            {children}
        </LocaleContext.Provider>
    );
}

export function useLocale() {
    const ctx = useContext(LocaleContext);
    if (!ctx) throw new Error('useLocale must be used within <LocaleProvider>');
    return ctx;
}
