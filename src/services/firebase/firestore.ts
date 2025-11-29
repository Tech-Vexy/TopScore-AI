import { db } from './config';
import { collection, query, where, getDocs, doc, getDoc, addDoc, updateDoc } from 'firebase/firestore';

export const getResources = async (grade: number, subject?: string) => {
  let q = query(collection(db, 'resources'), where('grade', '==', grade));
  if (subject) {
    q = query(q, where('subject', '==', subject));
  }
  const querySnapshot = await getDocs(q);
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};

export const getStudentProgress = async (uid: string) => {
  const q = query(collection(db, `progress/${uid}/resources`));
  const querySnapshot = await getDocs(q);
  return querySnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
};
