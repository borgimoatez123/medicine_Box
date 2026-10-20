import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { Drawer } from '@domain/entities/Drawer';
import type { FindDrawersOptions } from '@domain/repositories/IDrawerRepository';

export class GetMyDrawers {
  constructor(private readonly drawerRepository: IDrawerRepository) {}

  async execute(userId: string, options?: FindDrawersOptions): Promise<Drawer[]> {
    return this.drawerRepository.findAllByUserId(userId, options);
  }
}
