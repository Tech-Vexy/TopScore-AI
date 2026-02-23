import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Hero from '@/components/Hero';
import Screenshots from '@/components/Screenshots';
import Testimonials from '@/components/Testimonials';
import VideoDemo from '@/components/VideoDemo';
import FAQ from '@/components/FAQ';
import Newsletter from '@/components/Newsletter';
import CtaBanner from '@/components/CtaBanner';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
  alternates: { canonical: 'https://topscoreapp.ai' },
};

const organizationSchema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'TopScore AI',
  url: 'https://topscoreapp.ai',
  logo: 'https://topscoreapp.ai/logo.png',
  sameAs: [],
  description:
    'AI-powered tutoring and study resources for Kenyan students — CBC, IGCSE & KCSE.',
};

const softwareSchema = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'TopScore AI',
  url: 'https://topscoreapp.ai',
  logo: 'https://topscoreapp.ai/logo.png',
  description: 'AI-powered tutoring, study resources, and smart study tools for Kenyan students.',
  applicationCategory: 'EducationalApplication',
  operatingSystem: 'iOS, Android, Web',
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'KES',
  },
  screenshot: 'https://topscoreapp.ai/og-image.png',
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
      <Testimonials />
      <FAQ />
      <Newsletter />
      <CtaBanner />
      <Footer />
    </main>
  );
}
