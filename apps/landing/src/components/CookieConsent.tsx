'use client';
import { useState, useEffect } from 'react';
import { useLocale } from '@/i18n';
import styles from './CookieConsent.module.css';

const CONSENT_KEY = 'topscore_cookie_consent';

export function useCookieConsent() {
    const [consent, setConsent] = useState<boolean | null>(null);
    useEffect(() => {
        const stored = localStorage.getItem(CONSENT_KEY);
        if (stored === 'true') setConsent(true);
        else if (stored === 'false') setConsent(false);
    }, []);
    return consent;
}

export default function CookieConsent() {
    const { t } = useLocale();
    const [visible, setVisible] = useState(false);

    useEffect(() => {
        const stored = localStorage.getItem(CONSENT_KEY);
        if (stored === null) setVisible(true);
    }, []);

    const respond = (accepted: boolean) => {
        localStorage.setItem(CONSENT_KEY, String(accepted));
        setVisible(false);
        if (accepted) window.dispatchEvent(new Event('cookie-consent-granted'));
    };

    if (!visible) return null;

    return (
        <div className={styles.banner}>
            <p className={styles.text}>{t('cookie.text')}</p>
            <div className={styles.actions}>
                <button className={styles.accept} onClick={() => respond(true)}>
                    {t('cookie.accept')}
                </button>
                <button className={styles.decline} onClick={() => respond(false)}>
                    {t('cookie.decline')}
                </button>
            </div>
        </div>
    );
}
