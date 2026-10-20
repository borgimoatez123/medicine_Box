import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { errorMiddleware } from '@presentation/middlewares/errorMiddleware';
import { authRouter } from '@presentation/routes/auth.routes';
import { userRouter } from '@presentation/routes/user.routes';
import { patientRouter } from '@presentation/routes/patient.routes';
import { medicationRouter } from '@presentation/routes/medication.routes';
import { scheduleRouter } from '@presentation/routes/schedule.routes';
import { medicineBoxRouter } from '@presentation/routes/medicineBox.routes';
import { drawerRouter } from '@presentation/routes/drawer.routes';
import { drawerMedicationRouter } from '@presentation/routes/drawerMedication.routes';
import { devicesRouter } from '@presentation/routes/devices.routes';

const app = express();

const localhostDevPorts = [
  'http://localhost:3000',
  'http://localhost:3001',
  'http://localhost:3002',
  'http://localhost:3003',
  'http://localhost:3004',
  'http://localhost:3005',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:3001',
  'http://127.0.0.1:3002',
  'http://127.0.0.1:3003',
  'http://127.0.0.1:3004',
  'http://127.0.0.1:3005',
];

const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

const originWhitelist = Array.from(new Set([...localhostDevPorts, ...allowedOrigins]));

app.use(
  cors({
    origin: (requestOrigin, callback) => {
      if (!requestOrigin) {
        callback(null, true);
        return;
      }
      const matches = originWhitelist.some(
        (allowed) => requestOrigin === allowed || allowed === '*'
      );
      callback(null, matches ? requestOrigin : false);
    },
    credentials: true,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With'],
    optionsSuccessStatus: 204,
    preflightContinue: false,
  }),
);

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
    crossOriginOpenerPolicy: { policy: 'same-origin-allow-popups' },
    contentSecurityPolicy: {
      useDefaults: true,
      directives: {
        'default-src': ["'self'"],
        'connect-src': ["'self'", 'http://localhost:*', 'ws://localhost:*'],
        'img-src': ["'self'", 'data:', 'https:'],
        'style-src': ["'self'", "'unsafe-inline'"],
        'script-src': ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
        'font-src': ["'self'", 'data:'],
      },
    },
  }),
);

app.use(express.json());

const morganDevFormat =
  ':method :url :status :response-time ms - :res[content-length]';
app.use(
  morgan(process.env.NODE_ENV === 'development' ? morganDevFormat : 'combined'),
);

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.use('/api/auth', authRouter);
app.use('/api/users', userRouter);
app.use('/api/patients', patientRouter);
app.use('/api/medications', medicationRouter);
app.use('/api/schedules', scheduleRouter);
app.use('/api/medicine-boxes', medicineBoxRouter);
app.use('/api/drawers', drawerRouter);
app.use('/api/drawer-medications', drawerMedicationRouter);
app.use('/api/devices', devicesRouter);

app.use(errorMiddleware);

export { app };
