const { Router } = require('express');
const ipWhitelist = require('../middleware/ipWhitelist');
const validateFilename = require('../middleware/validateFilename');
const { listMemos, getMemo, createMemo, updateMemo, deleteMemo } = require('../services/gcs');

module.exports = (storage) => {
  const router = Router();

  router.use(ipWhitelist);

  router.get('/', async (req, res) => {
    try {
      const memos = await listMemos(storage);
      res.json(memos);
    } catch (e) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });

  router.get('/:filename', validateFilename, async (req, res) => {
    try {
      const content = await getMemo(storage, req.params.filename);
      if (content === null) return res.status(404).json({ error: 'Not Found' });
      res.type('text/plain').send(content);
    } catch (e) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });

  router.post('/', validateFilename, async (req, res) => {
    try {
      const { filename, content } = req.body;
      if (content === undefined) return res.status(400).json({ error: 'content is required' });

      const created = await createMemo(storage, filename, content);
      if (!created) return res.status(409).json({ error: 'Conflict: filename already exists' });

      res.status(201).json({ filename });
    } catch (e) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });

  router.put('/:filename', validateFilename, async (req, res) => {
    try {
      const { content } = req.body;
      if (content === undefined) return res.status(400).json({ error: 'content is required' });

      const updated = await updateMemo(storage, req.params.filename, content);
      if (!updated) return res.status(404).json({ error: 'Not Found' });

      res.json({ filename: req.params.filename });
    } catch (e) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });

  router.delete('/:filename', validateFilename, async (req, res) => {
    try {
      const deleted = await deleteMemo(storage, req.params.filename);
      if (!deleted) return res.status(404).json({ error: 'Not Found' });

      res.status(204).send();
    } catch (e) {
      res.status(500).json({ error: 'Internal Server Error' });
    }
  });

  return router;
};
