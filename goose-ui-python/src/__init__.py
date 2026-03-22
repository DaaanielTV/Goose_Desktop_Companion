"""
Goose Desktop Companion - Python UI Layer
Version 2.0 - PyQt5 Cross-Platform Rewrite
"""

__version__ = "2.0.0"
__author__ = "Goose Desktop Companion Contributors"

import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)
