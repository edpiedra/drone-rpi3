from src.utilities.orbbec_astra import AstraPi3
from src.utilities.body_detector import BodyDetector

import time 

camera = AstraPi3()
detector = BodyDetector()

while True:
    try:
        frame = camera.get_color_frame()
        _ = camera.get_depth_frame()
        
        bodies = detector.detect_bodies(frame)
        centers = detector.get_body_centers(bodies)
        
        print(centers)
        time.sleep(0.01)
        
    except KeyboardInterrupt:
        break

camera.__destroy__()
