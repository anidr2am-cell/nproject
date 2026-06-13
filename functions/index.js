const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

exports.processFcmQueue = onDocumentCreated('fcmQueue/{docId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('No data associated with the event');
    return null;
  }

  const data = snapshot.data();
  const docId = event.params.docId;

  const { token, title, body, data: extraData } = data;

  if (!token || !title || !body) {
    console.error(`Invalid FCM message data in doc: ${docId}`);
    return snapshot.ref.update({
      status: 'error',
      error: 'Missing required fields (token, title, or body)',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  const message = {
    token: token,
    notification: {
      title: title,
      body: body,
    },
    data: extraData || {},
    webpush: {
      notification: {
        icon: '/favicon.png',
      },
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log(`Successfully sent message to ${token}:`, response);

    // 발송 완료 후 큐에서 삭제
    return snapshot.ref.delete();
  } catch (error) {
    console.error(`Error sending FCM message for doc ${docId}:`, error);

    // 에러 발생 시 상태 기록
    return snapshot.ref.update({
      status: 'error',
      error: error.message || 'Unknown error during send',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});
