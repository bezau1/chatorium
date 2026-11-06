// Package store keeps message history on disk, encrypted with AES-256-GCM.
// The random key lives next to the data (mode 0600) and is created on first run.
package store

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"

	"github.com/bezau1/chatorium/hub/internal/proto"
)

type Store struct {
	mu   sync.Mutex
	path string
	aead cipher.AEAD
	msgs []proto.Message
	seen map[string]bool
}

func Open(dir string) (*Store, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	key, err := loadOrCreateKey(filepath.Join(dir, "store.key"))
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	s := &Store{path: filepath.Join(dir, "messages.enc"), aead: aead, seen: map[string]bool{}}
	if err := s.load(); err != nil {
		return nil, err
	}
	return s, nil
}

func loadOrCreateKey(p string) ([]byte, error) {
	if b, err := os.ReadFile(p); err == nil && len(b) == 32 {
		return b, nil
	}
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	return b, os.WriteFile(p, b, 0o600)
}

func (s *Store) load() error {
	raw, err := os.ReadFile(s.path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	n := s.aead.NonceSize()
	if len(raw) < n {
		return errors.New("store: truncated file")
	}
	plain, err := s.aead.Open(nil, raw[:n], raw[n:], nil)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(plain, &s.msgs); err != nil {
		return err
	}
	for _, m := range s.msgs {
		s.seen[m.Platform+"/"+m.ID] = true
	}
	return nil
}

func (s *Store) flush() error {
	plain, err := json.Marshal(s.msgs)
	if err != nil {
		return err
	}
	nonce := make([]byte, s.aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return err
	}
	out := s.aead.Seal(nonce, nonce, plain, nil)
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, out, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}

// Add stores m and reports whether it was new (duplicates are ignored).
func (s *Store) Add(m proto.Message) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	k := m.Platform + "/" + m.ID
	if m.ID != "" && s.seen[k] {
		return false, nil
	}
	s.seen[k] = true
	s.msgs = append(s.msgs, m)
	return true, s.flush()
}

// All returns a copy of the history, oldest first.
func (s *Store) All() []proto.Message {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]proto.Message(nil), s.msgs...)
}
