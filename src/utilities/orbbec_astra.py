from openni import openni2 
from openni import _openni2 as c_api
import cv2 
import numpy as np

class AstraPi3:
    def __init__(self):
        '''
        Creates an camera object.
        '''
        self.width = 320
        self.height = 240
        fps = 30
        
        openni2.initialize()
        dev = openni2.Device.open_all()[0]
        
        self.depth_stream = dev.create_depth_stream()
        
        self.depth_stream.set_video_mode(c_api.OniVideoMode(pixelFormat=c_api.OniPixelFormat.ONI_PIXEL_FORMAT_DEPTH_100_UM,
                                                       resolutionX=self.width,
                                                       resolutionY=self.height,
                                                       fps=fps))
        
        self.depth_stream.start()
        
        self.color_stream = dev.create_color_stream()
        
        self.color_stream.set_video_mode(c_api.OniVideoMode(pixelFormat=c_api.OniPixelFormat.ONI_PIXEL_FORMAT_RGB888,
                                                       resolutionX=self.width,
                                                       resolutionY=self.height,
                                                       fps=fps))
        
        self.color_stream.start()
        
        dev.set_image_registration_mode(openni2.IMAGE_REGISTRATION_DEPTH_TO_COLOR)
        dev.set_depth_color_sync_enabled(True)
        
    def __destroy__(self):
        self.depth_stream.stop()
        self.color_stream.stop()
        
        openni2.unload()
        
    def get_depth_frame(self):
        '''
        Returns a 2D depth frame.
        '''
        frame = self.depth_stream.read_frame()
        frame_data = frame.get_buffer_as_uint16()
        img = np.frombuffer(frame_data, dtype=np.uint16) 
        img.shape = (self.height, self.width)
        img = cv2.medianBlur(img, 3)
        img = cv2.flip(img, 1)
        
        return img
    
    def get_color_frame(self):
        '''
        Returns and RGB frame.
        '''
        frame = self.color_stream.read_frame()
        frame_data = frame.get_buffer_as_uint8()
        img = np.frombuffer(frame_data, dtype=np.uint8) 
        img.shape = (self.height, self.width, 3)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        img = cv2.flip(img, 1)
        
        return img