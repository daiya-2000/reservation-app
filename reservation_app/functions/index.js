
// ── 管理人アカウント作成 ──
// functions/index.js
const admin = require("firebase-admin");
admin.initializeApp();

const {onCall, HttpsError} = require("firebase-functions/v2/https");

exports.createManagerAccount = onCall(
    {region: "us-central1"},
    async (req) => {
    // 認証チェック
      if (!req.auth || !req.auth.uid) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
      }

      const {name, email, password, apartmentId} = req.data;
      if (!name || !email || !password || !apartmentId) {
        throw new HttpsError("invalid-argument", "すべてのフィールドが必要です。");
      }

      try {
      // Firebase Auth ユーザー作成
        const userRecord = await admin.auth().createUser({
          email,
          password,
          displayName: name,
        });

        // Firestore にロール情報などを保存
        await admin
            .firestore()
            .collection("users")
            .doc(userRecord.uid)
            .set({
              name,
              email,
              apartment: apartmentId,
              role: "BuildingAdmin",
            });

        return {success: true};
      } catch (error) {
      // まずはエラーコードとメッセージをログに出す
        console.error(
            "createManagerAccount error:",
            error.code,
            error.message,
        );

        // 代表的なエラーを分岐して返す
        if (error.code === "auth/email-already-exists") {
          throw new HttpsError(
              "already-exists",
              "このメールアドレスは既に使われています。",
          );
        }

        // それ以外は従来通り internal
        throw new HttpsError("internal", "アカウント作成に失敗しました。");
      }
    },
);


// ── 家族アカウント作成 ──
exports.createFamilyAccount = onCall(
    {region: "us-central1"},
    async (req) => {
      const {name, email, password, role, roomNumber, apartment} = req.data;
      try {
        const userRecord = await admin.auth().createUser({email, password});
        const userData = {name, email, role, roomNumber, apartment};
        Object.keys(userData).forEach((k) => userData[k]===undefined && delete userData[k]);
        await admin.firestore().collection("users").doc(userRecord.uid).set(userData);
        return {success: true};
      } catch (error) {
        console.error("createFamilyAccount error:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);


exports.deleteManagerAccount = onCall(
    {region: "us-central1"},
    async (req) => {
      if (!req.auth || !req.auth.uid) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
      }
      const targetUid = req.data.uid;
      if (!targetUid) {
        throw new HttpsError("invalid-argument", "削除対象の UID が必要です。");
      }

      try {
      // 1) Authentication から削除
        await admin.auth().deleteUser(targetUid);

        // 2) Firestore の users コレクションからも削除
        await admin.firestore().collection("users").doc(targetUid).delete();

        return {success: true};
      } catch (error) {
        console.error("deleteManagerAccount error:", error.code, error.message);
        throw new HttpsError("internal", "アカウントの削除に失敗しました。");
      }
    },
);


exports.deleteUserAccount = onCall(
    {region: "us-central1"},
    async (req) => {
      if (!req.auth || !req.auth.uid) {
        throw new HttpsError("unauthenticated", "ログインが必要です。");
      }

      const targetUid = req.data.uid;
      if (!targetUid) {
        throw new HttpsError("invalid-argument", "削除対象の UID が必要です。");
      }

      try {
      // 1) Auth から削除
        await admin.auth().deleteUser(targetUid);
        // 2) Firestore から削除
        await admin.firestore().collection("users").doc(targetUid).delete();
        return {success: true};
      } catch (error) {
        console.error("deleteUserAccount error:", error.code, error.message);
        throw new HttpsError("internal", "アカウントの削除に失敗しました。");
      }
    },
);

// ── Firestore の notifications 作成トリガー → FCM 配信 ──
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

// 通知ドキュメントが追加されたら呼ばれる
exports.sendFcmOnNotification = onDocumentCreated(
    {region: "us-central1", document: "notifications/{docId}"},
    async (event) => {
      const snap = event.data;
      const data = snap.data();
      const docId = event.params.docId;
      const messageBody = data.message || "";
      const recipients = Array.isArray(data.recipients) ? data.recipients : [];

      // FCM ペイロード
      const payload = {
        notification: {
          title: "新しい通知",
          body: messageBody,
        },
        data: {
          docId: docId,
          type: data.type || "",
        },
      };

      try {
        if (recipients.includes("all")) {
        // 全員向け → topic 'all' に送信
          await admin.messaging().sendToTopic("all", payload);
          console.log(`Sent FCM to topic 'all' for notification ${docId}`);
        } else if (recipients.length > 0) {
        // 個別ユーザー向け → 各ユーザーの fcmToken を取得して送信
          const tokens = [];
          const db = admin.firestore();

          // 並列でトークン取得
          await Promise.all(
              recipients.map(async (uid) => {
                const userDoc = await db.collection("users").doc(uid).get();
                const token = userDoc.exists && userDoc.data().fcmToken;
                if (typeof token === "string") {
                  tokens.push(token);
                }
              }),
          );

          if (tokens.length > 0) {
            const response = await admin.messaging().sendMulticast({
              tokens,
              ...payload,
            });
            console.log(
                `Sent FCM to ${tokens.length} tokens for notification ${docId}`,
            response.failureCount > 0 ?
              response.responses.filter((r) => !r.success) :
              "",
            );
          } else {
            console.log(`No valid FCM tokens found for recipients of ${docId}`);
          }
        } else {
          console.log(`Notification ${docId} has no recipients array.`);
        }
      } catch (err) {
        console.error("Error sending FCM for notification", docId, err);
      }
    },
);
