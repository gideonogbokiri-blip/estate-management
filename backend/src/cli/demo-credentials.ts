/** Demo-only credentials. Never used in production code paths. */
export const DEMO_PASSWORD = 'lancon123';
export const DEMO_EMAIL_DOMAIN = 'testlancon.com';

/** Derive a short estate prefix, e.g. "Palm Crest Residences" -> "pc". */
export function estateInitials(estateName: string): string {
  const cleaned = estateName.replace(/\([^)]*\)/g, ' ').trim();
  const words = cleaned.split(/[\s,.-]+/).filter(Boolean).slice(0, 2);
  const initials = words.map((word) => word[0]?.toLowerCase() ?? '').join('');
  return initials.replace(/[^a-z0-9]/g, '') || 'est';
}

export const DEMO_ESTATE_NAME = process.env.DEMO_ESTATE_NAME ?? 'Palm Crest Residences';
export const DEMO_ESTATE_PREFIX = estateInitials(DEMO_ESTATE_NAME);

export function demoEmail(prefix: string, role = '') {
  return `${prefix}${role}@${DEMO_EMAIL_DOMAIN}`;
}

/** Roles share the estate prefix; the primary manager keeps the plain address. */
export function demoEmails(prefix: string) {
  return {
    manager: demoEmail(prefix),
    approver: demoEmail(prefix, 'a'),
    resident: demoEmail(prefix, 'r'),
    landlord: demoEmail(prefix, 'l'),
    security: demoEmail(prefix, 's'),
    applicant: demoEmail(prefix, 'p'),
    platform: 'sa@testlancon.com',
  };
}
