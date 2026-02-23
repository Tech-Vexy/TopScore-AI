'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Card, CardContent } from "@/components/ui/card";
import { Quote } from "lucide-react";
import styles from './Testimonials.module.css';

const testimonialMeta: { avatar: string; rating: number; idx: number }[] = [
    { avatar: '👩🏾‍🎓', rating: 5, idx: 0 },
    { avatar: '👨🏾‍🏫', rating: 5, idx: 1 },
    { avatar: '👩🏾', rating: 5, idx: 2 },
    { avatar: '👦🏾', rating: 5, idx: 3 },
];

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
                                <Card className="border-none shadow-md overflow-hidden bg-card/50 backdrop-blur-sm">
                                    <CardContent className="p-6">
                                        <Quote className="h-8 w-8 text-primary/20 mb-4" />
                                        <div className="flex gap-0.5 text-yellow-400 mb-4">
                                            {Array.from({ length: 5 }).map((_, i) => (
                                                <span key={i}>{i < tm.rating ? '★' : '☆'}</span>
                                            ))}
                                        </div>
                                        <p className="text-lg italic text-foreground/90 leading-relaxed mb-6">
                                            &ldquo;{t(quoteKey)}&rdquo;
                                        </p>
                                        <div className="flex items-center gap-4 border-t pt-6 border-border/50">
                                            <span className="text-3xl grayscale hover:grayscale-0 transition-all cursor-default">
                                                {tm.avatar}
                                            </span>
                                            <div className="flex flex-col">
                                                <span className="font-bold text-sm">{t(nameKey)}</span>
                                                <span className="text-xs text-muted-foreground">{t(roleKey)}</span>
                                            </div>
                                        </div>
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
