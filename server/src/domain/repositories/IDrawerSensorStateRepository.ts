import type { DrawerSensorState } from '@domain/entities/DrawerSensorState';

export type UpsertDrawerSensorStateData = {
  drawerId: string;
  temperature: number;
  humidity: number;
  fireDetected: boolean;
};

export interface IDrawerSensorStateRepository {
  upsert(data: UpsertDrawerSensorStateData): Promise<DrawerSensorState>;
  findByDrawerId(drawerId: string): Promise<DrawerSensorState | null>;
  findManyByDrawerIds(drawerIds: string[]): Promise<DrawerSensorState[]>;
}
