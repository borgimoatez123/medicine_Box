import { Router } from 'express';
import { requireAuth } from '@presentation/middlewares/authMiddleware';
import { MedicationController } from '@presentation/controllers/MedicationController';

const medicationRouter = Router();

medicationRouter.use(requireAuth);

medicationRouter.post('/', MedicationController.create);
medicationRouter.get('/', MedicationController.list);
medicationRouter.get('/:id', MedicationController.getById);
medicationRouter.patch('/:id', MedicationController.update);
medicationRouter.delete('/:id', MedicationController.remove);

export { medicationRouter };
