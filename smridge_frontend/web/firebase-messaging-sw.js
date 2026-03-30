importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
    apiKey: "AIzaSyC90U_qTTsJdCDDvmFflZhJBPlW-apsY2g",
    authDomain: "smridge-a1203.firebaseapp.com",
    projectId: "smridge-a1203",
    storageBucket: "smridge-a1203.firebasestorage.app",
    messagingSenderId: "642051318446",
    appId: "1:642051318446:web:87e25e51afe982cd3574d0"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log("Received background message ", payload);
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: "/icons/Icon-192.png",
    };

    return self.registration.showNotification(notificationTitle, notificationOptions);
});
