import { classifySessionOutcome } from '@domain/entities/MedicationSession';
import { AssignMedicationToDrawer } from '@application/use-cases/drawer-medications/AssignMedicationToDrawer';
import type { Drawer } from '@domain/entities/Drawer';
import type { Medication } from '@domain/entities/Medication';
import type { MedicineBox } from '@domain/entities/MedicineBox';
import type { Patient } from '@domain/entities/Patient';
import { BadRequestError } from '@shared/errors';

describe('classifySessionOutcome — session result classification', () => {
  it('PATIENT_TAKEN: successful flow, no technical fails, completed', () => {
    const r = classifySessionOutcome({
      hadFaceRecognitionFailure: false,
      hadDeviceFailure: false,
      hadDispensingFailure: false,
      quantityBefore: 30,
      quantityAfter: 29,
      completedSuccessfully: true,
      sessionWindowExpired: false,
    });
    expect(r).toBe('PATIENT_TAKEN');
  });

  it('FACE_RECOGNITION_FAILED: 3 face fails first, no session progress possible', () => {
    const r = classifySessionOutcome({
      hadFaceRecognitionFailure: true,
      hadDeviceFailure: false,
      hadDispensingFailure: false,
      quantityBefore: 30,
      quantityAfter: 30,
      completedSuccessfully: false,
      sessionWindowExpired: true,
    });
    expect(r).toBe('FACE_RECOGNITION_FAILED');
  });

  it('DEVICE_FAILURE: device offline/unavailable before any action, quantity unchanged', () => {
    const r = classifySessionOutcome({
      hadFaceRecognitionFailure: false,
      hadDeviceFailure: true,
      hadDispensingFailure: false,
      quantityBefore: 30,
      quantityAfter: 30,
      completedSuccessfully: false,
      sessionWindowExpired: true,
    });
    expect(r).toBe('DEVICE_FAILURE');
  });

  it('DISPENSING_FAILURE: face ok, motor failed, quantity unchanged', () => {
    const r = classifySessionOutcome({
      hadFaceRecognitionFailure: false,
      hadDeviceFailure: false,
      hadDispensingFailure: true,
      quantityBefore: 30,
      quantityAfter: 30,
      completedSuccessfully: false,
      sessionWindowExpired: true,
    });
    expect(r).toBe('DISPENSING_FAILED');
  });

  it('PATIENT_SKIPPED: NO technical failure, session expires without completion, qty unchanged', () => {
    const r = classifySessionOutcome({
      hadFaceRecognitionFailure: false,
      hadDeviceFailure: false,
      hadDispensingFailure: false,
      quantityBefore: 30,
      quantityAfter: 30,
      completedSuccessfully: false,
      sessionWindowExpired: true,
    });
    expect(r).toBe('PATIENT_SKIPPED');
  });
});

function mockDmRepo() {
  return {
    create: jest.fn(),
    findById: jest.fn(),
    findByIdAndUserId: jest.fn(),
    findAll: jest.fn(),
    findAllByUserId: jest.fn(),
    findAllByMedicineBoxId: jest.fn(),
    findByDrawerId: jest.fn(async () => null),
    findByMedicationId: jest.fn(async () => null),
    upsert: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };
}
type MockDrRepo = {
  findByIdAndUserId: jest.Mock;
  findById: jest.Mock;
  findByIdAndMedicineBoxId: jest.Mock;
  findAllByMedicineBoxId: jest.Mock;
  findAllByMedicineBoxIdList: jest.Mock;
};
function mockDrRepo(): MockDrRepo {
  return {
    findByIdAndUserId: jest.fn(),
    findById: jest.fn(),
    findByIdAndMedicineBoxId: jest.fn(),
    findAllByMedicineBoxId: jest.fn(),
    findAllByMedicineBoxIdList: jest.fn(),
  };
}
type MockMedRepo = {
  findByIdAndUserId: jest.Mock;
  findById: jest.Mock;
  findAllByUserId: jest.Mock;
  findDuplicate: jest.Mock;
  create: jest.Mock;
  update: jest.Mock;
  delete: jest.Mock;
};
function mockMedRepo(): MockMedRepo {
  return {
    findByIdAndUserId: jest.fn(),
    findById: jest.fn(),
    findAllByUserId: jest.fn(),
    findDuplicate: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };
}
type MockMbRepo = {
  findByIdAndUserId: jest.Mock;
  findByDeviceId: jest.Mock;
  markDeviceSeen: jest.Mock;
  findAllByUserId: jest.Mock;
};
function mockMbRepo(): MockMbRepo {
  return {
    findByIdAndUserId: jest.fn(),
    findByDeviceId: jest.fn(),
    markDeviceSeen: jest.fn(),
    findAllByUserId: jest.fn(),
  };
}
type MockPatientRepo = {
  findById: jest.Mock;
};
function mockPatientRepo(): MockPatientRepo {
  return { findById: jest.fn() };
}

