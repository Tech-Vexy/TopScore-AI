'use client';
import { useState } from 'react';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import { cn } from "@/lib/utils";
import AnimatedSection from './AnimatedSection';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardFooter } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Check } from "lucide-react";
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

                    <div className="flex items-center justify-center gap-4 mt-8">
                        <span className={cn("text-sm transition-colors", !annual ? "text-foreground font-semibold" : "text-muted-foreground")}>
                            {t('pricing.monthly')}
                        </span>
                        <Switch
                            checked={annual}
                            onCheckedChange={setAnnual}
                            aria-label="Toggle billing period"
                        />
                        <span className={cn("text-sm transition-colors", annual ? "text-foreground font-semibold" : "text-muted-foreground")}>
                            {t('pricing.annual')}
                            <span className="ml-2 inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-400">
                                {t('pricing.save')}
                            </span>
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
                                <Card className={cn(
                                    "relative flex flex-col h-full",
                                    p.featured ? "border-primary shadow-xl scale-105 z-10" : "border-border"
                                )}>
                                    {badge && badge !== badgeKey && (
                                        <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-primary text-primary-foreground text-xs font-bold px-3 py-1 rounded-full shadow-lg">
                                            {badge}
                                        </div>
                                    )}
                                    <CardHeader>
                                        <CardTitle className="text-2xl font-bold">{t(nameKey)}</CardTitle>
                                        <div className="mt-4 flex items-baseline gap-1">
                                            <span className="text-4xl font-bold">
                                                {t(annual ? priceAnnualKey : priceMonthlyKey)}
                                            </span>
                                            <span className="text-muted-foreground">/{t(periodKey)}</span>
                                        </div>
                                    </CardHeader>
                                    <CardContent className="flex-grow">
                                        <ul className="space-y-3">
                                            {t(featuresKey).split('|').map((f) => (
                                                <li key={f} className="flex items-start gap-3 text-sm">
                                                    <Check className="h-4 w-4 text-primary mt-0.5 shrink-0" />
                                                    <span>{f}</span>
                                                </li>
                                            ))}
                                        </ul>
                                    </CardContent>
                                    <CardFooter>
                                        <Button asChild variant={p.featured ? "default" : "outline"} className="w-full">
                                            <a href="https://app.topscoreapp.ai">
                                                {t(ctaKey)}
                                            </a>
                                        </Button>
                                    </CardFooter>
                                </Card>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
