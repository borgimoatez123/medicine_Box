import { app } from './app';
import { logDatabaseStatus } from '@shared/utils/dbHealthcheck';
import {
  startOfflineMonitor,
  stopOfflineMonitor,
} from '@application/services/DeviceOfflineMonitor';

const PORT = Number(process.env.PORT) || 3000;

const start = async () => {
  await logDatabaseStatus();

  startOfflineMonitor();

  const server = app.listen(PORT, () => {
    console.log(`[server] Server is running on http://localhost:${PORT}`);
    console.log(`[server] Environment: ${process.env.NODE_ENV || 'development'}`);
  });

  const shutdown = (signal: string) => {
    console.log(`[server] ${signal} received, shutting down gracefully...`);
    stopOfflineMonitor();
    server.close(() => {
      console.log('[server] Server closed');
      process.exit(0);
    });
    setTimeout(() => {
      console.error('[server] Forced shutdown');
      process.exit(1);
    }, 10000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  return { server };
};

void start();

export {};