describe('AssignMedicationToDrawer — client-provided quantity + missingQuantity persistence', () => {
  const userId = 'u-1';
  const drawer: Drawer = {
    id: 'd-1', medicineBoxId: 'mb-1', drawerNumber: 1, status: 'EMPTY',
    createdAt: new Date(), updatedAt: new Date(),
  };
  function buildMed(qty: number): Medication {
    const exp = new Date(Date.now() + 86400000 * 730);
    return {
      id: 'm-1', patientId: 'p-1', name: 'X', dosage: '10mg', form: 'TABLET',
      quantity: qty, expiryDate: exp, createdAt: new Date(), updatedAt: new Date(),
    };
  }
  function buildPatient(uid: string = userId): Patient {
    return {
      id: 'p-1', userId: uid, fullName: 'P', dateOfBirth: null, gender: null,
      weightKg: null, heightCm: null, bloodType: null, allergies: null, notes: null,
      avatarUrl: null, createdAt: new Date(), updatedAt: new Date(),
    };
  }
  function buildBox(cap: number): MedicineBox {
    return {
      id: 'mb-1', deviceId: 'PI-DEV-001', deviceToken: 'SECRET', name: 'B',
      status: 'ACTIVE', deviceStatus: 'OFFLINE', lastSeenAt: null, userId: 'u-1',
      numberOfDrawers: 4, drawerCapacity: cap,
      createdAt: new Date(), updatedAt: new Date(),
    };
  }
  function setup(medQuantity: number, capacity: number) {
    const drRepo = mockDrRepo();
    const medRepo = mockMedRepo();
    const mbRepo = mockMbRepo();
    const dmRepo = mockDmRepo();
    const patientRepo = mockPatientRepo();
    drRepo.findByIdAndUserId.mockResolvedValue(drawer);
    drRepo.findByIdAndMedicineBoxId.mockResolvedValue(drawer);
    medRepo.findByIdAndUserId.mockResolvedValue(buildMed(medQuantity));
    medRepo.findById.mockResolvedValue(buildMed(medQuantity));
    mbRepo.findByIdAndUserId.mockResolvedValue(buildBox(capacity));
    patientRepo.findById.mockResolvedValue(buildPatient());
    dmRepo.create.mockImplementation(async (d: any) => ({
      id: 'dm-new', drawerId: drawer.id, medicationId: 'm-1',
      quantity: d.quantity, missingQuantity: d.missingQuantity,
      assignedAt: new Date(), isActive: true, createdAt: new Date(), updatedAt: new Date(),
    }));
    return {
      uc: new AssignMedicationToDrawer(dmRepo as never, drRepo as never, medRepo as never, mbRepo as never),
      dmRepo,
    };
  }

  it('[§9-Test1] q=20 miss=70 → stored exactly as sent', async () => {
    const { uc, dmRepo } = setup(90, 20);
    const out = await uc.execute(userId, { drawerId: drawer.id, medicationId: 'm-1', quantity: 20, missingQuantity: 70 });
    expect(out.quantity).toBe(20);
    expect(out.missingQuantity).toBe(70);
    expect(dmRepo.create).toHaveBeenCalledWith(
      expect.objectContaining({ quantity: 20, missingQuantity: 70 }),
    );
  });

  it('[§9-Test2] q=15 miss=0 → stored exactly as sent', async () => {
    const { uc, dmRepo } = setup(15, 20);
    const out = await uc.execute(userId, { drawerId: drawer.id, medicationId: 'm-1', quantity: 15, missingQuantity: 0 });
    expect(out.quantity).toBe(15);
    expect(out.missingQuantity).toBe(0);
    expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ quantity: 15, missingQuantity: 0 }));
  });

  it('[§6] missingQuantity sent 5 even if MIN/MAX formula says 0 → stored exactly 5 (no silent replace)', async () => {
    const { uc, dmRepo } = setup(15, 20);
    const out = await uc.execute(userId, { drawerId: drawer.id, medicationId: 'm-1', quantity: 15, missingQuantity: 5 });
    expect(out.quantity).toBe(15);
    expect(out.missingQuantity).toBe(5);
    expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ quantity: 15, missingQuantity: 5 }));
  });

  it('preserves existing quantity logic — quantity > capacity throws BadRequest', async () => {
    const { uc } = setup(90, 20);
    await expect(
      uc.execute(userId, { drawerId: drawer.id, medicationId: 'm-1', quantity: 21, missingQuantity: 69 }),
    ).rejects.toThrow(BadRequestError);
  });

  it('preserves existing quantity logic — quantity > medication stock throws BadRequest', async () => {
    const { uc } = setup(10, 20);
    await expect(
      uc.execute(userId, { drawerId: drawer.id, medicationId: 'm-1', quantity: 11, missingQuantity: 0 }),
    ).rejects.toThrow(BadRequestError);
  });

  it('q=0 miss=0 allowed (zero stock case)', async () => {
    const { uc, dmRepo } = setup(0, 20);
    const out = await uc.execute(userId, { drawerId: drawer.id, medicationId: 'm-1', quantity: 0, missingQuantity: 0 });
    expect(out.quantity).toBe(0);
    expect(out.missingQuantity).toBe(0);
    expect(dmRepo.create).toHaveBeenCalledWith(expect.objectContaining({ quantity: 0, missingQuantity: 0 }));
  });
});

