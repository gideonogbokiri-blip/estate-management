const test = require('node:test');
const assert = require('node:assert/strict');
const { PropertyLocationService } = require('../dist/src/properties/property-location.service.js');

function makeProperty(overrides = {}) {
  return {
    id: 'property-1', estateId: 'estate-1', code: 'PC-001', propertyType: 'Detached house',
    unitNumber: 'Unit 1', status: 'ACTIVE',
    latitude: null, longitude: null, locationAccuracyMeters: null, locationCaptureMethod: null,
    locationCapturedAt: null, locationVerificationStatus: 'UNVERIFIED',
    locationVerifiedAt: null, locationCorrectionReason: null,
    ...overrides,
  };
}

function fake() {
  let role = 'RESIDENT';
  let property = makeProperty();
  const prisma = {
    estateMembership: { findFirst: async ({ where }) => {
      if (where.role?.in && !where.role.in.includes(role)) return null;
      return { role };
    } },
    estateProperty: {
      findMany: async () => [property],
      findFirst: async () => property,
      update: async ({ data }) => { property = { ...property, ...data }; return property; },
    },
    auditEvent: { create: async () => ({}) },
    $queryRaw: async () => [],
    $transaction: async (callback) => callback(prisma),
  };
  return { prisma, setRole: (value) => { role = value; }, getProperty: () => property };
}

const captureInput = { latitude: 6.5244, longitude: 3.3792, accuracyMeters: 12, captureMethod: 'GPS_DEVICE' };

test('manager capture stores coordinates with pending verification', async () => {
  const { prisma, setRole, getProperty } = fake();
  setRole('ESTATE_MANAGER');
  const service = new PropertyLocationService(prisma);
  const result = await service.capture('manager-1', 'estate-1', 'property-1', captureInput);
  assert.equal(result.verificationStatus, 'pending_verification');
  assert.equal(result.latitude, '6.5244');
  assert.equal(getProperty().locationCaptureMethod, 'GPS_DEVICE');
});

test('residents cannot capture property locations', async () => {
  const { prisma } = fake();
  const service = new PropertyLocationService(prisma);
  await assert.rejects(
    service.capture('resident-1', 'estate-1', 'property-1', captureInput),
    /management access/,
  );
});

test('residents do not see unverified coordinates', async () => {
  const { prisma, setRole } = fake();
  setRole('ESTATE_MANAGER');
  const service = new PropertyLocationService(prisma);
  await service.capture('manager-1', 'estate-1', 'property-1', captureInput);
  setRole('RESIDENT');
  const list = await service.list('resident-1', 'estate-1');
  assert.equal(list.items[0].latitude, null);
  assert.equal(list.items[0].verificationStatus, 'pending_verification');
});

test('verification requires a reason on rejection', async () => {
  const { prisma, setRole } = fake();
  setRole('ESTATE_MANAGER');
  const service = new PropertyLocationService(prisma);
  await service.capture('manager-1', 'estate-1', 'property-1', captureInput);
  await assert.rejects(
    service.verify('manager-1', 'estate-1', 'property-1', { decision: 'reject' }),
    /reason is required/,
  );
  const verified = await service.verify('manager-1', 'estate-1', 'property-1', { decision: 'verify' });
  assert.equal(verified.verificationStatus, 'verified');
  setRole('RESIDENT');
  const list = await service.list('resident-1', 'estate-1');
  assert.equal(list.items[0].latitude, '6.5244');
});
