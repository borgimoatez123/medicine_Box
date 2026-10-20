import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IDrawerSensorStateRepository } from '@domain/repositories/IDrawerSensorStateRepository';
import { NotFoundError, ForbiddenError } from '@shared/errors';

export type RecordDrawerSensorReadingPayload = {
  deviceId: string;
  drawerId: string;
  temperature: number;
  humidity: number;
  fireDetected: boolean;
};

export type RecordDrawerSensorReadingResult = {
  drawerId: string;
  temperature: number;
  humidity: number;
  fireDetected: boolean;
  updatedAt: Date;
};

export class RecordDrawerSensorReading {
  constructor(
    private readonly medicineBoxRepo: IMedicineBoxRepository,
    private readonly drawerRepo: IDrawerRepository,
    private readonly sensorRepo: IDrawerSensorStateRepository,
  ) {}

  async execute(
    payload: RecordDrawerSensorReadingPayload,
  ): Promise<RecordDrawerSensorReadingResult> {
    const deviceId = payload.deviceId.trim();
    const drawerId = payload.drawerId.trim();

    const box = await this.medicineBoxRepo.findByDeviceId(deviceId);
    if (!box) {
      throw new NotFoundError('Device not found');
    }

    const drawer = await this.drawerRepo.findById(drawerId);
    if (!drawer) {
      throw new NotFoundError('Drawer not found');
    }

    if (drawer.medicineBoxId !== box.id) {
      throw new ForbiddenError('Drawer does not belong to this device\'s medicine box');
    }

    const saved = await this.sensorRepo.upsert({
      drawerId,
      temperature: payload.temperature,
      humidity: payload.humidity,
      fireDetected: payload.fireDetected,
    });

    return {
      drawerId: saved.drawerId,
      temperature: saved.temperature as number,
      humidity: saved.humidity as number,
      fireDetected: saved.fireDetected,
      updatedAt: saved.updatedAt,
    };
  }
}
