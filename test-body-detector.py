import time

from src.utilities.orbbec_astra import AstraPi3
from src.utilities.body_detector import BodyDetector

detector = BodyDetector()

with AstraPi3() as camera:
    try:
        while True:
            frame = camera.get_color_frame()
            depth = camera.get_depth_frame()

            if frame is None or depth is None:
                time.sleep(0.005)
                continue

            bodies = detector.detect_bodies(frame)
            centers = detector.get_body_centers(bodies)
            print('bodies: ', bodies)
            print('centers: ', centers)

            time.sleep(0.005)
    except KeyboardInterrupt:
        pass
    finally:
        print("Shutdown complete.")