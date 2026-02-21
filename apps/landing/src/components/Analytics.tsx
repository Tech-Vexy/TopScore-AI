'use client';
import { useEffect, useState } from 'react';
import Script from 'next/script';

const GA_MEASUREMENT_ID = 'G-BDBMLR9DD0';

export default function Analytics() {
    const [consented, setConsented] = useState(false);

    useEffect(() => {
        // Check if consent was already given
        if (localStorage.getItem('topscore_cookie_consent') === 'true') {
            setConsented(true);
        }
        // Listen for new consent
        const handler = () => setConsented(true);
        window.addEventListener('cookie-consent-granted', handler);
        return () => window.removeEventListener('cookie-consent-granted', handler);
    }, []);

    if (!consented) return null;

    return (
        <>
            <Script
                src={`https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`}
                strategy="afterInteractive"
            />
            <Script id="ga4-init" strategy="afterInteractive">
                {`
                    window.dataLayer = window.dataLayer || [];
                    function gtag(){dataLayer.push(arguments);}
                    gtag('js', new Date());
                    gtag('config', '${GA_MEASUREMENT_ID}');
                `}
            </Script>
        </>
    );
}
