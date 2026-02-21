importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyDoG5zU8EzdPPFrXFstx0licFDklaxs83M",
    authDomain: "elimisha-90787.firebaseapp.com",
    databaseURL: "https://elimisha-90787-default-rtdb.firebaseio.com",
    projectId: "elimisha-90787",
    storageBucket: "elimisha-90787.firebasestorage.app",
    messagingSenderId: "974459699084",
    appId: "1:974459699084:web:8d47fa11d39ca31968a0a9",
    measurementId: "G-YBP1DZ3VC9"
});

const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);

    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/icons/Icon-192.png' // Ensure you have an icon at this path
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
