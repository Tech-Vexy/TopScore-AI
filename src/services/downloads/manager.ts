import * as FileSystem from 'expo-file-system';
import { shareAsync } from 'expo-sharing';
import { Resource, DownloadTask, LocalFile } from '../../types';
import AsyncStorage from '@react-native-async-storage/async-storage';

const DOWNLOAD_DIR = ((FileSystem as any).documentDirectory || (FileSystem as any).cacheDirectory) + 'ElimuPamoja/';
const DOWNLOADS_STORAGE_KEY = 'elimu_downloads';

export const ensureDownloadDirectory = async () => {
  const dirInfo = await FileSystem.getInfoAsync(DOWNLOAD_DIR);
  if (!dirInfo.exists) {
    await FileSystem.makeDirectoryAsync(DOWNLOAD_DIR, { intermediates: true });
  }
};

export const downloadResource = async (
  resource: Resource,
  onProgress: (progress: number) => void
): Promise<string> => {
  await ensureDownloadDirectory();
  const filename = `${resource.title.replace(/[^a-z0-9]/gi, '_')}.${resource.downloadUrl.split('.').pop()}`;
  const fileUri = DOWNLOAD_DIR + filename;

  const downloadResumable = FileSystem.createDownloadResumable(
    resource.downloadUrl,
    fileUri,
    {},
    (downloadProgress) => {
      const progress = downloadProgress.totalBytesWritten / downloadProgress.totalBytesExpectedToWrite;
      onProgress(progress);
    }
  );

  try {
    const result = await downloadResumable.downloadAsync();
    if (result && result.uri) {
      await saveDownloadRecord({
        id: resource.id, // Using resource ID as file ID for simplicity
        resourceId: resource.id,
        localPath: result.uri,
        downloadedAt: Date.now(),
        filename: filename
      });
      return result.uri;
    } else {
      throw new Error('Download failed');
    }
  } catch (e) {
    console.error(e);
    throw e;
  }
};

const saveDownloadRecord = async (file: LocalFile) => {
  const existing = await listDownloads();
  const updated = [...existing.filter(f => f.id !== file.id), file];
  await AsyncStorage.setItem(DOWNLOADS_STORAGE_KEY, JSON.stringify(updated));
};

export const listDownloads = async (): Promise<LocalFile[]> => {
  const json = await AsyncStorage.getItem(DOWNLOADS_STORAGE_KEY);
  return json ? JSON.parse(json) : [];
};

export const deleteDownload = async (fileId: string) => {
  const downloads = await listDownloads();
  const file = downloads.find(f => f.id === fileId);
  if (file) {
    await FileSystem.deleteAsync(file.localPath, { idempotent: true });
    const updated = downloads.filter(f => f.id !== fileId);
    await AsyncStorage.setItem(DOWNLOADS_STORAGE_KEY, JSON.stringify(updated));
  }
};

export const openDownload = async (fileId: string) => {
  const downloads = await listDownloads();
  const file = downloads.find(f => f.id === fileId);
  if (file) {
    if (await FileSystem.getInfoAsync(file.localPath).then(i => i.exists)) {
        await shareAsync(file.localPath);
    } else {
        throw new Error('File not found locally');
    }
  }
};
