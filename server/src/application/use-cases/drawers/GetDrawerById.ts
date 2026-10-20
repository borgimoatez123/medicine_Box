import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { Drawer } from '@domain/entities/Drawer';
import { NotFoundError } from '@shared/errors';

export class GetDrawerById {
  constructor(private readonly drawerRepository: IDrawerRepository) {}

  async execute(userId: string, drawerId: string): Promise<Drawer> {
    const drawer = await this.drawerRepository.findByIdAndUserId(drawerId, userId);
    if (!drawer) throw new NotFoundError('Drawer not found');
    return drawer;
  }
}
