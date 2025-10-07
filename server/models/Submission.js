export class Submission {
  constructor(data) {
    this.id = data.id;
    this.siteId = data.siteId;
    this.siteName = data.siteName;
    this.waterLevelMeters = data.waterLevelMeters;
    this.lat = data.lat;
    this.lng = data.lng;
    this.capturedAt = data.capturedAt;
    this.imageUrl = data.imageUrl;
    this.deviceId = data.deviceId || 'unknown';
    this.status = data.status || 'synced';
    this.createdAt = data.createdAt || new Date();
    this.userId = data.userId || null;
  }

  static validate(data) {
    const required = ['id', 'siteId', 'siteName', 'waterLevelMeters', 'lat', 'lng', 'capturedAt', 'imageUrl'];
    const missing = required.filter(field => data[field] === undefined || data[field] === null);
    
    if (missing.length > 0) {
      return [`Missing required fields: ${missing.join(', ')}`];
    }
    
    return [];
  }

  toJSON() {
    return {
      id: this.id,
      siteId: this.siteId,
      siteName: this.siteName,
      waterLevelMeters: this.waterLevelMeters,
      lat: this.lat,
      lng: this.lng,
      capturedAt: this.capturedAt,
      imageUrl: this.imageUrl,
      deviceId: this.deviceId,
      status: this.status,
      createdAt: this.createdAt,
      userId: this.userId
    };
  }
}
