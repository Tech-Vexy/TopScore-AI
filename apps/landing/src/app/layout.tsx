import type { Metadata } from 'next';
import './globals.css';
import { LocaleProvider } from '@/i18n';

const siteUrl = 'https://topscore-ai.com';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'TopScore AI — Smart Learning for Every Kenyan Student',
    template: '%s | TopScore AI',
  },
  description:
    'AI-powered tutoring, CBC & KCSE study resources, past papers, smart study tools, parental insights, and offline mode — all in one free app for Kenyan students.',
  keywords: [
    'TopScore AI', 'Kenya education app', 'CBC learning', 'KCSE revision',
    'AI tutor Kenya', 'study app Kenya', 'past papers', 'IGCSE Kenya',
    'online tutoring', 'student app', 'parental controls learning',
  ],
  authors: [{ name: 'TopScore AI' }],
  creator: 'TopScore AI',
  publisher: 'TopScore AI',
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, 'max-image-preview': 'large' },
  },
  openGraph: {
    type: 'website',
    locale: 'en_KE',
    url: siteUrl,
    siteName: 'TopScore AI',
    title: 'TopScore AI — Smart Learning for Every Kenyan Student',
    description:
      'AI-powered tutoring, study resources, and smart tools built for Kenyan students. Free to download.',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'TopScore AI — Smart Learning for Every Kenyan Student',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'TopScore AI — Smart Learning for Every Kenyan Student',
    description:
      'AI-powered tutoring, study resources, and smart tools built for Kenyan students. Free to download.',
    images: ['/og-image.png'],
    creator: '@TopScoreAI',
  },
  alternates: {
    canonical: siteUrl,
  },
  icons: {
    icon: '/logo.png',
    apple: '/logo.png',
  },
};

import BackToTop from '@/components/BackToTop';
import CookieConsent from '@/components/CookieConsent';
import Analytics from '@/components/Analytics';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        {/* Enable CSS View Transitions for smooth page navigation */}
        <style>{`
          @view-transition { navigation: auto; }

          ::view-transition-old(root) {
            animation: 220ms cubic-bezier(0.4, 0, 1, 1) both vtFadeOut;
          }
          ::view-transition-new(root) {
            animation: 320ms cubic-bezier(0, 0, 0.2, 1) 80ms both vtFadeIn;
          }
          @keyframes vtFadeOut {
            from { opacity: 1; transform: translateY(0); }
            to   { opacity: 0; transform: translateY(-8px); }
          }
          @keyframes vtFadeIn {
            from { opacity: 0; transform: translateY(12px); }
            to   { opacity: 1; transform: translateY(0); }
          }
          @media (prefers-reduced-motion: reduce) {
            ::view-transition-old(root),
            ::view-transition-new(root) { animation: none; }
          }
        `}</style>
      </head>
      <body>
        <LocaleProvider>
          {children}
          <CookieConsent />
        </LocaleProvider>
        <BackToTop />
        <Analytics />
      </body>
    </html>
  );
}
