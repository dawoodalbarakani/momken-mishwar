package ride_state

import (
	"errors"
	"fmt"
)

// RideStatus is the lifecycle status of a ride.
type RideStatus string

const (
	StatusSearching     RideStatus = "SEARCHING"
	StatusNoDriverFound RideStatus = "NO_DRIVER_FOUND"
	StatusAssigned      RideStatus = "ASSIGNED"
	StatusArriving      RideStatus = "ARRIVING"
	StatusArrived       RideStatus = "ARRIVED"
	StatusInProgress    RideStatus = "IN_PROGRESS"
	StatusCompleted     RideStatus = "COMPLETED"
	StatusCancelled     RideStatus = "CANCELLED"
)

// RideEvent is a lifecycle event that triggers a status transition.
type RideEvent string

const (
	EventDriverAssigned RideEvent = "DRIVER_ASSIGNED"
	EventSearchExpired  RideEvent = "SEARCH_EXPIRED"
	EventDriverEnRoute  RideEvent = "DRIVER_EN_ROUTE"
	EventDriverArrived  RideEvent = "DRIVER_ARRIVED"
	EventTripStarted    RideEvent = "TRIP_STARTED"
	EventTripCompleted  RideEvent = "TRIP_COMPLETED"
	EventCancel         RideEvent = "CANCEL"
)

// ActorRole is the role of the actor performing a transition.
type ActorRole string

const (
	ActorCustomer ActorRole = "CUSTOMER"
	ActorDriver   ActorRole = "DRIVER"
	ActorSystem   ActorRole = "SYSTEM"
	ActorStaff    ActorRole = "STAFF"
)

// Actor is the identity of the actor performing a transition.
type Actor struct {
	Role   ActorRole
	UserID string
}

// RideSnapshot is the minimal ride state needed to evaluate a transition.
type RideSnapshot struct {
	Status     RideStatus
	CustomerID string
	DriverID   *string
}

// TransitionContext carries additional data required for specific transitions.
type TransitionContext struct {
	// StartCodeVerified is required for TRIP_STARTED.
	StartCodeVerified bool
	// CancelReasonCode is required for CANCEL.
	CancelReasonCode string
	// AssignedDriverID is required for DRIVER_ASSIGNED.
	AssignedDriverID string
}

// TransitionResult is the outcome of a transition evaluation.
type TransitionResult struct {
	To               RideStatus
	CancelledBy      *ActorRole
	CancelReasonCode string
}

var (
	// TerminalStatuses are statuses from which no transition is allowed.
	TerminalStatuses = []RideStatus{StatusCompleted, StatusCancelled, StatusNoDriverFound}
	// ActiveDriverStatuses are statuses where a driver is actively assigned.
	ActiveDriverStatuses = []RideStatus{StatusAssigned, StatusArriving, StatusArrived, StatusInProgress}
	// CancellableByParties are statuses that a customer or driver may cancel.
	CancellableByParties = []RideStatus{StatusSearching, StatusAssigned, StatusArriving, StatusArrived}
)

// RideTransitionError is returned when a transition is not allowed.
type RideTransitionError struct {
	Code    string
	Message string
}

func (e *RideTransitionError) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *RideTransitionError) Unwrap() error { return errors.New(e.Message) }

const (
	ErrCodeInvalidTransition    = "INVALID_TRANSITION"
	ErrCodeForbiddenActor       = "FORBIDDEN_ACTOR"
	ErrCodeStartCodeNotVerified = "START_CODE_NOT_VERIFIED"
	ErrCodeReasonRequired       = "REASON_REQUIRED"
	ErrCodeDriverRequired       = "DRIVER_REQUIRED"
)

func newRideTransitionError(code, message string) *RideTransitionError {
	return &RideTransitionError{Code: code, Message: message}
}

// IsRideTransitionError reports whether err is a RideTransitionError with the given code.
func IsRideTransitionError(err error, code string) bool {
	var e *RideTransitionError
	return errors.As(err, &e) && e.Code == code
}

// driverSteps maps driver events to their from/to statuses.
var driverSteps = map[RideEvent]struct {
	From RideStatus
	To   RideStatus
}{
	EventDriverEnRoute: {From: StatusAssigned, To: StatusArriving},
	EventDriverArrived: {From: StatusArriving, To: StatusArrived},
	EventTripStarted:   {From: StatusArrived, To: StatusInProgress},
	EventTripCompleted: {From: StatusInProgress, To: StatusCompleted},
}

func isTerminal(status RideStatus) bool {
	for _, s := range TerminalStatuses {
		if status == s {
			return true
		}
	}
	return false
}

func isCancellableByParties(status RideStatus) bool {
	for _, s := range CancellableByParties {
		if status == s {
			return true
		}
	}
	return false
}

