import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Pricing from '@/components/Pricing';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'Pricing',
    description:
        'Start for free and upgrade when ready. TopScore AI offers flexible pricing plans tailored to Kenyan learners.',
    openGraph: {
        title: 'Pricing — TopScore AI',
        description: 'Start for free and upgrade when ready. Flexible pricing plans.',
        url: 'https://topscoreapp.ai/pricing',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscoreapp.ai/pricing' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Pricing | TopScore AI',
    url: 'https://topscoreapp.ai/pricing',
    description: metadata.description,
    alternates: { canonical: 'https://topscoreapp.ai/pricing' },
    openGraph: {
        url: 'https://topscoreapp.ai/pricing',
    },
    isPartOf: { '@type': 'WebSite', name: 'TopScore AI', url: 'https://topscoreapp.ai' },
};

export default function PricingPage() {
    return (
        <main>
            <JsonLd data={schema} />
            <Nav />
            <div style={{ paddingTop: '68px' }}>
                <Pricing />
            </div>
            <Footer />
        </main>
    );
}
