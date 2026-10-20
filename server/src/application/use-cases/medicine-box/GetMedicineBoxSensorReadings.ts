import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IDrawerSensorStateRepository } from '@domain/repositories/IDrawerSensorStateRepository';
import type { DrawerSensorState } from '@domain/entities/DrawerSensorState';
import { NotFoundError } from '@shared/errors';

export type DrawerSensorReadingView = {
  drawerId: string;
  temperature: number | null;
  humidity: number | null;
  fireDetected: boolean;
  updatedAt: Date | null;
};

export type MedicineBoxSensorReadingsResult = {
  medicineBoxId: string;
  drawers: DrawerSensorReadingView[];
};

const sensorByDrawerId = (
  rows: DrawerSensorState[],
): Record<string, DrawerSensorState> => {
  const map: Record<string, DrawerSensorState> = {};
  for (const r of rows) map[r.drawerId] = r;
  return map;
};

export class GetMedicineBoxSensorReadings {
  constructor(
    private readonly medicineBoxRepo: IMedicineBoxRepository,
    private readonly drawerRepo: IDrawerRepository,
    private readonly sensorRepo: IDrawerSensorStateRepository,
  ) {}

  async execute(
    userId: string,
    medicineBoxId: string,
  ): Promise<MedicineBoxSensorReadingsResult> {
    const box = await this.medicineBoxRepo.findByIdAndUserId(medicineBoxId, userId);
    if (!box) {
      throw new NotFoundError('Medicine box not found');
    }

    const drawers = await this.drawerRepo.findAllByMedicineBoxId(box.id);
    const drawerIds = drawers.map((d) => d.id);
    const sensorRows = await this.sensorRepo.findManyByDrawerIds(drawerIds);
    const sensorMap = sensorByDrawerId(sensorRows);

    const views = drawers.map<DrawerSensorReadingView>((d) => {
      const s = sensorMap[d.id];
      if (s) {
        return {
          drawerId: s.drawerId,
          temperature: s.temperature,
          humidity: s.humidity,
          fireDetected: s.fireDetected,
          updatedAt: s.updatedAt,
        };
      }
      return {
        drawerId: d.id,
        temperature: null,
        humidity: null,
        fireDetected: false,
        updatedAt: null,
      };
    });

    return {
      medicineBoxId: box.id,
      drawers: views,
    };
  }
}
