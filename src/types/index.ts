export interface Resource {
  id: string;
  title: string;
  type: 'past_paper' | 'notes' | 'topical' | 'mock';
  subject: string;
  grade: number;
  year?: number;
  curriculum: 'KCPE' | 'KCSE' | 'CBC';
  downloadUrl: string;
  fileSize: number;
  premium: boolean;
}

export interface DownloadTask {
  id: string;
  url: string;
  filename: string;
  progress: number;
  status: 'pending' | 'downloading' | 'complete' | 'error';
  localUri?: string;
}

export interface LocalFile {
  id: string;
  resourceId: string;
  localPath: string;
  downloadedAt: number;
  filename: string;
}
