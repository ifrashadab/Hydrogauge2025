import express from 'express';
import { authenticateToken } from '../middleware/authMiddleware.js';
import { exponentialSmoothing, generateForecast } from '../utils/forecast.js';

const router = express.Router();

export function createForecastRoutes(db) {
  const submissionsCollection = db.collection('submissions');

  router.get('/:siteId/forecast', authenticateToken, async (req, res) => {
    try {
      const { siteId } = req.params;
      
      const docs = await submissionsCollection
        .find({ siteId })
        .sort({ capturedAt: 1 })
        .limit(100)
        .toArray();

      if (!docs.length) {
        return res.json({ 
          ok: true, 
          forecast: [] 
        });
      }

      const levels = docs.map(d => Number(d.waterLevelMeters));
      const alpha = Number(process.env.FORECAST_ALPHA || 0.3);
      const horizon = Number(process.env.FORECAST_HOURS || 12);
      
      const smoothedValue = exponentialSmoothing(levels, alpha);
      const forecast = generateForecast(smoothedValue, horizon);

      return res.json({ 
        ok: true, 
        forecast,
        siteId,
        dataPoints: levels.length
      });
    } catch (error) {
      console.error('Forecast error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to compute forecast' 
      });
    }
  });

  return router;
}
