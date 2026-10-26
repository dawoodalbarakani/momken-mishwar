package money

import (
	"testing"
)

func TestMoneyAddSubSameCurrency(t *testing.T) {
	a := MustNew(1000, "YER")
	b := MustNew(500, "YER")
	sum, err := Add(a, b)
	if err != nil || sum.Minor != 1500 || sum.Currency != "YER" {
		t.Fatalf("unexpected sum: %+v err=%v", sum, err)
	}
	diff, err := Sub(a, b)
	if err != nil || diff.Minor != 500 {
		t.Fatalf("unexpected diff: %+v err=%v", diff, err)
	}
}

func TestMoneyCurrencyMismatch(t *testing.T) {
	a := MustNew(1000, "YER")
	b := MustNew(500, "USD")
	if _, err := Add(a, b); !Is(err, ErrCodeCurrencyMismatch) {
		t.Fatalf("expected currency mismatch, got %v", err)
	}
	if _, err := Sub(a, b); !Is(err, ErrCodeCurrencyMismatch) {
		t.Fatalf("expected currency mismatch, got %v", err)
	}
}

func TestMoneyNegativeRejected(t *testing.T) {
	if _, err := New(-1, "YER"); !Is(err, ErrCodeNegativeNotAllowed) {
		t.Fatalf("expected negative rejected, got %v", err)
	}
	neg, err := New(-500, "YER")
	if err == nil {
		_ = neg
		t.Fatal("expected error for negative amount")
	}
	if _, err := Add(MustNew(1000, "YER"), neg); err == nil {
		t.Fatal("expected negative addend rejected")
	}
}

func TestMulDivRound(t *testing.T) {
	cases := []struct {
		a, b, d Minor
		want    Minor
	}{
		{1000, 3, 1000, 3}, // 1000*3/1000 = 3
		{1000, 7, 1000, 7}, // 1000*7/1000 = 7
		{1000, 3, 2, 1500}, // 1000*3/2 = 1500
		{1, 1, 3, 0},       // round_half_up(1/3) = 0
		{1, 2, 3, 1},       // round_half_up(2/3) = 1
		{5, 5, 2, 13},      // round_half_up(25/2) = 13
	}
	for _, c := range cases {
		got, err := MulDivRound(c.a, c.b, c.d)
		if err != nil || got != c.want {
			t.Fatalf("MulDivRound(%d,%d,%d) = %d, %v; want %d", c.a, c.b, c.d, got, err, c.want)
		}
	}
}

func TestMulDivRoundInvalidDivisor(t *testing.T) {
	if _, err := MulDivRound(100, 100, 0); !Is(err, ErrCodeInvalidRatio) {
		t.Fatalf("expected invalid ratio, got %v", err)
	}
	if _, err := MulDivRound(-1, 100, 10); !Is(err, ErrCodeNegativeNotAllowed) {
		t.Fatalf("expected negative rejected, got %v", err)
	}
}

func TestRoundToStep(t *testing.T) {
	cases := []struct {
		value, step, want Minor
	}{
		{1000, 100, 1000},
		{1050, 100, 1100}, // half up
		{1049, 100, 1000},
		{7, 5, 5},  // round_half_up(7/5)=1 *5 = 5
		{8, 5, 10}, // round_half_up(8/5)=2 *5 = 10
		{1, 1, 1},
	}
	for _, c := range cases {
		got, err := RoundToStep(c.value, c.step)
		if err != nil || got != c.want {
			t.Fatalf("RoundToStep(%d,%d) = %d, %v; want %d", c.value, c.step, got, err, c.want)
		}
	}
}

func TestRoundToStepInvalidStep(t *testing.T) {
	if _, err := RoundToStep(100, 0); !Is(err, ErrCodeInvalidRatio) {
		t.Fatalf("expected invalid ratio, got %v", err)
	}
}
