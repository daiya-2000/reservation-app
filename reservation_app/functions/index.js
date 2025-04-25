const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.createFamilyAccount = functions.https.onCall(async (data, context) => {
  const {name, email, password, role, roomNumber, apartment} = data.data;


  try {
    // ユーザーを作成
    const userRecord = await admin.auth().createUser({
      email,
      password,
    });

    // Firestore に保存するオブジェクトを構築
    const userData = {
      name,
      email,
      role,
      roomNumber,
      apartment,
    };

    // すべての undefined フィールドを削除（ここが重要！）
    Object.keys(userData).forEach((key) => {
      if (userData[key] === undefined) {
        delete userData[key];
      }
    });

    console.log("👤 Creating user with UID:", userRecord.uid);

    // Firestore に保存
    await admin
        .firestore()
        .collection("users")
        .doc(userRecord.uid)
        .set(userData);

    return {success: true};
  } catch (error) {
    console.error("Error creating family account:", error);
    return {success: false, error: error.message};
  }
});
