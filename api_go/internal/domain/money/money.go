package money

import (
	"errors"
	"fmt"
)

// Minor represents a monetary amount in the currency's minor unit (e.g. cents).
// All monetary arithmetic is performed on int64 to avoid floating-point error.
type Minor int64

// CurrencyCode is an ISO-4217 style currency code.
type CurrencyCode string

// Money is an amount in minor units with a currency.
type Money struct {
	Minor    Minor
	Currency CurrencyCode
}

// Error codes returned by money operations.
const (
	ErrCodeNotSafeInteger     = "NOT_SAFE_INTEGER"
	ErrCodeNegativeNotAllowed = "NEGATIVE_NOT_ALLOWED"
	ErrCodeCurrencyMismatch   = "CURRENCY_MISMATCH"
	ErrCodeInvalidRatio       = "INVALID_RATIO"
)

// Error is returned by money operations.
type Error struct {
	Code    string
	Message string
}

func (e *Error) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *Error) Unwrap() error { return errors.New(e.Message) }

func newError(code, message string) *Error {
	return &Error{Code: code, Message: message}
}

// Is reports whether err is a money.Error with the given code.
func Is(err error, code string) bool {
	var e *Error
	if errors.As(err, &e) {
		return e.Code == code
	}
	return false
}

// AssertMinor validates that v is a non-negative minor unit amount.
func AssertMinor(v Minor, label string) error {
	if v < 0 {
		return newError(ErrCodeNegativeNotAllowed, fmt.Sprintf("%s must be >= 0, got %d", label, v))
	}
	return nil
}

// New constructs a Money value, validating non-negative minor units.
func New(minor int64, currency CurrencyCode) (Money, error) {
	m := Minor(minor)
	if err := AssertMinor(m, "amount"); err != nil {
		return Money{}, err
	}
	return Money{Minor: m, Currency: currency}, nil
}

// MustNew constructs a Money value and panics on invalid input. Use only for
// fixed, trusted constants.
func MustNew(minor int64, currency CurrencyCode) Money {
	m, err := New(minor, currency)
	if err != nil {
		panic(err)
	}
	return m
}

// AssertSameCurrency returns an error if a and b use different currencies.
func AssertSameCurrency(a, b Money) error {
	if a.Currency != b.Currency {
		return newError(ErrCodeCurrencyMismatch, fmt.Sprintf("currency mismatch: %s vs %s", a.Currency, b.Currency))
	}
	return nil
}

// Add returns a + b. Both operands must share a currency.
func Add(a, b Money) (Money, error) {
	if err := AssertSameCurrency(a, b); err != nil {
		return Money{}, err
	}
	return Money{Minor: a.Minor + b.Minor, Currency: a.Currency}, nil
}

// Sub returns a - b. The result may be negative (callers decide validity).
func Sub(a, b Money) (Money, error) {
	if err := AssertSameCurrency(a, b); err != nil {
		return Money{}, err
	}
	return Money{Minor: a.Minor - b.Minor, Currency: a.Currency}, nil
}

// MulDivRound computes round_half_up(a * b / d) for non-negative integers using
// int64 arithmetic. The intermediate product is checked for overflow.
func MulDivRound(a, b, d Minor) (Minor, error) {
	if err := AssertMinor(a, "a"); err != nil {
		return 0, err
	}
	if err := AssertMinor(b, "b"); err != nil {
		return 0, err
	}
	if d <= 0 {
		return 0, newError(ErrCodeInvalidRatio, fmt.Sprintf("divisor must be positive, got %d", d))
	}
	const maxInt64 = 1<<63 - 1
	if a > 0 && b > 0 && a > maxInt64/b {
		return 0, newError(ErrCodeNotSafeInteger, fmt.Sprintf("product %d * %d overflows int64", a, b))
	}
	prod := int64(a) * int64(b)
	half := int64(d) / 2
	result := (prod + half) / int64(d)
	if result > maxInt64 {
		return 0, newError(ErrCodeNotSafeInteger, "result overflows int64")
	}
	return Minor(result), nil
}

// RoundToStep rounds value to the nearest multiple of step (half up). step >= 1.
func RoundToStep(value, step Minor) (Minor, error) {
	if err := AssertMinor(value, "value"); err != nil {
		return 0, err
	}
	if step < 1 {
		return 0, newError(ErrCodeInvalidRatio, fmt.Sprintf("rounding step must be >= 1, got %d", step))
	}
	quotient, _ := MulDivRound(value, 1, step)
	return quotient * step, nil
}
