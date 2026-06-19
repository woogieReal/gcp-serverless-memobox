const BUCKET_NAME = process.env.BUCKET_NAME || 'woogie-sandbox-gcp-memobox';

function getFile(storage, filename) {
  return storage.bucket(BUCKET_NAME).file(`${filename}.txt`);
}

async function listMemos(storage) {
  const [files] = await storage.bucket(BUCKET_NAME).getFiles();
  return files.map((f) => f.name.replace(/\.txt$/, ''));
}

async function getMemo(storage, filename) {
  const file = getFile(storage, filename);
  const [exists] = await file.exists();
  if (!exists) return null;

  const [contents] = await file.download();
  return contents.toString('utf-8');
}

async function createMemo(storage, filename, content) {
  const file = getFile(storage, filename);
  const [exists] = await file.exists();
  if (exists) return false;

  await file.save(content, { contentType: 'text/plain' });
  return true;
}

async function updateMemo(storage, filename, content) {
  const file = getFile(storage, filename);
  const [exists] = await file.exists();
  if (!exists) return false;

  await file.save(content, { contentType: 'text/plain' });
  return true;
}

async function deleteMemo(storage, filename) {
  const file = getFile(storage, filename);
  const [exists] = await file.exists();
  if (!exists) return false;

  await file.delete();
  return true;
}

module.exports = { listMemos, getMemo, createMemo, updateMemo, deleteMemo };
