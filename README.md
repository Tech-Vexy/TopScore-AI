# 🎓 TopScore AI

![TopScore Logo](apps/mobile/assets/images/logo.png)

**TopScore AI** is a cutting-edge education platform for Kenyan students (CBC/8-4-4). It combines AI tutoring, gamification, and essential study tools into one "Juicy" experience.

---

## 🏗️ Monorepo Architecture

This project is a monorepo managed by **Turborepo**, separating the core applications into focused workspaces:

-   **`apps/mobile/`**: The main Flutter application (iOS, Android, Web).
-   **`apps/landing/`**: Modern Next.js landing page for product marketing and waitlist management.
-   **`docs/`**: Centralized documentation and implementation guides.

---

## 🚀 Key Features

### 🧠 AI Tutor & RAG 
-   **Chat with Documents**: Upload handwritten notes or PDFs (Past Papers) and chat with them using Gemini 1.5.
-   **Contextual Help**: The AI understands your current syllabus and subject.

### 🎮 Gamification ("Juicy" Design)
-   **Leagues & XP**: Earn XP for studying. Promote from "Bronze" to "Diamond".
-   **Streaks**: Daily login rewards.
-   **Vibrant UI**: Beautiful gradients, shadows, and fonts (Nunito).

### 🛠️ Smart Toolkit
-   **AI Flashcards**: Generate study cards instantly from any text/note.
-   **Smart Timetable**: Plan your weekly classes. Data persists to the cloud.
-   **Document Scanner**: Native "Google Lens-style" camera to digitize notes into PDFs.

### 📊 Integrated Analytics
-   **Flutter Analytics**: Comprehensive event tracking for user progression, AI tutor usage, and study sessions.
-   **Landing Page GA4**: Optimized for tracking pre-launch conversion and waitlist signups.

---

## 🛠️ Tech Stack

-   **Frontend**: Flutter (Mobile) & Next.js (Landing)
-   **Backend**: Firebase (Functions, Firestore, Storage, Auth, Messaging)
-   **AI**: Google Gemini Pro (via Cloud Functions)
-   **Orchestration**: Turborepo, npm Workspaces

---

## 📦 Setup Instructions

### 1. Prerequisites
-   Flutter SDK (`3.x`)
-   Node.js (`18+`)
-   Firebase CLI (`npm i -g firebase-tools`)

### 2. Installation

1.  **Clone the repo**:
    ```bash
    git clone https://github.com/your-repo/topscore-ai.git
    cd topscore-ai
    ```

2.  **Install project-wide dependencies**:
    ```bash
    npm install
    ```

3.  **Bootstrap Flutter**:
    ```bash
    cd apps/mobile
    flutter pub get
    ```

### 3. Running the Development environment

From the root directory:

```bash
# Run both applications
npm run dev

# Run only the landing page
npm run dev -- --filter=landing

# Run the mobile app directly
cd apps/mobile
flutter run
```

---

## 🤝 Contributing
1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'feat: add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

**Built with ❤️ for Kenyan Students.**
