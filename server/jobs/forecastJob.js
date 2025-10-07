import 'dotenv/config';
import { MongoClient } from 'mongodb';

const uri = process.env.MONGODB_URI;
const dbName = process.env.DB_NAME || 'hydrogauge';
const colName = process.env.COLLECTION || 'submissions';
const forecastsCol = process.env.FORECASTS_COLLECTION || 'forecasts';
const alpha = Number(process.env.FORECAST_ALPHA || 0.3);
const horizon = Number(process.env.FORECAST_HOURS || 12);

if (!uri) {
  console.error('Missing MONGODB_URI');
  process.exit(1);
}

async function computeForecastForSite(db, siteId) {
  const col = db.collection(colName);
  const docs = await col.find({ siteId }).sort({ capturedAt: 1 }).limit(100).toArray();
  if (!docs.length) return;
  const levels = docs.map((d) => Number(d.waterLevelMeters));
  let s = levels[0] ?? 0;
  for (let i = 1; i < levels.length; i++) s = alpha * levels[i] + (1 - alpha) * s;
  const points = Array.from({ length: horizon }, (_, i) => ({ t: i, y: s }));
  await db.collection(forecastsCol).updateOne(
    { siteId },
    { $set: { siteId, points, createdAt: new Date() } },
    { upsert: true }
  );
  console.log(`Forecast saved for ${siteId}`);
}

async function main() {
  const client = new MongoClient(uri);
  await client.connect();
  const db = client.db(dbName);
  const siteIds = await db.collection(colName).distinct('siteId');
  for (const id of siteIds) {
    await computeForecastForSite(db, id);
  }
  await client.close();
  console.log('Forecast batch complete ✅');
}

main().catch((e) => {
  console.error('Forecast job failed', e);
  process.exit(1);
});


