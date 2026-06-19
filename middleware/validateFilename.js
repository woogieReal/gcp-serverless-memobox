const FILENAME_PATTERN = /^[a-zA-Z0-9_-]+$/;
const FILENAME_MAX_LENGTH = 100;

function validateFilename(req, res, next) {
  const filename = req.params.filename || req.body?.filename;

  if (!filename) {
    return res.status(400).json({ error: 'filename is required' });
  }

  if (filename.length > FILENAME_MAX_LENGTH) {
    return res.status(400).json({ error: `filename must be ${FILENAME_MAX_LENGTH} characters or less` });
  }

  if (!FILENAME_PATTERN.test(filename)) {
    return res.status(400).json({ error: 'filename may only contain letters, numbers, hyphens, and underscores' });
  }

  next();
}

module.exports = validateFilename;
