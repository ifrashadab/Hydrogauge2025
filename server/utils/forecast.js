export function exponentialSmoothing(levels, alpha = 0.3) {
  if (!levels || levels.length === 0) return 0;
  
  let s = levels[0];
  for (let i = 1; i < levels.length; i++) {
    s = alpha * levels[i] + (1 - alpha) * s;
  }
  
  return s;
}

export function generateForecast(smoothedValue, horizon = 12) {
  return Array.from({ length: horizon }, (_, i) => ({
    t: i,
    y: smoothedValue
  }));
}
