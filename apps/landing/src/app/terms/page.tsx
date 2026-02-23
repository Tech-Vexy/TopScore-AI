import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Footer from '@/components/Footer';
import styles from '@/components/LegalPage.module.css';

export const metadata: Metadata = {
    title: 'Terms of Service',
    description: 'TopScore AI Terms of Service — rules and guidelines for using our platform.',
    alternates: { canonical: 'https://topscoreapp.ai/terms' },
};

export default function TermsPage() {
    return (
        <main>
            <Nav />
            <article className={styles.legal}>
                <h1>Terms of Service</h1>
                <p className={styles.updated}>Last updated: February 2026</p>

                <h2>1. Acceptance of Terms</h2>
                <p>
                    By downloading, accessing, or using TopScore AI (&quot;the App&quot;), you agree to be bound
                    by these Terms of Service. If you do not agree to these terms, please do not use the App.
                    If you are under 18, your parent or guardian must agree to these terms on your behalf.
                </p>

                <h2>2. Description of Service</h2>
                <p>
                    TopScore AI is an AI-powered educational platform providing tutoring assistance, study
                    resources, past papers, and smart study tools for Kenyan
                    learners following the CBC, KCSE, and IGCSE curricula.
                </p>

                <h2>3. User Accounts</h2>
                <p>
                    You are responsible for maintaining the confidentiality of your account credentials and
                    for all activities that occur under your account. You must provide accurate and complete
                    information when creating an account.
                </p>

                <h2>4. Acceptable Use</h2>
                <p>You agree not to:</p>
                <ul>
                    <li>Use the App for any unlawful purpose</li>
                    <li>Attempt to bypass AI content moderation or safety filters</li>
                    <li>Share your account credentials with others</li>
                    <li>Upload harmful, offensive, or inappropriate content</li>
                    <li>Attempt to reverse-engineer, decompile, or hack the App</li>
                    <li>Use the App to generate content for academic dishonesty</li>
                </ul>

                <h2>5. AI-Generated Content</h2>
                <p>
                    TopScore AI uses artificial intelligence to provide tutoring assistance. While we strive
                    for accuracy, AI-generated content may occasionally contain errors. The App is intended as
                    a supplementary educational tool and should not be the sole source of academic guidance.
                    Always verify important information with official educational resources.
                </p>

                <h2>6. Subscriptions &amp; Payments</h2>
                <p>
                    TopScore AI offers both free and premium (Pro) plans. Premium features require a paid
                    subscription. New users receive a 7-day free trial of Pro features. Subscriptions
                    auto-renew unless cancelled before the renewal date. Refund requests are handled in
                    accordance with Google Play Store and Apple App Store policies.
                </p>

                <h2>7. Intellectual Property</h2>
                <p>
                    All content, design, code, and AI models within TopScore AI are the intellectual property
                    of TopScore AI and its licensors. Study resources may be sourced from publicly available
                    educational materials and are provided for personal educational use only.
                </p>

                <h2>8. Limitation of Liability</h2>
                <p>
                    TopScore AI is provided &quot;as is&quot; without warranties of any kind. We are not liable for
                    any indirect, incidental, or consequential damages arising from your use of the App. Our
                    total liability shall not exceed the amount you have paid for the service in the
                    preceding 12 months.
                </p>

                <h2>9. Termination</h2>
                <p>
                    We reserve the right to suspend or terminate your account if you violate these terms. You
                    may delete your account at any time through the App settings.
                </p>

                <h2>10. Changes to Terms</h2>
                <p>
                    We may update these Terms of Service from time to time. We will notify you of significant
                    changes through the App or via email. Your continued use of the App after changes
                    constitutes acceptance of the updated terms.
                </p>

                <h2>11. Governing Law</h2>
                <p>
                    These terms shall be governed by the laws of the Republic of Kenya. Any disputes shall be
                    resolved through arbitration in Nairobi, Kenya.
                </p>

                <h2>12. Contact Us</h2>
                <p>
                    For questions about these terms, please contact us at{' '}
                    <a href="mailto:legal@topscore-ai.com">legal@topscore-ai.com</a>.
                </p>
            </article>
            <Footer />
        </main>
    );
}
