'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Card, CardContent, CardHeader } from "@/components/ui/card";
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

                        // ... (in the mapping loop)
                        return (
                            <AnimatedSection key={num} animation="fadeUp" delay={`${i * 0.1}s`} className={styles.stepWrapper}>
                                <Card className={styles.step}>
                                    <div className={styles.num}>{num}</div>
                                    <CardHeader className="p-0 space-y-2">
                                        <h3 className="font-bold text-xl">{t(titleKey)}</h3>
                                    </CardHeader>
                                    <CardContent className="p-0 pt-2 flex-grow">
                                        <p className="text-muted-foreground">{t(descKey)}</p>
                                    </CardContent>
                                </Card>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
