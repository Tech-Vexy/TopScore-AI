import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import CtaBanner from '@/components/CtaBanner';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'Download TopScore AI — Free',
    description:
        'Download TopScore AI free on Android or iOS. AI tutor, CBC & KCSE study resources, offline mode, and smart study tools — all free, no credit card required.',
    openGraph: {
        title: 'Download TopScore AI — Free on Android & iOS',
        description: 'Get TopScore AI free. No credit card required. Available on Google Play and the App Store.',
        url: 'https://topscore-ai.com/download',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscore-ai.com/download' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    name: 'TopScore AI',
    operatingSystem: 'Android, iOS',
    applicationCategory: 'EducationApplication',
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'KES' },
    downloadUrl: 'https://topscore-ai.com/download',
};

export default function DownloadPage() {
    return (
        <main>
            <JsonLd data={schema} />
            <Nav />
            <div style={{ paddingTop: '68px', minHeight: 'calc(100vh - 68px)', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                <CtaBanner />
            </div>
            <Footer />
        </main>
    );
}

