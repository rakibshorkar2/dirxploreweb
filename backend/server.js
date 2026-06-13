require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const cheerio = require('cheerio');
const { SocksProxyAgent } = require('socks-proxy-agent');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const db = require('./db');

const app = express();
app.use(cors());
app.use(express.json());

// Memory store for config, initialized from environment variables
let config = {
  httpServerUrl: process.env.DEFAULT_HTTP_SERVER || 'http://172.16.50.4/',
  proxyHost: process.env.DEFAULT_PROXY_HOST || '103.166.253.92',
  proxyPort: parseInt(process.env.DEFAULT_PROXY_PORT || '1088'),
  proxyUser: process.env.DEFAULT_PROXY_USER || 'test',
  proxyPass: process.env.DEFAULT_PROXY_PASS || 'test',
  proxyEnabled: true,
  maxConcurrentDownloads: parseInt(process.env.MAX_CONCURRENT_DOWNLOADS || '3'),
  downloadDir: process.env.DOWNLOAD_DIR || 'downloads',
};

let DOWNLOAD_DIR = path.isAbsolute(config.downloadDir)
  ? config.downloadDir
  : path.join(__dirname, config.downloadDir);

if (!fs.existsSync(DOWNLOAD_DIR)) {
  fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });
}

// Map of active download streams/cancellation tokens to control them dynamically
const activeDownloads = new Map();

// Helper to create Axios client with active proxy configurations
function getAxiosClient() {
  const options = {
    timeout: 30000,
  };

  if (config.proxyEnabled && config.proxyHost && config.proxyPort) {
    let agentUrl = 'socks5h://';
    if (config.proxyUser && config.proxyPass) {
      agentUrl += `${encodeURIComponent(config.proxyUser)}:${encodeURIComponent(config.proxyPass)}@`;
    }
    agentUrl += `${config.proxyHost}:${config.proxyPort}`;
    
    console.log(`Configuring SOCKS5 proxy agent: socks5h://${config.proxyUser ? '***:***@' : ''}${config.proxyHost}:${config.proxyPort}`);
    options.httpAgent = new SocksProxyAgent(agentUrl);
    options.httpsAgent = new SocksProxyAgent(agentUrl);
  }

  return axios.create(options);
}

// Parse Size Text Helper
function parseSizeText(str) {
  if (!str || str === '-') return null;
  // Match number and suffix
  const match = str.trim().match(/^([\d.]+)\s*([KMGT]B|[B])?$/i);
  if (!match) return null;
  const val = parseFloat(match[1]);
  const unit = (match[2] || 'B').toUpperCase();
  switch (unit) {
    case 'B': return Math.round(val);
    case 'KB': return Math.round(val * 1024);
    case 'MB': return Math.round(val * 1024 * 1024);
    case 'GB': return Math.round(val * 1024 * 1024 * 1024);
    case 'TB': return Math.round(val * 1024 * 1024 * 1024 * 1024);
    default: return Math.round(val);
  }
}

// API CONFIG ENDPOINTS
app.get('/api/config', (req, res) => {
  res.json(config);
});

app.post('/api/config', (req, res) => {
  const { 
    httpServerUrl, 
    proxyHost, 
    proxyPort, 
    proxyUser, 
    proxyPass, 
    proxyEnabled,
    maxConcurrentDownloads,
    downloadDir
  } = req.body;
  
  if (httpServerUrl) {
    let url = httpServerUrl;
    if (!url.endsWith('/')) {
      url += '/';
    }
    config.httpServerUrl = url;
  }
  
  if (proxyHost !== undefined) config.proxyHost = proxyHost;
  if (proxyPort !== undefined) config.proxyPort = parseInt(proxyPort);
  if (proxyUser !== undefined) config.proxyUser = proxyUser;
  if (proxyPass !== undefined) config.proxyPass = proxyPass;
  if (proxyEnabled !== undefined) config.proxyEnabled = !!proxyEnabled;
  
  if (maxConcurrentDownloads !== undefined) {
    config.maxConcurrentDownloads = parseInt(maxConcurrentDownloads) || 3;
  }
  
  if (downloadDir !== undefined && downloadDir !== config.downloadDir) {
    config.downloadDir = downloadDir;
    DOWNLOAD_DIR = path.isAbsolute(downloadDir)
      ? downloadDir
      : path.join(__dirname, downloadDir);
    if (!fs.existsSync(DOWNLOAD_DIR)) {
      fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });
    }
  }

  console.log('Synchronized configurations with frontend:', {
    ...config,
    proxyPass: config.proxyPass ? '********' : ''
  });
  
  res.json({ success: true, config });
  processQueue();
});

