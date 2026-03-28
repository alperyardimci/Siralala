const express = require('express');
const cors = require('cors');
const Database = require('better-sqlite3');
const crypto = require('crypto');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// --- Database Setup ---
const db = new Database(path.join(__dirname, 'siralala.db'));
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    friend_code TEXT UNIQUE NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS friendships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    friend_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(user_id, friend_id)
  );

  CREATE TABLE IF NOT EXISTS groups_ (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    owner_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS group_members (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER REFERENCES groups_(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(group_id, user_id)
  );

  CREATE TABLE IF NOT EXISTS shared_questions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    group_id INTEGER REFERENCES groups_(id) ON DELETE CASCADE,
    creator_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    text TEXT NOT NULL,
    pool_name TEXT NOT NULL,
    item_count INTEGER NOT NULL,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS shared_question_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    question_id INTEGER REFERENCES shared_questions(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    image_data TEXT,
    sort_order INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS rankings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    question_id INTEGER REFERENCES shared_questions(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    completed_at TEXT DEFAULT (datetime('now')),
    UNIQUE(question_id, user_id)
  );

  CREATE TABLE IF NOT EXISTS ranking_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ranking_id INTEGER REFERENCES rankings(id) ON DELETE CASCADE,
    item_id INTEGER REFERENCES shared_question_items(id) ON DELETE CASCADE,
    rank INTEGER NOT NULL
  );
`);

function generateCode() {
  return crypto.randomBytes(3).toString('hex').toUpperCase();
}

function getUser(username) {
  return db.prepare('SELECT * FROM users WHERE username = ?').get(username);
}

// --- Users ---
app.post('/api/users/register', (req, res) => {
  const { username, displayName } = req.body;
  if (!username || !displayName) return res.status(400).json({ error: 'username and displayName required' });

  const existing = getUser(username);
  if (existing) return res.json(existing);

  const code = generateCode();
  const result = db.prepare('INSERT INTO users (username, display_name, friend_code) VALUES (?, ?, ?)').run(username, displayName, code);
  res.json({ id: result.lastInsertRowid, username, display_name: displayName, friend_code: code });
});

app.get('/api/users/me', (req, res) => {
  const user = getUser(req.query.username);
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json(user);
});

app.get('/api/users/search', (req, res) => {
  const user = db.prepare('SELECT id, username, display_name, friend_code FROM users WHERE friend_code = ?').get(req.query.code);
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json(user);
});

// --- Friends ---
app.post('/api/friends/add', (req, res) => {
  const { username, friendCode } = req.body;
  const user = getUser(username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const friend = db.prepare('SELECT * FROM users WHERE friend_code = ?').get(friendCode);
  if (!friend) return res.status(404).json({ error: 'Friend not found' });
  if (friend.id === user.id) return res.status(400).json({ error: 'Cannot add yourself' });

  const addFriend = db.prepare('INSERT OR IGNORE INTO friendships (user_id, friend_id) VALUES (?, ?)');
  db.transaction(() => {
    addFriend.run(user.id, friend.id);
    addFriend.run(friend.id, user.id);
  })();

  res.json({ success: true, friend: { id: friend.id, username: friend.username, display_name: friend.display_name } });
});

app.get('/api/friends', (req, res) => {
  const user = getUser(req.query.username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const friends = db.prepare(`
    SELECT u.id, u.username, u.display_name FROM friendships f
    JOIN users u ON u.id = f.friend_id
    WHERE f.user_id = ?
  `).all(user.id);

  res.json(friends);
});

app.delete('/api/friends/:friendId', (req, res) => {
  const user = getUser(req.query.username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  db.transaction(() => {
    db.prepare('DELETE FROM friendships WHERE user_id = ? AND friend_id = ?').run(user.id, req.params.friendId);
    db.prepare('DELETE FROM friendships WHERE user_id = ? AND friend_id = ?').run(req.params.friendId, user.id);
  })();

  res.json({ success: true });
});

// --- Groups ---
app.post('/api/groups', (req, res) => {
  const { username, name, memberUsernames } = req.body;
  const user = getUser(username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const group = db.transaction(() => {
    const result = db.prepare('INSERT INTO groups_ (name, owner_id) VALUES (?, ?)').run(name, user.id);
    const groupId = result.lastInsertRowid;

    const addMember = db.prepare('INSERT OR IGNORE INTO group_members (group_id, user_id) VALUES (?, ?)');
    addMember.run(groupId, user.id);

    if (memberUsernames) {
      for (const mu of memberUsernames) {
        const member = getUser(mu);
        if (member) addMember.run(groupId, member.id);
      }
    }

    const members = db.prepare(`
      SELECT u.id, u.username, u.display_name FROM group_members gm
      JOIN users u ON u.id = gm.user_id WHERE gm.group_id = ?
    `).all(groupId);

    return { id: groupId, name, owner_id: user.id, members };
  })();

  res.json(group);
});

app.get('/api/groups', (req, res) => {
  const user = getUser(req.query.username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const groups = db.prepare(`
    SELECT g.id, g.name, g.owner_id FROM group_members gm
    JOIN groups_ g ON g.id = gm.group_id
    WHERE gm.user_id = ?
  `).all(user.id);

  for (const g of groups) {
    g.members = db.prepare(`
      SELECT u.id, u.username, u.display_name FROM group_members gm
      JOIN users u ON u.id = gm.user_id WHERE gm.group_id = ?
    `).all(g.id);
  }

  res.json(groups);
});

app.get('/api/groups/:groupId/questions', (req, res) => {
  const user = getUser(req.query.username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const questions = db.prepare(`
    SELECT sq.*, u.display_name as creator_name, g.name as group_name
    FROM shared_questions sq
    JOIN groups_ g ON g.id = sq.group_id
    JOIN users u ON u.id = sq.creator_id
    WHERE sq.group_id = ?
    ORDER BY sq.created_at DESC
  `).all(req.params.groupId);

  for (const q of questions) {
    q.items = db.prepare('SELECT id, name, image_data, sort_order FROM shared_question_items WHERE question_id = ? ORDER BY sort_order').all(q.id);
    q.completion_count = db.prepare('SELECT COUNT(*) as c FROM rankings WHERE question_id = ?').get(q.id).c;
    q.user_ranked = db.prepare('SELECT COUNT(*) as c FROM rankings WHERE question_id = ? AND user_id = ?').get(q.id, user.id).c > 0;
  }

  res.json(questions);
});

app.delete('/api/groups/:groupId', (req, res) => {
  db.prepare('DELETE FROM groups_ WHERE id = ?').run(req.params.groupId);
  res.json({ success: true });
});

app.post('/api/groups/:groupId/members', (req, res) => {
  const { username } = req.body;
  const member = getUser(username);
  if (!member) return res.status(404).json({ error: 'User not found' });

  db.prepare('INSERT OR IGNORE INTO group_members (group_id, user_id) VALUES (?, ?)').run(req.params.groupId, member.id);
  res.json({ success: true });
});

// --- Questions ---
app.post('/api/questions', (req, res) => {
  const { username, groupId, text, poolName, items, itemCount } = req.body;
  const user = getUser(username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const question = db.transaction(() => {
    const count = itemCount || items.length;
    const result = db.prepare(
      'INSERT INTO shared_questions (group_id, creator_id, text, pool_name, item_count) VALUES (?, ?, ?, ?, ?)'
    ).run(groupId, user.id, text, poolName, count);
    const qId = result.lastInsertRowid;

    const insertItem = db.prepare('INSERT INTO shared_question_items (question_id, name, image_data, sort_order) VALUES (?, ?, ?, ?)');
    const insertedItems = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const itemName = typeof item === 'string' ? item : item.name;
      const itemImage = typeof item === 'string' ? null : (item.imageData || null);
      const r = insertItem.run(qId, itemName, itemImage, i);
      insertedItems.push({ id: r.lastInsertRowid, name: itemName, image_data: itemImage, sort_order: i });
    }

    return {
      id: qId, group_id: groupId, creator_id: user.id, creator_name: user.display_name,
      text, pool_name: poolName, item_count: count, items: insertedItems
    };
  })();

  res.json(question);
});

app.get('/api/questions/pending', (req, res) => {
  const user = getUser(req.query.username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const questions = db.prepare(`
    SELECT sq.*, u.display_name as creator_name, g.name as group_name
    FROM shared_questions sq
    JOIN groups_ g ON g.id = sq.group_id
    JOIN group_members gm ON gm.group_id = sq.group_id AND gm.user_id = ?
    JOIN users u ON u.id = sq.creator_id
    WHERE sq.is_active = 1
    AND sq.id NOT IN (SELECT question_id FROM rankings WHERE user_id = ?)
  `).all(user.id, user.id);

  for (const q of questions) {
    q.items = db.prepare('SELECT id, name, image_data, sort_order FROM shared_question_items WHERE question_id = ? ORDER BY sort_order').all(q.id);
    q.completion_count = db.prepare('SELECT COUNT(*) as c FROM rankings WHERE question_id = ?').get(q.id).c;
  }

  res.json(questions);
});

app.get('/api/questions/completed', (req, res) => {
  const user = getUser(req.query.username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const questions = db.prepare(`
    SELECT sq.*, u.display_name as creator_name, g.name as group_name
    FROM shared_questions sq
    JOIN groups_ g ON g.id = sq.group_id
    JOIN rankings r ON r.question_id = sq.id AND r.user_id = ?
    JOIN users u ON u.id = sq.creator_id
  `).all(user.id);

  for (const q of questions) {
    q.items = db.prepare('SELECT id, name, image_data, sort_order FROM shared_question_items WHERE question_id = ? ORDER BY sort_order').all(q.id);
    q.completion_count = db.prepare('SELECT COUNT(*) as c FROM rankings WHERE question_id = ?').get(q.id).c;
  }

  res.json(questions);
});

app.delete('/api/questions/:questionId', (req, res) => {
  db.prepare('DELETE FROM shared_questions WHERE id = ?').run(req.params.questionId);
  res.json({ success: true });
});

// --- Rankings ---
app.post('/api/rankings', (req, res) => {
  const { username, questionId, entries } = req.body;
  const user = getUser(username);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const existing = db.prepare('SELECT id FROM rankings WHERE question_id = ? AND user_id = ?').get(questionId, user.id);
  if (existing) return res.status(400).json({ error: 'Already ranked' });

  const ranking = db.transaction(() => {
    const result = db.prepare('INSERT INTO rankings (question_id, user_id) VALUES (?, ?)').run(questionId, user.id);
    const rankingId = result.lastInsertRowid;

    const insertEntry = db.prepare('INSERT INTO ranking_entries (ranking_id, item_id, rank) VALUES (?, ?, ?)');
    for (const e of entries) {
      insertEntry.run(rankingId, e.itemId, e.rank);
    }

    return { id: rankingId, question_id: questionId, user_id: user.id };
  })();

  res.json(ranking);
});

app.get('/api/rankings', (req, res) => {
  const questionId = req.query.questionId;

  const rankings = db.prepare(`
    SELECT r.id, r.completed_at, u.display_name as participant_name
    FROM rankings r
    JOIN users u ON u.id = r.user_id
    WHERE r.question_id = ?
  `).all(questionId);

  for (const r of rankings) {
    r.entries = db.prepare(`
      SELECT re.rank, sqi.id as item_id, sqi.name as item_name, sqi.image_data as item_image
      FROM ranking_entries re
      JOIN shared_question_items sqi ON sqi.id = re.item_id
      WHERE re.ranking_id = ?
      ORDER BY re.rank
    `).all(r.id);
  }

  res.json(rankings);
});

// --- Start ---
const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Siralala server running on http://localhost:${PORT}`);
});
