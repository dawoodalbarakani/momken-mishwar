import { IsString, IsOptional, IsEmail, IsEnum, IsPhoneNumber } from 'class-validator';
import { Expose, Type } from 'class-transformer';

export class CreateUserDto {
  @IsOptional()
  @IsPhoneNumber()
  phoneE164?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsString()
  @IsOptional()
  displayName?: string;

  @IsEnum(['ar', 'en'])
  @IsOptional()
  locale?: 'ar' | 'en';

  @IsString()
  @IsOptional()
  password?: string;
}
