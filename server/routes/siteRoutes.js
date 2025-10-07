import express from 'express';
import { authenticateToken, authorizeRoles } from '../middleware/authMiddleware.js';
import { Site } from '../models/Site.js';

const router = express.Router();

export function createSiteRoutes(db) {
  const sitesCollection = db.collection('sites');

  router.get('/', authenticateToken, async (req, res) => {
    try {
      const sites = await sitesCollection.find({}).sort({ name: 1 }).toArray();
      return res.json({ 
        ok: true, 
        sites 
      });
    } catch (error) {
      console.error('Get sites error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to fetch sites' 
      });
    }
  });

  router.get('/:id', authenticateToken, async (req, res) => {
    try {
      const site = await sitesCollection.findOne({ id: req.params.id });
      
      if (!site) {
        return res.status(404).json({ 
          ok: false, 
          error: 'Site not found' 
        });
      }

      return res.json({ 
        ok: true, 
        site 
      });
    } catch (error) {
      console.error('Get site error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to fetch site' 
      });
    }
  });

  router.post('/', authenticateToken, authorizeRoles('Supervisor', 'Analyst'), async (req, res) => {
    try {
      const validationErrors = Site.validate(req.body);
      if (validationErrors.length > 0) {
        return res.status(400).json({ 
          ok: false, 
          error: validationErrors.join(', ') 
        });
      }

      const site = new Site(req.body);
      await sitesCollection.insertOne(site.toJSON());

      return res.status(201).json({ 
        ok: true, 
        message: 'Site created successfully',
        site: site.toJSON() 
      });
    } catch (error) {
      console.error('Create site error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to create site' 
      });
    }
  });

  router.put('/:id', authenticateToken, authorizeRoles('Supervisor', 'Analyst'), async (req, res) => {
    try {
      const { id } = req.params;
      const updateData = { ...req.body, updatedAt: new Date() };
      
      const result = await sitesCollection.updateOne(
        { id },
        { $set: updateData }
      );

      if (result.matchedCount === 0) {
        return res.status(404).json({ 
          ok: false, 
          error: 'Site not found' 
        });
      }

      return res.json({ 
        ok: true, 
        message: 'Site updated successfully' 
      });
    } catch (error) {
      console.error('Update site error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to update site' 
      });
    }
  });

  router.delete('/:id', authenticateToken, authorizeRoles('Supervisor'), async (req, res) => {
    try {
      const { id } = req.params;
      
      const result = await sitesCollection.deleteOne({ id });

      if (result.deletedCount === 0) {
        return res.status(404).json({ 
          ok: false, 
          error: 'Site not found' 
        });
      }

      return res.json({ 
        ok: true, 
        message: 'Site deleted successfully' 
      });
    } catch (error) {
      console.error('Delete site error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to delete site' 
      });
    }
  });

  return router;
}
