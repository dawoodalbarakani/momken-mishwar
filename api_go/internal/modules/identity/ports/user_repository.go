package ports

import (
	"context"
	"errors"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
)

var ErrUserNotFound = errors.New("user not found")

type UserRepository interface {
	FindByID(ctx context.Context, id string) (domain.User, error)
	FindByPhone(ctx context.Context, phoneE164 string) (domain.User, error)
	FindByEmail(ctx context.Context, email string) (domain.User, error)
}
