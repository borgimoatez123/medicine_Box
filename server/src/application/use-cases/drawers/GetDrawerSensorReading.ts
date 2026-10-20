import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IDrawerSensorStateRepository } from '@domain/repositories/IDrawerSensorStateRepository';
import type { DrawerSensorReadingView } from '@application/use-cases/medicine-box/GetMedicineBoxSensorReadings';
import { NotFoundError } from '@shared/errors';

export class GetDrawerSensorReading {
  constructor(
    private readonly drawerRepo: IDrawerRepository,
    private readonly sensorRepo: IDrawerSensorStateRepository,
  ) {}

  async execute(
    userId: string,
    drawerId: string,
  ): Promise<DrawerSensorReadingView> {
    const drawer = await this.drawerRepo.findByIdAndUserId(drawerId, userId);
    if (!drawer) {
      throw new NotFoundError('Drawer not found');
    }

    const sensor = await this.sensorRepo.findByDrawerId(drawer.id);
    if (sensor) {
      return {
        drawerId: sensor.drawerId,
        temperature: sensor.temperature,
        humidity: sensor.humidity,
        fireDetected: sensor.fireDetected,
        updatedAt: sensor.updatedAt,
      };
    }
    return {
      drawerId: drawer.id,
      temperature: null,
      humidity: null,
      fireDetected: false,
      updatedAt: null,
    };
  }
}
