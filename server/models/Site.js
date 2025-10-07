export class Site {
  constructor(data) {
    this.id = data.id;
    this.name = data.name;
    this.location = data.location || '';
    this.lat = data.lat;
    this.lng = data.lng;
    this.description = data.description || '';
    this.createdAt = data.createdAt || new Date();
    this.updatedAt = data.updatedAt || new Date();
  }

  static validate(data) {
    const errors = [];
    
    if (!data.id || data.id.trim().length === 0) {
      errors.push('Site ID is required');
    }
    
    if (!data.name || data.name.trim().length === 0) {
      errors.push('Site name is required');
    }
    
    if (data.lat === undefined || data.lng === undefined) {
      errors.push('Latitude and longitude are required');
    }
    
    return errors;
  }

  toJSON() {
    return {
      id: this.id,
      name: this.name,
      location: this.location,
      lat: this.lat,
      lng: this.lng,
      description: this.description,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt
    };
  }
}
