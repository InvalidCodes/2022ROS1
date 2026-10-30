#!/bin/bash
# End-to-end check: start the runway simulation without the Gazebo window, send the car to the
# far end of the track and pass once it stops within TOLERANCE metres of the goal.
#
#   docker run --rm ros1-racecar test_navigation.sh
GOAL_X=${GOAL_X:-17.5}
GOAL_Y=${GOAL_Y:--4.0}
TOLERANCE=${TOLERANCE:-0.5}
TIMEOUT=${TIMEOUT:-300}              # seconds of wall-clock time for the drive
LOG=${LOG:-/tmp/test_navigation}
mkdir -p "$LOG"

# gzserver still renders the car's camera, so it needs an X display even without the GUI.
export DISPLAY=:98 LIBGL_ALWAYS_SOFTWARE=1
Xvfb :98 -screen 0 640x480x24 -nolisten tcp &
sleep 2

roslaunch racecar_gazebo racecar_runway_navigation.launch gui:=false > "$LOG/roslaunch.log" 2>&1 &
rosrun racecar_gazebo path_pursuit.py > "$LOG/pursuit.log" 2>&1 &

python3 - "$GOAL_X" "$GOAL_Y" "$TOLERANCE" "$TIMEOUT" <<'PY'
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
