export function calculateZScore(values) {
  if (!values || values.length < 2) {
    return { z: 0, mean: 0, sd: 0 };
  }
  
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  const variance = values.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / values.length;
  const sd = Math.sqrt(variance);
  const latest = values[values.length - 1];
  const z = sd === 0 ? 0 : (latest - mean) / sd;
  
  return { z: Number(z.toFixed(2)), mean, sd };
}

export function getRiskLevel(zScore) {
  const absZ = Math.abs(zScore);
  if (absZ >= 3) return 'high';
  if (absZ >= 2) return 'med';
  return 'low';
}
