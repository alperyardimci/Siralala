const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");

// Initialize Firebase Admin from env var
if (!admin.apps.length) {
  const cred = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({ credential: admin.credential.cert(cred) });
}
const db = admin.firestore();

const app = express();
app.use(cors());
app.use(express.json({ limit: "50mb" }));

function generateCode() {
  const chars = "ABCDEF0123456789";
  let code = "";
  for (let i = 0; i < 6; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
}

async function getUser(username) {
  const snap = await db.collection("users").where("username", "==", username).limit(1).get();
  if (snap.empty) return null;
  return { id: snap.docs[0].id, ...snap.docs[0].data() };
}

// --- Users ---
app.post("/api/users/register", async (req, res) => {
  const { username, displayName } = req.body;
  if (!username || !displayName) return res.status(400).json({ error: "required" });
  const snap = await db.collection("users").where("username", "==", username).limit(1).get();
  if (!snap.empty) { const d = snap.docs[0]; return res.json({ id: d.id, ...d.data() }); }
  const code = generateCode();
  const ref = await db.collection("users").add({ username, display_name: displayName, friend_code: code, created_at: new Date().toISOString() });
  res.json({ id: ref.id, username, display_name: displayName, friend_code: code });
});

app.get("/api/users/me", async (req, res) => {
  const snap = await db.collection("users").where("username", "==", req.query.username).limit(1).get();
  if (snap.empty) return res.status(404).json({ error: "User not found" });
  const d = snap.docs[0]; res.json({ id: d.id, ...d.data() });
});

app.get("/api/users/search", async (req, res) => {
  const snap = await db.collection("users").where("friend_code", "==", req.query.code).limit(1).get();
  if (snap.empty) return res.status(404).json({ error: "User not found" });
  const d = snap.docs[0]; const u = d.data();
  res.json({ id: d.id, username: u.username, display_name: u.display_name, friend_code: u.friend_code });
});

// --- Friends ---
app.post("/api/friends/add", async (req, res) => {
  const { username, friendCode } = req.body;
  const user = await getUser(username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const fSnap = await db.collection("users").where("friend_code", "==", friendCode).limit(1).get();
  if (fSnap.empty) return res.status(404).json({ error: "Friend not found" });
  const friend = { id: fSnap.docs[0].id, ...fSnap.docs[0].data() };
  if (friend.id === user.id) return res.status(400).json({ error: "Cannot add yourself" });
  await db.collection("friendships").doc(`${user.id}_${friend.id}`).set({ user_id: user.id, friend_id: friend.id });
  await db.collection("friendships").doc(`${friend.id}_${user.id}`).set({ user_id: friend.id, friend_id: user.id });
  res.json({ success: true, friend: { id: friend.id, username: friend.username, display_name: friend.display_name } });
});

app.get("/api/friends", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const snap = await db.collection("friendships").where("user_id", "==", user.id).get();
  const friends = [];
  for (const d of snap.docs) {
    const fdoc = await db.collection("users").doc(d.data().friend_id).get();
    if (fdoc.exists) { const u = fdoc.data(); friends.push({ id: fdoc.id, username: u.username, display_name: u.display_name }); }
  }
  res.json(friends);
});

app.delete("/api/friends/:friendId", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  await db.collection("friendships").doc(`${user.id}_${req.params.friendId}`).delete();
  await db.collection("friendships").doc(`${req.params.friendId}_${user.id}`).delete();
  res.json({ success: true });
});

// --- Groups ---
app.post("/api/groups", async (req, res) => {
  const { username, name, memberUsernames } = req.body;
  const user = await getUser(username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const ref = await db.collection("groups").add({ name, owner_id: user.id, created_at: new Date().toISOString() });
  const members = [{ id: user.id, username: user.username, display_name: user.display_name }];
  await db.collection("group_members").doc(`${ref.id}_${user.id}`).set({ group_id: ref.id, user_id: user.id });
  if (memberUsernames) {
    for (const mu of memberUsernames) {
      const m = await getUser(mu);
      if (m) { await db.collection("group_members").doc(`${ref.id}_${m.id}`).set({ group_id: ref.id, user_id: m.id }); members.push({ id: m.id, username: m.username, display_name: m.display_name }); }
    }
  }
  res.json({ id: ref.id, name, owner_id: user.id, members });
});

app.get("/api/groups", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const gmSnap = await db.collection("group_members").where("user_id", "==", user.id).get();
  const groupIds = [...new Set(gmSnap.docs.map(d => d.data().group_id))];
  const groups = [];
  for (const gid of groupIds) {
    const gdoc = await db.collection("groups").doc(gid).get();
    if (!gdoc.exists) continue;
    const mSnap = await db.collection("group_members").where("group_id", "==", gid).get();
    const members = [];
    for (const md of mSnap.docs) { const udoc = await db.collection("users").doc(md.data().user_id).get(); if (udoc.exists) { const u = udoc.data(); members.push({ id: udoc.id, username: u.username, display_name: u.display_name }); } }
    groups.push({ id: gid, name: gdoc.data().name, owner_id: gdoc.data().owner_id, members });
  }
  res.json(groups);
});

