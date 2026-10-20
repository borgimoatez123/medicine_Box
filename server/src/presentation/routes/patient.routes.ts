import { Router } from 'express';
import { requireAuth } from '@presentation/middlewares/authMiddleware';
import { avatarUploadSingle } from '@presentation/middlewares/uploadMiddleware';
import { PatientController } from '@presentation/controllers/PatientController';

const patientRouter = Router();

patientRouter.use(requireAuth);

patientRouter.post('/', PatientController.create);
patientRouter.post('/:id/avatar', avatarUploadSingle, PatientController.uploadAvatar);
patientRouter.get('/', PatientController.list);
patientRouter.get('/:id', PatientController.getById);
patientRouter.patch('/:id', PatientController.update);
patientRouter.delete('/:id/avatar', PatientController.deleteAvatar);
patientRouter.delete('/:id', PatientController.remove);

export { patientRouter };
