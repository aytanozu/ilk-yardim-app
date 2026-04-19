/**
 * Dev seed — quizzes, training items, sample emergencies.
 * Requires GOOGLE_APPLICATION_CREDENTIALS pointing to a service account JSON.
 *
 * Run with:
 *   cd firebase/functions
 *   npx ts-node ../seed/seed_dev.ts
 */
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

async function seedQuizzes() {
  const quizRef = db.collection('quizzes').doc('basic_life_support');
  await quizRef.set({
    title: 'Temel Yaşam Desteği',
    categoryId: 'basic',
    questionCount: 3,
  });
  const qs = [
    {
      text: 'Bilinci kapalı bir yetişkinde solunum kontrolü kaç saniye süreyle yapılmalıdır?',
      options: ['5 saniye', '10 saniye', '15 saniye', '20 saniye'],
      correctIndex: 1,
      order: 0,
    },
    {
      text: 'Yetişkin bir hastada göğüs kompresyonları dakikada kaç sıklıkta yapılmalıdır?',
      options: ['60-80', '80-100', '100-120', '120-140'],
      correctIndex: 2,
      order: 1,
    },
    {
      text: 'Kalp masajı derinliği yetişkinde kaç cm olmalıdır?',
      options: ['2-3 cm', '3-4 cm', '5-6 cm', '7-8 cm'],
      correctIndex: 2,
      order: 2,
    },
  ];
  for (const q of qs) {
    await quizRef.collection('questions').add(q);
  }
}

async function seedTraining() {
  const items = [
    {
      title: 'Heimlich Manevrası Nasıl Yapılır?',
      description: 'Boğulma durumlarında uygulanan temel ilk yardım tekniği.',
      category: 'basic',
      type: 'video',
      durationSeconds: 225,
      viewCount: 12000,
      featured: true,
    },
    {
      title: 'Kalp Masajı (CPR)',
      description: 'Yetişkin hastada göğüs kompresyonu tekniği.',
      category: 'cardio',
      type: 'video',
      durationSeconds: 130,
      viewCount: 8000,
    },
    {
      title: 'Kanama Kontrolü',
      description: 'Dış kanamaları durdurma teknikleri.',
      category: 'injuries',
      type: 'video',
      durationSeconds: 260,
      viewCount: 5400,
    },
  ];
  for (const i of items) {
    await db.collection('training_items').add(i);
  }
}

async function main() {
  console.log('Seeding...');
  await seedQuizzes();
  await seedTraining();
  console.log('Done.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
