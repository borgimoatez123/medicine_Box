import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { Drawer } from '@domain/entities/Drawer';

export class GetAllDrawers {
  constructor(private readonly drawerRepository: IDrawerRepository) {}

  async execute(): Promise<Drawer[]> {
    return this.drawerRepository.findAll();
  }
}
