import { ConflictException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { DispatchService } from './dispatch.service.js';

const driverId = '00000000-0000-4000-8000-000000000011';
const rideId = '00000000-0000-4000-8000-000000000021';
const offerId = '00000000-0000-4000-8000-000000000031';
const vehicleId = '00000000-0000-4000-8000-000000000041';

describe('DispatchService.acceptOffer', () => {
  const tx = {
    $queryRaw: vi.fn(),
    dispatchSettings: { findUnique: vi.fn() },
    rideOffers: { update: vi.fn(), updateMany: vi.fn() },
    rideEvents: { create: vi.fn() },
  };
  const prisma = { tx: vi.fn((fn: (arg: typeof tx) => unknown) => fn(tx)) };
  let service: DispatchService;

  const setup = () => {
    tx.$queryRaw
      .mockResolvedValueOnce([{ ride_id: rideId }])
      .mockResolvedValueOnce([{
        id: rideId, status: 'SEARCHING', driver_id: null,
        service_area_id: 'area-1', vehicle_type_id: 'type-1',
      }])
      .mockResolvedValueOnce([{
        id: offerId, ride_id: rideId, driver_id: driverId, status: 'PENDING',
        expires_at: new Date(Date.now() + 60_000),
      }])
      .mockResolvedValueOnce([{
        verification_status: 'APPROVED', is_online: true,
        service_area_id: 'area-1', status: 'ACTIVE',
      }])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ id: vehicleId }])
      .mockResolvedValueOnce([{ id: rideId, status: 'ASSIGNED', driver_id: driverId }]);
    tx.dispatchSettings.findUnique.mockResolvedValue({ startCodeTtlMinutes: 15 });
    tx.rideOffers.update.mockResolvedValue({});
    tx.rideOffers.updateMany.mockResolvedValue({ count: 1 });
    tx.rideEvents.create.mockResolvedValue({});
  };

  beforeEach(() => {
    vi.clearAllMocks();
    tx.$queryRaw.mockReset();
    service = new DispatchService(prisma as any);
    setup();
  });

  it('assigns once after locking ride, offer, then driver and validates vehicle ownership', async () => {
    const result = await service.acceptOffer({ offerId, driverId, vehicleId });
    expect(result.ride.status).toBe('ASSIGNED');
    expect(tx.$queryRaw).toHaveBeenCalledTimes(7);
    expect(tx.rideOffers.update).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: offerId },
      data: expect.objectContaining({ status: 'ACCEPTED' }),
    }));
    expect(tx.rideEvents.create).toHaveBeenCalledTimes(1);
  });

  it('rejects a driver who already has an active ride before updating the offer', async () => {
    tx.$queryRaw.mockReset();
    tx.$queryRaw
      .mockResolvedValueOnce([{ ride_id: rideId }])
      .mockResolvedValueOnce([{
        id: rideId, status: 'SEARCHING', driver_id: null,
        service_area_id: 'area-1', vehicle_type_id: 'type-1',
      }])
      .mockResolvedValueOnce([{
        id: offerId, ride_id: rideId, driver_id: driverId, status: 'PENDING',
        expires_at: new Date(Date.now() + 60_000),
      }])
      .mockResolvedValueOnce([{
        verification_status: 'APPROVED', is_online: true,
        service_area_id: 'area-1', status: 'ACTIVE',
      }])
      .mockResolvedValueOnce([{ id: 'another-active-ride' }]);
    await expect(service.acceptOffer({ offerId, driverId, vehicleId })).rejects.toBeInstanceOf(ConflictException);
    expect(tx.rideOffers.update).not.toHaveBeenCalled();
    expect(tx.rideEvents.create).not.toHaveBeenCalled();
  });
});
