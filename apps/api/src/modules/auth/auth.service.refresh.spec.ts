import { UnauthorizedException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthService } from './auth.service.js';

const user_id = '00000000-0000-4000-8000-0000000000a1';
const family_id = '00000000-0000-4000-8000-0000000000a2';
const token_id = '00000000-0000-4000-8000-0000000000a3';

describe('AuthService.refresh', () => {
  const prisma = {
    refresh_tokens: { findUnique: vi.fn(), updateMany: vi.fn(), create: vi.fn() },
    user_roles: { findMany: vi.fn() },
    users: { findUnique: vi.fn() },
  };
  const jwt = { sign: vi.fn(() => 'signed-access-token') };
  let service: AuthService;

  const storedToken = (overrides: Record<string, unknown> = {}) => ({
    id: token_id,
    user_id,
    family_id,
    token_hash: 'hash-of-presented-token',
    expires_at: new Date(Date.now() + 60_000),
    rotated_at: null,
    revoked_at: null,
    ...overrides,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    service = new AuthService(prisma as any, jwt as any, { send: vi.fn() } as any, {} as any);
    prisma.user_roles.findMany.mockResolvedValue([]);
    prisma.refresh_tokens.create.mockResolvedValue({});
    prisma.refresh_tokens.updateMany.mockResolvedValue({ count: 1 });
    prisma.users.findUnique.mockResolvedValue({ id: user_id, status: 'ACTIVE' });
  });

  it('rejects a token that was never issued, without revoking anything', async () => {
    prisma.refresh_tokens.findUnique.mockResolvedValue(null);

    await expect(service.refresh('forged')).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.refresh_tokens.updateMany).not.toHaveBeenCalled();
  });

  it('rejects an expired token without revoking its family', async () => {
    prisma.refresh_tokens.findUnique.mockResolvedValue(
      storedToken({ expires_at: new Date(Date.now() - 1_000) }),
    );

    await expect(service.refresh('expired')).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.refresh_tokens.updateMany).not.toHaveBeenCalled();
  });

  it('rotates the presented token conditionally and reissues it inside the same family', async () => {
    prisma.refresh_tokens.findUnique.mockResolvedValue(storedToken());

    const result = await service.refresh('valid-token');

    expect(result.accessToken).toBe('signed-access-token');
    expect(prisma.refresh_tokens.updateMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        id: token_id,
        revoked_at: null,
        rotated_at: null,
      }),
      data: expect.objectContaining({
        revoked_reason: 'ROTATED',
        rotated_at: expect.any(Date),
        revoked_at: expect.any(Date),
      }),
    });
    // The regression guard: a fresh family_id here would make reuse detection
    // miss every token issued after the replayed one.
    expect(prisma.refresh_tokens.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ user_id, family_id }),
    });
  });

  it('revokes the whole family when an already-spent token is replayed', async () => {
    prisma.refresh_tokens.findUnique.mockResolvedValue(
      storedToken({ rotated_at: new Date(), revoked_at: new Date() }),
    );

    await expect(service.refresh('replayed')).rejects.toBeInstanceOf(UnauthorizedException);

    expect(prisma.refresh_tokens.updateMany).toHaveBeenCalledTimes(1);
    expect(prisma.refresh_tokens.updateMany).toHaveBeenCalledWith({
      where: { family_id },
      data: expect.objectContaining({ revoked_reason: 'REUSE_DETECTED' }),
    });
    expect(prisma.refresh_tokens.create).not.toHaveBeenCalled();
  });

  it('issues nothing when another request wins the rotation race', async () => {
    prisma.refresh_tokens.findUnique.mockResolvedValue(storedToken());
    prisma.refresh_tokens.updateMany.mockResolvedValue({ count: 0 });

    await expect(service.refresh('valid-token')).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.refresh_tokens.create).not.toHaveBeenCalled();
  });

  it('issues nothing when the account is no longer active', async () => {
    prisma.refresh_tokens.findUnique.mockResolvedValue(storedToken());
    prisma.users.findUnique.mockResolvedValue({ id: user_id, status: 'SUSPENDED' });

    await expect(service.refresh('valid-token')).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.refresh_tokens.create).not.toHaveBeenCalled();
  });
});
