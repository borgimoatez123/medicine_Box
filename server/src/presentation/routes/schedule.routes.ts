import { Router } from 'express';
import { requireAuth } from '@presentation/middlewares/authMiddleware';
import { ScheduleController } from '@presentation/controllers/ScheduleController';

const scheduleRouter = Router();

scheduleRouter.use(requireAuth);

scheduleRouter.post('/', ScheduleController.create);
scheduleRouter.get('/', ScheduleController.list);
scheduleRouter.get('/:id', ScheduleController.getById);
scheduleRouter.patch('/:id', ScheduleController.update);
scheduleRouter.delete('/:id', ScheduleController.remove);

export { scheduleRouter };
