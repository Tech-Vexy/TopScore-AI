import { storage } from './config';
import { ref, getDownloadURL } from 'firebase/storage';

export const getFileUrl = async (path: string) => {
  const storageRef = ref(storage, path);
  return await getDownloadURL(storageRef);
};
