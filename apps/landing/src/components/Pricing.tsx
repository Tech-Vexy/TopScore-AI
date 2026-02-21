'use client';
import { useState } from 'react';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './Pricing.module.css';

const plans: { idx: number; featured: boolean }[] = [
    { idx: 0, featured: false },
    { idx: 1, featured: true },
];

export default function Pricing() {
    const { t } = useLocale();
    const [annual, setAnnual] = useState(false);

    return (
        <section id="pricing" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('pricing.label')}</div>
                    <h2 className={styles.title}>
                        {t('pricing.title')}<br />{t('pricing.titleBr')}
                    </h2>
                    <p className={styles.sub}>{t('pricing.sub')}</p>

                    <div className={styles.toggle}>
                        <span className={!annual ? styles.toggleActive : ''}>{t('pricing.monthly')}</span>
                        <button
                            className={styles.toggleBtn}
                            onClick={() => setAnnual((a) => !a)}
                            aria-label="Toggle billing period"
                        >
                            <span className={`${styles.toggleKnob} ${annual ? styles.toggleKnobRight : ''}`} />
                        </button>
                        <span className={annual ? styles.toggleActive : ''}>
                            {t('pricing.annual')} <span className={styles.save}>{t('pricing.save')}</span>
                        </span>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {plans.map((p, i) => {
                        const nameKey = `pricing.${p.idx}.name` as TranslationKey;
                        const priceMonthlyKey = `pricing.${p.idx}.priceMonthly` as TranslationKey;
                        const priceAnnualKey = `pricing.${p.idx}.priceAnnual` as TranslationKey;
                        const periodKey = `pricing.${p.idx}.period` as TranslationKey;
                        const ctaKey = `pricing.${p.idx}.cta` as TranslationKey;
                        const featuresKey = `pricing.${p.idx}.features` as TranslationKey;
                        const badgeKey = `pricing.${p.idx}.badge` as TranslationKey;
                        const badge = t(badgeKey);

                        return (
                            <AnimatedSection key={p.idx} animation="fadeUp" delay={`${i * 0.12}s`}>
                                <div className={`${styles.card} ${p.featured ? styles.featured : ''}`}>
                                    {badge && badge !== badgeKey && (
                                        <div className={styles.badge}>{badge}</div>
                                    )}
                                    <h3 className={styles.planName}>{t(nameKey)}</h3>
                                    <div className={styles.price}>
                                        {t(annual ? priceAnnualKey : priceMonthlyKey)}
                                        <span className={styles.period}>/{t(periodKey)}</span>
                                    </div>
                                    <ul className={styles.features}>
                                        {t(featuresKey).split('|').map((f) => (
                                            <li key={f}><span className={styles.check}>✓</span> {f}</li>
                                        ))}
                                    </ul>
                                    <a href="https://app.topscoreapp.ai" className={p.featured ? styles.ctaPrimary : styles.ctaSecondary}>
                                        {t(ctaKey)}
                                    </a>
                                </div>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
