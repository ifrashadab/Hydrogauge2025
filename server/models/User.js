import bcrypt from 'bcryptjs';

export class User {
  constructor(data) {
    this.username = data.username;
    this.password = data.password;
    this.name = data.name || '';
    this.phone = data.phone || '';
    this.role = data.role || 'Employee';
    this.createdAt = data.createdAt || new Date();
  }

  static async hashPassword(password) {
    return await bcrypt.hash(password, 10);
  }

  static async comparePassword(password, hash) {
    return await bcrypt.compare(password, hash);
  }

  static validate(data) {
    const errors = [];
    
    if (!data.username || data.username.trim().length < 3) {
      errors.push('Username must be at least 3 characters');
    }
    
    if (!data.password || data.password.length < 6) {
      errors.push('Password must be at least 6 characters');
    }
    
    const validRoles = ['Supervisor', 'Analyst', 'Employee'];
    if (data.role && !validRoles.includes(data.role)) {
      errors.push('Invalid role. Must be Supervisor, Analyst, or Employee');
    }
    
    return errors;
  }

  toJSON() {
    return {
      username: this.username,
      name: this.name,
      phone: this.phone,
      role: this.role,
      createdAt: this.createdAt
    };
  }
}
