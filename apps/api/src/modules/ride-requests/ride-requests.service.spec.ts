import { ConflictException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createHash } from 'node:crypto';
import { RideRequestsService } from './ride-requests.service.js';

const customerId = '00000000-0000-4000-8000-000000000001';
const rideId = '00000000-0000-4000-8000-000000000010';
const params = {
  customerId,
  serviceAreaId: '00000000-0000-4000-8000-000000000002',
  vehicleTypeId: '00000000-0000-4000-8000-000000000003',
  pickupLat: 15.35, pickupLon: 44.20, destLat: 15.40, destLon: 44.25,
  idempotencyKey: 'request-1',
};
const hash = () => createHash('sha256').update(JSON.stringify({
  serviceAreaId: params.serviceAreaId,
  vehicleTypeId: params.vehicleTypeId,
  pickupLat: params.pickupLat,
  pickupLon: params.pickupLon,
  destLat: params.destLat,
  destLon: params.destLon,
})).digest('hex');

describe('RideRequestsService.create', () => {
  const tx = {
    $queryRaw: vi.fn(),
    idempotencyKeys: { findUnique: vi.fn(), create: vi.fn() },
    rides: { findFirst: vi.fn(), findUnique: vi.fn() },
  };
  const prisma = { tx: vi.fn((fn: (arg: typeof tx) => unknown) => fn(tx)) };
  const pricing = { quote: vi.fn() };
  let service: RideRequestsService;

  beforeEach(() => {
    vi.clearAllMocks();
    tx.$queryRaw.mockReset();
    service = new RideRequestsService(prisma as any, pricing as any);
    tx.idempotencyKeys.findUnique.mockResolvedValue(null);
    tx.rides.findFirst.mockResolvedValue(null);
    tx.$queryRaw.mockResolvedValueOnce([{ id: customerId }]).mockResolvedValueOnce([{ id: rideId }]);
    pricing.quote.mockResolvedValue({
      currency: 'YER', ruleId: 'rule-1', ruleVersion: 1, totalMinor: 100000,
      distanceMeters: 5000, durationSeconds: 600,
    });
    tx.rides.findUnique.mockResolvedValue({ id: rideId, status: 'SEARCHING' });
    tx.idempotencyKeys.create.mockResolvedValue({});
  });

  it('replays the same key and request without repricing or inserting another ride', async () => {
    tx.idempotencyKeys.findUnique.mockResolvedValue({ requestHash: hash(), resourceId: rideId });
    const result = await service.create(params);
    expect(result).toEqual({ replayed: true, resourceId: rideId });
    expect(pricing.quote).not.toHaveBeenCalled();
    expect(tx.$queryRaw).toHaveBeenCalledTimes(1); // only customer row lock
    expect(tx.rides.findUnique).not.toHaveBeenCalled();
  });

  it('rejects reusing an idempotency key for a different payload', async () => {
    tx.idempotencyKeys.findUnique.mockResolvedValue({ requestHash: 'different-hash', resourceId: rideId });
    await expect(service.create(params)).rejects.toBeInstanceOf(ConflictException);
    expect(pricing.quote).not.toHaveBeenCalled();
    expect(tx.idempotencyKeys.create).not.toHaveBeenCalled();
  });

  it('creates the ride and idempotency record in one transaction with the exact inserted id', async () => {
    const result = await service.create(params);
    expect(result).toEqual({ replayed: false, ride: { id: rideId, status: 'SEARCHING' } });
    expect(prisma.tx).toHaveBeenCalledTimes(1);
    expect(tx.$queryRaw).toHaveBeenCalledTimes(2);
    expect(tx.rides.findUnique).toHaveBeenCalledWith({ where: { id: rideId } });
    expect(tx.idempotencyKeys.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ requestHash: hash(), resourceId: rideId, state: 'COMPLETED' }),
    }));
  });
});
