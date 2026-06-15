const { onRequest } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const axios = require('axios');
const cors = require('cors')({ origin: true });

admin.initializeApp();

exports.kakaoGetToken = onRequest(
  { cors: true },
  async (req, res) => {
    try {
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Origin', '*');
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        return res.status(204).send('');
      }
      res.set('Access-Control-Allow-Origin', '*');
      const { code, redirect_uri } = req.body;

      if (!code || !redirect_uri) {
        return res.status(400).send({ error: 'Missing code or redirect_uri' });
      }

      const params = new URLSearchParams();
      params.append('grant_type', 'authorization_code');
      params.append('client_id', 'b5f8383395eb1541fd44d134a1ef6d6b');
      params.append('redirect_uri', redirect_uri);
      params.append('code', code);

      const response = await axios.post('https://kauth.kakao.com/oauth/token', params, {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
        },
      });

      return res.send(response.data);
    } catch (error) {
      console.error('Kakao Token Error:', error.response ? error.response.data : error.message);
      return res.status(error.response ? error.response.status : 500).send(
        error.response ? error.response.data : { error: error.message }
      );
    }
  }
);

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
