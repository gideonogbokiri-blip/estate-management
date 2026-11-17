import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';

export class QueueQueryDto {
  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 25;
}

export class AssignReviewerDto {
  @IsUUID()
  reviewerUserId!: string;
}

export class DecisionReasonDto {
  @IsString()
  @MaxLength(2000)
  reason!: string;
}

export class ApproveApplicationDto {
  @IsUUID()
  initialAdministratorUserId!: string;
}
