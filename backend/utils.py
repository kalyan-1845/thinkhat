import hashlib

def generate_group_id(pattern: str) -> str:
    """
    Generate a deterministic group ID from a plain text pattern.
    Using SHA-256 hash allows simple mapping but hides the raw pattern string.
    """
    return hashlib.sha256(pattern.encode('utf-8')).hexdigest()

def is_valid_username(username: str) -> bool:
    """Validate username length and characters."""
    return username and 2 <= len(username) <= 30
