import cv2
import logging 

from typing import List, Tuple

logger = logging.getLogger(__name__)

# full list of cascade types can be found in data/haarcascades
CASCADE_TYPE = 'fullbody'

class BodyDetector:
    def __init__(self):
        """
        Creates a BodyDetector object that uses haarcascade filters.
        """
        cascade_filename = f'./data/haarcascades/haarcascade_{CASCADE_TYPE}.xml'
        self.body_cascade = cv2.CascadeClassifier(cascade_filename)
        if self.body_cascade.empty():
            raise RuntimeError(f"Failed to load cascade: {cascade_filename}")

    def detect_bodies(self, frame) -> List[Tuple[int, int, int, int]]:
        """
        Scans a frame for bodies.

        Args:
            frame: RGB or BGR image (HxWx3)
        Returns:
            list of (x, y, w, h) for each detected body
        """
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        bodies = self.body_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=3)
        return bodies

    def get_body_centers(self, bodies: List[Tuple[int, int, int, int]]) -> List[Tuple[int, int]]:
        """
        Returns a list of centers for each body

        Args:
            bodies: iterable of (x, y, w, h)
        Returns:
            list[(cx, cy)]
        """
        centers = []
        for (x, y, w, h) in bodies:
            center_x = x + w // 2
            center_y = y + h // 2
            centers.append((center_x, center_y))
        return centers