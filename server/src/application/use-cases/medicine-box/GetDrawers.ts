import type { IDrawerRepository } from '@domain/repositories/IDrawerRepository';
import type { IMedicineBoxRepository } from '@domain/repositories/IMedicineBoxRepository';
import type { Drawer } from '@domain/entities/Drawer';
import { NotFoundError } from '@shared/errors';

type GetDrawersInput = {
  userId: string;
  boxId: string;
};

type GetDrawersOutput = Drawer[];

export class GetDrawers {
  constructor(
    private readonly drawerRepo: IDrawerRepository,
    private readonly medicineBoxRepo: IMedicineBoxRepository,
  ) {}

  public async execute(input: GetDrawersInput): Promise<GetDrawersOutput> {
    const medicineBox = await this.medicineBoxRepo.findByIdAndUserId(input.boxId, input.userId);
    if (!medicineBox) {
      throw new NotFoundError('Medicine box not found');
    }

    const drawers = await this.drawerRepo.findAllByMedicineBoxId(input.boxId);
    return drawers;
  }
}
