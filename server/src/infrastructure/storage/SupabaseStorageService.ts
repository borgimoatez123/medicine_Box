import type { IStorageService, UploadResult } from '@domain/repositories/IStorageService';
import { supabase, supabaseUrl } from '@infrastructure/database/supabase/client';
import { InternalServerError } from '@shared/errors/AppError';

export class SupabaseStorageService implements IStorageService {
  async upload(
    bucket: string,
    path: string,
    buffer: Buffer,
    contentType: string,
  ): Promise<UploadResult> {
    const { data, error } = await supabase.storage
      .from(bucket)
      .upload(path, buffer, { contentType, upsert: false });

    if (error || !data) {
      throw new InternalServerError(
        `Storage upload failed: ${error?.message ?? 'unknown error'}`,
      );
    }

    const publicUrl = this.getPublicUrl(bucket, data.path);
    return { path: data.path, publicUrl };
  }

  async delete(bucket: string, path: string): Promise<void> {
    const { error } = await supabase.storage.from(bucket).remove([path]);
    if (error) {
      throw new InternalServerError(
        `Storage delete failed: ${error.message}`,
      );
    }
  }

  getPublicUrl(bucket: string, path: string): string {
    const { data } = supabase.storage.from(bucket).getPublicUrl(path);
    return data.publicUrl;
  }

  extractPathFromPublicUrl(bucket: string, publicUrl: string): string | null {
    if (!publicUrl) return null;
    const base = supabaseUrl().replace(/\/$/, '');
    const prefix = `${base}/storage/v1/object/public/${bucket}/`;
    if (!publicUrl.startsWith(prefix)) return null;
    const path = publicUrl.slice(prefix.length);
    return path.length > 0 ? path : null;
  }
}
