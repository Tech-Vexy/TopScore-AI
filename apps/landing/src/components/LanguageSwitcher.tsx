'use client';

import { useLocale, type Locale } from '@/i18n';
import styles from './LanguageSwitcher.module.css';

const options: { value: Locale; label: string; flag: string }[] = [
    { value: 'en', label: 'EN', flag: '🇬🇧' },
    { value: 'sw', label: 'SW', flag: '🇰🇪' },
];

export default function LanguageSwitcher() {
    const { locale, setLocale } = useLocale();

    return (
        <div className={styles.switcher} role="radiogroup" aria-label="Language">
            {options.map((opt) => (
                <button
                    key={opt.value}
                    className={`${styles.option} ${locale === opt.value ? styles.active : ''}`}
                    onClick={() => setLocale(opt.value)}
                    role="radio"
                    aria-checked={locale === opt.value}
                    aria-label={opt.value === 'en' ? 'English' : 'Kiswahili'}
                >
                    <span className={styles.flag}>{opt.flag}</span>
                    {opt.label}
                </button>
            ))}
        </div>
    );
}
