import { Router } from 'express';
import { requireAuth, requireRole } from '@presentation/middlewares/authMiddleware';
import { DrawerController } from '@presentation/controllers/DrawerController';

const drawerRouter = Router();
drawerRouter.use(requireAuth);

drawerRouter.get(
  '/admin/all',
  requireRole('ADMIN'),
  DrawerController.adminListAll,
);
drawerRouter.get(
  '/admin/:id',
  requireRole('ADMIN'),
  DrawerController.adminGetById,
);
drawerRouter.patch(
  '/admin/:id',
  requireRole('ADMIN'),
  DrawerController.adminUpdate,
);

drawerRouter.get('/', DrawerController.listMy);
drawerRouter.get('/:id/sensors', DrawerController.getSensors);
drawerRouter.post('/:drawerId/open', DrawerController.openDrawer);
drawerRouter.post('/:drawerId/close', DrawerController.closeDrawer);
drawerRouter.get('/:id', DrawerController.getById);
drawerRouter.patch('/:id', DrawerController.update);

export { drawerRouter };
