import type {
  CreateDeviceCommandData,
  IDeviceCommandRepository,
  UpdateCommandResultData,
} from '@domain/repositories/IDeviceCommandRepository';
import type { DeviceCommand } from '@domain/entities/DeviceCommand';
import { prisma } from '@infrastructure/database/prisma/client';

type PrismaDeviceCommandRow = {
  id: string;
  deviceId: string;
  drawerId: string | null;
  type: 'OPEN_DRAWER';
  status: 'PENDING' | 'SENT' | 'EXECUTED' | 'FAILED' | 'EXPIRED';
  reason: string | null;
  createdAt: Date;
  sentAt: Date | null;
  executedAt: Date | null;
  error: string | null;
};

export const toDomainDeviceCommand = (
  row: PrismaDeviceCommandRow,
): DeviceCommand => ({
  id: row.id,
  deviceId: row.deviceId,
  drawerId: row.drawerId,
  type: row.type,
  status: row.status,
  reason: row.reason,
  createdAt: row.createdAt,
  sentAt: row.sentAt,
  executedAt: row.executedAt,
  error: row.error,
});

export class PrismaDeviceCommandRepository implements IDeviceCommandRepository {
  async create(data: CreateDeviceCommandData): Promise<DeviceCommand> {
    const created = await prisma.deviceCommand.create({
      data: {
        deviceId: data.deviceId,
        drawerId: data.drawerId ?? null,
        type: data.type,
        status: data.status ?? 'PENDING',
        reason: data.reason ?? null,
      },
    });
    return toDomainDeviceCommand(created as unknown as PrismaDeviceCommandRow);
  }

  async findById(commandId: string): Promise<DeviceCommand | null> {
    const row = await prisma.deviceCommand.findUnique({ where: { id: commandId } });
    return row ? toDomainDeviceCommand(row as unknown as PrismaDeviceCommandRow) : null;
  }

  async findPendingByDeviceId(deviceId: string): Promise<DeviceCommand[]> {
    const rows = await prisma.deviceCommand.findMany({
      where: { deviceId, status: 'PENDING' },
      orderBy: [{ createdAt: 'asc' }],
    });
    return rows.map(r => toDomainDeviceCommand(r as unknown as PrismaDeviceCommandRow));
  }

  async markManyAsSentInTransaction(commandIds: string[]): Promise<void> {
    if (commandIds.length === 0) return;
    const now = new Date();
    await prisma.$transaction([
      prisma.deviceCommand.updateMany({
        where: { id: { in: commandIds } },
        data: { status: 'SENT', sentAt: now },
      }),
    ]);
  }

  async updateResult(
    commandId: string,
    result: UpdateCommandResultData,
  ): Promise<DeviceCommand | null> {
    const now = new Date();
    const updated = await prisma.deviceCommand.update({
      where: { id: commandId },
      data: {
        status: result.status,
        executedAt: result.status === 'EXECUTED' ? now : null,
        error:
          result.status === 'FAILED'
            ? typeof result.error === 'string'
              ? result.error
              : null
            : null,
      },
    });
    return toDomainDeviceCommand(updated as unknown as PrismaDeviceCommandRow);
  }
}
