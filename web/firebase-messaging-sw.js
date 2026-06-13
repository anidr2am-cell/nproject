importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC-YthDzO64YBukHy7iRIHSYiPOJiA1QBc',
  appId: '1:400795002326:web:bbfdb1c8850384148eb077',
  messagingSenderId: '400795002326',
  projectId: 'nproject-302c9',
  authDomain: 'nproject-302c9.firebaseapp.com',
  storageBucket: 'nproject-302c9.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
