import { IsEmail, IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class IssueRecoveryCodeDto {
  @IsIn(['email_verification', 'password_reset']) purpose!: string;
}

export class ConfirmRecoveryDto {
  @IsEmail() @MaxLength(254) email!: string;
  @IsString() @MinLength(6) @MaxLength(20) code!: string;
  @IsOptional() @IsString() @MinLength(12) @MaxLength(128) newPassword?: string;
}
