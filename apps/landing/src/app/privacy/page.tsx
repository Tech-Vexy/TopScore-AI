import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Footer from '@/components/Footer';
import styles from '@/components/LegalPage.module.css';

export const metadata: Metadata = {
    title: 'Privacy Policy',
    description: 'TopScore AI Privacy Policy — how we collect, use, and protect your data.',
    alternates: { canonical: 'https://topscore-ai.com/privacy' },
};

export default function PrivacyPage() {
    return (
        <main>
            <Nav />
            <article className={styles.legal}>
                <h1>Privacy Policy</h1>
                <p className={styles.updated}>Last updated: February 2026</p>

                <h2>1. Introduction</h2>
                <p>
                    TopScore AI (&quot;we&quot;, &quot;us&quot;, or &quot;our&quot;) is committed to protecting the
                    privacy of students, parents, teachers, and all users of our educational platform. This
                    Privacy Policy explains how we collect, use, store, and share information when you use the
                    TopScore AI mobile application and website.
                </p>

                <h2>2. Information We Collect</h2>
                <p>We may collect the following types of information:</p>
                <ul>
                    <li><strong>Account Information:</strong> Name, email address, phone number, user role (student, parent, teacher), and school information.</li>
                    <li><strong>Usage Data:</strong> Study activity, streak data, subjects accessed, time spent, and interactions with the AI tutor.</li>
                    <li><strong>Device Information:</strong> Device type, operating system, unique device identifiers, and mobile network information.</li>
                    <li><strong>Content:</strong> Messages sent to the AI tutor, uploaded documents, and notes saved within the app.</li>
                </ul>

                <h2>3. How We Use Your Information</h2>
                <p>We use collected information to:</p>
                <ul>
                    <li>Provide and improve our AI tutoring services</li>
                    <li>Personalise learning experiences and recommendations</li>
                    <li>Track study progress and generate performance reports</li>
                    <li>Enable parental oversight through Family Link features</li>
                    <li>Communicate important updates and notifications</li>
                    <li>Ensure platform safety and prevent misuse</li>
                </ul>

                <h2>4. Data Sharing</h2>
                <p>
                    We do not sell your personal data. We may share information with trusted third-party service
                    providers (such as cloud hosting, analytics, and authentication services) solely to operate
                    and improve our platform. Parents/guardians may access their linked children&apos;s study data
                    through the Family Link feature.
                </p>

                <h2>5. Children&apos;s Privacy</h2>
                <p>
                    TopScore AI is designed for use by students, including those under 18 years of age. We
                    implement safeguards including AI content moderation, parental controls, and limited data
                    collection to protect young users. Parental consent is required for users under 13.
                </p>

                <h2>6. Data Security</h2>
                <p>
                    We implement industry-standard security measures including encryption in transit and at
                    rest, access controls, and regular security audits. Data is stored on secure cloud
                    infrastructure.
                </p>

                <h2>7. Data Retention</h2>
                <p>
                    We retain your data for as long as your account is active. You may request deletion of
                    your account and associated data at any time by contacting us.
                </p>

                <h2>8. Your Rights</h2>
                <p>You have the right to:</p>
                <ul>
                    <li>Access and export your personal data</li>
                    <li>Correct inaccurate information</li>
                    <li>Request deletion of your account</li>
                    <li>Withdraw consent for optional data processing</li>
                    <li>Lodge a complaint with relevant data protection authorities</li>
                </ul>

                <h2>9. Cookies &amp; Analytics</h2>
                <p>
                    Our website uses cookies and analytics tools to understand visitor behaviour and improve
                    our services. You may control cookie preferences through the consent banner displayed on
                    your first visit.
                </p>

                <h2>10. Contact Us</h2>
                <p>
                    For privacy-related inquiries, please contact us at{' '}
                    <a href="mailto:privacy@topscore-ai.com">privacy@topscore-ai.com</a>.
                </p>
            </article>
            <Footer />
        </main>
    );
}
