#!/bin/bash
# End-to-end checks without the Gazebo window. CI runs both on every push.
#
#   docker run --rm ros1-racecar test_navigation.sh rmus      # car + AMCL reaches 3 goals
#   docker run --rm ros1-racecar test_navigation.sh racecar   # racecar reaches the runway end
WORLD=${1:-rmus}
LOG=${LOG:-/tmp/test_navigation}
mkdir -p "$LOG"

# gzserver still renders the lidar and cameras, so it needs an X display even without the GUI.
export DISPLAY=:98 LIBGL_ALWAYS_SOFTWARE=1 PYTHONUNBUFFERED=1
Xvfb :98 -screen 0 640x480x24 -nolisten tcp &
sleep 2

case $WORLD in
rmus)
  roslaunch nav-demo rmus_nav.launch gui:=false > "$LOG/roslaunch.log" 2>&1 &
  until rostopic echo -n 1 /odom/pose/pose/position > /dev/null 2>&1; do sleep 2; done
  sleep 5
  timeout 600 rosrun nav-demo tour.py _route:=nav 2>&1 | tee "$LOG/tour.log"
  REACHED=$(grep -c ': reached' "$LOG/tour.log")
  if [ "$REACHED" -eq 3 ]; then echo "PASS: 3/3 goals reached"; exit 0; fi
  echo "FAIL: $REACHED/3 goals reached"
  tail -n 40 "$LOG/roslaunch.log"
  exit 1 ;;
racecar)
  roslaunch racecar_gazebo racecar_runway_navigation.launch gui:=false > "$LOG/roslaunch.log" 2>&1 &
  rosrun racecar_gazebo path_pursuit.py > "$LOG/pursuit.log" 2>&1 &
  ;;
*) echo "usage: $0 rmus|racecar" >&2; exit 2 ;;
esac

# Racecar: send it to the far end of the runway, pass once it is within 0.5 m of the goal.
python3 - 17.5 -4.0 0.5 300 <<'PY'
import math
import sys
import time

import rospy
from geometry_msgs.msg import PoseStamped
from nav_msgs.msg import Odometry

goal_x, goal_y, tolerance, timeout = map(float, sys.argv[1:])
rospy.init_node("test_navigation", disable_signals=True)

rospy.wait_for_message("/vesc/odom", Odometry, timeout=240)
rospy.sleep(5.0)  # let the car settle and move_base finish loading the costmaps
start = rospy.wait_for_message("/vesc/odom", Odometry, timeout=30).pose.pose.position
print(f"car at ({start.x:.2f}, {start.y:.2f}), goal ({goal_x:.2f}, {goal_y:.2f})", flush=True)

goal = PoseStamped()
goal.header.frame_id = "map"
goal.pose.position.x, goal.pose.position.y = goal_x, goal_y
goal.pose.orientation.w = 1.0
pub = rospy.Publisher("/move_base_simple/goal", PoseStamped, queue_size=1, latch=True)
rospy.sleep(1.0)
goal.header.stamp = rospy.Time.now()
pub.publish(goal)

t0 = time.time()
best = math.inf
while time.time() - t0 < timeout:
    p = rospy.wait_for_message("/vesc/odom", Odometry, timeout=30).pose.pose.position
    error = math.hypot(p.x - goal_x, p.y - goal_y)
    best = min(best, error)
    if error < tolerance:
        print(f"PASS: reached ({p.x:.2f}, {p.y:.2f}), {error:.2f} m from the goal, "
              f"after {time.time() - t0:.0f} s", flush=True)
        sys.exit(0)
    time.sleep(2.0)
print(f"FAIL: closest approach {best:.2f} m after {timeout:.0f} s", flush=True)
sys.exit(1)
PY
STATUS=$?
[ $STATUS -ne 0 ] && tail -n 40 "$LOG/roslaunch.log"
exit $STATUS
