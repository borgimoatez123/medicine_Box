import { Router } from 'express';
import { DevicesController } from '@presentation/controllers/DevicesController';
import { probeImageUploadSingle } from '@presentation/middlewares/uploadMiddleware';

const devicesRouter = Router();

devicesRouter.post('/heartbeat', DevicesController.heartbeat);
devicesRouter.get(
  '/patients/:patientId/face-reference',
  DevicesController.getFaceReference,
);
devicesRouter.post(
  '/face-verification',
  probeImageUploadSingle,
  DevicesController.recordFaceVerification,
);
devicesRouter.get('/:deviceId/schedule', DevicesController.getDeviceSchedule);
devicesRouter.get('/medication-events', DevicesController.listMedicationEvents);
devicesRouter.post('/medication-events', DevicesController.recordMedicationEvent);
devicesRouter.post('/sensor-readings', DevicesController.recordSensorReading);
devicesRouter.get('/:deviceId/commands', DevicesController.getPendingCommands);
devicesRouter.post('/commands/:commandId/result', DevicesController.acknowledgeCommandResult);

export { devicesRouter };
