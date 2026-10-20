import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { Drawer } from '@domain/entities/Drawer';
import type { UpdateDrawerData } from '@domain/repositories/IDrawerRepository';
import { NotFoundError } from '@shared/errors';

export class UpdateDrawer {
  constructor(
    private readonly drawerRepository: IDrawerRepository,
    private readonly medicineBoxRepository: IMedicineBoxRepository,
  ) {}

  async execute(userId: string, drawerId: string, data: UpdateDrawerData): Promise<Drawer> {
    const exists = await this.drawerRepository.findByIdAndUserId(drawerId, userId);
    if (!exists) throw new NotFoundError('Drawer not found');
    const box = await this.medicineBoxRepository.findByIdAndUserId(exists.medicineBoxId, userId);
    if (!box) throw new NotFoundError('Medicine box not found');
    return this.drawerRepository.update(drawerId, data);
  }
}
