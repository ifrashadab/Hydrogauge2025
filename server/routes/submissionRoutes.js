import express from 'express';
import crypto from 'crypto';
import { Submission } from '../models/Submission.js';
import { authenticateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

function verifySignature({ id, capturedAt, deviceId }, signature, qrSecret) {
  const data = `${id}|${capturedAt}|${deviceId ?? 'unknown'}`;
  const mac = crypto.createHmac('sha256', qrSecret).update(data).digest('hex');
  try {
    return crypto.timingSafeEqual(Buffer.from(mac), Buffer.from(signature));
  } catch {
    return false;
  }
}

export function createSubmissionRoutes(db, qrSecret) {
  const submissionsCollection = db.collection('submissions');

  router.post('/', async (req, res) => {
    try {
      const sig = req.header('X-Signature') || '';
      const payload = req.body || {};
      
      if (!verifySignature({ 
        id: payload.id, 
        capturedAt: payload.capturedAt, 
        deviceId: payload.deviceId 
      }, sig, qrSecret)) {
        return res.status(401).json({ 
          ok: false, 
          error: 'Invalid signature' 
        });
      }

      const validationErrors = Submission.validate(payload);
      if (validationErrors.length > 0) {
        return res.status(400).json({ 
          ok: false, 
          error: validationErrors.join(', ') 
        });
      }

      const submission = new Submission({
        ...payload,
        userId: req.user?.username || null
      });

      await submissionsCollection.insertOne(submission.toJSON());
      
      return res.json({ 
        ok: true, 
        message: 'Submission saved successfully' 
      });
    } catch (error) {
      if (error?.code === 11000) {
        return res.status(200).json({ 
          ok: true, 
          message: 'Submission already exists',
          dedup: true 
        });
      }
      console.error('Submission error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Server error' 
      });
    }
  });

  router.get('/', authenticateToken, async (req, res) => {
    try {
      const { siteId, limit = 100 } = req.query;
      const query = siteId ? { siteId } : {};
      
      const submissions = await submissionsCollection
        .find(query)
        .sort({ capturedAt: -1 })
        .limit(parseInt(limit))
        .toArray();

      return res.json({ 
        ok: true, 
        submissions 
      });
    } catch (error) {
      console.error('Get submissions error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to fetch submissions' 
      });
    }
  });

  router.get('/:id', authenticateToken, async (req, res) => {
    try {
      const submission = await submissionsCollection.findOne({ id: req.params.id });
      
      if (!submission) {
        return res.status(404).json({ 
          ok: false, 
          error: 'Submission not found' 
        });
      }

      return res.json({ 
        ok: true, 
        submission 
      });
    } catch (error) {
      console.error('Get submission error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to fetch submission' 
      });
    }
  });

  return router;
}
