import express from 'express';
import { User } from '../models/User.js';
import { generateToken } from '../middleware/authMiddleware.js';

const router = express.Router();

export function createAuthRoutes(db) {
  const usersCollection = db.collection('users');

  router.post('/register', async (req, res) => {
    try {
      const { username, password, name, phone, role } = req.body;
      
      const validationErrors = User.validate({ username, password, role });
      if (validationErrors.length > 0) {
        return res.status(400).json({ 
          ok: false, 
          error: validationErrors.join(', ') 
        });
      }

      const existingUser = await usersCollection.findOne({ username });
      if (existingUser) {
        return res.status(400).json({ 
          ok: false, 
          error: 'Username already exists' 
        });
      }

      const hashedPassword = await User.hashPassword(password);
      const user = new User({
        username,
        password: hashedPassword,
        name: name || '',
        phone: phone || '',
        role: role || 'Employee'
      });

      await usersCollection.insertOne({
        username: user.username,
        password: user.password,
        name: user.name,
        phone: user.phone,
        role: user.role,
        createdAt: user.createdAt
      });

      const token = generateToken(user);
      
      return res.status(201).json({ 
        ok: true, 
        message: 'User registered successfully',
        token,
        user: user.toJSON()
      });
    } catch (error) {
      console.error('Register error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Server error during registration' 
      });
    }
  });

  router.post('/login', async (req, res) => {
    try {
      const { username, password } = req.body;

      if (!username || !password) {
        return res.status(400).json({ 
          ok: false, 
          error: 'Username and password are required' 
        });
      }

      const userDoc = await usersCollection.findOne({ username });
      if (!userDoc) {
        return res.status(401).json({ 
          ok: false, 
          error: 'Invalid username or password' 
        });
      }

      const isValid = await User.comparePassword(password, userDoc.password);
      if (!isValid) {
        return res.status(401).json({ 
          ok: false, 
          error: 'Invalid username or password' 
        });
      }

      const user = new User(userDoc);
      const token = generateToken(user);

      return res.json({ 
        ok: true, 
        message: 'Login successful',
        token,
        user: user.toJSON()
      });
    } catch (error) {
      console.error('Login error:', error);
      return res.status(500).json({ 
        ok: false, 
        error: 'Server error during login' 
      });
    }
  });

  return router;
}
