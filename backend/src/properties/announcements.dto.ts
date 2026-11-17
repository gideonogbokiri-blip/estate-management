import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateEstateAnnouncementDto {
  @IsString() @MinLength(3) @MaxLength(160)
  title!: string;

  @IsString() @MinLength(1) @MaxLength(5000)
  body!: string;

  @IsIn(['normal', 'emergency'])
  priority!: 'normal' | 'emergency';
}
