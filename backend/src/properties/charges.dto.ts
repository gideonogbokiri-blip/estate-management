import { Type } from 'class-transformer';
import { IsDateString, IsEmail, IsIn, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

const RECURRENCES = ['ONE_TIME', 'MONTHLY', 'QUARTERLY', 'ANNUALLY'] as const;
const SCOPES = ['ESTATE', 'PROPERTY', 'PROPERTY_TYPE'] as const;

export class CreateEstateChargeDto {
  @IsString() @MinLength(2) @MaxLength(40) @Matches(/^[A-Za-z0-9_-]+$/) code!: string;
  @IsString() @MinLength(2) @MaxLength(120) name!: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string | null;
  @IsString() @MinLength(2) @MaxLength(40) category!: string;
  @IsString() @Matches(/^(0|[1-9]\d{0,9})\.\d{2}$/) amount!: string;
  @IsString() @Matches(/^[A-Z]{3}$/) currency!: string;
  @IsIn(RECURRENCES) recurrence!: (typeof RECURRENCES)[number];
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) effectiveFrom!: string;
  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) effectiveTo?: string | null;
  @Type(() => Number) @IsInt() @Min(1) @Max(31) dueDay!: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(90) graceDays?: number;
  @IsIn(SCOPES) appliesTo!: (typeof SCOPES)[number];
  @IsOptional() @IsUUID('4') propertyId?: string | null;
  @IsOptional() @IsString() @MaxLength(80) propertyType?: string | null;
}

export class CreateEstateChargeVersionDto extends CreateEstateChargeDto {}

export class CreateEstateInvoiceDraftDto {
  @IsUUID('4') chargeVersionId!: string;
  @IsUUID('4') propertyId!: string;
  @IsEmail() @MaxLength(254) payerEmail!: string;
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) periodStart!: string;
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) periodEnd!: string;
}

export class PreviewChargeApplicabilityDto {
  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) periodStart?: string;
  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) periodEnd?: string;
}

export class GenerateRecurringInvoicesDto {
  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) from?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(24) months?: number;
}

export class CreateEstateSettlementPolicyDto {
  @IsString() @Matches(/^[A-Z]{3}$/) currency!: string;
  @IsString() @MinLength(2) @MaxLength(100) bankName!: string;
  @IsString() @MinLength(2) @MaxLength(120) accountName!: string;
  @IsString() @Matches(/^[A-Za-z0-9 -]{6,34}$/) accountNumber!: string;
  @IsString() @MinLength(3) @MaxLength(200) paymentReferenceFormat!: string;
}

export class RecordEstateInvoiceSettlementDto {
  @IsString() @Matches(/^(0|[1-9]\d{0,9})\.\d{2}$/) amount!: string;
  @IsString() @MinLength(2) @MaxLength(120) bankReference!: string;
  @IsDateString() receivedAt!: string;
  @IsString() @MinLength(10) @MaxLength(500) verificationNote!: string;
}
