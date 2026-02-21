'use client';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './VideoDemo.module.css';

const YOUTUBE_VIDEO_ID = 'dQw4w9WgXcQ'; // Replace with actual TopScore AI demo video ID

export default function VideoDemo() {
    const { t } = useLocale();

    return (
        <section id="demo" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('video.label')}</div>
                    <h2 className={styles.title}>{t('video.title')}</h2>
                    <p className={styles.sub}>{t('video.sub')}</p>
                </AnimatedSection>

                <AnimatedSection animation="fadeUp" delay="0.2s">
                    <div className={styles.videoWrap}>
                        <iframe
                            src={`https://www.youtube.com/embed/${YOUTUBE_VIDEO_ID}?rel=0`}
                            title={t('video.title')}
                            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                            allowFullScreen
                            className={styles.iframe}
                        />
                    </div>
                </AnimatedSection>
            </div>
        </section>
    );
}
