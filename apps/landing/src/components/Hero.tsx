'use client';
import { useEffect, useRef, useState } from 'react';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Button } from '@/components/ui/button';
import styles from './Hero.module.css';

const stats: { end: number; suffix: string; key: TranslationKey }[] = [
    { end: 10000, suffix: '+', key: 'hero.stat.resources' },
    { end: 24, suffix: '/7', key: 'hero.stat.tutor' },
    { end: 8, suffix: '', key: 'hero.stat.tools' },
    { end: 100, suffix: '%', key: 'hero.stat.free' },
];

function Counter({ end, suffix }: { end: number; suffix: string }) {
    const [count, setCount] = useState(0);
    const ref = useRef<HTMLElement>(null);
    const started = useRef(false);

    useEffect(() => {
        const el = ref.current;
        if (!el) return;
        const obs = new IntersectionObserver(([entry]) => {
            if (!entry.isIntersecting || started.current) return;
            started.current = true;
            const duration = 1400;
            const steps = 60;
            const step = end / steps;
            let current = 0;
            const t = setInterval(() => {
                current = Math.min(current + step, end);
                setCount(Math.round(current));
                if (current >= end) clearInterval(t);
            }, duration / steps);
        }, { threshold: 0.5 });
        obs.observe(el);
        return () => obs.disconnect();
    }, [end]);

    return <strong ref={ref}>{end >= 1000 ? (count / 1000).toFixed(count >= end ? 0 : 1) + 'K' : count}{suffix}</strong>;
}

export default function Hero() {
    const { t } = useLocale();

    return (
        <section className={styles.hero} id="home">
            <div className={styles.bg} aria-hidden />
            <div className={styles.content}>
                <AnimatedSection animation="fadeUp" delay="0s">
                    <div className={styles.badge}>
                        <span>🇰🇪</span> {t('hero.badge')}
                    </div>
                </AnimatedSection>

                <AnimatedSection animation="fadeUp" delay="0.1s">
                    <h1 className={styles.h1}>
                        {t('hero.h1a')}<span className={styles.grad}>{t('hero.h1Grad')}</span><br />
                        {t('hero.h1b')}
                    </h1>
                </AnimatedSection>

                <AnimatedSection animation="fadeUp" delay="0.2s">
                    <p className={styles.sub}>
                        {t('hero.sub')}
                    </p>
                </AnimatedSection>

                <AnimatedSection animation="fadeUp" delay="0.3s">
                    <div className={styles.actions}>
                        <Button asChild size="lg" className={styles.btnPrimary}>
                            <a href="https://app.topscoreapp.ai">
                                {t('hero.cta')}
                            </a>
                        </Button>
                        <Button asChild variant="outline" size="lg" className={styles.btnSecondary}>
                            <a href="/features">
                                {t('hero.explore')}
                            </a>
                        </Button>
                    </div>
                </AnimatedSection>

                <AnimatedSection animation="fadeUp" delay="0.4s">
                    <div className={styles.stats}>
                        {stats.map((s) => (
                            <div className={styles.statItem} key={s.key}>
                                <Counter end={s.end} suffix={s.suffix} />
                                <span>{t(s.key)}</span>
                            </div>
                        ))}
                    </div>
                </AnimatedSection>
            </div>
        </section>
    );
}
