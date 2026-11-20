import { IsBoolean, IsIn, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

const METHODS = ['DEMO_DECLARATION', 'PROVIDER_TOKEN', 'DOCUMENT_REVIEW'] as const;
const LEVELS = ['BASIC', 'ENHANCED'] as const;

export class SubmitIdentityVerificationDto {
  @IsIn(METHODS) method!: (typeof METHODS)[number];
  @IsString() @MinLength(2) @MaxLength(60) provider!: string;
  @IsOptional() @IsString() @MaxLength(180) providerReference?: string;
  @IsIn(LEVELS) level!: (typeof LEVELS)[number];
  @IsBoolean() consentGiven!: boolean;
}

export class DecideIdentityVerificationDto {
  @IsIn(['verify', 'reject']) decision!: 'verify' | 'reject';
  @IsOptional() @IsString() @MaxLength(500) reason?: string;
}
