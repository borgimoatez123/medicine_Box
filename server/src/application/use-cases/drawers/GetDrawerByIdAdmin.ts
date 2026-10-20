import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { Drawer } from '@domain/entities/Drawer';
import { NotFoundError } from '@shared/errors';

export class GetDrawerByIdAdmin {
  constructor(private readonly drawerRepository: IDrawerRepository) {}

  async execute(drawerId: string): Promise<Drawer> {
    const drawer = await this.drawerRepository.findById(drawerId);
    if (!drawer) throw new NotFoundError('Drawer not found');
    return drawer;
  }
}
