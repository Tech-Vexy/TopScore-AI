'use client';
import { useState } from 'react';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import styles from './Newsletter.module.css';

export default function Newsletter() {
    const { t } = useLocale();
    const [email, setEmail] = useState('');
    const [submitted, setSubmitted] = useState(false);
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!email || loading) return;

        setLoading(true);
        // Simulate a tiny networking delay for better perceived feedback
        await new Promise(r => setTimeout(r, 800));

        try {
            const list = JSON.parse(localStorage.getItem('topscore_newsletter') ?? '[]');
            list.push({ email, date: new Date().toISOString() });
            localStorage.setItem('topscore_newsletter', JSON.stringify(list));
        } catch { /* noop */ }

        setLoading(false);
        setSubmitted(true);
    };

    return (
        <section className={styles.wrapper}>
            <div className={styles.inner}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('newsletter.label')}</div>
                    <h2 className={styles.title}>{t('newsletter.title')}</h2>
                    <p className={styles.sub}>{t('newsletter.sub')}</p>
                </AnimatedSection>

                <AnimatedSection animation="fadeUp" delay="0.15s">
                    {submitted ? (
                        <div className={styles.success}>
                            ✅ {t('newsletter.success')}
                        </div>
                    ) : (
                        <form className={styles.form} onSubmit={handleSubmit}>
                            <Input
                                type="email"
                                className={styles.input}
                                placeholder={t('newsletter.placeholder')}
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                required
                            />
                            <Button type="submit" className={styles.btn} disabled={loading} size="lg">
                                {loading ? '...' : t('newsletter.cta')}
                            </Button>
                        </form>
                    )}
                </AnimatedSection>
            </div>
        </section>
    );
}
