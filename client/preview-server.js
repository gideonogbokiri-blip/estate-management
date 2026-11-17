const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, 'build');
const port = Number(process.env.PORT || 8765);
const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.otf': 'font/otf',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
};

http.createServer((request, response) => {
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  } catch {
    response.writeHead(400).end('Bad request');
    return;
  }

  const file = path.resolve(root, `.${pathname}`);
  if (file !== root && !file.startsWith(`${root}${path.sep}`)) {
    response.writeHead(403).end('Forbidden');
    return;
  }

  fs.stat(file, (statError, stat) => {
    if (statError) {
      response.writeHead(404).end('Not found');
      return;
    }
    const target = stat.isDirectory() ? path.join(file, 'index.html') : file;
    fs.readFile(target, (readError, content) => {
      if (readError) {
        response.writeHead(404).end('Not found');
        return;
      }
      response.writeHead(200, {
        'Content-Type': contentTypes[path.extname(target)] || 'application/octet-stream',
        'Cache-Control': 'no-cache',
        'X-Content-Type-Options': 'nosniff',
      });
      response.end(content);
    });
  });
}).listen(port, '127.0.0.1', () => {
  process.stdout.write(`Estate Management preview server listening at http://127.0.0.1:${port}/\n`);
});
