import { Router } from 'express';
import { requireAuth, requireRole } from '@presentation/middlewares/authMiddleware';
import { MedicineBoxController } from '@presentation/controllers/MedicineBoxController';
import { DrawerController } from '@presentation/controllers/DrawerController';

const medicineBoxRouter = Router();
medicineBoxRouter.use(requireAuth);

medicineBoxRouter.post('/activate', MedicineBoxController.activate);

medicineBoxRouter.post(
  '/',
  requireRole('ADMIN'),
  MedicineBoxController.add,
);
medicineBoxRouter.post(
  '/:medicineBoxId/drawers',
  requireRole('ADMIN'),
  DrawerController.provision,
);
medicineBoxRouter.get(
  '/admin/all',
  requireRole('ADMIN'),
  MedicineBoxController.adminListAll,
);
medicineBoxRouter.get(
  '/admin/:id',
  requireRole('ADMIN'),
  MedicineBoxController.adminGetById,
);
medicineBoxRouter.patch(
  '/admin/:id',
  requireRole('ADMIN'),
  MedicineBoxController.adminUpdate,
);

medicineBoxRouter.get('/', MedicineBoxController.listMy);
medicineBoxRouter.post('/:id/unassign', MedicineBoxController.unassign);
medicineBoxRouter.get('/:id/sensors', MedicineBoxController.getSensors);
medicineBoxRouter.get('/:id', MedicineBoxController.getById);
medicineBoxRouter.patch('/:id', MedicineBoxController.update);

export { medicineBoxRouter };
