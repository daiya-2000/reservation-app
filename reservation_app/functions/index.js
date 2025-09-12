// ── 管理人アカウント作成 ──
// functions/index.js
const admin = require("firebase-admin");
admin.initializeApp();

const functions = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

/* =========================================================
 *  共通: 権限チェック & Resident作成ユーティリティ
 * =======================================================*/

/**
 * BuildingAdmin / CompanyAdmin のみ許可（不要ならコメントアウトOK）
 */
async function assertOperatorRoleOrThrow(uid) {
  const snap = await admin.firestore().collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "ユーザー情報が見つかりません。");
  }
  const role = snap.data().role;
  const allowed = role === "BuildingAdmin" || role === "CompanyAdmin";
  if (!allowed) {
    throw new HttpsError(
      "permission-denied",
      "この操作を行う権限がありません。",
    );
  }
}

/**
 * Residentユーザーを Auth/Firestore に作成（既存ならパスワード更新）し、Firestoreは upsert。
 * 返り値: { uid, created: boolean }
 */
async function ensureResidentUser({
  email,
  password,
  name,
  roomNumber,
  apartment,
}) {
  const normalizedEmail = String(email || "")
    .trim()
    .toLowerCase();
  const normalizedRoom = String(roomNumber || "").trim();
  const displayName = String(name || normalizedRoom || normalizedEmail);

  if (!normalizedEmail || !password || !normalizedRoom || !apartment) {
    throw new HttpsError(
      "invalid-argument",
      "email, password, roomNumber, apartment は必須です。",
    );
  }

  let userRecord;
  let created = false;
  try {
    // 新規作成
    userRecord = await admin.auth().createUser({
      email: normalizedEmail,
      password,
      displayName,
    });
    created = true;
  } catch (error) {
    // 既存メールの場合は更新
    if (error.code === "auth/email-already-exists") {
      userRecord = await admin.auth().getUserByEmail(normalizedEmail);
      await admin.auth().updateUser(userRecord.uid, { password, displayName });
    } else {
      console.error(
        "ensureResidentUser.createUser error:",
        error.code,
        error.message,
      );
      throw new HttpsError("internal", "ユーザー作成に失敗しました。");
    }
  }

  // Firestore upsert
  const userDocRef = admin.firestore().collection("users").doc(userRecord.uid);
  const userData = {
    name: displayName,
    email: normalizedEmail,
    roomNumber: normalizedRoom,
    role: "Resident",
    apartment: apartment,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const existing = await userDocRef.get();
  if (!existing.exists) {
    userData.createdAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await userDocRef.set(userData, { merge: true });

  return { uid: userRecord.uid, created };
}

/* =========================================================
 *  Resident 単体 & 一括 作成 Callables
 * =======================================================*/

/**
 * 単体: 入居者（Resident）アカウント作成
 * data: { email, password, roomNumber, name?, apartment }
 */
exports.createResidentAccount = onCall(
  { region: "us-central1" },
  async (req) => {
    if (!req.auth || !req.auth.uid) {
      throw new HttpsError("unauthenticated", "ログインが必要です。");
    }
    // 権限チェック（不要ならコメントアウト）
    await assertOperatorRoleOrThrow(req.auth.uid);

    const { email, password, roomNumber, name, apartment } = req.data || {};
    try {
      const { uid, created } = await ensureResidentUser({
        email,
        password,
        name,
        roomNumber,
        apartment,
      });
      return { success: true, uid, created };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      const _code = error && error.code ? error.code : undefined;
      const _msg = error && error.message ? error.message : String(error);
      console.error("createResidentAccount error:", _code, _msg);
      throw new HttpsError("internal", "入居者アカウント作成に失敗しました。");
    }
  },
);

/**
 * 一括: 入居者（Resident）アカウント作成
 * data: {
 *   apartment: string,
 *   residents: Array<{ roomNumber: string, password: string, email?: string, name?: string }>,
 *   defaultEmailDomain?: string // 例: "example.com"（未指定なら example.com）
 * }
 *
 * - メール重複は Admin SDK 側で検知し、既存ならパスワード更新＋Firestore upsert。
 * - 逐次処理（シンプル & 書き込みレートを抑制）。必要なら並列度を上げる設計に変更可。
 */
exports.bulkCreateResidents = onCall({ region: "us-central1" }, async (req) => {
  if (!req.auth || !req.auth.uid) {
    throw new HttpsError("unauthenticated", "ログインが必要です。");
  }
  await assertOperatorRoleOrThrow(req.auth.uid);

  const { apartment, residents, defaultEmailDomain } = req.data || {};
  if (!apartment || !Array.isArray(residents) || residents.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "apartment と residents は必須です。",
    );
  }

  const domain = String(defaultEmailDomain || "example.com").trim();

  const results = [];
  let successCount = 0;

  // 逐次処理（必要なら chunk + Promise.allSettled で並列度制御）
  for (let i = 0; i < residents.length; i++) {
    const r = residents[i] || {};
    try {
      const room = String(r.roomNumber || "").trim();
      const pass = String(r.password || "");
      const email = String(r.email || `${room}@${domain}`)
        .trim()
        .toLowerCase();
      const name = r.name || room;

      const { uid, created } = await ensureResidentUser({
        email,
        password: pass,
        name,
        roomNumber: room,
        apartment,
      });

      results.push({
        index: i,
        roomNumber: room,
        email,
        uid,
        created,
        success: true,
      });
      successCount++;
    } catch (e) {
      let msg;
      if (e instanceof HttpsError) {
        msg = `${e.code}: ${e.message}`;
      } else if (e && e.message) {
        msg = e.message;
      } else {
        msg = String(e);
      }

      const roomNumber =
        residents[i] && residents[i].roomNumber
          ? residents[i].roomNumber
          : undefined;
      const email =
        residents[i] && residents[i].email ? residents[i].email : undefined;

      results.push({
        index: i,
        roomNumber: roomNumber,
        email: email,
        success: false,
        error: msg,
      });
    }
  }

  return {
    success: true,
    successCount,
    failureCount: results.length - successCount,
    results,
  };
});

/* =========================================================
 *  既存の管理機能（あなたの元コード）
 * =======================================================*/

exports.createManagerAccount = onCall(
  { region: "us-central1" },
  async (req) => {
    // 認証チェック
    if (!req.auth || !req.auth.uid) {
      throw new HttpsError("unauthenticated", "ログインが必要です。");
    }

    const { name, email, password, apartmentId } = req.data;
    if (!name || !email || !password || !apartmentId) {
      throw new HttpsError(
        "invalid-argument",
        "すべてのフィールドが必要です。",
      );
    }

    try {
      // Firebase Auth ユーザー作成
      const userRecord = await admin.auth().createUser({
        email,
        password,
        displayName: name,
      });

      // Firestore にロール情報などを保存
      await admin.firestore().collection("users").doc(userRecord.uid).set({
        name,
        email,
        apartment: apartmentId,
        role: "BuildingAdmin",
      });

      return { success: true };
    } catch (error) {
      // まずはエラーコードとメッセージをログに出す
      console.error("createManagerAccount error:", error.code, error.message);

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
exports.createFamilyAccount = onCall({ region: "us-central1" }, async (req) => {
  const { name, email, password, role, roomNumber, apartment } = req.data;
  try {
    const userRecord = await admin.auth().createUser({ email, password });
    const userData = { name, email, role, roomNumber, apartment };
    Object.keys(userData).forEach(
      (k) => userData[k] === undefined && delete userData[k],
    );
    await admin
      .firestore()
      .collection("users")
      .doc(userRecord.uid)
      .set(userData);
    return { success: true };
  } catch (error) {
    console.error("createFamilyAccount error:", error);
    throw new HttpsError("internal", error.message);
  }
});

exports.deleteManagerAccount = onCall(
  { region: "us-central1" },
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

      return { success: true };
    } catch (error) {
      console.error("deleteManagerAccount error:", error.code, error.message);
      throw new HttpsError("internal", "アカウントの削除に失敗しました。");
    }
  },
);

exports.deleteUserAccount = onCall({ region: "us-central1" }, async (req) => {
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
    return { success: true };
  } catch (error) {
    console.error("deleteUserAccount error:", error.code, error.message);
    throw new HttpsError("internal", "アカウントの削除に失敗しました。");
  }
});

// ── Firestore の notifications 作成トリガー → FCM 配信 ──
exports.sendFcmOnNotification = onDocumentCreated(
  { region: "us-central1", document: "notifications/{docId}" },
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
            response.failureCount > 0
              ? response.responses.filter((r) => !r.success)
              : "",
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

// 旧 onCall (v1) を利用している既存コードはそのまま維持
exports.sendBulletinNotification = functions.https.onCall(
  async (data, context) => {
    const { title } = data;

    const message = {
      notification: {
        title: "新しい掲示板投稿",
        body: `管理人が「${title}」を投稿しました。`,
      },
      topic: "all",
    };

    try {
      const response = await admin.messaging().send(message);
      console.log("通知送信成功:", response);
      return { success: true };
    } catch (error) {
      console.error("通知送信失敗:", error);
      return { success: false, error: error.message };
    }
  },
);
