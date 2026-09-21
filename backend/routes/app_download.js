const express = require('express');
const fs = require('fs');
const path = require('path');

const router = express.Router();

// Static files (APK etc.) are served from backend/downloads.
// Drop your release APK there, e.g. backend/downloads/app-release.apk
const DOWNLOADS_DIR = path.join(__dirname, '..', 'downloads');

function readReleaseInfo() {
  try {
    // Optional metadata file with shape:
    // {
    //   "versionName": "1.0.1",
    //   "versionCode": 2,
    //   "apkFile": "app-release.apk",
    //   "notes": "Bug fixes and improvements"
    // }
    const metaPath = path.join(DOWNLOADS_DIR, 'release.json');
    const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));

    const apkFile = path.join(DOWNLOADS_DIR, meta.apkFile || 'app-release.apk');
    const stat = fs.existsSync(apkFile) ? fs.statSync(apkFile) : null;

    return {
      available: stat != null,
      versionName: meta.versionName || null,
      versionCode: meta.versionCode || null,
      notes: meta.notes || null,
      apkPath: stat ? `/downloads/${meta.apkFile || 'app-release.apk'}` : null,
      apkSizeBytes: stat ? stat.size : null,
      updatedAt: stat ? stat.mtime.toISOString() : null,
    };
  } catch (_) {
    // No release.json -> fall back to whatever APK file exists.
    try {
      const files = fs.readdirSync(DOWNLOADS_DIR).filter((f) => f.toLowerCase().endsWith('.apk'));
      if (!files.length) return { available: false };
      const apkPath = path.join(DOWNLOADS_DIR, files[0]);
      const stat = fs.statSync(apkPath);
      return {
        available: true,
        versionName: null,
        versionCode: null,
        notes: null,
        apkPath: `/downloads/${files[0]}`,
        apkSizeBytes: stat.size,
        updatedAt: stat.mtime.toISOString(),
      };
    } catch (_err) {
      return { available: false };
    }
  }
}

router.get('/release', (req, res) => {
  const release = readReleaseInfo();
  if (!release.available) {
    return res.status(404).json({ success: false, message: 'No app release published yet.' });
  }
  res.json({ success: true, release });
});

module.exports = router;
