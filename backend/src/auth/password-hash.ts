import { randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';

const SCRYPT_COST = 1 << 15;
const SCRYPT_BLOCK_SIZE = 8;
const SCRYPT_PARALLELIZATION = 1;
const SCRYPT_KEY_LENGTH = 64;

function deriveScrypt(password: string, salt: Buffer, keyLength: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    scryptCallback(password, salt, keyLength, {
      N: SCRYPT_COST,
      r: SCRYPT_BLOCK_SIZE,
      p: SCRYPT_PARALLELIZATION,
      maxmem: 64 * 1024 * 1024,
    }, (error, derived) => {
      if (error) reject(error);
      else resolve(derived);
    });
  });
}

export async function hashAccountPassword(password: string): Promise<string> {
  const salt = randomBytes(16);
  const derived = await deriveScrypt(password, salt, SCRYPT_KEY_LENGTH);
  return `scrypt$${SCRYPT_COST}$${SCRYPT_BLOCK_SIZE}$${SCRYPT_PARALLELIZATION}$${salt.toString('base64url')}$${derived.toString('base64url')}`;
}

export async function verifyAccountPassword(password: string, encoded: string): Promise<boolean> {
  const [algorithm, cost, blockSize, parallelization, saltText, hashText] = encoded.split('$');
  if (
    algorithm !== 'scrypt' ||
    Number(cost) !== SCRYPT_COST ||
    Number(blockSize) !== SCRYPT_BLOCK_SIZE ||
    Number(parallelization) !== SCRYPT_PARALLELIZATION ||
    !saltText || !hashText
  ) return false;

  const salt = Buffer.from(saltText, 'base64url');
  const expected = Buffer.from(hashText, 'base64url');
  const actual = await deriveScrypt(password, salt, expected.length);
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}
