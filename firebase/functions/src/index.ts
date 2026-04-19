import * as admin from 'firebase-admin';

admin.initializeApp();

export * from './auth';
export * from './emergency';
export * from './admin';