describe('Configuration works during READY provisioning state', () => {
  it('Assign: box status=READY works — no provisioning conflict', async () => {
    const drawer: Drawer = {
      id: 'd-1', medicineBoxId: 'mb-1', drawerNumber: 1, status: 'EMPTY',
      createdAt: new Date(), updatedAt: new Date(),
    };
    const exp = new Date(Date.now() + 86400000 * 730);
    const medication: Medication = {
      id: 'm-1', patientId: 'p-1', name: 'X', dosage: '10mg', form: 'TABLET',
      quantity: 90, expiryDate: exp, createdAt: new Date(), updatedAt: new Date(),
    };
    const box: MedicineBox = {
      id: 'mb-1', deviceId: 'PI-DEV-001', deviceToken: 'SECRET', name: 'B',
      status: 'READY', deviceStatus: 'OFFLINE', lastSeenAt: null, userId: 'u-1',
      numberOfDrawers: 4, drawerCapacity: 30,
      createdAt: new Date(), updatedAt: new Date(),
    };
    const drRepo = mockDrRepo();
    const medRepo = mockMedRepo();
    const mbRepo = mockMbRepo();
    const dmRepo = mockDmRepo();
    drRepo.findByIdAndUserId.mockResolvedValue(drawer);
    medRepo.findByIdAndUserId.mockResolvedValue(medication);
    mbRepo.findByIdAndUserId.mockResolvedValue(box);
    dmRepo.create.mockResolvedValue({
      id: 'dm-new', drawerId: drawer.id, medicationId: medication.id,
      quantity: 30, missingQuantity: 60,
      assignedAt: new Date(), isActive: true, createdAt: new Date(), updatedAt: new Date(),
    });
    const uc = new AssignMedicationToDrawer(dmRepo as never, drRepo as never, medRepo as never, mbRepo as never);
    await expect(
      uc.execute('u-1', { drawerId: drawer.id, medicationId: medication.id, quantity: 30, missingQuantity: 60 }),
    ).resolves.toMatchObject({ drawerId: drawer.id, medicationId: medication.id, quantity: 30, missingQuantity: 60 });
  });
});
