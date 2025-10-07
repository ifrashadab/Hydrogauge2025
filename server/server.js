import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { MongoClient } from 'mongodb';
import { createAuthRoutes } from './routes/authRoutes.js';
import { createSubmissionRoutes } from './routes/submissionRoutes.js';
import { createForecastRoutes } from './routes/forecastRoutes.js';
import { createAnomalyRoutes } from './routes/anomalyRoutes.js';
import { createSiteRoutes } from './routes/siteRoutes.js';
import { createVisitRoutes } from './routes/visitRoutes.js';
import { createUserRoutes } from './routes/userRoutes.js';

const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));

const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || 'hydrogauge';
const QR_SECRET = process.env.QR_SECRET || 'supersecret123';
const PORT = process.env.PORT || 8080;

if (!MONGODB_URI) {
  console.error('❌ Missing MONGODB_URI in environment variables');
  process.exit(1);
}

const client = new MongoClient(MONGODB_URI, { 
  serverSelectionTimeoutMS: 20000 
});

async function initDb() {
  try {
    await client.connect();
    console.log('✅ MongoDB connected successfully');
    
    const db = client.db(DB_NAME);
    
    await db.collection('submissions').createIndex({ id: 1 }, { unique: true });
    await db.collection('users').createIndex({ username: 1 }, { unique: true });
    await db.collection('sites').createIndex({ id: 1 }, { unique: true });
    await db.collection('visits').createIndex({ id: 1 }, { unique: true });
    
    console.log('✅ Database indexes created');
    
    return db;
  } catch (error) {
    console.error('❌ Failed to connect to MongoDB:', error);
    process.exit(1);
  }
}

initDb().then((db) => {
  app.get('/health', (_req, res) => res.json({ ok: true, status: 'healthy' }));
  app.get('/', (_req, res) => res.send('HydroGauge Backend API ✅'));
  app.get('/api/ping', (_req, res) => res.json({ ok: true, message: 'Server is running' }));

  app.use('/auth', createAuthRoutes(db));
  app.use('/submissions', createSubmissionRoutes(db, QR_SECRET));
  app.use('/sites', createSiteRoutes(db));
  app.use('/sites', createForecastRoutes(db));
  app.use('/sites', createAnomalyRoutes(db));
  app.use('/visits', createVisitRoutes(db));
  app.use('/users', createUserRoutes(db));

  app.use((err, req, res, next) => {
    console.error('Server error:', err);
    res.status(500).json({ 
      ok: false, 
      error: 'Internal server error' 
    });
  });

  app.listen(PORT, 'localhost', () => {
    console.log(`🚀 HydroGauge API server listening on http://localhost:${PORT}`);
    console.log(`📊 Database: ${DB_NAME}`);
    console.log(`🔐 Environment: ${process.env.NODE_ENV || 'development'}`);
  });
}).catch((error) => {
  console.error('❌ Failed to initialize server:', error);
  process.exit(1);
});
