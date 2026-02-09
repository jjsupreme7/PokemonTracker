'use client';

import { useRef } from 'react';
import { ScanIcon } from '@/components/icons';

interface CameraCaptureProps {
  onCapture: (base64: string, mimeType: string) => void;
  isProcessing: boolean;
}

function resizeImage(file: File, maxSize: number): Promise<{ base64: string; mimeType: string }> {
  return new Promise((resolve, reject) => {
    const img = new window.Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');
      const scale = Math.min(maxSize / img.width, maxSize / img.height, 1);
      canvas.width = img.width * scale;
      canvas.height = img.height * scale;
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        reject(new Error('Could not get canvas context'));
        return;
      }
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      const dataUrl = canvas.toDataURL('image/jpeg', 0.85);
      const base64 = dataUrl.split(',')[1];
      resolve({ base64, mimeType: 'image/jpeg' });
    };
    img.onerror = () => reject(new Error('Failed to load image'));
    img.src = URL.createObjectURL(file);
  });
}

export function CameraCapture({ onCapture, isProcessing }: CameraCaptureProps) {
  const cameraRef = useRef<HTMLInputElement>(null);
  const uploadRef = useRef<HTMLInputElement>(null);

  const handleFile = async (file: File) => {
    try {
      const { base64, mimeType } = await resizeImage(file, 1024);
      onCapture(base64, mimeType);
    } catch (error) {
      console.error('Image processing error:', error);
    }
  };

  return (
    <div className="space-y-4">
      {/* Scanner Area */}
      <div className="relative aspect-[2.5/3.5] max-w-[280px] mx-auto">
        <div className="absolute inset-0 border-2 border-dashed border-accent-red/40 rounded-2xl flex flex-col items-center justify-center gap-4">
          <div className="w-16 h-16 rounded-full bg-accent-red/10 flex items-center justify-center">
            <ScanIcon className="w-8 h-8 text-accent-red" />
          </div>
          <p className="text-text-secondary text-sm text-center px-4">
            Take a photo or upload an image of your Pokemon card
          </p>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex gap-3">
        <button
          onClick={() => cameraRef.current?.click()}
          disabled={isProcessing}
          className="flex-1 flex items-center justify-center gap-2 py-3 bg-accent-red text-white font-semibold rounded-xl btn-pokeball disabled:opacity-50"
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M6.827 6.175A2.31 2.31 0 0 1 5.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 0 0-1.134-.175 2.31 2.31 0 0 1-1.64-1.055l-.822-1.316a2.192 2.192 0 0 0-1.736-1.039 48.774 48.774 0 0 0-5.232 0 2.192 2.192 0 0 0-1.736 1.039l-.821 1.316Z" />
            <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 12.75a4.5 4.5 0 1 1-9 0 4.5 4.5 0 0 1 9 0Z" />
          </svg>
          Take Photo
        </button>
        <button
          onClick={() => uploadRef.current?.click()}
          disabled={isProcessing}
          className="flex-1 flex items-center justify-center gap-2 py-3 bg-bg-surface border border-border-subtle text-text-primary font-semibold rounded-xl transition-colors hover:bg-bg-surface-hover disabled:opacity-50"
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75V16.5m-13.5-9L12 3m0 0 4.5 4.5M12 3v13.5" />
          </svg>
          Upload
        </button>
      </div>

      {/* Hidden file inputs */}
      <input
        ref={cameraRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) handleFile(file);
          e.target.value = '';
        }}
      />
      <input
        ref={uploadRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) handleFile(file);
          e.target.value = '';
        }}
      />
    </div>
  );
}
