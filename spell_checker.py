# ============================================================
#  SpellCheckManager — Singleton for spell checking across MyPsychAdmin
# ============================================================

from __future__ import annotations

import os
import re
from typing import Optional

from spellchecker import SpellChecker


class SpellCheckManager:
    """
    Singleton class managing spell checking across the application.

    Uses pyspellchecker for spell checking and supports:
    - Custom medical/psychiatric dictionary
    - Word caching for performance
    - RapidFuzz integration for better suggestions
    """

    _instance: Optional[SpellCheckManager] = None

    def __init__(self):
        # Initialize with British English
        self.checker = SpellChecker(language='en')

        # Cache for performance
        self._word_cache: dict[str, bool] = {}
        self._suggestion_cache: dict[str, list[str]] = {}

        # User-added words (persist per session)
        self._user_words: set[str] = set()

        # Load custom medical dictionary
        self._load_medical_dictionary()

    @classmethod
    def instance(cls) -> SpellCheckManager:
        """Get or create the singleton instance."""
        if cls._instance is None:
            cls._instance = SpellCheckManager()
        return cls._instance

    def _load_medical_dictionary(self):
        """Load medical/psychiatric terms from dictionary file."""
        # Try multiple potential locations for the dictionary
        potential_paths = [
            os.path.join(os.path.dirname(__file__), "medical_dictionary.txt"),
            os.path.join(os.path.dirname(__file__), "resources", "medical_dictionary.txt"),
        ]

        # Check for PyInstaller frozen app
        if hasattr(os.sys, '_MEIPASS'):
            potential_paths.insert(0, os.path.join(os.sys._MEIPASS, "medical_dictionary.txt"))

        for dict_path in potential_paths:
            if os.path.exists(dict_path):
                try:
                    with open(dict_path, 'r', encoding='utf-8') as f:
                        words = []
                        for line in f:
                            line = line.strip()
                            if line and not line.startswith('#'):
                                words.append(line.lower())
                        if words:
                            self.checker.word_frequency.load_words(words)
                            print(f"[SPELL] Loaded {len(words)} medical terms from {dict_path}")
                    break
                except Exception as e:
                    print(f"[SPELL] Error loading dictionary: {e}")

    def is_misspelled(self, word: str) -> bool:
        """
        Check if a word is misspelled.

        Args:
            word: The word to check

        Returns:
            True if misspelled, False if correct
        """
        if not word:
            return False

        # Normalize to lowercase for checking
        word_lower = word.lower()

        # Check cache first
        if word_lower in self._word_cache:
            return self._word_cache[word_lower]

        # Skip very short words
        if len(word_lower) < 2:
            self._word_cache[word_lower] = False
            return False

        # Skip words that are all uppercase (acronyms)
        if word.isupper() and len(word) <= 6:
            self._word_cache[word_lower] = False
            return False

        # Skip words with numbers
        if any(c.isdigit() for c in word):
            self._word_cache[word_lower] = False
            return False

        # Skip user-added words
        if word_lower in self._user_words:
            self._word_cache[word_lower] = False
            return False

        # Check with spellchecker
        misspelled = word_lower in self.checker.unknown([word_lower])
        self._word_cache[word_lower] = misspelled

        return misspelled

    def get_suggestions(self, word: str, max_suggestions: int = 5) -> list[str]:
        """
        Get spelling suggestions for a misspelled word.

        Args:
            word: The misspelled word
            max_suggestions: Maximum number of suggestions to return

        Returns:
            List of suggested corrections
        """
        if not word:
            return []

        word_lower = word.lower()

        # Check cache
        if word_lower in self._suggestion_cache:
            return self._suggestion_cache[word_lower][:max_suggestions]

        # Get candidates from spellchecker
        candidates = self.checker.candidates(word_lower)

        if not candidates:
            self._suggestion_cache[word_lower] = []
            return []

        suggestions = list(candidates)

        # Try to rank by similarity using RapidFuzz if available
        try:
            from rapidfuzz import process, fuzz
            if len(suggestions) > max_suggestions:
                ranked = process.extract(
                    word_lower,
                    suggestions,
                    scorer=fuzz.ratio,
                    limit=max_suggestions
                )
                suggestions = [r[0] for r in ranked]
        except ImportError:
            pass

        # Preserve original case if word was capitalized
        if word and word[0].isupper():
            suggestions = [s.capitalize() for s in suggestions]

        self._suggestion_cache[word_lower] = suggestions
        return suggestions[:max_suggestions]

    def add_to_dictionary(self, word: str):
        """
        Add a word to the user dictionary.

        Args:
            word: Word to add
        """
        if not word:
            return

        word_lower = word.lower()
        self._user_words.add(word_lower)
        self.checker.word_frequency.load_words([word_lower])

        # Clear caches for this word
        if word_lower in self._word_cache:
            del self._word_cache[word_lower]
        if word_lower in self._suggestion_cache:
            del self._suggestion_cache[word_lower]

    def clear_cache(self):
        """Clear the word cache (useful if dictionary changes)."""
        self._word_cache.clear()
        self._suggestion_cache.clear()

    def check_batch(self, words: list[str]) -> set[str]:
        """
        Check multiple words at once for efficiency.

        Args:
            words: List of words to check

        Returns:
            Set of misspelled words
        """
        if not words:
            return set()

        # Filter and normalize
        to_check = []
        for word in words:
            if word and len(word) >= 2:
                word_lower = word.lower()
                if word_lower not in self._word_cache:
                    to_check.append(word_lower)

        if to_check:
            # Batch check
            misspelled = self.checker.unknown(to_check)
            for word in to_check:
                self._word_cache[word] = word in misspelled

        # Return misspelled words
        return {w for w in words if self.is_misspelled(w)}
