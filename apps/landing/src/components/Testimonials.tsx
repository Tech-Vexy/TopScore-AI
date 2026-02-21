'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './Testimonials.module.css';

const testimonialMeta: { avatar: string; rating: number; idx: number }[] = [
    { avatar: '👩🏾‍🎓', rating: 5, idx: 0 },
    { avatar: '👨🏾‍🏫', rating: 5, idx: 1 },
    { avatar: '👩🏾', rating: 5, idx: 2 },
    { avatar: '👦🏾', rating: 5, idx: 3 },
];

const stars = (n: number) => '★'.repeat(n) + '☆'.repeat(5 - n);

export default function Testimonials() {
    const { t } = useLocale();

    return (
        <section className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('testimonials.label')}</div>
                    <h2 className={styles.title}>
                        {t('testimonials.title')}<br />{t('testimonials.titleBr')}
                    </h2>
                </AnimatedSection>

                <div className={styles.grid}>
                    {testimonialMeta.map((tm, i) => {
                        const nameKey = `testimonials.${tm.idx}.name` as TranslationKey;
                        const roleKey = `testimonials.${tm.idx}.role` as TranslationKey;
                        const quoteKey = `testimonials.${tm.idx}.quote` as TranslationKey;
                        return (
                            <AnimatedSection key={tm.idx} animation="fadeUp" delay={`${i * 0.1}s`}>
                                <div className={styles.card}>
                                    <div className={styles.stars} aria-label={`${tm.rating} out of 5 stars`}>
                                        {stars(tm.rating)}
                                    </div>
                                    <p className={styles.quote}>&ldquo;{t(quoteKey)}&rdquo;</p>
                                    <div className={styles.person}>
                                        <span className={styles.avatar}>{tm.avatar}</span>
                                        <div>
                                            <strong>{t(nameKey)}</strong>
                                            <span>{t(roleKey)}</span>
                                        </div>
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
