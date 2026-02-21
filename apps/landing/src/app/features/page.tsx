import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Features from '@/components/Features';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'Features',
    description:
        'Explore TopScore AI features: AI Tutor available 24/7, full CBC & KCSE resource library, daily streak tracker, Family Link parental controls, offline mode, and real-time global search.',
    openGraph: {
        title: 'Features — TopScore AI',
        description: 'AI Tutor, resource library, streaks, parental controls, offline mode, and global search — all in one app.',
        url: 'https://topscore-ai.com/features',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscore-ai.com/features' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'TopScore AI Features',
    url: 'https://topscore-ai.com/features',
    description: metadata.description,
    isPartOf: { '@type': 'WebSite', name: 'TopScore AI', url: 'https://topscore-ai.com' },
};

export default function FeaturesPage() {
    return (
        <main>
            <JsonLd data={schema} />
            <Nav />
            <div style={{ paddingTop: '68px' }}>
                <Features />
            </div>
            <Footer />
        </main>
    );
}

