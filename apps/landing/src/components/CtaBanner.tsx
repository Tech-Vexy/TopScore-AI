'use client';
import Image from 'next/image';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './CtaBanner.module.css';

export default function CtaBanner() {
    const { locale, t } = useLocale();

    const playBadgeSrc = locale === 'sw'
        ? '/GetItOnGooglePlay_Badge_Web_color_Swahili.svg'
        : '/GetItOnGooglePlay_Badge_Web_color_English.svg';

    const playBadgeAlt = locale === 'sw'
        ? 'Ipate kwenye Google Play'
        : 'Get it on Google Play';

    return (
        <section id="download" className={styles.wrapper}>
            <div className={styles.inner}>
                <AnimatedSection animation="fadeUp" delay="0s">
                    <div className={styles.label}>{t('cta.label')}</div>
                </AnimatedSection>
                <AnimatedSection animation="fadeUp" delay="0.1s">
                    <h2 className={styles.title}>
                        {t('cta.title')}<br />
                        <span className={styles.grad}>{t('cta.titleGrad')}</span>
                    </h2>
                </AnimatedSection>
                <AnimatedSection animation="fadeUp" delay="0.2s">
                    <p className={styles.sub}>
                        {t('cta.sub')}
                    </p>
                </AnimatedSection>
                <AnimatedSection animation="fadeUp" delay="0.3s">
                    <div className={styles.buttons}>
                        <a href="https://app.topscoreapp.ai" className={styles.storeBtn} aria-label={playBadgeAlt}>
                            <Image src={playBadgeSrc} alt={playBadgeAlt} width={200} height={59} className={styles.badge} />
                        </a>
                        <a href="https://app.topscoreapp.ai" className={styles.storeBtn} aria-label="Download on the App Store">
                            <Image src="/app-store-badge.svg" alt="Download on the App Store" width={200} height={59} className={styles.badge} />
                        </a>
                    </div>
                </AnimatedSection>
            </div>
        </section>
    );
}
