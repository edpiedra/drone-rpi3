import cv2
import logging 

import numpy as np

from openni import openni2
from openni import _openni2 as c_api
from typing import Optional 

logger = logging.getLogger(__name__)

class AstraPi3:
    def __init__(self, width: int = 320, height: int = 240, fps: int = 30):
        """
        Creates a camera object and starts depth + color streams.
        
        Args:
            width : in pixels (320, 640, ...)
            height : in pixels (240, 480, ...)
            fps : frames per second (typically 30)
        """
        self.width = width
        self.height = height
        self.fps = fps
        self._opened = False

        openni2.initialize()
        devs = openni2.Device.open_all()
        if not devs:
            logger.error('no OpenNI-compatible device found.')
            openni2.unload()
            raise RuntimeError("No OpenNI-compatible device found.")
        dev = devs[0]

        # Depth stream
        self.depth_stream = dev.create_depth_stream()
        self.depth_stream.set_video_mode(c_api.OniVideoMode(
            pixelFormat=c_api.OniPixelFormat.ONI_PIXEL_FORMAT_DEPTH_100_UM,
            resolutionX=self.width,
            resolutionY=self.height,
            fps=self.fps,
        ))
        self.depth_stream.start()

        # Color stream
        self.color_stream = dev.create_color_stream()
        self.color_stream.set_video_mode(c_api.OniVideoMode(
            pixelFormat=c_api.OniPixelFormat.ONI_PIXEL_FORMAT_RGB888,
            resolutionX=self.width,
            resolutionY=self.height,
            fps=self.fps,
        ))
        self.color_stream.start()

        # Align depth to color
        dev.set_image_registration_mode(openni2.IMAGE_REGISTRATION_DEPTH_TO_COLOR)
        dev.set_depth_color_sync_enabled(True)
        self._opened = True

    # Optional: context manager support
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.__destroy__()

    def __destroy__(self):
        if not self._opened:
            return
        try:
            self.depth_stream.stop()
        except Exception:
            pass
        try:
            self.color_stream.stop()
        except Exception:
            pass
        try:
            openni2.unload()
        finally:
            self._opened = False

    def _wait(self, stream, timeout_ms: int) -> bool:
        try:
            openni2.wait_for_any_stream([stream], timeout_ms)
            return True
        except Exception:
            return False

    def get_depth_frame(self, timeout_ms: int = 50) -> Optional[np.ndarray]:
        """
        Returns a 2D depth frame (uint16) or None on timeout.
        """
        if not self._wait(self.depth_stream, timeout_ms):
            return None
        frame = self.depth_stream.read_frame()
        frame_data = frame.get_buffer_as_uint16()
        img = np.frombuffer(frame_data, dtype=np.uint16)
        img.shape = (self.height, self.width)
        img = cv2.medianBlur(img, 3)
        img = cv2.flip(img, 1)
        return img

    def get_color_frame(self, timeout_ms: int = 50) -> Optional[np.ndarray]:
        """
        Returns an RGB frame (uint8 HxWx3) or None on timeout.
        """
        if not self._wait(self.color_stream, timeout_ms):
            return None
        frame = self.color_stream.read_frame()
        frame_data = frame.get_buffer_as_uint8()
        img = np.frombuffer(frame_data, dtype=np.uint8)
        img.shape = (self.height, self.width, 3)
        img = cv2.flip(img, 1)
        return img