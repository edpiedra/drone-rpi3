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

> use sudo raspi-config to change hostname and password and reboot

> clone repository and install project
```
sudo apt update && sudo apt -y dist-upgrade
sudo reboot
sudo apt install -y git
cd ~
git clone https://github.com/edpiedra/drone-rpi3.git
cd drone-rpi3
chmod +x install/install.sh
bash ./install/install.sh

# it will ask you to plug the orbbec astra mini s camera into the usb and hit ENTER
```

> run test samples
```
cd ~/drone-rpi3
source .venv/bin/activate
python3 -m test-body-detector
python3 -m test-motors
```