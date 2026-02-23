import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import HowItWorks from '@/components/HowItWorks';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
    title: 'How It Works',
    description:
        'Get started with TopScore AI in 4 steps: download the app, pick your grade and subjects, study with your AI tutor, and build a daily learning streak.',
    openGraph: {
        title: 'How It Works — TopScore AI',
        description: 'Get started in 4 easy steps — free to download, no credit card needed.',
        url: 'https://topscoreapp.ai/how-it-works',
        images: [{ url: '/og-image.png', width: 1200, height: 630 }],
    },
    alternates: { canonical: 'https://topscoreapp.ai/how-it-works' },
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'HowTo',
    name: 'How to Get Started with TopScore AI',
    description: metadata.description,
    step: [
        { '@type': 'HowToStep', name: 'Download & Sign Up', text: 'Install TopScore AI and create a free account.' },
        { '@type': 'HowToStep', name: 'Pick Your Grade & Subjects', text: 'Set your curriculum, grade, and subjects.' },
        { '@type': 'HowToStep', name: 'Study with AI', text: 'Chat with your AI tutor or browse the resource library.' },
        { '@type': 'HowToStep', name: 'Build Your Streak', text: 'Study daily to build streaks and unlock achievements.' },
    ],
};

export default function HowItWorksPage() {
    return (
        <main>
            <JsonLd data={schema} />
            <Nav />
            <div style={{ paddingTop: '68px' }}>
                <HowItWorks />
            </div>
            <Footer />
        </main>
    );
}

