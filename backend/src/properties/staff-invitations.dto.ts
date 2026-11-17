import { IsEmail, IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateStaffInvitationDto {
  @IsEmail() @MaxLength(254) email!: string;
  @IsIn(['ESTATE_MANAGER', 'FINANCE_MANAGER', 'SECURITY_OFFICER']) role!: 'ESTATE_MANAGER' | 'FINANCE_MANAGER' | 'SECURITY_OFFICER';
}

export class AcceptStaffInvitationDto {
  @IsString() @MinLength(32) @MaxLength(128) token!: string;
}
