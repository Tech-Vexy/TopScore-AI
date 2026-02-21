'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './Tools.module.css';

const toolMeta: { icon: string; idx: number }[] = [
    { icon: '📷', idx: 0 },
    { icon: '🧮', idx: 1 },
    { icon: '⚗️', idx: 2 },
    { icon: '🧬', idx: 3 },
    { icon: '🃏', idx: 4 },
    { icon: '📅', idx: 5 },
    { icon: '🔍', idx: 6 },
    { icon: '📖', idx: 7 },
];

export default function Tools() {
    const { t } = useLocale();

    return (
        <section id="tools">
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('tools.label')}</div>
                    <h2 className={styles.title}>
                        {t('tools.title')}<br />{t('tools.titleBr')}
                    </h2>
                    <p className={styles.sub}>
                        {t('tools.sub')}
                    </p>
                </AnimatedSection>

                <div className={styles.strip}>
                    {toolMeta.map((tm, i) => {
                        const nameKey = `tools.${tm.idx}.name` as TranslationKey;
                        const descKey = `tools.${tm.idx}.desc` as TranslationKey;
                        return (
                            <AnimatedSection key={tm.idx} animation="fadeUp" delay={`${i * 0.06}s`}>
                                <div className={styles.item}>
                                    <div className={styles.icon}>{tm.icon}</div>
                                    <h4>{t(nameKey)}</h4>
                                    <p>{t(descKey)}</p>
                                </div>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
