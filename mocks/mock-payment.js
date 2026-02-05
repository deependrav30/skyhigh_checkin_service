import http from 'http';

const port = process.env.PAYMENT_MOCK_PORT || 4002;

const server = http.createServer((req, res) => {
  if (req.method === 'POST' && req.url === '/webhook') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      try {
        const parsed = JSON.parse(body || '{}');
        const { intentId = 'pi-demo', status = 'succeeded' } = parsed;
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ intentId, status }));
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
  console.log(`Payment mock listening on ${port}`);
});
