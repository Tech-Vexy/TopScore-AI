'use client';
import { useCallback, ReactNode } from 'react';
import styles from './AnimatedSection.module.css';

type Animation = 'fadeUp' | 'fadeIn' | 'fadeLeft' | 'fadeRight';
type HtmlTag = 'div' | 'section' | 'article' | 'aside' | 'header' | 'footer' | 'main' | 'li' | 'span';

interface Props {
    children: ReactNode;
    animation?: Animation;
    delay?: string;
    className?: string;
    tag?: HtmlTag;
}

export default function AnimatedSection({
    children,
    animation = 'fadeUp',
    delay = '0s',
    className = '',
    tag: Tag = 'div',
}: Props) {
    // Callback ref — avoids HTMLElement / HTMLDivElement type mismatch
    const observe = useCallback((el: HTMLElement | null) => {
        if (!el) return;
        const observer = new IntersectionObserver(
            ([entry]) => {
                if (entry.isIntersecting) {
                    el.classList.add(styles.visible);
                    observer.unobserve(el);
                }
            },
            { threshold: 0.12 }
        );
        observer.observe(el);
    }, []);

    const cls = [styles.animated, styles[animation], className].filter(Boolean).join(' ');

    // Render as a typed element to avoid dynamic-tag type errors
    const props = { ref: observe, className: cls, style: { transitionDelay: delay } };

    if (Tag === 'section') return <section {...props}>{children}</section>;
    if (Tag === 'article') return <article {...props}>{children}</article>;
    if (Tag === 'aside') return <aside   {...props}>{children}</aside>;
    if (Tag === 'header') return <header  {...props}>{children}</header>;
    if (Tag === 'footer') return <footer  {...props}>{children}</footer>;
    if (Tag === 'main') return <main    {...props}>{children}</main>;
    if (Tag === 'li') return <li      {...props}>{children}</li>;
    if (Tag === 'span') return <span    {...props}>{children}</span>;
    return <div {...props}>{children}</div>;
}
