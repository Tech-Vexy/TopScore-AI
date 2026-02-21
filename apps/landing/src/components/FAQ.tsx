'use client';
import { useState } from 'react';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './FAQ.module.css';

const faqCount = 8;

export default function FAQ() {
    const { t } = useLocale();
    const [openIdx, setOpenIdx] = useState<number | null>(null);

    return (
        <section id="faq" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('faq.label')}</div>
                    <h2 className={styles.title}>{t('faq.title')}</h2>
                    <p className={styles.sub}>{t('faq.sub')}</p>
                </AnimatedSection>

                <div className={styles.list}>
                    {Array.from({ length: faqCount }, (_, i) => {
                        const qKey = `faq.${i}.q` as TranslationKey;
                        const aKey = `faq.${i}.a` as TranslationKey;
                        const isOpen = openIdx === i;
                        return (
                            <AnimatedSection key={i} animation="fadeUp" delay={`${i * 0.05}s`}>
                                <div className={`${styles.item} ${isOpen ? styles.itemOpen : ''}`}>
                                    <button
                                        className={styles.question}
                                        onClick={() => setOpenIdx(isOpen ? null : i)}
                                        aria-expanded={isOpen}
                                    >
                                        <span>{t(qKey)}</span>
                                        <span className={styles.chevron}>{isOpen ? '−' : '+'}</span>
                                    </button>
                                    <div className={styles.answer} style={{ maxHeight: isOpen ? '500px' : '0' }}>
                                        <p>{t(aKey)}</p>
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
