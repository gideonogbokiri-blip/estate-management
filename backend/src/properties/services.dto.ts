import { IsIn, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class CreateEstateServiceDto {
  @IsString() @MinLength(2) @MaxLength(40) @Matches(/^[A-Z0-9_-]+$/)
  code!: string;

  @IsString() @MinLength(2) @MaxLength(120) name!: string;

  @IsOptional() @IsString() @MaxLength(500) description?: string | null;

  @IsString() @MinLength(2) @MaxLength(40) category!: string;

  @IsString() @MinLength(2) @MaxLength(60) provider!: string;

  @IsString() @Matches(/^(0|[1-9]\d{0,9})\.\d{2}$/) amount!: string;

  @IsString() @Matches(/^[A-Z]{3}$/) currency!: string;
}

export class SetEstateServiceStatusDto {
  @IsIn(['ACTIVE', 'INACTIVE']) status!: 'ACTIVE' | 'INACTIVE';
}