// DIRECT DOWNLOAD STREAM TO CLIENT (through SOCKS5 proxy)
app.get('/api/download/direct', async (req, res) => {
  const fileUrl = req.query.url;
  const fileName = req.query.name || 'file';

  if (!fileUrl) {
    return res.status(400).send('URL is required');
  }

  console.log(`Direct download request for: ${fileName} from ${fileUrl}`);

  try {
    const client = getAxiosClient();
    
    // Pass Range and conditional range/validation headers if client requested them
    // This supports pausing/resuming in browser native downloads (especially Safari on iOS)
    const generatedEtag = `"${crypto.createHash('md5').update(fileUrl).digest('hex')}"`;
    const headers = {};
    if (req.headers.range) headers['Range'] = req.headers.range;

    // Filter out our generated ETag from validation headers before forwarding to target
    // server so target server doesn't fail comparison and return 200 OK instead of 206
    if (req.headers['if-range'] && req.headers['if-range'] !== generatedEtag) {
      headers['If-Range'] = req.headers['if-range'];
    }
    if (req.headers['if-match'] && req.headers['if-match'] !== generatedEtag) {
      headers['If-Match'] = req.headers['if-match'];
    }
    if (req.headers['if-none-match'] && req.headers['if-none-match'] !== generatedEtag) {
      headers['If-None-Match'] = req.headers['if-none-match'];
    }
    if (req.headers['if-modified-since']) headers['If-Modified-Since'] = req.headers['if-modified-since'];
    if (req.headers['if-unmodified-since']) headers['If-Unmodified-Since'] = req.headers['if-unmodified-since'];

    const response = await client.get(fileUrl, {
      responseType: 'stream',
      headers,
    });

    // Copy response status and headers
    res.status(response.status);
    
    // Always advertise range support
    res.setHeader('Accept-Ranges', 'bytes');
    
    if (response.headers['content-type']) res.setHeader('Content-Type', response.headers['content-type']);
    if (response.headers['content-length']) res.setHeader('Content-Length', response.headers['content-length']);
    if (response.headers['content-range']) res.setHeader('Content-Range', response.headers['content-range']);
    
    // Forward or generate ETag (Safari requires a persistent ETag to resume)
    if (response.headers['etag']) {
      res.setHeader('ETag', response.headers['etag']);
    } else {
      const etag = crypto.createHash('md5').update(fileUrl).digest('hex');
      res.setHeader('ETag', `"${etag}"`);
    }

    if (response.headers['last-modified']) {
      res.setHeader('Last-Modified', response.headers['last-modified']);
    }
    
    // Set attachment content disposition to force browser save dialog
    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(fileName)}"`);

    response.data.pipe(res);
  } catch (error) {
    console.error(`Direct download failed for ${fileName}:`, error.message);
    res.status(500).send(`Failed to stream download: ${error.message}`);
  }
});

