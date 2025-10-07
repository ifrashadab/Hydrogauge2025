export class Visit {
  constructor(data) {
    this.id = data.id;
    this.siteId = data.siteId;
    this.siteName = data.siteName;
    this.scheduledDate = data.scheduledDate;
    this.assignedTo = data.assignedTo || '';
    this.status = data.status || 'scheduled';
    this.notes = data.notes || '';
    this.createdBy = data.createdBy || '';
    this.createdAt = data.createdAt || new Date();
    this.completedAt = data.completedAt || null;
  }

  static validate(data) {
    const errors = [];
    
    if (!data.siteId) {
      errors.push('Site ID is required');
    }
    
    if (!data.scheduledDate) {
      errors.push('Scheduled date is required');
    }
    
    const validStatuses = ['scheduled', 'in-progress', 'completed', 'cancelled'];
    if (data.status && !validStatuses.includes(data.status)) {
      errors.push('Invalid status');
    }
    
    return errors;
  }

  toJSON() {
    return {
      id: this.id,
      siteId: this.siteId,
      siteName: this.siteName,
      scheduledDate: this.scheduledDate,
      assignedTo: this.assignedTo,
      status: this.status,
      notes: this.notes,
      createdBy: this.createdBy,
      createdAt: this.createdAt,
      completedAt: this.completedAt
    };
  }
}
