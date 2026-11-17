import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsBoolean, IsIn, IsOptional, IsString, Matches, MaxLength, ValidateNested } from 'class-validator';

const MONEY = /^\d{1,10}(?:\.\d{1,2})?$/;

export class CreateExpenseCategoryDto {
  @IsString() @Matches(/^[A-Za-z0-9_-]{2,60}$/) code!: string;
  @IsString() @MaxLength(120) name!: string;
}

export class CreateExpensePayeeDto {
  @IsString() @Matches(/^[A-Za-z0-9_-]{2,60}$/) reference!: string;
  @IsString() @MaxLength(160) displayName!: string;
  @IsString() @Matches(/^[A-Z]{3}$/) currency!: string;
  @IsString() @Matches(/^ref:[A-Za-z0-9._-]{4,112}$/) destinationReference!: string;
}

export class ExpenseApprovalStageDto {
  @IsIn(['ESTATE_ADMINISTRATOR', 'FINANCE_MANAGER']) role!: string;
  @IsOptional() @IsString() @Matches(MONEY) maximumAmount?: string;
}

export class ConfigureExpensePolicyDto {
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(4) @ValidateNested({ each: true }) @Type(() => ExpenseApprovalStageDto)
  stages!: ExpenseApprovalStageDto[];
  @IsBoolean() allowUnbudgeted!: boolean;
  @IsBoolean() requireDistinctApprovers!: boolean;
}

export class CreateExpenseRequestDto {
  @IsString() @MaxLength(1000) description!: string;
  @IsString() @Matches(/^[0-9a-f-]{36}$/i) categoryId!: string;
  @IsString() @Matches(/^[0-9a-f-]{36}$/i) payeeId!: string;
  @IsOptional() @IsString() @Matches(/^[0-9a-f-]{36}$/i) budgetLineId?: string;
  @IsString() @Matches(MONEY) amount!: string;
  @IsString() @Matches(/^[A-Z]{3}$/) currency!: string;
  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) neededBy?: string;
}

export class SubmitExpenseDecisionDto {
  @IsIn(['approve', 'reject']) decision!: 'approve' | 'reject';
  @IsOptional() @IsString() @MaxLength(1000) reason?: string;
}

export class EstateBudgetLineDto {
  @IsString() @Matches(/^[0-9a-f-]{36}$/i) categoryId!: string;
  @IsString() @Matches(MONEY) allocatedAmount!: string;
}

export class CreateEstateBudgetDto {
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) periodStart!: string;
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) periodEnd!: string;
  @IsString() @Matches(/^[A-Z]{3}$/) currency!: string;
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(100) @ValidateNested({ each: true }) @Type(() => EstateBudgetLineDto)
  lines!: EstateBudgetLineDto[];
}

export class DecideEstateBudgetDto {
  @IsIn(['approve', 'reject']) decision!: 'approve' | 'reject';
  @IsOptional() @IsString() @MaxLength(1000) reason?: string;
}

export class ReconcileEstateExpenseDto {
  @IsString() @Matches(MONEY) amount!: string;
  @IsString() @MaxLength(120) @Matches(/^[A-Za-z0-9._/-]{4,120}$/) bankReference!: string;
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) receivedAt!: string;
  @IsString() @MaxLength(1000) verificationNote!: string;
}
