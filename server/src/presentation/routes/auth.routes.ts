import { Router } from 'express';
import { AuthController } from '@presentation/controllers/AuthController';

const authRouter = Router();

authRouter.post('/register', AuthController.register);
authRouter.post('/login', AuthController.login);

export { authRouter };
