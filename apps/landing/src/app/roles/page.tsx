import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Roles from '@/components/Roles';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'For Students, Parents & Teachers',
    description:
        'TopScore AI tailors a unique experience for students, parents, and teachers — with role-specific dashboards, parental controls, weekly reports, and teacher resource management.',
    openGraph: {
        title: 'For Students, Parents & Teachers — TopScore AI',
        description: 'Role-specific dashboards for students, parents, and teachers.',
        url: 'https://topscoreapp.ai/roles',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscoreapp.ai/roles' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'TopScore AI — For Students, Parents & Teachers',
    url: 'https://topscoreapp.ai/roles',
    description: metadata.description,
};

export default function RolesPage() {
    return (
        <main>
            <JsonLd data={schema} />
            <Nav />
            <div style={{ paddingTop: '68px' }}>
                <Roles />
            </div>
            <Footer />
        </main>
    );
}

