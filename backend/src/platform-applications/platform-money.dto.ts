import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Matches,
  Min,
  MinLength,
} from 'class-validator';

export class PlatformAccountsQueryDto {
  @IsOptional() @MaxLength(120) search?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 25;
}

export class PlatformAdjustmentDto {
  @Matches(/^[0-9]+(\.[0-9]{1,2})?$/) amount!: string;
  @IsString() @Matches(/^[A-Z]{3}$/) currency!: string;
  @IsIn(['credit', 'debit']) direction!: string;
  @IsString() @MinLength(5) @MaxLength(500) reason!: string;
}

export class PlatformAdjustmentsQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 25;
}
