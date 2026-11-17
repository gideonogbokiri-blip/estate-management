import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { AuthenticatedRequest } from './access-token.guard.js';
import { AccessTokenGuard } from './access-token.guard.js';
import { AuthService } from './auth.service.js';
import { LoginDto, RefreshDto, RegisterDto } from './auth.dto.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(@Body() body: RegisterDto) {
    return this.auth.register(body);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() body: LoginDto) {
    return this.auth.login(body);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() body: RefreshDto) {
    return this.auth.refresh(body.refreshToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(AccessTokenGuard)
  async logout(@Req() request: AuthenticatedRequest): Promise<void> {
    await this.auth.revokeSession(request.actor.sessionId, request.actor.userId);
  }

  @Get('me')
  @UseGuards(AccessTokenGuard)
  me(@Req() request: AuthenticatedRequest) {
    return this.auth.readCurrentUser(request.actor.userId);
  }
}
