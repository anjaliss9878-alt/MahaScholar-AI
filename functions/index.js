const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

const CODE_TTL_MS = 10 * 60 * 1000;
const MAX_LINK_ATTEMPTS = 10;
const ATTEMPT_WINDOW_MS = 60 * 60 * 1000;

function messageFor(before, after, studentName) {
  const who = studentName || "विद्यार्थी";
  switch (after.state) {
    case "started":
      return { title: who, body: "तुमच्या मुलाने अभ्यास सत्र सुरू केले आहे" };
    case "paused":
      return { title: who, body: "तुमच्या मुलाने अभ्यास सत्र थांबवले आहे" };
    case "active":
      if (before && before.state === "paused") {
        return { title: who, body: "तुमच्या मुलाने अभ्यास सत्र पुन्हा सुरू केले आहे" };
      }
      return null;
    case "ended": {
      const minutes = Math.round((after.activeSeconds || 0) / 60);
      return {
        title: who,
        body: `तुमच्या मुलाचे अभ्यास सत्र संपले आहे (${minutes} मिनिटे)`,
      };
    }
    default:
      return null;
  }
}

// Fires on every session write; only a real state transition sends a push.
exports.onStudySessionWrite = onDocumentWritten(
  "study_sessions/{sessionId}",
  async (event) => {
    const after = event.data.after.exists ? event.data.after.data() : null;
    const before = event.data.before.exists ? event.data.before.data() : null;
    if (!after || (before && before.state === after.state)) return;

    const message = messageFor(before, after, after.studentName);
    if (!message) return;

    const student = await db.doc(`users/${after.studentUid}`).get();
    const parentUids = (student.data() || {}).parentUids || [];
    if (!parentUids.length) return;

    const snaps = await Promise.all(
      parentUids.map((uid) => db.collection(`users/${uid}/fcm_tokens`).get())
    );
    // One entry per distinct token (a shared device can appear under 2 parents).
    const refsByToken = new Map();
    snaps.forEach((snap) =>
      snap.forEach((d) => {
        refsByToken.set(d.id, [...(refsByToken.get(d.id) || []), d.ref]);
      })
    );
    const tokens = [...refsByToken.keys()];
    if (!tokens.length) return;

    const stale = [];
    // sendEachForMulticast accepts at most 500 tokens per call.
    for (let i = 0; i < tokens.length; i += 500) {
      const chunk = tokens.slice(i, i + 500);
      const response = await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: message,
        data: { sessionId: event.params.sessionId, state: after.state },
        android: { priority: "high" },
      });

      // Prune tokens that are no longer registered.
      response.responses.forEach((r, j) => {
        const code = r.error && r.error.code;
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          refsByToken.get(chunk[j]).forEach((ref) => stale.push(ref.delete()));
        }
      });
    }
    await Promise.all(stale);
  }
);

// Student: create a single-use code the parent redeems.
exports.createParentLinkCode = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = String(crypto.randomInt(0, 100000000)).padStart(8, "0");
    try {
      await db.doc(`parent_link_codes/${code}`).create({
        studentUid: request.auth.uid,
        expiresAt: Date.now() + CODE_TTL_MS,
      });
      return { code };
    } catch (error) {
      if (error.code !== 6) throw error; // 6 = ALREADY_EXISTS: pick another
    }
  }
  throw new HttpsError("internal", "कोड तयार झाला नाही / Could not create a code");
});

// Limits guessing of the 8-digit code (counted outside the redeem
// transaction so failed guesses are not rolled back).
async function registerLinkAttempt(uid) {
  const ref = db.doc(`parent_link_attempts/${uid}`);
  await db.runTransaction(async (tx) => {
    const now = Date.now();
    const saved = (await tx.get(ref)).data() || {};
    const expired = !saved.windowStart || now - saved.windowStart > ATTEMPT_WINDOW_MS;
    const count = expired ? 0 : saved.count || 0;
    if (count >= MAX_LINK_ATTEMPTS) {
      throw new HttpsError(
        "resource-exhausted",
        "खूप प्रयत्न झाले; नंतर पुन्हा करा / Too many attempts, try later"
      );
    }
    tx.set(ref, { count: count + 1, windowStart: expired ? now : saved.windowStart });
  });
}

// Parent: redeem the code; adds the parent to the student's parentUids.
exports.linkParent = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const code = String((request.data || {}).code || "");
  if (!/^\d{8}$/.test(code)) {
    throw new HttpsError("invalid-argument", "कोड अवैध आहे / Invalid code");
  }
  await registerLinkAttempt(request.auth.uid);
  const ref = db.doc(`parent_link_codes/${code}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    if (!snap.exists || data.expiresAt < Date.now()) {
      throw new HttpsError("not-found", "कोड चुकीचा किंवा कालबाह्य / Code invalid or expired");
    }
    if (data.studentUid === request.auth.uid) {
      throw new HttpsError("failed-precondition", "स्वतःला जोडता येत नाही / Cannot link yourself");
    }
    tx.set(
      db.doc(`users/${data.studentUid}`),
      { parentUids: admin.firestore.FieldValue.arrayUnion(request.auth.uid) },
      { merge: true }
    );
    tx.delete(ref);
  });
  return { ok: true };
});
