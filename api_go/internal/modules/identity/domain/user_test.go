package domain

import (
	"errors"
	"testing"
	"time"
)

func TestUserValidate(t *testing.T) {
	phone := "+967771234567"
	email := "user@example.com"
	now := time.Now().UTC()

	tests := []struct {
		name    string
		user    User
		wantErr bool
	}{
		{
			name: "active user with phone",
			user: User{ID: "u-1", PhoneE164: &phone, Locale: "ar", Status: UserActive, CreatedAt: now, UpdatedAt: now},
		},
		{
			name:    "active user without identifier",
			user:    User{ID: "u-2", Locale: "ar", Status: UserActive},
			wantErr: true,
		},
		{
			name:    "unsupported locale",
			user:    User{ID: "u-3", Email: &email, Locale: "fr", Status: UserActive},
			wantErr: true,
		},
		{
			name:    "unknown status",
			user:    User{ID: "u-4", Email: &email, Locale: "en", Status: "UNKNOWN"},
			wantErr: true,
		},
		{
			name: "deleted user may be anonymized",
			user: User{ID: "u-5", Locale: "en", Status: UserDeleted},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.user.Validate()
			if tt.wantErr && err == nil {
				t.Fatal("Validate() expected an error")
			}
			if !tt.wantErr && err != nil {
				t.Fatalf("Validate() unexpected error: %v", err)
			}
			if tt.wantErr && !errors.Is(err, ErrInvalidUser) {
				t.Fatalf("Validate() error = %v, want ErrInvalidUser", err)
			}
		})
	}
}

func TestCanAuthenticate(t *testing.T) {
	tests := []struct {
		status UserStatus
		want   bool
	}{
		{status: UserActive, want: true},
		{status: UserSuspended, want: false},
		{status: UserDeleted, want: false},
	}
	for _, tt := range tests {
		user := User{Status: tt.status}
		if got := user.CanAuthenticate(); got != tt.want {
			t.Errorf("CanAuthenticate() for %s = %v, want %v", tt.status, got, tt.want)
		}
	}
}
