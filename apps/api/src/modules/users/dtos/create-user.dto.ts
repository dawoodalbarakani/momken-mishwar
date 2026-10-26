import { IsString, IsOptional, IsEmail, IsEnum, IsPhoneNumber } from 'class-validator';
import { Expose, Type } from 'class-transformer';

export class CreateUserDto {
  @IsOptional()
  @IsPhoneNumber()
  phone_e164?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsString()
  @IsOptional()
  display_name?: string;

  @IsEnum(['ar', 'en'])
  @IsOptional()
  locale?: 'ar' | 'en';

  @IsString()
  @IsOptional()
  password?: string;
}
