import { Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { dirname, resolve, sep } from 'node:path';

@Injectable()
export class PrivateDocumentsService {
  private readonly root = resolve(process.env.DOCUMENT_STORAGE_PATH ?? resolve(process.cwd(), '.private-documents'));
  private readonly blobToken = process.env.BLOB_READ_WRITE_TOKEN;
  private readonly blobOidc = process.env.BLOB_STORE_ID && process.env.VERCEL_OIDC_TOKEN
    ? { storeId: process.env.BLOB_STORE_ID, oidcToken: process.env.VERCEL_OIDC_TOKEN }
    : null;
  private readonly useBlob = Boolean(this.blobToken || this.blobOidc);

  private get blobAuth(): Record<string, string> {
    if (this.blobToken) return { token: this.blobToken };
    if (this.blobOidc) return this.blobOidc;
    return {};
  }

  async storeApplicationDocument(applicationId: string, documentId: string, extension: 'pdf' | 'jpg' | 'png', bytes: Buffer) {
    const objectKey = `applications/${applicationId}/${documentId}.${extension}`;
    return this.store(objectKey, bytes);
  }

  async storeIncidentEvidence(incidentId: string, evidenceId: string, extension: 'pdf' | 'jpg' | 'png', bytes: Buffer) {
    const objectKey = `incidents/${incidentId}/${evidenceId}.${extension}`;
    return this.store(objectKey, bytes);
  }

  async read(objectKey: string) {
    this.assertObjectKey(objectKey);
    if (this.useBlob) {
      const { get } = await import('@vercel/blob');
      try {
        const file = await get(objectKey, { access: 'private', ...this.blobAuth } as never);
        if (!file || file.statusCode !== 200) throw new NotFoundException('Document content is unavailable.');
        return Buffer.from(await new Response(file.stream).arrayBuffer());
      } catch (error) {
        if (error instanceof NotFoundException) throw error;
        throw new InternalServerErrorException('The private document could not be read.');
      }
    }
    try {
      return await readFile(this.pathFor(objectKey));
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') throw new NotFoundException('Document content is unavailable.');
      throw new InternalServerErrorException('The private document could not be read.');
    }
  }

  async remove(objectKey: string) {
    this.assertObjectKey(objectKey);
    if (this.useBlob) {
      const { del } = await import('@vercel/blob');
      await del(objectKey, { ...this.blobAuth } as never).catch(() => undefined);
      return;
    }
    await rm(this.pathFor(objectKey), { force: true }).catch(() => undefined);
  }

  private async store(objectKey: string, bytes: Buffer) {
    this.assertObjectKey(objectKey);
    if (this.useBlob) {
      const { put } = await import('@vercel/blob');
      try {
        await put(objectKey, bytes, {
          access: 'private',
          addRandomSuffix: false,
          contentType: objectKey.endsWith('.pdf') ? 'application/pdf' : objectKey.endsWith('.png') ? 'image/png' : 'image/jpeg',
          ...this.blobAuth,
        } as never);
        return objectKey;
      } catch {
        throw new InternalServerErrorException('The private document could not be stored.');
      }
    }
    const destination = this.pathFor(objectKey);
    const temporary = `${destination}.${randomUUID()}.upload`;
    try {
      await mkdir(dirname(destination), { recursive: true, mode: 0o700 });
      await writeFile(temporary, bytes, { flag: 'wx', mode: 0o600 });
      await rename(temporary, destination);
      return objectKey;
    } catch {
      await rm(temporary, { force: true }).catch(() => undefined);
      throw new InternalServerErrorException('The private document could not be stored.');
    }
  }

  private assertObjectKey(objectKey: string) {
    if (!/^(applications|incidents)\/[0-9a-f-]{36}\/[0-9a-f-]{36}\.(pdf|jpg|png)$/.test(objectKey)) {
      throw new InternalServerErrorException('Invalid private document reference.');
    }
  }

  private pathFor(objectKey: string) {
    this.assertObjectKey(objectKey);
    const destination = resolve(this.root, objectKey);
    if (!destination.startsWith(`${this.root}${sep}`)) throw new InternalServerErrorException('Invalid private document reference.');
    return destination;
  }
}
