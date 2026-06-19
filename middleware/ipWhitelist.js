const ALLOWED_IPS = (process.env.ALLOWED_IPS || '').split(',').map((ip) => ip.trim()).filter(Boolean);

function ipWhitelist(req, res, next) {
  const forwarded = req.headers['x-forwarded-for'];
  const clientIp = forwarded ? forwarded.split(',').pop().trim() : req.socket.remoteAddress;

  if (!ALLOWED_IPS.includes(clientIp)) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  next();
}

module.exports = ipWhitelist;
