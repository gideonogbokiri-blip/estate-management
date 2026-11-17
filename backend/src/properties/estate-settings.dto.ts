import { IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateEstateSettingsDto {
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  name!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  estateType!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(300)
  address!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(100)
  state!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(100)
  lga!: string;
}
