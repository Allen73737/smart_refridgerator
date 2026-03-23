importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
    apiKey: "AIzaSyB7wZb2tO1-Fs6GbDADUSTs2Qs3w08Hovw",
    authDomain: "flutterfire-e2e-tests.firebaseapp.com",
    projectId: "flutterfire-e2e-tests",
    storageBucket: "flutterfire-e2e-tests.appspot.com",
    messagingSenderId: "406099696497",
    appId: "1:406099696497:web:87e25e51afe982cd3574d0"
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
