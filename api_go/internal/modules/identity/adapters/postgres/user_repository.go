package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/domain"
	"github.com/barakanid96/momken-mishwar/api_go/internal/modules/identity/ports"
)

type UserRepository struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
	return &UserRepository{db: db}
}

const userColumns = `id::text, phone_e164, phone_verified_at, email, password_hash,
	display_name, locale, status, created_at, updated_at`

func (r *UserRepository) FindByID(ctx context.Context, id string) (domain.User, error) {
	return r.find(ctx, "id::text = $1", id)
}

func (r *UserRepository) FindByPhone(ctx context.Context, phoneE164 string) (domain.User, error) {
	return r.find(ctx, "phone_e164 = $1", phoneE164)
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (domain.User, error) {
	return r.find(ctx, "email = lower($1)", email)
}

func (r *UserRepository) find(ctx context.Context, predicate string, arg any) (domain.User, error) {
	if r.db == nil {
		return domain.User{}, errors.New("identity repository: nil database")
	}
	// predicate is selected only by the fixed methods above; user input is always a bind parameter.
	query := "SELECT " + userColumns + " FROM users WHERE " + predicate
	var user domain.User
	var phone, email, passwordHash, displayName sql.NullString
	var phoneVerifiedAt sql.NullTime
	var status string

	err := r.db.QueryRow(ctx, query, arg).Scan(
		&user.ID, &phone, &phoneVerifiedAt, &email, &passwordHash,
		&displayName, &user.Locale, &status, &user.CreatedAt, &user.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.User{}, ports.ErrUserNotFound
	}
	if err != nil {
		return domain.User{}, fmt.Errorf("query identity user: %w", err)
	}
	user.Status = domain.UserStatus(status)
	user.PhoneE164 = nullableString(phone)
	user.Email = nullableString(email)
	user.PasswordHash = nullableString(passwordHash)
	user.DisplayName = nullableString(displayName)
	if phoneVerifiedAt.Valid {
		user.PhoneVerifiedAt = &phoneVerifiedAt.Time
	}

	rows, err := r.db.Query(ctx, "SELECT role FROM user_roles WHERE user_id = $1::uuid ORDER BY role", user.ID)
	if err != nil {
		return domain.User{}, fmt.Errorf("query identity roles: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var role string
		if err := rows.Scan(&role); err != nil {
			return domain.User{}, fmt.Errorf("scan identity role: %w", err)
		}
		user.Roles = append(user.Roles, domain.Role(role))
	}
	if err := rows.Err(); err != nil {
		return domain.User{}, fmt.Errorf("iterate identity roles: %w", err)
	}
	if err := user.Validate(); err != nil {
		return domain.User{}, fmt.Errorf("stored identity user violates domain invariants: %w", err)
	}
	return user, nil
}

func nullableString(value sql.NullString) *string {
	if !value.Valid {
		return nil
	}
	v := value.String
	return &v
}
