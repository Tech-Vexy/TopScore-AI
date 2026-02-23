'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import AnimatedSection from './AnimatedSection';
import styles from './FAQ.module.css';

const faqCount = 8;


export default function FAQ() {
    const { t } = useLocale();

    return (
        <section id="faq" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('faq.label')}</div>
                    <h2 className={styles.title}>{t('faq.title')}</h2>
                    <p className={styles.sub}>{t('faq.sub')}</p>
                </AnimatedSection>

                <div className={styles.list}>
                    <Accordion type="single" collapsible className="w-full">
                        {Array.from({ length: faqCount }, (_, i) => {
                            const qKey = `faq.${i}.q` as TranslationKey;
                            const aKey = `faq.${i}.a` as TranslationKey;
                            return (
                                <AnimatedSection key={i} animation="fadeUp" delay={`${i * 0.05}s`}>
                                    <AccordionItem value={`item-${i}`} className={styles.item}>
                                        <AccordionTrigger className={styles.question}>
                                            <span>{t(qKey)}</span>
                                        </AccordionTrigger>
                                        <AccordionContent className={styles.answer}>
                                            <p>{t(aKey)}</p>
                                        </AccordionContent>
                                    </AccordionItem>
                                </AnimatedSection>
                            );
                        })}
                    </Accordion>
                </div>
            </div>
        </section>
    );
}
