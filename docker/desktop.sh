#!/bin/bash
# Interactive mode: a virtual desktop streamed to the browser through noVNC.
#
#   docker run --rm -p 6080:6080 ros1-racecar desktop.sh            # runway navigation demo
#   docker run --rm -p 6080:6080 ros1-racecar desktop.sh roslaunch racecar_gazebo racecar_runway.launch
#
# then open http://localhost:6080/vnc.html and click Connect.
export DISPLAY=:0 LIBGL_ALWAYS_SOFTWARE=1 QT_X11_NO_MITSHM=1
Xvfb :0 -screen 0 "${RESOLUTION:-1600x900}x24" -nolisten tcp &
sleep 2
fluxbox > /dev/null 2>&1 &
x11vnc -display :0 -forever -shared -nopw -quiet > /dev/null 2>&1 &
websockify --web /usr/share/novnc 6080 localhost:5900 > /dev/null 2>&1 &
echo "Desktop ready: open http://localhost:6080/vnc.html"

if [ $# -eq 0 ]; then
  echo "Pick a target with RViz's 2D Nav Goal tool and the car drives there."
  set -- roslaunch racecar_gazebo racecar_runway_demo.launch
fi
exec "$@"
