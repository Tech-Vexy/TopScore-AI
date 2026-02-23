'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import styles from './Roles.module.css';

const roleMeta: { emoji: string; idx: number }[] = [
    { emoji: '🎓', idx: 0 },
    { emoji: '👩‍👧', idx: 1 },
    { emoji: '👨‍🏫', idx: 2 },
];

export default function Roles() {
    const { t } = useLocale();

    return (
        <section id="roles" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('roles.label')}</div>
                    <h2 className={styles.title}>
                        {t('roles.title')}<br />{t('roles.titleBr')}
                    </h2>
                    <p className={styles.sub}>
                        {t('roles.sub')}
                    </p>
                </AnimatedSection>

                <div className={styles.grid}>
                    {roleMeta.map((r, i) => {
                        const titleKey = `roles.${r.idx}.title` as TranslationKey;
                        const descKey = `roles.${r.idx}.desc` as TranslationKey;
                        const perksKey = `roles.${r.idx}.perks` as TranslationKey;
                        return (
                            <AnimatedSection key={r.idx} animation="fadeUp" delay={`${i * 0.12}s`}>
                                <Card className={styles.card}>
                                    <div className={styles.emoji}>{r.emoji}</div>
                                    <CardHeader className="p-0 space-y-2">
                                        <h3 className="font-bold text-xl">{t(titleKey)}</h3>
                                    </CardHeader>
                                    <CardContent className="p-0 pt-2">
                                        <p className="text-muted-foreground mb-4">{t(descKey)}</p>
                                        <ul className={styles.perks}>
                                            {t(perksKey).split(',').map((p) => (
                                                <li className={styles.perk} key={p}>{p}</li>
                                            ))}
                                        </ul>
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
