'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './Features.module.css';

const featureMeta: { icon: string; bg: string; idx: number }[] = [
    { icon: '🤖', bg: 'linear-gradient(135deg, #7C6EEA, #a855f7)', idx: 0 },
    { icon: '📚', bg: 'linear-gradient(135deg, #34D9CB, #3b82f6)', idx: 1 },
    { icon: '🔥', bg: 'linear-gradient(135deg, #FF6B6B, #f7971e)', idx: 2 },
    { icon: '👨‍👩‍👧', bg: 'linear-gradient(135deg, #a8edea, #fed6e3)', idx: 3 },
    { icon: '📶', bg: 'linear-gradient(135deg, #3a7bd5, #00d2ff)', idx: 4 },
    { icon: '🔍', bg: 'linear-gradient(135deg, #f093fb, #f5576c)', idx: 5 },
];

export default function Features() {
    const { t } = useLocale();

    return (
        <section id="features">
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <div className={styles.label}>{t('features.label')}</div>
                        <h2 className={styles.title}>
                            {t('features.title')}<br />{t('features.titleBr')}
                        </h2>
                        <p className={styles.sub}>
                            {t('features.sub')}
                        </p>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {featureMeta.map((f, i) => {
                        const titleKey = `features.${f.idx}.title` as TranslationKey;
                        const descKey = `features.${f.idx}.desc` as TranslationKey;
                        const tagsKey = `features.${f.idx}.tags` as TranslationKey;
                        return (
                            <AnimatedSection key={f.idx} animation="fadeUp" delay={`${i * 0.08}s`}>
                                <div className={styles.card}>
                                    <div className={styles.icon} style={{ background: f.bg }}>
                                        {f.icon}
                                    </div>
                                    <h3>{t(titleKey)}</h3>
                                    <p>{t(descKey)}</p>
                                    <div className={styles.tags}>
                                        {t(tagsKey).split(',').map((tag) => (
                                            <span className={styles.tag} key={tag}>{tag}</span>
                                        ))}
                                    </div>
                                </div>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
