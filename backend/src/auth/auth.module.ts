import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { AccessTokenGuard } from './access-token.guard.js';
import { AccountLifecycleController } from './account-lifecycle.controller.js';
import { AccountLifecycleService } from './account-lifecycle.service.js';

@Module({
  controllers: [AuthController, AccountLifecycleController],
  providers: [AuthService, AccessTokenGuard, AccountLifecycleService],
  exports: [AccessTokenGuard, AuthService, AccountLifecycleService],
})
export class AuthModule {}