// BROWSE DIRECTORY ENDPOINT
app.get('/api/browse', async (req, res) => {
  const relativePath = req.query.path || '';
  
  // Safeguard path traversal
  let targetUrl = new URL(relativePath, config.httpServerUrl).toString();
  if (!targetUrl.endsWith('/') && !targetUrl.includes('?')) {
    targetUrl += '/';
  }
  console.log(`Browsing target: ${targetUrl}`);

  try {
    const client = getAxiosClient();
    const response = await client.get(targetUrl);
    const html = response.data;

    const $ = cheerio.load(html);
    const items = [];

    $('a').each((i, el) => {
      const href = $(el).attr('href');
      const name = $(el).text().trim();
      
      const lowerHref = href ? href.trim().toLowerCase() : '';
      // Skip parent directory links, query sorting links, mailto/javascript, and h5ai site home links
      if (!href || 
          href === '/' ||
          href === '../' || 
          lowerHref.startsWith('javascript:') || 
          lowerHref.startsWith('mailto:') ||
          href.startsWith('?') || 
          name === 'Parent Directory' ||
          name.toLowerCase() === 'parent directory' ||
          href.includes('://larsjung.de')
      ) {
        return;
      }
      
      let absoluteUrl;
      try {
        absoluteUrl = new URL(href, targetUrl).toString();
      } catch (e) {
        return;
      }
      
      const isDirectory = href.endsWith('/') || absoluteUrl.endsWith('/');
      const cleanName = name.replace(/\/$/, '') || href.replace(/\/$/, '').split('/').pop();
      
      let size = null;
      let modified = null;

      // Try parsing from tables (standard Apache/Nginx format)
      const parentRow = $(el).closest('tr');
      if (parentRow.length > 0) {
        const tds = parentRow.find('td');
        if (tds.length >= 3) {
          // Column 2 is typically modified date, Column 3 is size
          const dateText = $(tds[2]).text().trim();
          const sizeText = $(tds[3]).text().trim();

          if (dateText && !dateText.includes('-') && Date.parse(dateText)) {
            modified = new Date(dateText).toISOString();
          }
          if (sizeText && sizeText !== '-') {
            size = parseSizeText(sizeText);
          }
        }
      }

      // Fallback: parse preformatted directory layouts
      if (!size && !modified) {
        const nextText = el.nextSibling && el.nextSibling.nodeType === 3 ? el.nextSibling.nodeValue : '';
        const parts = nextText.trim().split(/\s+/);
        if (parts.length >= 2) {
          const potentialDate = `${parts[0]} ${parts[1]}`;
          if (Date.parse(potentialDate)) {
            modified = new Date(potentialDate).toISOString();
          }
          
          const potentialSize = parts[parts.length - 1];
          if (/^\d+$/.test(potentialSize)) {
            size = parseInt(potentialSize, 10);
          } else {
            size = parseSizeText(potentialSize);
          }
        }
      }

      items.push({
        name: cleanName,
        path: absoluteUrl,
        isDirectory,
        size,
        modified,
      });
    });

    res.json(items);
  } catch (error) {
    console.error(`Error browsing ${targetUrl}:`, error.message);
    res.status(500).json({ error: `Failed to browse directory: ${error.message}` });
  }
});

