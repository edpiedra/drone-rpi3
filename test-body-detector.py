from src.utilities.orbbec_astra import AstraPi3
from src.utilities.body_detector import BodyDetector
import time

# Tip: you can also use: with AstraPi3() as camera:
# which guarantees cleanup even on unexpected exceptions
camera = AstraPi3()

detector = BodyDetector()

try:
    while True:
        # Non-blocking reads with short timeouts; return None on timeout
        frame = camera.get_color_frame()
        depth = camera.get_depth_frame()

        if frame is None or depth is None:
            # No new frame yet; yield to allow signal processing
            time.sleep(0.005)
            continue

        bodies = detector.detect_bodies(frame)
        centers = detector.get_body_centers(bodies)
        print(centers)

        # Tiny sleep so we don't starve the interpreter
        time.sleep(0.005)
except KeyboardInterrupt:
    # Immediate Ctrl+C exit
    pass
finally:
    # Always clean up hardware resources
    camera.__destroy__()
    print("Shutdown complete.")