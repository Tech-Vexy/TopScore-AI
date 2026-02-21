import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Hero from '@/components/Hero';
import Screenshots from '@/components/Screenshots';
import VideoDemo from '@/components/VideoDemo';
import FAQ from '@/components/FAQ';
import Newsletter from '@/components/Newsletter';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
  alternates: { canonical: 'https://topscore-ai.com' },
};

const organizationSchema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'TopScore AI',
  url: 'https://topscore-ai.com',
  logo: 'https://topscore-ai.com/logo.png',
  sameAs: [],
  description:
    'AI-powered tutoring and study resources for Kenyan students — CBC, IGCSE & KCSE.',
};

const softwareSchema = {
  '@context': 'https://schema.org',
  '@type': 'MobileApplication',
  name: 'TopScore AI',
  operatingSystem: 'Android, iOS',
  applicationCategory: 'EducationApplication',
  offers: { '@type': 'Offer', price: '0', priceCurrency: 'KES' },
  description:
    'AI tutor, study resources, parental controls, offline mode, and smart study tools for Kenyan students.',
  screenshot: 'https://topscore-ai.com/og-image.png',
};

export default function Home() {
  return (
    <main>
      <JsonLd data={organizationSchema} />
      <JsonLd data={softwareSchema} />
      <Nav />
      <Hero />
      <Screenshots />
      <VideoDemo />
      <FAQ />
      <Newsletter />
      <Footer />
    </main>
  );
}
