import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Tools from '@/components/Tools';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'Study Tools',
    description:
        '8 built-in study tools in TopScore AI: Smart Scanner, Scientific Calculator, Virtual Science Lab, Interactive Periodic Table, AI Flashcard Generator, Timetable, Global Search, and PDF Viewer.',
    openGraph: {
        title: 'Study Tools — TopScore AI',
        description: '8 built-in tools: scanner, calculator, science lab, periodic table, flashcards, timetable, search & PDF viewer.',
        url: 'https://topscore-ai.com/tools',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscore-ai.com/tools' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name: 'TopScore AI Study Tools',
    url: 'https://topscore-ai.com/tools',
    itemListElement: [
        'Smart Scanner', 'Scientific Calculator', 'Science Lab',
        'Periodic Table', 'Flashcard Generator', 'Timetable',
        'Global Search', 'PDF Viewer',
    ].map((name, i) => ({
        '@type': 'ListItem',
        position: i + 1,
        name,
    })),
};

export default function ToolsPage() {
    return (
        <main>
            <JsonLd data={schema} />
            <Nav />
            <div style={{ paddingTop: '68px' }}>
                <Tools />
            </div>
            <Footer />
        </main>
    );
}

