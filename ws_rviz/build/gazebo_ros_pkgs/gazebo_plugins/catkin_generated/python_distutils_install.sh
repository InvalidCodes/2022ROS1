#!/bin/sh

if [ -n "$DESTDIR" ] ; then
    case $DESTDIR in
        /*) # ok
            ;;
        *)
            /bin/echo "DESTDIR argument must be absolute... "
            /bin/echo "otherwise python's distutils will bork things."
            exit 1
    esac
fi

echo_and_run() { echo "+ $@" ; "$@" ; }

echo_and_run cd "/home/ge/Desktop/ros1/ws_rviz/src/gazebo_ros_pkgs/gazebo_plugins"

# ensure that Python install destination exists
echo_and_run mkdir -p "$DESTDIR/home/ge/Desktop/ros1/ws_rviz/install/lib/python3/dist-packages"

# Note that PYTHONPATH is pulled from the environment to support installing
# into one location when some dependencies were installed in another
# location, #123.
echo_and_run /usr/bin/env \
    PYTHONPATH="/home/ge/Desktop/ros1/ws_rviz/install/lib/python3/dist-packages:/home/ge/Desktop/ros1/ws_rviz/build/lib/python3/dist-packages:$PYTHONPATH" \
    CATKIN_BINARY_DIR="/home/ge/Desktop/ros1/ws_rviz/build" \
    "/usr/bin/python3" \
    "/home/ge/Desktop/ros1/ws_rviz/src/gazebo_ros_pkgs/gazebo_plugins/setup.py" \
     \
    build --build-base "/home/ge/Desktop/ros1/ws_rviz/build/gazebo_ros_pkgs/gazebo_plugins" \
    install \
    --root="${DESTDIR-/}" \
    --install-layout=deb --prefix="/home/ge/Desktop/ros1/ws_rviz/install" --install-scripts="/home/ge/Desktop/ros1/ws_rviz/install/bin"