// LIST DOWNLOADS
app.get('/api/downloads', async (req, res) => {
  try {
    const list = await db.all('SELECT * FROM downloads ORDER BY createdAt DESC');
    res.json(list);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ADD DOWNLOAD TO QUEUE
app.post('/api/downloads', async (req, res) => {
  const { name, url } = req.body;
  if (!name || !url) {
    return res.status(400).json({ error: 'Name and URL are required' });
  }

  const id = crypto.randomUUID();
  const createdAt = new Date().toISOString();

  try {
    // Insert into db
    await db.run(
      'INSERT INTO downloads (id, name, url, progress, speed, status, eta, downloadedBytes, totalBytes, createdAt) VALUES (?, ?, ?, 0.0, 0.0, "pending", NULL, 0, 0, ?)',
      [id, name, url, createdAt]
    );

    const newItem = await db.get('SELECT * FROM downloads WHERE id = ?', [id]);
    
    // Trigger download scheduler in background
    processQueue();

    res.status(201).json(newItem);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PAUSE DOWNLOAD
app.post('/api/downloads/:id/pause', async (req, res) => {
  const { id } = req.params;
  try {
    const item = await db.get('SELECT * FROM downloads WHERE id = ?', [id]);
    if (!item) {
      return res.status(404).json({ error: 'Download task not found' });
    }

    if (item.status === 'downloading' || item.status === 'pending') {
      const active = activeDownloads.get(id);
      if (active) {
        active.abortController.abort();
        activeDownloads.delete(id);
      }
      await db.run('UPDATE downloads SET status = "paused", speed = 0.0, eta = NULL WHERE id = ?', [id]);
      console.log(`Paused download: ${item.name}`);
    }

    res.json({ success: true });
    processQueue(); // Run queue to see if another can start
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// RESUME DOWNLOAD
app.post('/api/downloads/:id/resume', async (req, res) => {
  const { id } = req.params;
  try {
    const item = await db.get('SELECT * FROM downloads WHERE id = ?', [id]);
    if (!item) {
      return res.status(404).json({ error: 'Download task not found' });
    }

    if (item.status === 'paused' || item.status === 'failed') {
      await db.run('UPDATE downloads SET status = "pending" WHERE id = ?', [id]);
      console.log(`Resumed download (set to pending): ${item.name}`);
    }

    res.json({ success: true });
    processQueue();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// RETRY DOWNLOAD
app.post('/api/downloads/:id/retry', async (req, res) => {
  const { id } = req.params;
  try {
    const item = await db.get('SELECT * FROM downloads WHERE id = ?', [id]);
    if (!item) {
      return res.status(404).json({ error: 'Download task not found' });
    }

    // Delete existing partial files if retrying from scratch
    const partFilePath = path.join(DOWNLOAD_DIR, `${id}.part`);
    if (fs.existsSync(partFilePath)) {
      fs.unlinkSync(partFilePath);
    }

    await db.run('UPDATE downloads SET status = "pending", progress = 0.0, downloadedBytes = 0, speed = 0.0, eta = NULL WHERE id = ?', [id]);
    console.log(`Retrying download: ${item.name}`);
    res.json({ success: true });
    processQueue();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CANCEL & DELETE DOWNLOAD
app.post('/api/downloads/:id/cancel', async (req, res) => {
  const { id } = req.params;
  try {
    const item = await db.get('SELECT * FROM downloads WHERE id = ?', [id]);
    if (!item) {
      return res.status(404).json({ error: 'Download task not found' });
    }

    // Cancel active network stream
    const active = activeDownloads.get(id);
    if (active) {
      active.abortController.abort();
      activeDownloads.delete(id);
    }

    // Delete database entry
    await db.run('DELETE FROM downloads WHERE id = ?', [id]);

    // Clean up files
    const partFilePath = path.join(DOWNLOAD_DIR, `${id}.part`);
    if (fs.existsSync(partFilePath)) {
      fs.unlinkSync(partFilePath);
    }
    const finalFilePath = path.join(DOWNLOAD_DIR, item.name);
    if (fs.existsSync(finalFilePath)) {
      fs.unlinkSync(finalFilePath);
    }

    console.log(`Cancelled & deleted download files for: ${item.name}`);
    res.json({ success: true });
    processQueue();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DOWNLOAD SCHEDULER & PIPELINE
async function processQueue() {
  const maxConcurrency = parseInt(process.env.MAX_CONCURRENT_DOWNLOADS || '3');
  
  try {
    const activeCountRow = await db.get('SELECT COUNT(*) as count FROM downloads WHERE status = "downloading"');
    const activeCount = activeCountRow.count;
    
    if (activeCount >= maxConcurrency) {
      return; // Queue is full
    }

    const vacancy = maxConcurrency - activeCount;
    // Get the next pending downloads in order of creation
    const pending = await db.all('SELECT * FROM downloads WHERE status = "pending" ORDER BY createdAt ASC LIMIT ?', [vacancy]);

    for (const item of pending) {
      startDownload(item);
    }
  } catch (error) {
    console.error('Error processing queue:', error.message);
  }
}

async function startDownload(item) {
  const { id, name, url } = item;
  const targetUrl = new URL(url, config.httpServerUrl).toString();
  const partFilePath = path.join(DOWNLOAD_DIR, `${id}.part`);
  const finalFilePath = path.join(DOWNLOAD_DIR, name);

  console.log(`Starting download task: ${name} from ${targetUrl}`);

  // Create AbortController to support cancellation/pausing
  const abortController = new AbortController();
  activeDownloads.set(id, { abortController });

  await db.run('UPDATE downloads SET status = "downloading" WHERE id = ?', [id]);

  let downloadedBytes = 0;
  if (fs.existsSync(partFilePath)) {
    const stats = fs.statSync(partFilePath);
    downloadedBytes = stats.size;
  }

  const client = getAxiosClient();
  let headers = {};
  if (downloadedBytes > 0) {
    headers['Range'] = `bytes=${downloadedBytes}-`;
    console.log(`Resuming download. Requesting Range: bytes=${downloadedBytes}-`);
  }

  // Tracking metrics
  let lastTime = Date.now();
  let lastBytes = downloadedBytes;
  let speed = 0;
  let dbUpdateTimer = null;

  try {
    const response = await client.get(targetUrl, {
      responseType: 'stream',
      headers,
      signal: abortController.signal,
    });

    const isPartial = response.status === 206;
    const totalContentLength = parseInt(response.headers['content-length'] || '0');
    const totalBytes = isPartial ? (totalContentLength + downloadedBytes) : totalContentLength;

    await db.run('UPDATE downloads SET totalBytes = ? WHERE id = ?', [totalBytes, id]);

    // Setup file write stream.
    // If it's a partial content, append to existing file, else overwrite
    const writeStream = fs.createWriteStream(partFilePath, { flags: isPartial ? 'a' : 'w' });

    response.data.pipe(writeStream);

    response.data.on('data', (chunk) => {
      downloadedBytes += chunk.length;
    });

    // Setup periodic database progress updater
    dbUpdateTimer = setInterval(async () => {
      const now = Date.now();
      const timeDiff = (now - lastTime) / 1000; // seconds
      if (timeDiff >= 0.5) {
        const bytesDiff = downloadedBytes - lastBytes;
        speed = Math.max(0, bytesDiff / timeDiff); // bytes per second
        
        lastTime = now;
        lastBytes = downloadedBytes;

        const progress = totalBytes > 0 ? (downloadedBytes / totalBytes) : 0;
        let eta = 'Calculating...';
        if (speed > 0 && totalBytes > downloadedBytes) {
          const secondsRemaining = (totalBytes - downloadedBytes) / speed;
          if (secondsRemaining < 60) {
            eta = `${Math.round(secondsRemaining)}s`;
          } else {
            const mins = Math.floor(secondsRemaining / 60);
            const secs = Math.round(secondsRemaining % 60);
            eta = `${mins}m ${secs}s`;
          }
        }

        try {
          await db.run(
            'UPDATE downloads SET progress = ?, speed = ?, eta = ?, downloadedBytes = ? WHERE id = ?',
            [progress, speed, eta, downloadedBytes, id]
          );
        } catch (dbErr) {
          console.error('Error updating progress in DB:', dbErr.message);
        }
      }
    }, 1000);

    await new Promise((resolve, reject) => {
      writeStream.on('finish', resolve);
      writeStream.on('error', (err) => {
        reject(err);
      });
      response.data.on('error', (err) => {
        reject(err);
      });
    });

    // Cleanup updater
    clearInterval(dbUpdateTimer);
    activeDownloads.delete(id);

    // Finalize: rename file from .part to actual filename
    if (fs.existsSync(partFilePath)) {
      if (fs.existsSync(finalFilePath)) {
        fs.unlinkSync(finalFilePath); // delete pre-existing file
      }
      fs.renameSync(partFilePath, finalFilePath);
    }

    await db.run(
      'UPDATE downloads SET status = "completed", progress = 1.0, speed = 0.0, eta = NULL, downloadedBytes = ? WHERE id = ?',
      [totalBytes || downloadedBytes, id]
    );

    console.log(`Download completed successfully: ${name}`);
    processQueue(); // run queue again

  } catch (error) {
    if (dbUpdateTimer) clearInterval(dbUpdateTimer);
    activeDownloads.delete(id);

    if (axios.isCancel(error) || error.name === 'CanceledError' || abortController.signal.aborted) {
      console.log(`Download paused/cancelled by user: ${name}`);
    } else {
      console.error(`Download failed for ${name}:`, error.message);
      try {
        await db.run(
          'UPDATE downloads SET status = "failed", speed = 0.0, eta = NULL WHERE id = ?',
          [id]
        );
      } catch (dbErr) {
        console.error('Error marking failed download in DB:', dbErr.message);
      }
      processQueue(); // run queue again
    }
  }
}

// Serve static Flutter Web build if available
const buildPath = path.join(__dirname, '../build/web');
if (fs.existsSync(buildPath)) {
  app.use(express.static(buildPath));
  // Keep API routes active, fallback non-API routes to index.html for Flutter routing
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api')) {
      return next();
    }
    res.sendFile(path.join(buildPath, 'index.html'));
  });
  console.log(`Configured static server for Flutter Web build at: ${buildPath}`);
}

// Start server
const PORT = process.env.PORT || 3000;
db.initializeDb().then(() => {
  app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
    processQueue(); // Check for pending downloads on start
  });
}).catch(err => {
  console.error('Failed to initialize database. Exiting...', err);
  process.exit(1);
});
