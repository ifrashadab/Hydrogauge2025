import express from 'express';
import { authenticateToken } from '../middleware/authMiddleware.js';
import { User } from '../models/User.js';

const router = express.Router();

export function createUserRoutes(db) {
  const usersCollection = db.collection('users');

  router.get('/profile', authenticateToken, async (req, res) => {
    try {
      const userDoc = await usersCollection.findOne({ username: req.user.username });
      
      if (!userDoc) {
        return res.status(404).json({ 
          ok: false, 
          error: 'User not found' 
        });
      }

      const user = new User(userDoc);
      return res.json({ 
        ok: true, 
        user: user.toJSON() 
      });
    } catch (error) {
      console.error('Get profile error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to fetch profile' 
      });
    }
  });

  router.put('/profile', authenticateToken, async (req, res) => {
    try {
      const { name, phone } = req.body;
      const updateData = {};
      
      if (name !== undefined) updateData.name = name;
      if (phone !== undefined) updateData.phone = phone;

      const result = await usersCollection.updateOne(
        { username: req.user.username },
        { $set: updateData }
      );

      if (result.matchedCount === 0) {
        return res.status(404).json({ 
          ok: false, 
          error: 'User not found' 
        });
      }

      return res.json({ 
        ok: true, 
        message: 'Profile updated successfully' 
      });
    } catch (error) {
      console.error('Update profile error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to update profile' 
      });
    }
  });

  router.put('/profile/password', authenticateToken, async (req, res) => {
    try {
      const { currentPassword, newPassword } = req.body;

      if (!currentPassword || !newPassword) {
        return res.status(400).json({ 
          ok: false, 
          error: 'Current and new password are required' 
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({ 
          ok: false, 
          error: 'New password must be at least 6 characters' 
        });
      }

      const userDoc = await usersCollection.findOne({ username: req.user.username });
      
      if (!userDoc) {
        return res.status(404).json({ 
          ok: false, 
          error: 'User not found' 
        });
      }

      const isValid = await User.comparePassword(currentPassword, userDoc.password);
      if (!isValid) {
        return res.status(401).json({ 
          ok: false, 
          error: 'Current password is incorrect' 
        });
      }

      const hashedPassword = await User.hashPassword(newPassword);
      
      await usersCollection.updateOne(
        { username: req.user.username },
        { $set: { password: hashedPassword } }
      );

      return res.json({ 
        ok: true, 
        message: 'Password updated successfully' 
      });
    } catch (error) {
      console.error('Update password error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Failed to update password' 
      });
    }
  });

  return router;
}
