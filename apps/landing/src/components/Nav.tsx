'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { usePathname } from 'next/navigation';
import { useLocale } from '@/i18n';
import { Button } from '@/components/ui/button';
import { Menu } from 'lucide-react';
import {
    Sheet,
    SheetContent,
    SheetTrigger,
} from "@/components/ui/sheet";
import { ThemeToggle } from "./ThemeToggle";
import LanguageSwitcher from "./LanguageSwitcher";
import styles from './Nav.module.css';

import type { TranslationKey } from '@/i18n';

const linkKeys: { href: string; key: TranslationKey }[] = [
    { href: '/features', key: 'nav.features' },
    { href: '/how-it-works', key: 'nav.howItWorks' },
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
                        <div className="flex items-center gap-3 ml-4 border-l pl-4 border-border/50">
                            <LanguageSwitcher />
                            <ThemeToggle />
                            <Button asChild className={styles.cta}>
                                <Link href="https://app.topscoreapp.ai">
                                    {t('nav.download')}
                                </Link>
                            </Button>
                        </div>
                    </nav>

                    {/* Mobile menu using Shadcn Sheet */}
                    <div className="md:hidden">
                        <Sheet open={open} onOpenChange={setOpen}>
                            <SheetTrigger asChild>
                                <Button variant="ghost" size="icon" className={styles.burger}>
                                    <Menu className="h-6 w-6" />
                                    <span className="sr-only">Toggle menu</span>
                                </Button>
                            </SheetTrigger>
                            <SheetContent side="right" className={styles.drawer}>
                                <nav className={styles.drawerLinks}>
                                    {linkKeys.map(({ href, key }) => (
                                        <Link
                                            key={href}
                                            href={href}
                                            className={`${styles.drawerLink} ${pathname === href ? styles.drawerActive : ''}`}
                                            onClick={() => setOpen(false)}
                                        >
                                            {t(key)}
                                        </Link>
                                    ))}
                                    <Button asChild className={styles.drawerCta}>
                                        <Link href="https://app.topscoreapp.ai" onClick={() => setOpen(false)}>
                                            {t('nav.downloadMobile')}
                                        </Link>
                                    </Button>
                                </nav>
                            </SheetContent>
                        </Sheet>
                    </div>
                </div>
            </header>
        </>
    );
}
