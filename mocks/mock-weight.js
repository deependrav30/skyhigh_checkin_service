import http from 'http';

const port = process.env.WEIGHT_MOCK_PORT || 4001;

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/weight') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      try {
        const parsed = JSON.parse(body || '{}');
        const { weightKg = 0 } = parsed;
        const overweight = weightKg > 25;
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ overweight }));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Bad request' }));
      }
    });
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(port, () => {
  console.log(`Weight mock listening on ${port}`);
});
