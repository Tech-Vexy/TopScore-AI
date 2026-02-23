'use client';
import Link from 'next/link';
import Image from 'next/image';
import { useLocale } from '@/i18n';
import { Button } from "@/components/ui/button";
import styles from './Footer.module.css';

export default function Footer() {
    const year = new Date().getFullYear();
    const { t } = useLocale();

    return (
        <footer className={styles.footer}>
            <div className={styles.logo}>
                <Image src="/logo.png" alt="TopScore AI" width={36} height={36} />
                TopScore AI
            </div>
            <p>{t('footer.tagline')}</p>
            <div className={styles.legalLinks}>
                <Link href="/privacy">{t('footer.privacy')}</Link>
                <span className={styles.dot}>·</span>
                <Link href="/terms">{t('footer.terms')}</Link>
                <span className={styles.dot}>·</span>
                <Link href="/sitemap.xml">{t('footer.sitemap')}</Link>
                <span className={styles.dot}>·</span>
                <Button asChild variant="link" className="p-0 h-auto font-normal text-muted-foreground hover:text-foreground">
                    <a href="https://app.topscoreapp.ai" target="_blank" rel="noopener noreferrer">
                        {t('footer.launchApp')}
                    </a>
                </Button>
            </div>
            <p>{t('footer.copy', { year: String(year) })}</p>
        </footer>
    );
}
