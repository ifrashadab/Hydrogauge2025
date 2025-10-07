import express from 'express';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';
import { Visit } from '../models/Visit.js';

const router = express.Router();

export function createVisitRoutes(db) {
  const visitsCollection = db.collection('visits');

  router.post('/schedule', authenticateToken, authorizeRoles('Supervisor'), async (req, res) => {
    try {
      const validationErrors = Visit.validate(req.body);
      if (validationErrors.length > 0) {
        return res.status(400).json({ 
          ok: false, 
          error: validationErrors.join(', ') 
        });
      }

      const visit = new Visit({
        ...req.body,
        id: `visit_${Date.now()}`,
        createdBy: req.user.username
      });

      await visitsCollection.insertOne(visit.toJSON());

      return res.status(201).json({ 
        ok: true, 
        message: 'Visit scheduled successfully',
        visit: visit.toJSON() 
      });
    } catch (error) {
      console.error('Schedule visit error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to schedule visit' 
      });
    }
  });

  router.get('/', authenticateToken, async (req, res) => {
    try {
      const { status, siteId } = req.query;
      const query = {};
      
      if (status) query.status = status;
      if (siteId) query.siteId = siteId;

      const visits = await visitsCollection
        .find(query)
        .sort({ scheduledDate: -1 })
        .toArray();

      return res.json({ 
        ok: true, 
        visits 
      });
    } catch (error) {
      console.error('Get visits error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to fetch visits' 
      });
    }
  });

  router.get('/:id', authenticateToken, async (req, res) => {
    try {
      const visit = await visitsCollection.findOne({ id: req.params.id });
      
      if (!visit) {
        return res.status(404).json({ 
          ok: false, 
          error: 'Visit not found' 
        });
      }

      return res.json({ 
        ok: true, 
        visit 
      });
    } catch (error) {
      console.error('Get visit error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to fetch visit' 
      });
    }
  });

  router.put('/:id', authenticateToken, async (req, res) => {
    try {
      const { id } = req.params;
      const { status, notes, completedAt } = req.body;
      
      const updateData = {};
      if (status) updateData.status = status;
      if (notes) updateData.notes = notes;
      if (completedAt) updateData.completedAt = completedAt;

      const result = await visitsCollection.updateOne(
        { id },
        { $set: updateData }
      );

      if (result.matchedCount === 0) {
        return res.status(404).json({ 
          ok: false, 
          error: 'Visit not found' 
        });
      }

      return res.json({ 
        ok: true, 
        message: 'Visit updated successfully' 
      });
    } catch (error) {
      console.error('Update visit error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to update visit' 
      });
    }
  });

  return router;
}
