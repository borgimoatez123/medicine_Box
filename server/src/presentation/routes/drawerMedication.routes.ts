import { Router } from 'express';
import { requireAuth, requireRole } from '@presentation/middlewares/authMiddleware';
import { DrawerMedicationController } from '@presentation/controllers/DrawerMedicationController';

const drawerMedicationRouter = Router();
drawerMedicationRouter.use(requireAuth);

drawerMedicationRouter.get(
  '/admin/all',
  requireRole('ADMIN'),
  DrawerMedicationController.adminListAll,
);
drawerMedicationRouter.get(
  '/admin/:id',
  requireRole('ADMIN'),
  DrawerMedicationController.adminGetById,
);

drawerMedicationRouter.post('/', DrawerMedicationController.create);
drawerMedicationRouter.get('/', DrawerMedicationController.listMy);
drawerMedicationRouter.get('/:id', DrawerMedicationController.getById);
drawerMedicationRouter.patch('/:id', DrawerMedicationController.update);
drawerMedicationRouter.delete('/:id', DrawerMedicationController.delete);

export { drawerMedicationRouter };
