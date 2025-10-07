import express from 'express';
import { authenticateToken } from '../middleware/authMiddleware.js';
import { calculateZScore, getRiskLevel } from '../utils/anomaly.js';

const router = express.Router();

export function createAnomalyRoutes(db) {
  const submissionsCollection = db.collection('submissions');
  const anomaliesCollection = db.collection('anomalies');

  router.get('/:siteId/anomaly', authenticateToken, async (req, res) => {
    try {
      const { siteId } = req.params;
      const N = Number(process.env.ANOMALY_WINDOW || 20);
      
      const docs = await submissionsCollection
        .find({ siteId })
        .sort({ capturedAt: -1 })
        .limit(N)
        .toArray();

      if (!docs.length) {
        return res.json({ 
          ok: true, 
          z: 0, 
          risk: 'low' 
        });
      }

      const values = docs.map(d => Number(d.waterLevelMeters)).reverse();
      const { z, mean, sd } = calculateZScore(values);
      const risk = getRiskLevel(z);

      if (risk !== 'low') {
        await anomaliesCollection.insertOne({
          id: `anomaly_${Date.now()}`,
          siteId,
          submissionId: docs[0].id,
          zScore: z,
          risk,
          detectedAt: new Date(),
          acknowledged: false
        });
      }

      return res.json({ 
        ok: true, 
        z, 
        risk,
        mean,
        sd,
        siteId,
        dataPoints: values.length
      });
    } catch (error) {
      console.error('Anomaly detection error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to compute anomaly' 
      });
    }
  });

  router.get('/anomalies', authenticateToken, async (req, res) => {
    try {
      const { acknowledged } = req.query;
      const query = acknowledged !== undefined ? { acknowledged: acknowledged === 'true' } : {};
      
      const anomalies = await anomaliesCollection
        .find(query)
        .sort({ detectedAt: -1 })
        .limit(50)
        .toArray();

      return res.json({ 
        ok: true, 
        anomalies 
      });
    } catch (error) {
      console.error('Get anomalies error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to fetch anomalies' 
      });
    }
  });

  return router;
}
