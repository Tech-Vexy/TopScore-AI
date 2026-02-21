'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname } from 'next/navigation';
import { useLocale } from '@/i18n';
import styles from './Nav.module.css';

import type { TranslationKey } from '@/i18n';

const linkKeys: { href: string; key: TranslationKey }[] = [
    { href: '/features', key: 'nav.features' },
    { href: '/how-it-works', key: 'nav.howItWorks' },
    { href: '/roles', key: 'nav.forYou' },
    { href: '/tools', key: 'nav.tools' },
];

export default function Nav() {
    const [scrolled, setScrolled] = useState(false);
    const [open, setOpen] = useState(false);
    const pathname = usePathname();
    const { t } = useLocale();

    useEffect(() => {
        const onScroll = () => setScrolled(window.scrollY > 20);
        window.addEventListener('scroll', onScroll);
        return () => window.removeEventListener('scroll', onScroll);
    }, []);

    // Close menu on route change
    useEffect(() => { setOpen(false); }, [pathname]);

    return (
        <>
            <header
                className={`${styles.nav} ${scrolled ? styles.scrolled : ''}`}
            >
                <div className={styles.inner}>
                    <Link href="/" className={styles.logo}>
                        <Image src="/logo.png" alt="TopScore AI" width={36} height={36} className={styles.logoImg} />
                        TopScore AI
                    </Link>

                    {/* Desktop links */}
                    <nav className={styles.links}>
                        {linkKeys.map(({ href, key }) => (
                            <Link key={href} href={href} className={pathname === href ? styles.active : ''}>
                                {t(key)}
                            </Link>
                        ))}
                        <Link href="https://app.topscoreapp.ai" className={styles.cta}>
                            {t('nav.download')}
                        </Link>
                    </nav>

                    {/* Mobile hamburger */}
                    <button
                        className={`${styles.burger} ${open ? styles.burgerOpen : ''}`}
                        onClick={() => setOpen((o) => !o)}
                        aria-label={open ? 'Close menu' : 'Open menu'}
                        aria-expanded={open}
                    >
                        <span /><span /><span />
                    </button>
                </div>
            </header>

            {/* Mobile drawer */}
            <div className={`${styles.drawer} ${open ? styles.drawerOpen : ''}`} aria-hidden={!open}>
                <nav className={styles.drawerLinks}>
                    {linkKeys.map(({ href, key }) => (
                        <Link key={href} href={href} className={`${styles.drawerLink} ${pathname === href ? styles.drawerActive : ''}`}>
                            {t(key)}
                        </Link>
                    ))}
                    <Link href="https://app.topscoreapp.ai" className={styles.drawerCta}>
                        {t('nav.downloadMobile')}
                    </Link>
                </nav>
            </div>
            {open && <div className={styles.overlay} onClick={() => setOpen(false)} />}
        </>
    );
}
