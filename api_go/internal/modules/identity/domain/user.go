package domain

import (
	"errors"
	"strings"
	"time"
)

type Role string

const (
	RoleCustomer          Role = "CUSTOMER"
	RoleDriver            Role = "DRIVER"
	RoleSupportAgent      Role = "SUPPORT_AGENT"
	RoleOperationsManager Role = "OPERATIONS_MANAGER"
	RoleFinanceManager    Role = "FINANCE_MANAGER"
	RoleAdmin             Role = "ADMIN"
	RoleSuperAdmin        Role = "SUPER_ADMIN"
)

type UserStatus string

const (
	UserActive    UserStatus = "ACTIVE"
	UserSuspended UserStatus = "SUSPENDED"
	UserDeleted   UserStatus = "DELETED"
)

var (
	ErrInvalidUser  = errors.New("invalid user")
	ErrUserInactive = errors.New("user is not active")
)

type User struct {
	ID              string
	PhoneE164       *string
	PhoneVerifiedAt *time.Time
	Email           *string
	PasswordHash    *string
	DisplayName     *string
	Locale          string
	Status          UserStatus
	Roles           []Role
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

func (u User) Validate() error {
	if strings.TrimSpace(u.ID) == "" {
		return ErrInvalidUser
	}
	if u.Status != UserActive && u.Status != UserSuspended && u.Status != UserDeleted {
		return ErrInvalidUser
	}
	if u.Locale != "ar" && u.Locale != "en" {
		return ErrInvalidUser
	}
	if u.Status != UserDeleted && (u.PhoneE164 == nil || *u.PhoneE164 == "") && (u.Email == nil || *u.Email == "") {
		return ErrInvalidUser
	}
	return nil
}

func (u User) CanAuthenticate() bool {
	return u.Status == UserActive
}
