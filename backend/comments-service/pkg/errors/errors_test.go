package errors

import (
	"errors"
	"net/http"
	"testing"
)

func TestNotFound(t *testing.T) {
	err := NotFound("resource not found")
	
	if err.Code != ErrCodeNotFound {
		t.Errorf("expected code %s, got %s", ErrCodeNotFound, err.Code)
	}
	
	if err.StatusCode != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, err.StatusCode)
	}
}

func TestAppError_Error(t *testing.T) {
	err := InternalServer("database error", errors.New("connection failed"))
	
	expected := "database error: connection failed"
	if err.Error() != expected {
		t.Errorf("expected %s, got %s", expected, err.Error())
	}
}

func TestAppError_Unwrap(t *testing.T) {
	underlying := errors.New("underlying")
	err := InternalServer("wrapped", underlying)
	
	if err.Unwrap() != underlying {
		t.Error("Unwrap failed")
	}
}