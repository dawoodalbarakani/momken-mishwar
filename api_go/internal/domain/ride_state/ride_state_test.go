package ride_state

import (
	"testing"
)

func TestTransitionSearchToAssigned(t *testing.T) {
	ride := RideSnapshot{Status: StatusSearching, CustomerID: "cust-1"}
	actor := Actor{Role: ActorSystem, UserID: ""}
	ctx := TransitionContext{AssignedDriverID: "driver-1"}
	result, err := Transition(ride, EventDriverAssigned, actor, ctx)
	if err != nil || result.To != StatusAssigned {
		t.Fatalf("unexpected: to=%v err=%v", result.To, err)
	}
}

func TestTransitionDriverSteps(t *testing.T) {
	ride := RideSnapshot{Status: StatusAssigned, CustomerID: "cust-1", DriverID: strPtr("driver-1")}
	actor := Actor{Role: ActorDriver, UserID: "driver-1"}

	// en-route
	result, err := Transition(ride, EventDriverEnRoute, actor, TransitionContext{})
	if err != nil || result.To != StatusArriving {
		t.Fatalf("en-route: to=%v err=%v", result.To, err)
	}
	ride.Status = StatusArriving
	// arrived
	result, err = Transition(ride, EventDriverArrived, actor, TransitionContext{})
	if err != nil || result.To != StatusArrived {
		t.Fatalf("arrived: to=%v err=%v", result.To, err)
	}
	ride.Status = StatusArrived
	// start (requires start code verified)
	result, err = Transition(ride, EventTripStarted, actor, TransitionContext{StartCodeVerified: true})
	if err != nil || result.To != StatusInProgress {
		t.Fatalf("start: to=%v err=%v", result.To, err)
	}
	ride.Status = StatusInProgress
	// complete
	result, err = Transition(ride, EventTripCompleted, actor, TransitionContext{})
	if err != nil || result.To != StatusCompleted {
		t.Fatalf("complete: to=%v err=%v", result.To, err)
	}
}

func TestTransitionStartCodeRequired(t *testing.T) {
	ride := RideSnapshot{Status: StatusArrived, CustomerID: "cust-1", DriverID: strPtr("driver-1")}
	actor := Actor{Role: ActorDriver, UserID: "driver-1"}
	_, err := Transition(ride, EventTripStarted, actor, TransitionContext{})
	if !IsRideTransitionError(err, ErrCodeStartCodeNotVerified) {
		t.Fatalf("expected start code not verified, got %v", err)
	}
}

func TestTransitionForbiddenActor(t *testing.T) {
	ride := RideSnapshot{Status: StatusAssigned, CustomerID: "cust-1", DriverID: strPtr("driver-1")}
	actor := Actor{Role: ActorDriver, UserID: "driver-2"} // not the assigned driver
	_, err := Transition(ride, EventDriverEnRoute, actor, TransitionContext{})
	if !IsRideTransitionError(err, ErrCodeForbiddenActor) {
		t.Fatalf("expected forbidden actor, got %v", err)
	}
}

func TestTransitionTerminalRejected(t *testing.T) {
	ride := RideSnapshot{Status: StatusCompleted, CustomerID: "cust-1"}
	actor := Actor{Role: ActorDriver, UserID: "driver-1"}
	_, err := Transition(ride, EventCancel, actor, TransitionContext{CancelReasonCode: "test"})
	if !IsRideTransitionError(err, ErrCodeInvalidTransition) {
		t.Fatalf("expected invalid transition for terminal status, got %v", err)
	}
}

func TestTransitionCustomerCancel(t *testing.T) {
	ride := RideSnapshot{Status: StatusAssigned, CustomerID: "cust-1", DriverID: strPtr("driver-1")}
	actor := Actor{Role: ActorCustomer, UserID: "cust-1"}
	result, err := Transition(ride, EventCancel, actor, TransitionContext{CancelReasonCode: "changed_mind"})
	if err != nil || result.To != StatusCancelled {
		t.Fatalf("unexpected: to=%v err=%v", result.To, err)
	}
	if result.CancelledBy == nil || *result.CancelledBy != ActorCustomer {
		t.Fatalf("cancelledBy = %v, want CUSTOMER", result.CancelledBy)
	}
}

func TestTransitionReasonRequired(t *testing.T) {
	ride := RideSnapshot{Status: StatusAssigned, CustomerID: "cust-1"}
	actor := Actor{Role: ActorCustomer, UserID: "cust-1"}
	_, err := Transition(ride, EventCancel, actor, TransitionContext{})
	if !IsRideTransitionError(err, ErrCodeReasonRequired) {
		t.Fatalf("expected reason required, got %v", err)
	}
}

func TestTransitionSearchExpiredSystemOnly(t *testing.T) {
	ride := RideSnapshot{Status: StatusSearching, CustomerID: "cust-1"}
	actor := Actor{Role: ActorDriver, UserID: "driver-1"}
	_, err := Transition(ride, EventSearchExpired, actor, TransitionContext{})
	if !IsRideTransitionError(err, ErrCodeForbiddenActor) {
		t.Fatalf("expected forbidden actor for search expired, got %v", err)
	}
}

func strPtr(s string) *string { return &s }
