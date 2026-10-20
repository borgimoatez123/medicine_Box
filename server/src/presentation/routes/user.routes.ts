import { Router } from 'express';
import { requireAuth, requireRole } from '@presentation/middlewares/authMiddleware';
import { UserController } from '@presentation/controllers/UserController';

const userRouter = Router();

userRouter.use(requireAuth);

userRouter.get('/me', UserController.getMe);
userRouter.patch('/me', UserController.updateMe);
userRouter.patch('/me/password', UserController.changePassword);

userRouter.get('/', requireRole('ADMIN'), UserController.listUsers);
userRouter.get('/:id', requireRole('ADMIN'), UserController.getUserById);

export { userRouter };
