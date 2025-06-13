
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
