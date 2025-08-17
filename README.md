DRONE ENVIRONMENT

Install Emlid image
-------------------------------------------------------------------
> emlid-raspian-20220608.img.xz using Raspberry Pi Imager
    > update network ssid and psk for local wifi in wpa_supplicant.conf

> boot and follow ArduPilot setup instructions
```
sudo emlidtool ardupilot
# choose <copter> <arducopter> <enable> <start> <Apply>
sudo nano /etc/default/arducopter
sudo systemctl daemon-reload
sudo emlidtool ardupilot
sudo systemctl start arducopter
```

> test connection to Mission Planner on the GCS

> use sudo raspi-config to change hostname and password and reboot

> calibrate ESCs
------------------------------------------------------
```
# set ardupilot to start on boot
sudo emlidtool ardupilot
sudo systemctl start arducopter
# start Mission Planner and connect
# setup -> mandatory hardware -> ESC calibration
# press 'Calibrate ESCs'
# power off, wait 10-15 seconds, and power on.
# ESCs will beep once calibrated
# power off, wait 10-15 seconds, and power on.
```

> test motors
--------------------------------------------------------------------------
```
# setup -> optional hardware -> motor test


> clone repository and install project
```
sudo apt -qq update && sudo apt -y -qq dist-upgrade
sudo apt install -y -qq git
sudo reboot
cd ~
git clone https://github.com/edpiedra/drone-rpi3.git
cd drone-rpi3
bash ./install/install.sh

# it will ask you to plug the orbbec astra mini s camera into the usb and hit ENTER
sudo reboot # when install is finished
```


> run test samples
```
cd ~
sudo /home/pi/openni/OpenNI-Linux-Arm-2.3.0.63/Samples/SimpleRead/Bin/Arm-Release/SimpleRead

cd ~/drone-rpi3
source .venv/bin/activate
python3 -m test-body-detector

sudo /usr/bin/arducopter-A udp:127.0.0.1:14550
python3 -m test-motors
```



```
# cut power to ESCs
sudo pkill -f arducopter
sudo systemctl stop arducopter
# power up ESCs
sudo /usr/bin/arducopter -A udp:192.168.1.31:14550 -E udp:127.0.0.1:14551
```

# alternatively
-----------------------------------------------------
```
# cut power to ESCs
sudo pkill -f arducopter
sudo systemctl stop arducopter
cd ~/drone-rpi3
source .venv/bin/activate

# power up ESCs
python3 -m calibration-script
```