#!/usr/bin/env python3
"""Send the car through a list of waypoints with move_base, one goal after another.

Coordinates are in the map frame, which here matches the field's own coordinates: x from
0 to 15 m across, y from 0 to 28 m along the field. Both routes stay on the floor of the
lower half and the right-hand corridor. The raised platform in the middle is ringed by
9 cm steps that a 2D lidar cannot see, so the planner is not sent across it.

    rosrun nav-demo tour.py                 # mapping route, ends where it started
    rosrun nav-demo tour.py _route:=nav     # three goals far apart, for AMCL
"""
import rospy
import actionlib
from move_base_msgs.msg import MoveBaseAction, MoveBaseGoal

ROUTES = {
    "slam": [(11.0, 3.0), (7.5, 7.0), (11.8, 10.5), (12.2, 13.6), (4.0, 3.7), (4.0, 1.9)],
    "nav": [(12.2, 13.6), (5.5, 6.0), (10.5, 1.8)],
}


def main():
    rospy.init_node("tour")
    route = rospy.get_param("~waypoints", ROUTES[rospy.get_param("~route", "slam")])
    client = actionlib.SimpleActionClient("move_base", MoveBaseAction)
    client.wait_for_server()
    for i, (x, y) in enumerate(route, 1):
        goal = MoveBaseGoal()
        goal.target_pose.header.frame_id = "map"
        goal.target_pose.header.stamp = rospy.Time.now()
        goal.target_pose.pose.position.x, goal.target_pose.pose.position.y = x, y
        goal.target_pose.pose.orientation.w = 1.0
        client.send_goal(goal)
        client.wait_for_result(rospy.Duration(120))
        state = client.get_state()
        rospy.loginfo("waypoint %d/%d (%.1f, %.1f): %s", i, len(route), x, y,
                      "reached" if state == actionlib.GoalStatus.SUCCEEDED else "state %d" % state)


if __name__ == "__main__":
    main()
