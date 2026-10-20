import 'dotenv/config';
import { PrismaClient, UserRole } from '@prisma/client';
import { hashSync } from 'bcrypt';

const prisma = new PrismaClient();

const log = (msg: string) => {
  process.stdout.write(`[bootstrap-admin] ${msg}\n`);
};

const main = async () => {
  const email = process.env.SYSTEM_ADMIN_EMAIL?.trim();
  const password = process.env.SYSTEM_ADMIN_PASSWORD?.trim();

  if (!email || !password) {
    throw new Error(
      'SYSTEM_ADMIN_EMAIL and SYSTEM_ADMIN_PASSWORD env variables are required for system admin bootstrap',
    );
  }

  const existing = await prisma.user.findUnique({ where: { email } });

  if (existing) {
    if (existing.role !== UserRole.ADMIN) {
      log(`User ${email} already exists — upgrading role to ADMIN (preserving password)`);
      await prisma.user.update({ where: { email }, data: { role: UserRole.ADMIN } });
    } else {
      log(`System admin ${email} already exists, role=ADMIN (no-op: idempotent)`);
    }
    return;
  }

  const salt = Number(process.env.BCRYPT_SALT_ROUNDS ?? 12);
  const passwordHash = hashSync(password, Number.isFinite(salt) && salt > 0 ? salt : 12);

  await prisma.user.create({
    data: {
      email,
      passwordHash,
      role: UserRole.ADMIN,
      firstName: null,
      lastName: null,
      phone: null,
    },
  });

  log(`Created system admin user: ${email} (role=ADMIN)`);
};

main()
  .catch((err: unknown) => {
    process.stderr.write(`[bootstrap-admin] ERROR: ${(err as Error).message}\n`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
