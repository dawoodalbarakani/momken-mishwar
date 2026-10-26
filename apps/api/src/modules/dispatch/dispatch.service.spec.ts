import { ConflictException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { DispatchService } from './dispatch.service.js';

const driver_id = '00000000-0000-4000-8000-000000000011';
const ride_id = '00000000-0000-4000-8000-000000000021';
const offerId = '00000000-0000-4000-8000-000000000031';
const vehicle_id = '00000000-0000-4000-8000-000000000041';

describe('DispatchService.acceptOffer', () => {
  const tx = {
    $queryRaw: vi.fn(),
    dispatch_settings: { findUnique: vi.fn() },
    ride_offers: { update: vi.fn(), updateMany: vi.fn() },
    ride_events: { create: vi.fn() },
  };
  const prisma = { tx: vi.fn((fn: (arg: typeof tx) => unknown) => fn(tx)) };
  let service: DispatchService;

  const setup = () => {
    tx.$queryRaw
      .mockResolvedValueOnce([{ ride_id: ride_id }])
      .mockResolvedValueOnce([{
        id: ride_id, status: 'SEARCHING', driver_id: null,
        service_area_id: 'area-1', vehicle_type_id: 'type-1',
      }])
      .mockResolvedValueOnce([{
        id: offerId, ride_id: ride_id, driver_id: driver_id, status: 'PENDING',
        expires_at: new Date(Date.now() + 60_000),
      }])
      .mockResolvedValueOnce([{
        verification_status: 'APPROVED', is_online: true,
        service_area_id: 'area-1', status: 'ACTIVE',
      }])
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([{ id: vehicle_id }])
      .mockResolvedValueOnce([{ id: ride_id, status: 'ASSIGNED', driver_id: driver_id }]);
    tx.dispatch_settings.findUnique.mockResolvedValue({ start_code_ttl_minutes: 15 });
    tx.ride_offers.update.mockResolvedValue({});
    tx.ride_offers.updateMany.mockResolvedValue({ count: 1 });
    tx.ride_events.create.mockResolvedValue({});
  };

  beforeEach(() => {
    vi.clearAllMocks();
    tx.$queryRaw.mockReset();
    service = new DispatchService(prisma as any);
    setup();
  });

  it('assigns once after locking ride, offer, then driver and validates vehicle ownership', async () => {
    const result = await service.acceptOffer({ offerId, driver_id, vehicle_id });
    expect(result.ride.status).toBe('ASSIGNED');
    expect(tx.$queryRaw).toHaveBeenCalledTimes(7);
    expect(tx.ride_offers.update).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: offerId },
      data: expect.objectContaining({ status: 'ACCEPTED' }),
    }));
    expect(tx.ride_events.create).toHaveBeenCalledTimes(1);
  });

  it('rejects a driver who already has an active ride before updating the offer', async () => {
    tx.$queryRaw.mockReset();
    tx.$queryRaw
      .mockResolvedValueOnce([{ ride_id: ride_id }])
      .mockResolvedValueOnce([{
        id: ride_id, status: 'SEARCHING', driver_id: null,
        service_area_id: 'area-1', vehicle_type_id: 'type-1',
      }])
      .mockResolvedValueOnce([{
        id: offerId, ride_id: ride_id, driver_id: driver_id, status: 'PENDING',
        expires_at: new Date(Date.now() + 60_000),
      }])
      .mockResolvedValueOnce([{
        verification_status: 'APPROVED', is_online: true,
        service_area_id: 'area-1', status: 'ACTIVE',
      }])
      .mockResolvedValueOnce([{ id: 'another-active-ride' }]);
    await expect(service.acceptOffer({ offerId, driver_id, vehicle_id })).rejects.toBeInstanceOf(ConflictException);
    expect(tx.ride_offers.update).not.toHaveBeenCalled();
    expect(tx.ride_events.create).not.toHaveBeenCalled();
  });
});
