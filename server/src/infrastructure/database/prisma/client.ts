import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient({
  errorFormat: 'minimal',
  log: process.env.NODE_ENV === 'development' ? ['warn'] : ['error'],
});

export { prisma };
