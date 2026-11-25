package auth

import (
	"testing"
)

func TestPasswordHasher(t *testing.T) {
	h := NewPasswordHasher()

	hash, err := h.Hash("correct horse battery staple")
	if err != nil {
		t.Fatalf("hash failed: %v", err)
	}

	ok, err := h.Verify("correct horse battery staple", hash)
	if err != nil {
		t.Fatalf("verify returned error: %v", err)
	}
	if !ok {
		t.Fatal("expected password to match")
	}

	ok, err = h.Verify("wrong password", hash)
	if err != nil {
		t.Fatalf("verify returned error: %v", err)
	}
	if ok {
		t.Fatal("expected password to not match")
	}
}

func TestGenerateToken(t *testing.T) {
	raw1, hash1, err := GenerateToken()
	if err != nil {
		t.Fatalf("generate token failed: %v", err)
	}
	if raw1 == "" || hash1 == "" {
		t.Fatal("expected non-empty token and hash")
	}
	if HashToken(raw1) != hash1 {
		t.Fatal("hash of raw token did not match stored hash")
	}

	raw2, hash2, err := GenerateToken()
	if err != nil {
		t.Fatalf("generate token failed: %v", err)
	}
	if raw1 == raw2 || hash1 == hash2 {
		t.Fatal("expected unique tokens")
	}
}
