import type {
  IDrawerSensorStateRepository,
  UpsertDrawerSensorStateData,
} from '@domain/repositories/IDrawerSensorStateRepository';
import type { DrawerSensorState } from '@domain/entities/DrawerSensorState';
import { prisma } from '@infrastructure/database/prisma/client';

export const toDomainDrawerSensorState = (
  model: {
    id: string;
    drawerId: string;
    temperature: number | null;
    humidity: number | null;
    fireDetected: boolean;
    updatedAt: Date;
    createdAt: Date;
  },
): DrawerSensorState => ({
  id: model.id,
  drawerId: model.drawerId,
  temperature: model.temperature,
  humidity: model.humidity,
  fireDetected: model.fireDetected,
  updatedAt: model.updatedAt,
  createdAt: model.createdAt,
});

export class PrismaDrawerSensorStateRepository implements IDrawerSensorStateRepository {
  async upsert(data: UpsertDrawerSensorStateData): Promise<DrawerSensorState> {
    const row = await prisma.drawerSensorState.upsert({
      where: { drawerId: data.drawerId },
      create: {
        drawerId: data.drawerId,
        temperature: data.temperature,
        humidity: data.humidity,
        fireDetected: data.fireDetected,
      },
      update: {
        temperature: data.temperature,
        humidity: data.humidity,
        fireDetected: data.fireDetected,
      },
    });
    return toDomainDrawerSensorState(row);
  }

  async findByDrawerId(drawerId: string): Promise<DrawerSensorState | null> {
    const row = await prisma.drawerSensorState.findUnique({ where: { drawerId } });
    return row ? toDomainDrawerSensorState(row) : null;
  }

  async findManyByDrawerIds(drawerIds: string[]): Promise<DrawerSensorState[]> {
    if (drawerIds.length === 0) return [];
    const rows = await prisma.drawerSensorState.findMany({
      where: { drawerId: { in: drawerIds } },
    });
    return rows.map(toDomainDrawerSensorState);
  }
}
