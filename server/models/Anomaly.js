export class Anomaly {
  constructor(data) {
    this.id = data.id;
    this.siteId = data.siteId;
    this.submissionId = data.submissionId;
    this.zScore = data.zScore;
    this.risk = data.risk;
    this.detectedAt = data.detectedAt || new Date();
    this.acknowledged = data.acknowledged || false;
    this.acknowledgedBy = data.acknowledgedBy || null;
  }

  static calculateRisk(zScore) {
    const absZ = Math.abs(zScore);
    if (absZ >= 3) return 'high';
    if (absZ >= 2) return 'med';
    return 'low';
  }

  toJSON() {
    return {
      id: this.id,
      siteId: this.siteId,
      submissionId: this.submissionId,
      zScore: this.zScore,
      risk: this.risk,
      detectedAt: this.detectedAt,
      acknowledged: this.acknowledged,
      acknowledgedBy: this.acknowledgedBy
    };
  }
}
