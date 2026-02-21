'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './HowItWorks.module.css';

const stepNums = ['1', '2', '3', '4'];

export default function HowItWorks() {
    const { t } = useLocale();

    return (
        <section id="how-it-works">
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('howItWorks.label')}</div>
                    <h2 className={styles.title}>{t('howItWorks.title')}</h2>
                    <p className={styles.sub}>
                        {t('howItWorks.sub')}
                    </p>
                </AnimatedSection>

                <div className={styles.stepsGrid}>
                    {stepNums.map((num, i) => {
                        const titleKey = `howItWorks.${i}.title` as TranslationKey;
                        const descKey = `howItWorks.${i}.desc` as TranslationKey;
                        return (
                            <AnimatedSection key={num} animation="fadeUp" delay={`${i * 0.1}s`}>
                                <div className={styles.step}>
                                    <div className={styles.num}>{num}</div>
                                    <h3>{t(titleKey)}</h3>
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
