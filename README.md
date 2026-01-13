# 🎓 TopScore AI (Elimisha)

![TopScore Logo](assets/images/topscore_logo.jpg)

**TopScore AI** is a cutting-edge education platform for Kenyan students (CBC/8-4-4). It combines AI tutoring, gamification, and essential study tools into one "Juicy" experience.

---

## 🚀 Key Features

### 🧠 AI Tutor & RAG 
-   **Chat with Documents**: Upload handwritten notes or PDFs (Past Papers) and chat with them using Gemini 1.5.
-   **Contextual Help**: The AI understands your current syllabus and subject.

### 🎮 Gamification ("Juicy" Design)
-   **Leagues & XP**: Earn XP for studying. Promote from "Bronze" to "Diamond".
-   **Streaks**: Daily login rewards.
-   **Vibrant UI**: Beautiful gradients, shadows, and fonts (Nunito).

### 🛠️ Smart Toolkit (New!)
-   **AI Flashcards**: Generate study cards instantly from any text/note.
-   **Smart Timetable**: Plan your weekly classes. Data persists to the cloud.
-   **Document Scanner**: Native "Google Lens-style" camera to digitize notes into PDFs.

### 🔒 Content Security
-   **Secure PDF Viewer**: Prevents unauthorized downloads.
-   **Freemium Model**: 7-Day Free Trial on signup. Automated subscription expiry checks.

---

## 🛠️ Tech Stack using Flutter & Firebase

-   **Frontend**: Flutter (Mobile & Web)
-   **Backend**: Firebase (Functions, Firestore, Storage, Auth, Messaging)
-   **AI**: Google Gemini Pro (via Cloud Functions)
-   **Search**: Algolia (Optional integration)

---

## 📦 Setup Instructions

### 1. Prerequisites
-   Flutter SDK (`3.x`)
-   Node.js (`18+`)
-   Firebase CLI (`npm i -g firebase-tools`)
-   VS Code (Recommended)

### 2. Installation
```bash
# Clone the repo
git clone https://github.com/your-repo/topscore-ai.git
cd topscore-ai

# Install Flutter dependencies
flutter pub get

# Install Backend dependencies
cd functions
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Firebase Configuration
1.  Enable **Authentication** (Email/Password, Google).
2.  Enable **Firestore** and **Storage**.
3.  Deploy Rules & Indexes:
    ```bash
    firebase deploy --only firestore:rules,firestore:indexes,storage
    ```
4.  Deploy Cloud Functions:
    ```bash
    firebase deploy --only functions
    ```
    *Make sure to set your Gemini API Key in Google Cloud Secret Manager or environment variables.*

### 4. Running the App
```bash
# Run on Chrome
flutter run -d chrome

# Run on Android
flutter run -d android
```

---

## 🏗️ Project Structure
-   `lib/screens`: All UI Screens (Home, Chat, Tools).
-   `lib/services`: Logic for AI, Auth, and Gamification.
-   `lib/widgets`: Reusable UI components (Scanner, PDF Viewer).
-   `functions/`: Python Cloud Functions (FastAPI style).

---

## 🤝 Contributing
1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

---

**Built with ❤️ for Kenyan Students.**
