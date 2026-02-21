'use client';
import { useRef, useState, useEffect } from 'react';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './Screenshots.module.css';

const screens: { emoji: string; idx: number; gradient: string }[] = [
    { emoji: '🤖', idx: 0, gradient: 'linear-gradient(135deg, #7C6EEA 0%, #a855f7 100%)' },
    { emoji: '📚', idx: 1, gradient: 'linear-gradient(135deg, #34D9CB 0%, #3b82f6 100%)' },
    { emoji: '🔥', idx: 2, gradient: 'linear-gradient(135deg, #FF6B6B 0%, #f7971e 100%)' },
    { emoji: '👨‍👩‍👧', idx: 3, gradient: 'linear-gradient(135deg, #a8edea 0%, #15803d 100%)' },
];

export default function Screenshots() {
    const { t } = useLocale();
    const scrollRef = useRef<HTMLDivElement>(null);
    const [active, setActive] = useState(0);

    useEffect(() => {
        const el = scrollRef.current;
        if (!el) return;
        const onScroll = () => {
            const idx = Math.round(el.scrollLeft / (el.offsetWidth * 0.72));
            setActive(Math.min(idx, screens.length - 1));
        };
        el.addEventListener('scroll', onScroll, { passive: true });
        return () => el.removeEventListener('scroll', onScroll);
    }, []);

    const scrollTo = (i: number) => {
        scrollRef.current?.scrollTo({ left: i * (scrollRef.current.offsetWidth * 0.72), behavior: 'smooth' });
    };

    return (
        <section id="screenshots" className={styles.wrapper}>
            <AnimatedSection animation="fadeUp">
                <div className={styles.label}>{t('screenshots.label')}</div>
                <h2 className={styles.title}>
                    {t('screenshots.title')}<br />{t('screenshots.titleBr')}
                </h2>
                <p className={styles.sub}>{t('screenshots.sub')}</p>
            </AnimatedSection>

            <AnimatedSection animation="fadeUp" delay="0.2s">
                <div className={styles.carousel} ref={scrollRef}>
                    {screens.map((s) => {
                        const nameKey = `screenshots.${s.idx}.name` as TranslationKey;
                        const descKey = `screenshots.${s.idx}.desc` as TranslationKey;
                        return (
                            <div className={styles.phone} key={s.idx}>
                                <div className={styles.phoneScreen} style={{ background: s.gradient }}>
                                    <div className={styles.phoneNotch} />
                                    <div className={styles.screenEmoji}>{s.emoji}</div>
                                    <h3 className={styles.screenTitle}>{t(nameKey)}</h3>
                                    <p className={styles.screenDesc}>{t(descKey)}</p>
                                </div>
                            </div>
                        );
                    })}
                </div>

                <div className={styles.dots}>
                    {screens.map((_, i) => (
                        <button
                            key={i}
                            className={`${styles.dot} ${active === i ? styles.dotActive : ''}`}
                            onClick={() => scrollTo(i)}
                            aria-label={`Screenshot ${i + 1}`}
                        />
                    ))}
                </div>
            </AnimatedSection>
        </section>
    );
}
