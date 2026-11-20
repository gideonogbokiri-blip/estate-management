import { IsIn, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

export class UpdatePayoutPolicyDto {
  @Matches(/^[0-9]+(\.[0-9]{1,2})?$/) threshold!: string;
  @IsInt() @Min(1) @Max(3) requiredApprovals!: number;
}

export class CreateBeneficiaryDto {
  @IsString() @MinLength(2) @MaxLength(160) displayName!: string;
  @IsString() @MinLength(2) @MaxLength(120) bankName!: string;
  @IsString() @MinLength(6) @MaxLength(34) accountNumber!: string;
  @IsString() @MinLength(2) @MaxLength(120) bankCode!: string;
}

export class CreatePayoutDto {
  @IsUUID('4') beneficiaryId!: string;
  @Matches(/^[0-9]+(\.[0-9]{1,2})?$/) amount!: string;
  @IsString() @Matches(/^[A-Z]{3}$/) currency!: string;
  @IsString() @MinLength(5) @MaxLength(500) purpose!: string;
  @IsOptional() @IsString() @MaxLength(60) fundCategory?: string;
}

export class DecidePayoutDto {
  @IsIn(['approve', 'reject']) decision!: 'approve' | 'reject';
  @IsOptional() @IsString() @MaxLength(500) note?: string;
}
