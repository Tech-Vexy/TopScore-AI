'use client';
import { useState, useEffect } from 'react';
import styles from './BackToTop.module.css';

export default function BackToTop() {
    const [visible, setVisible] = useState(false);

    useEffect(() => {
        const onScroll = () => setVisible(window.scrollY > 400);
        window.addEventListener('scroll', onScroll, { passive: true });
        return () => window.removeEventListener('scroll', onScroll);
    }, []);

    const scrollUp = () => window.scrollTo({ top: 0, behavior: 'smooth' });

    return (
        <button
            onClick={scrollUp}
            className={`${styles.btn} ${visible ? styles.visible : ''}`}
            aria-label="Back to top"
        >
            ↑
        </button>
    );
}
