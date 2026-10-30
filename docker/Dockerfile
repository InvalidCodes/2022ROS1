# ROS Noetic + Gazebo 11 + RViz with both workspaces built. Runs headless on any Docker host,
# including Apple Silicon Macs where ROS 1 has no native install.
#
#   docker build -t ros1-racecar -f docker/Dockerfile .
FROM ros:noetic

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-noetic-desktop-full \
        ros-noetic-ackermann-msgs ros-noetic-gazebo-ros-control ros-noetic-ros-controllers \
        ros-noetic-gmapping ros-noetic-navigation ros-noetic-teb-local-planner \
        ros-noetic-joy ros-noetic-serial \
        python3-catkin-tools python3-tk libopencv-dev \
        xvfb ffmpeg x11vnc novnc websockify fluxbox \
    && rm -rf /var/lib/apt/lists/*

# The runway world uses construction_cone from Gazebo's retired online model database.
# Fetch it from the model repository and stop Gazebo from trying to download anything.
ARG CONE=https://raw.githubusercontent.com/osrf/gazebo_models/master/construction_cone
ADD ${CONE}/model.config ${CONE}/model.sdf /root/.gazebo/models/construction_cone/
ADD ${CONE}/meshes/construction_cone.dae /root/.gazebo/models/construction_cone/meshes/
ADD ${CONE}/materials/textures/Construction_Cone_Diffuse.png /root/.gazebo/models/construction_cone/materials/textures/
ENV GAZEBO_MODEL_DATABASE_URI="" DISABLE_ROS1_EOL_WARNINGS=1

COPY racecar_ws/src /ws/racecar_ws/src
COPY ws_rviz/src /ws/ws_rviz/src
RUN . /opt/ros/noetic/setup.sh \
    && cd /ws/racecar_ws && catkin config --extend /opt/ros/noetic && catkin build --no-status --summarize \
    && cd /ws/ws_rviz && catkin config --extend /ws/racecar_ws/devel && catkin build --no-status --summarize \
    && rm -rf /ws/*/build /ws/*/logs

COPY docker/*.sh /opt/demo/
COPY docker/rviz /opt/demo/rviz
ENV PATH=/opt/demo:$PATH
WORKDIR /ws
ENTRYPOINT ["/opt/demo/entrypoint.sh"]
CMD ["bash"]