app.delete("/api/groups/:groupId", async (req, res) => {
  await db.collection("groups").doc(req.params.groupId).delete();
  const mSnap = await db.collection("group_members").where("group_id", "==", req.params.groupId).get();
  for (const d of mSnap.docs) await d.ref.delete();
  res.json({ success: true });
});

app.post("/api/groups/:groupId/members", async (req, res) => {
  const m = await getUser(req.body.username);
  if (!m) return res.status(404).json({ error: "User not found" });
  await db.collection("group_members").doc(`${req.params.groupId}_${m.id}`).set({ group_id: req.params.groupId, user_id: m.id });
  res.json({ success: true });
});

// --- Shared Pools ---
app.post("/api/pools/share", async (req, res) => {
  const { username, groupId, name, items } = req.body;
  const user = await getUser(username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const ref = await db.collection("shared_pools").add({ group_id: groupId, creator_id: user.id, name, item_count: items.length, created_at: new Date().toISOString() });
  for (let i = 0; i < items.length; i++) { await db.collection("shared_pool_items").add({ pool_id: ref.id, name: items[i].name, image_data: items[i].imageData || null, sort_order: i }); }
  res.json({ id: ref.id, name, item_count: items.length });
});

app.get("/api/groups/:groupId/pools", async (req, res) => {
  const snap = await db.collection("shared_pools").where("group_id", "==", req.params.groupId).get();
  const pools = [];
  for (const doc of snap.docs) { const d = doc.data(); const udoc = await db.collection("users").doc(d.creator_id).get(); pools.push({ id: doc.id, name: d.name, group_id: d.group_id, creator_id: d.creator_id, creator_name: udoc.exists ? udoc.data().display_name : "?", item_count: d.item_count || 0 }); }
  res.json(pools);
});

app.get("/api/pools/shared", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const gmSnap = await db.collection("group_members").where("user_id", "==", user.id).get();
  const groupIds = [...new Set(gmSnap.docs.map(d => d.data().group_id))];
  const pools = [];
  for (const gid of groupIds) {
    const pSnap = await db.collection("shared_pools").where("group_id", "==", gid).get();
    const gdoc = await db.collection("groups").doc(gid).get();
    for (const doc of pSnap.docs) { const d = doc.data(); const udoc = await db.collection("users").doc(d.creator_id).get(); pools.push({ id: doc.id, name: d.name, group_id: gid, creator_id: d.creator_id, creator_name: udoc.exists ? udoc.data().display_name : "?", group_name: gdoc.exists ? gdoc.data().name : "?", item_count: d.item_count || 0 }); }
  }
  res.json(pools);
});

app.get("/api/pools/:poolId/items", async (req, res) => {
  const snap = await db.collection("shared_pool_items").where("pool_id", "==", req.params.poolId).orderBy("sort_order").get();
  res.json(snap.docs.map(d => ({ id: d.id, ...d.data() })));
});

app.delete("/api/pools/:poolId", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const doc = await db.collection("shared_pools").doc(req.params.poolId).get();
  if (!doc.exists || doc.data().creator_id !== user.id) return res.status(403).json({ error: "Only owner" });
  await doc.ref.delete();
  const items = await db.collection("shared_pool_items").where("pool_id", "==", req.params.poolId).get();
  for (const d of items.docs) await d.ref.delete();
  res.json({ success: true });
});

// --- Questions ---
app.post("/api/questions", async (req, res) => {
  const { username, groupId, text, poolName, items, itemCount } = req.body;
  const user = await getUser(username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const count = itemCount || items.length;
  const ref = await db.collection("shared_questions").add({ group_id: groupId, creator_id: user.id, text, pool_name: poolName, item_count: count, is_active: true, created_at: new Date().toISOString() });
  for (let i = 0; i < items.length; i++) {
    const item = items[i]; const n = typeof item === "string" ? item : item.name; const img = typeof item === "string" ? null : (item.imageData || null);
    await db.collection("shared_question_items").add({ question_id: ref.id, name: n, image_data: img, sort_order: i });
  }
  res.json({ id: ref.id, text, pool_name: poolName, item_count: count });
});

async function getQuestionFull(qDoc, user) {
  const q = qDoc.data();
  const udoc = await db.collection("users").doc(q.creator_id).get();
  const gdoc = await db.collection("groups").doc(q.group_id).get();
  const itemsSnap = await db.collection("shared_question_items").where("question_id", "==", qDoc.id).orderBy("sort_order").get();
  const rSnap = await db.collection("rankings").where("question_id", "==", qDoc.id).get();
  return {
    id: qDoc.id, text: q.text, pool_name: q.pool_name, item_count: q.item_count, creator_id: q.creator_id,
    creator_name: udoc.exists ? udoc.data().display_name : "?",
    group_name: gdoc.exists ? gdoc.data().name : "?",
    items: itemsSnap.docs.map(d => ({ id: d.id, ...d.data() })),
    completion_count: rSnap.size,
    user_ranked: user ? rSnap.docs.some(d => d.data().user_id === user.id) : false
  };
}

app.get("/api/questions/pending", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const gmSnap = await db.collection("group_members").where("user_id", "==", user.id).get();
  const groupIds = [...new Set(gmSnap.docs.map(d => d.data().group_id))];
  const rankedSnap = await db.collection("rankings").where("user_id", "==", user.id).get();
  const rankedQids = new Set(rankedSnap.docs.map(d => d.data().question_id));
  const dismissedSnap = await db.collection("dismissed_questions").where("user_id", "==", user.id).get();
  const dismissedQids = new Set(dismissedSnap.docs.map(d => d.data().question_id));
  const questions = [];
  for (const gid of groupIds) {
    const qSnap = await db.collection("shared_questions").where("group_id", "==", gid).where("is_active", "==", true).get();
    for (const qDoc of qSnap.docs) {
      if (rankedQids.has(qDoc.id) || dismissedQids.has(qDoc.id)) continue;
      questions.push(await getQuestionFull(qDoc, user));
    }
  }
  res.json(questions);
});

