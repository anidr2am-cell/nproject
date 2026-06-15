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
      const { code, redirect_uri } = req.body;

      if (!code || !redirect_uri) {
        return res.status(400).send({ error: 'Missing code or redirect_uri' });
      }

      const clientId = 'b5f8383395eb1541fd44d134a1ef6d6b';
      const clientSecret = ''; // Kakao Client Secret (Optional, if enabled in console)
      const redirectUri = redirect_uri;

      console.log('[KAKAO BACKEND] client_id length=', clientId?.length);
      console.log('[KAKAO BACKEND] client_secret exists=', !!clientSecret);
      console.log('[KAKAO BACKEND] redirect_uri=', redirectUri);

      // 1. Get Access Token from Kakao
      // Verification: Request sent to https://kauth.kakao.com/oauth/token
      // Body includes: grant_type, client_id, client_secret (if exists), redirect_uri, code
      const params = new URLSearchParams();
      params.append('grant_type', 'authorization_code');
      params.append('client_id', clientId);
      if (clientSecret) {
        params.append('client_secret', clientSecret);
      }
      params.append('redirect_uri', redirectUri);
      params.append('code', code);

      console.log('[KAKAO BACKEND] Token request body:', params.toString());

      const tokenResponse = await axios.post('https://kauth.kakao.com/oauth/token', params, {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
        },
      });

      const accessToken = tokenResponse.data.access_token;

      // 2. Get User Info from Kakao
      // Doing this server-side completely avoids client-side CORB/CORS issues
      const userResponse = await axios.get('https://kapi.kakao.com/v2/user/me', {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
        },
      });

      // Return both for the client to use
      return res.status(200).send({
        token: tokenResponse.data,
        user: userResponse.data
      });
    } catch (error) {
      console.error('Kakao API Error:', error.response ? error.response.data : error.message);
      const statusCode = error.response ? error.response.status : 500;
      const errorData = error.response ? error.response.data : { error: error.message };
      return res.status(statusCode).send(errorData);
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
