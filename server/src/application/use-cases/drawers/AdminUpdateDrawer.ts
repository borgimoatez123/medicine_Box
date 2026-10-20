import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { Drawer } from '@domain/entities/Drawer';
import type { UpdateDrawerData } from '@domain/repositories/IDrawerRepository';
import { NotFoundError } from '@shared/errors';

export class AdminUpdateDrawer {
  constructor(private readonly drawerRepository: IDrawerRepository) {}

  async execute(drawerId: string, data: UpdateDrawerData): Promise<Drawer> {
    const exists = await this.drawerRepository.findById(drawerId);
    if (!exists) throw new NotFoundError('Drawer not found');
    return this.drawerRepository.update(drawerId, data);
  }
}
