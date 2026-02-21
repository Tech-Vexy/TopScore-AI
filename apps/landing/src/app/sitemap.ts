import { MetadataRoute } from 'next';

const siteUrl = 'https://topscore-ai.com';

export default function sitemap(): MetadataRoute.Sitemap {
    const now = new Date();
    const pages = [
        { url: '/', priority: 1.0, changeFrequency: 'weekly' as const },
        { url: '/features', priority: 0.9, changeFrequency: 'monthly' as const },
        { url: '/how-it-works', priority: 0.8, changeFrequency: 'monthly' as const },
        { url: '/roles', priority: 0.8, changeFrequency: 'monthly' as const },
        { url: '/tools', priority: 0.8, changeFrequency: 'monthly' as const },
        { url: '/download', priority: 0.9, changeFrequency: 'weekly' as const },
        { url: '/privacy', priority: 0.3, changeFrequency: 'yearly' as const },
        { url: '/terms', priority: 0.3, changeFrequency: 'yearly' as const },
    ];

    return pages.map(({ url, priority, changeFrequency }) => ({
        url: `${siteUrl}${url}`,
        lastModified: now,
        changeFrequency,
        priority,
    }));
}