app.get("/api/questions/completed", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const rankedSnap = await db.collection("rankings").where("user_id", "==", user.id).get();
  const dismissedSnap = await db.collection("dismissed_questions").where("user_id", "==", user.id).get();
  const dismissedQids = new Set(dismissedSnap.docs.map(d => d.data().question_id));
  const questions = [];
  for (const rDoc of rankedSnap.docs) {
    const qid = rDoc.data().question_id;
    if (dismissedQids.has(qid)) continue;
    const qDoc = await db.collection("shared_questions").doc(qid).get();
    if (!qDoc.exists) continue;
    questions.push(await getQuestionFull(qDoc, user));
  }
  res.json(questions);
});

app.get("/api/groups/:groupId/questions", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const qSnap = await db.collection("shared_questions").where("group_id", "==", req.params.groupId).get();
  const questions = [];
  for (const qDoc of qSnap.docs) { questions.push(await getQuestionFull(qDoc, user)); }
  res.json(questions);
});

app.delete("/api/questions/:questionId", async (req, res) => {
  const user = await getUser(req.query.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const doc = await db.collection("shared_questions").doc(req.params.questionId).get();
  if (!doc.exists || doc.data().creator_id !== user.id) return res.status(403).json({ error: "Only owner" });
  await doc.ref.delete();
  const items = await db.collection("shared_question_items").where("question_id", "==", req.params.questionId).get();
  for (const d of items.docs) await d.ref.delete();
  res.json({ success: true });
});

app.post("/api/questions/:questionId/dismiss", async (req, res) => {
  const user = await getUser(req.body.username);
  if (!user) return res.status(404).json({ error: "User not found" });
  await db.collection("dismissed_questions").doc(`${user.id}_${req.params.questionId}`).set({ user_id: user.id, question_id: req.params.questionId });
  res.json({ success: true });
});

// --- Rankings ---
app.post("/api/rankings", async (req, res) => {
  const { username, questionId, entries } = req.body;
  const user = await getUser(username);
  if (!user) return res.status(404).json({ error: "User not found" });
  const existing = await db.collection("rankings").where("question_id", "==", questionId).where("user_id", "==", user.id).limit(1).get();
  if (!existing.empty) return res.status(400).json({ error: "Already ranked" });
  const ref = await db.collection("rankings").add({ question_id: questionId, user_id: user.id, completed_at: new Date().toISOString() });
  for (const e of entries) { await db.collection("ranking_entries").add({ ranking_id: ref.id, item_id: e.itemId, rank: e.rank }); }
  res.json({ id: ref.id });
});

app.get("/api/rankings", async (req, res) => {
  const rSnap = await db.collection("rankings").where("question_id", "==", req.query.questionId).get();
  const rankings = [];
  for (const rDoc of rSnap.docs) {
    const r = rDoc.data();
    const udoc = await db.collection("users").doc(r.user_id).get();
    const eSnap = await db.collection("ranking_entries").where("ranking_id", "==", rDoc.id).orderBy("rank").get();
    const entries = [];
    for (const eDoc of eSnap.docs) { const e = eDoc.data(); const itemDoc = await db.collection("shared_question_items").doc(e.item_id).get(); const id2 = itemDoc.exists ? itemDoc.data() : {}; entries.push({ rank: e.rank, item_id: e.item_id, item_name: id2.name || "?", item_image: id2.image_data || null }); }
    rankings.push({ id: rDoc.id, participant_name: udoc.exists ? udoc.data().display_name : "?", completed_at: r.completed_at, entries });
  }
  res.json(rankings);
});

// Health check
app.get("/api/health", (req, res) => res.json({ status: "ok" }));

module.exports = app;
