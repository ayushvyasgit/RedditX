package utils

import (
	"strings"
	"testing"
	"time"
)

func TestGenerateID(t *testing.T) {
	tests := []struct {
		name   string
		prefix string
	}{
		{"without prefix", ""},
		{"with prefix", "tenant"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			id := GenerateID(tt.prefix)
			
			if id == "" {
				t.Error("expected non-empty ID")
			}
			
			if tt.prefix != "" {
				if !strings.HasPrefix(id, tt.prefix+"_") {
					t.Errorf("expected ID to start with %s_, got %s", tt.prefix, id)
				}
			}
			
			// Test uniqueness
			id2 := GenerateID(tt.prefix)
			if id == id2 {
				t.Error("expected unique IDs")
			}
		})
	}
}

func TestHashString(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "simple string",
			input:    "hello",
			expected: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
		},
		{
			name:     "empty string",
			input:    "",
			expected: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := HashString(tt.input)
			if got != tt.expected {
				t.Errorf("HashString() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestPointerHelpers(t *testing.T) {
	t.Run("StringPtr and StringValue", func(t *testing.T) {
		str := "test"
		ptr := StringPtr(str)
		if ptr == nil {
			t.Fatal("expected non-nil pointer")
		}
		if *ptr != str {
			t.Errorf("expected %s, got %s", str, *ptr)
		}
		
		val := StringValue(ptr)
		if val != str {
			t.Errorf("expected %s, got %s", str, val)
		}
		
		// Test nil pointer
		val = StringValue(nil)
		if val != "" {
			t.Errorf("expected empty string for nil pointer, got %s", val)
		}
	})

	t.Run("IntPtr and IntValue", func(t *testing.T) {
		num := 42
		ptr := IntPtr(num)
		if ptr == nil {
			t.Fatal("expected non-nil pointer")
		}
		if *ptr != num {
			t.Errorf("expected %d, got %d", num, *ptr)
		}
		
		val := IntValue(ptr)
		if val != num {
			t.Errorf("expected %d, got %d", num, val)
		}
		
		// Test nil pointer
		val = IntValue(nil)
		if val != 0 {
			t.Errorf("expected 0 for nil pointer, got %d", val)
		}
	})

	t.Run("TimePtr and TimeValue", func(t *testing.T) {
		now := time.Now()
		ptr := TimePtr(now)
		if ptr == nil {
			t.Fatal("expected non-nil pointer")
		}
		if !ptr.Equal(now) {
			t.Errorf("expected %v, got %v", now, *ptr)
		}
		
		val := TimeValue(ptr)
		if !val.Equal(now) {
			t.Errorf("expected %v, got %v", now, val)
		}
		
		// Test nil pointer
		val = TimeValue(nil)
		if !val.IsZero() {
			t.Errorf("expected zero time for nil pointer, got %v", val)
		}
	})
}

func TestContains(t *testing.T) {
	slice := []string{"apple", "banana", "cherry"}
	
	tests := []struct {
		name     string
		item     string
		expected bool
	}{
		{"item exists", "banana", true},
		{"item doesn't exist", "grape", false},
		{"empty string", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Contains(slice, tt.item)
			if got != tt.expected {
				t.Errorf("Contains() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestContainsInt(t *testing.T) {
	slice := []int{1, 2, 3, 4, 5}
	
	tests := []struct {
		name     string
		item     int
		expected bool
	}{
		{"item exists", 3, true},
		{"item doesn't exist", 10, false},
		{"zero", 0, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ContainsInt(slice, tt.item)
			if got != tt.expected {
				t.Errorf("ContainsInt() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestTruncateString(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		maxLen   int
		expected string
	}{
		{"no truncation needed", "hello", 10, "hello"},
		{"truncate with ellipsis", "hello world", 8, "hello..."},
		{"exact length", "hello", 5, "hello"},
		{"very short maxLen", "hello", 2, "he"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := TruncateString(tt.input, tt.maxLen)
			if got != tt.expected {
				t.Errorf("TruncateString() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestSanitizeSubdomain(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{"valid subdomain", "mycompany", "mycompany"},
		{"uppercase", "MyCompany", "mycompany"},
		{"with spaces", "my company", "mycompany"},
		{"with hyphens", "my-company", "my-company"},
		{"with special chars", "my_company!", "mycompany"},
		{"leading/trailing hyphens", "-mycompany-", "mycompany"},
		{"numbers", "company123", "company123"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := SanitizeSubdomain(tt.input)
			if got != tt.expected {
				t.Errorf("SanitizeSubdomain() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestValidateEmail(t *testing.T) {
	tests := []struct {
		name     string
		email    string
		expected bool
	}{
		{"valid email", "user@example.com", true},
		{"valid email with subdomain", "user@mail.example.com", true},
		{"no @", "userexample.com", false},
		{"no domain", "user@", false},
		{"no local part", "@example.com", false},
		{"multiple @", "user@@example.com", false},
		{"no TLD", "user@example", false},
		{"empty string", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ValidateEmail(tt.email)
			if got != tt.expected {
				t.Errorf("ValidateEmail(%s) = %v, want %v", tt.email, got, tt.expected)
			}
		})
	}
}

func TestPaginate(t *testing.T) {
	tests := []struct {
		name           string
		page           int
		limit          int
		expectedOffset int
		expectedLimit  int
	}{
		{"first page", 1, 20, 0, 20},
		{"second page", 2, 20, 20, 20},
		{"invalid page", 0, 20, 0, 20},
		{"invalid limit", 1, 0, 0, 20},
		{"limit too high", 1, 200, 0, 100},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			offset, limit := Paginate(tt.page, tt.limit)
			if offset != tt.expectedOffset {
				t.Errorf("offset = %v, want %v", offset, tt.expectedOffset)
			}
			if limit != tt.expectedLimit {
				t.Errorf("limit = %v, want %v", limit, tt.expectedLimit)
			}
		})
	}
}

func TestCalculateTotalPages(t *testing.T) {
	tests := []struct {
		name     string
		total    int
		limit    int
		expected int
	}{
		{"exact division", 100, 20, 5},
		{"with remainder", 105, 20, 6},
		{"less than one page", 15, 20, 1},
		{"zero total", 0, 20, 0},
		{"zero limit", 100, 0, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CalculateTotalPages(tt.total, tt.limit)
			if got != tt.expected {
				t.Errorf("CalculateTotalPages() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestRemoveDuplicates(t *testing.T) {
	tests := []struct {
		name     string
		input    []string
		expected []string
	}{
		{
			name:     "with duplicates",
			input:    []string{"a", "b", "a", "c", "b"},
			expected: []string{"a", "b", "c"},
		},
		{
			name:     "no duplicates",
			input:    []string{"a", "b", "c"},
			expected: []string{"a", "b", "c"},
		},
		{
			name:     "empty slice",
			input:    []string{},
			expected: []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := RemoveDuplicates(tt.input)
			if len(got) != len(tt.expected) {
				t.Errorf("len = %v, want %v", len(got), len(tt.expected))
			}
		})
	}
}

func TestChunkSlice(t *testing.T) {
	tests := []struct {
		name          string
		input         []string
		chunkSize     int
		expectedChunks int
	}{
		{"normal chunking", []string{"a", "b", "c", "d", "e"}, 2, 3},
		{"exact chunks", []string{"a", "b", "c", "d"}, 2, 2},
		{"chunk larger than slice", []string{"a", "b"}, 5, 1},
		{"invalid chunk size", []string{"a", "b"}, 0, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ChunkSlice(tt.input, tt.chunkSize)
			if len(got) != tt.expectedChunks {
				t.Errorf("chunks = %v, want %v", len(got), tt.expectedChunks)
			}
		})
	}
}

func TestDefaultString(t *testing.T) {
	tests := []struct {
		name         string
		value        string
		defaultValue string
		expected     string
	}{
		{"non-empty value", "hello", "default", "hello"},
		{"empty value", "", "default", "default"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := DefaultString(tt.value, tt.defaultValue)
			if got != tt.expected {
				t.Errorf("DefaultString() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestDefaultInt(t *testing.T) {
	tests := []struct {
		name         string
		value        int
		defaultValue int
		expected     int
	}{
		{"non-zero value", 42, 10, 42},
		{"zero value", 0, 10, 10},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := DefaultInt(tt.value, tt.defaultValue)
			if got != tt.expected {
				t.Errorf("DefaultInt() = %v, want %v", got, tt.expected)
			}
		})
	}
}
