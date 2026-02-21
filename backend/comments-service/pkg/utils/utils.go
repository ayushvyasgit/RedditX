// Package utils provides common utility functions
package utils

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)

// GenerateID generates a random hex ID
func GenerateID(prefix string) string {
	bytes := make([]byte, 16)
	rand.Read(bytes)
	id := hex.EncodeToString(bytes)
	if prefix != "" {
		return fmt.Sprintf("%s_%s", prefix, id)
	}
	return id
}

// HashString creates a SHA-256 hash of a string
func HashString(s string) string {
	hash := sha256.Sum256([]byte(s))
	return hex.EncodeToString(hash[:])
}

// StringPtr returns a pointer to a string value
func StringPtr(s string) *string {
	return &s
}

// IntPtr returns a pointer to an int value
func IntPtr(i int) *int {
	return &i
}

// TimePtr returns a pointer to a time value
func TimePtr(t time.Time) *time.Time {
	return &t
}

// StringValue safely dereferences a string pointer
func StringValue(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// IntValue safely dereferences an int pointer
func IntValue(i *int) int {
	if i == nil {
		return 0
	}
	return *i
}

// TimeValue safely dereferences a time pointer
func TimeValue(t *time.Time) time.Time {
	if t == nil {
		return time.Time{}
	}
	return *t
}

// Contains checks if a string slice contains a value
func Contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

// ContainsInt checks if an int slice contains a value
func ContainsInt(slice []int, item int) bool {
	for _, i := range slice {
		if i == item {
			return true
		}
	}
	return false
}

// TruncateString truncates a string to a maximum length
func TruncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	if maxLen < 3 {
		return s[:maxLen]
	}
	return s[:maxLen-3] + "..."
}

// SanitizeSubdomain ensures a subdomain is valid (lowercase, alphanumeric, hyphens)
func SanitizeSubdomain(subdomain string) string {
	subdomain = strings.ToLower(subdomain)
	subdomain = strings.TrimSpace(subdomain)
	
	// Remove invalid characters
	result := ""
	for _, char := range subdomain {
		if (char >= 'a' && char <= 'z') || (char >= '0' && char <= '9') || char == '-' {
			result += string(char)
		}
	}
	
	// Remove leading/trailing hyphens
	result = strings.Trim(result, "-")
	
	return result
}

// ValidateEmail performs basic email validation
func ValidateEmail(email string) bool {
	if email == "" {
		return false
	}
	
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return false
	}
	
	localPart := parts[0]
	domainPart := parts[1]
	
	if localPart == "" || domainPart == "" {
		return false
	}
	
	// Check domain has at least one dot
	if !strings.Contains(domainPart, ".") {
		return false
	}
	
	return true
}

// Paginate calculates pagination offset
func Paginate(page, limit int) (offset int, actualLimit int) {
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	
	offset = (page - 1) * limit
	return offset, limit
}

// CalculateTotalPages calculates total pages for pagination
func CalculateTotalPages(total, limit int) int {
	if limit == 0 {
		return 0
	}
	return (total + limit - 1) / limit
}

// RemoveDuplicates removes duplicate strings from a slice
func RemoveDuplicates(slice []string) []string {
	keys := make(map[string]bool)
	result := []string{}
	
	for _, item := range slice {
		if _, exists := keys[item]; !exists {
			keys[item] = true
			result = append(result, item)
		}
	}
	
	return result
}

// ChunkSlice splits a slice into chunks of specified size
func ChunkSlice(slice []string, chunkSize int) [][]string {
	if chunkSize <= 0 {
		return nil
	}
	
	var chunks [][]string
	for i := 0; i < len(slice); i += chunkSize {
		end := i + chunkSize
		if end > len(slice) {
			end = len(slice)
		}
		chunks = append(chunks, slice[i:end])
	}
	
	return chunks
}

// DefaultString returns the default value if the string is empty
func DefaultString(value, defaultValue string) string {
	if value == "" {
		return defaultValue
	}
	return value
}

// DefaultInt returns the default value if the int is zero
func DefaultInt(value, defaultValue int) int {
	if value == 0 {
		return defaultValue
	}
	return value
}