func isAssignedDriver(ride RideSnapshot, actor Actor) bool {
	return actor.Role == ActorDriver && actor.UserID != "" && ride.DriverID != nil && *ride.DriverID == actor.UserID
}

func isOwnerCustomer(ride RideSnapshot, actor Actor) bool {
	return actor.Role == ActorCustomer && actor.UserID != "" && ride.CustomerID == actor.UserID
}

// Transition evaluates whether a ride lifecycle event is allowed and returns
// the resulting status. It is pure: no I/O, no database access.
func Transition(ride RideSnapshot, event RideEvent, actor Actor, ctx TransitionContext) (TransitionResult, error) {
	if isTerminal(ride.Status) {
		return TransitionResult{}, newRideTransitionError(ErrCodeInvalidTransition,
			fmt.Sprintf("Event %s is not allowed from status %s", event, ride.Status))
	}

	switch event {
	case EventDriverAssigned:
		if ride.Status != StatusSearching {
			return TransitionResult{}, newRideTransitionError(ErrCodeInvalidTransition,
				fmt.Sprintf("Event %s is not allowed from status %s", event, ride.Status))
		}
		if actor.Role != ActorSystem &&
			(actor.Role != ActorDriver || actor.UserID != ctx.AssignedDriverID) {
			return TransitionResult{}, newRideTransitionError(ErrCodeForbiddenActor,
				fmt.Sprintf("Actor %s may not perform %s on this ride", actor.Role, event))
		}
		if ctx.AssignedDriverID == "" {
			return TransitionResult{}, newRideTransitionError(ErrCodeDriverRequired, "DRIVER_ASSIGNED requires assignedDriverId")
		}
		return TransitionResult{To: StatusAssigned}, nil

	case EventSearchExpired:
		if ride.Status != StatusSearching {
			return TransitionResult{}, newRideTransitionError(ErrCodeInvalidTransition,
				fmt.Sprintf("Event %s is not allowed from status %s", event, ride.Status))
		}
		if actor.Role != ActorSystem {
			return TransitionResult{}, newRideTransitionError(ErrCodeForbiddenActor,
				fmt.Sprintf("Actor %s may not perform %s on this ride", actor.Role, event))
		}
		return TransitionResult{To: StatusNoDriverFound}, nil

	case EventDriverEnRoute, EventDriverArrived, EventTripStarted, EventTripCompleted:
		step, ok := driverSteps[event]
		if !ok {
			return TransitionResult{}, newRideTransitionError(ErrCodeInvalidTransition,
				fmt.Sprintf("unknown driver event %s", event))
		}
		if ride.Status != step.From {
			return TransitionResult{}, newRideTransitionError(ErrCodeInvalidTransition,
				fmt.Sprintf("Event %s is not allowed from status %s", event, ride.Status))
		}
		if !isAssignedDriver(ride, actor) {
			return TransitionResult{}, newRideTransitionError(ErrCodeForbiddenActor,
				fmt.Sprintf("Actor %s may not perform %s on this ride", actor.Role, event))
		}
		if event == EventTripStarted && !ctx.StartCodeVerified {
			return TransitionResult{}, newRideTransitionError(ErrCodeStartCodeNotVerified,
				"TRIP_STARTED requires a verified start code")
		}
		return TransitionResult{To: step.To}, nil

	case EventCancel:
		if ctx.CancelReasonCode == "" {
			return TransitionResult{}, newRideTransitionError(ErrCodeReasonRequired, "CANCEL requires a reason code")
		}
		cancelledBy := actor.Role
		if ride.Status == StatusInProgress {
			if actor.Role != ActorStaff {
				return TransitionResult{}, newRideTransitionError(ErrCodeForbiddenActor,
					fmt.Sprintf("Actor %s may not perform %s on this ride", actor.Role, event))
			}
		} else if isCancellableByParties(ride.Status) {
			allowed := isOwnerCustomer(ride, actor) ||
				isAssignedDriver(ride, actor) ||
				actor.Role == ActorStaff ||
				actor.Role == ActorSystem
			if !allowed {
				return TransitionResult{}, newRideTransitionError(ErrCodeForbiddenActor,
					fmt.Sprintf("Actor %s may not perform %s on this ride", actor.Role, event))
			}
		} else {
			return TransitionResult{}, newRideTransitionError(ErrCodeInvalidTransition,
				fmt.Sprintf("Event %s is not allowed from status %s", event, ride.Status))
		}
		cb := cancelledBy
		return TransitionResult{To: StatusCancelled, CancelledBy: &cb, CancelReasonCode: ctx.CancelReasonCode}, nil

	default:
		return TransitionResult{}, newRideTransitionError(ErrCodeInvalidTransition,
			fmt.Sprintf("unknown event %s", event))
	}
}
