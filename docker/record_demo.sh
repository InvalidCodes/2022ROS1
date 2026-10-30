#!/bin/bash
# Record a demo headlessly: Gazebo (left) and RViz (right) on a virtual 1920x1080 screen while
# the racecar drives itself down the runway, then cut the drive into a side-by-side clip.
#
#   docker run --rm -v "$PWD/out:/out" ros1-racecar record_demo.sh navigation
#   docker run --rm -v "$PWD/out:/out" ros1-racecar record_demo.sh mapping
#
# navigation  move_base + TEB on the saved map; RViz follows the car (costmaps, plans, lidar)
# mapping     the same drive while gmapping builds a new map from the lidar; RViz shows the map
#
# Writes /out/<demo>.mp4 (1.5x speed), /out/<demo>.gif (3x speed) and /out/<demo>_raw.mp4.
DEMO=${1:-navigation}
DURATION=${DURATION:-70}             # seconds of screen recording
GOAL_X=${GOAL_X:-17.5}               # far end of the runway, in the map frame
GOAL_Y=${GOAL_Y:--4.0}
CLIP=${CLIP:-6:53}                   # start:end of the drive inside the raw recording
OUT=${OUT:-/out}

case $DEMO in
  navigation) LAUNCH=racecar_runway_navigation.launch; RVIZ_CROP=798:930:1106:90 ;;
  mapping)    LAUNCH=racecar_runway_mapping.launch;    RVIZ_CROP=460:930:1280:90 ;;
  *) echo "usage: $0 navigation|mapping" >&2; exit 2 ;;
esac
GAZEBO_CROP=460:930:435:74           # the runway column of the Gazebo window
mkdir -p "$OUT"
LOG=$OUT/logs
mkdir -p "$LOG"

export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 QT_X11_NO_MITSHM=1
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
sleep 2

# Gazebo client on the left; the runway world's camera looks straight down on the track.
mkdir -p ~/.gazebo
printf "[geometry]\nx=0\ny=0\nwidth=1100\nheight=1080\n" > ~/.gazebo/gui.ini
roslaunch racecar_gazebo $LAUNCH > "$LOG/$DEMO.roslaunch.log" 2>&1 &

# Wait until the car is spawned and publishing odometry.
for i in $(seq 1 90); do
  rostopic echo -n 1 /vesc/odom/pose/pose/position > /dev/null 2>&1 && break
  sleep 2
done
echo "car up after ~$((i * 2)) s"
# The keyboard-teleop window would sit on top of the Gazebo view.
rosnode kill /keyboard_teleop > /dev/null 2>&1
sleep 5

rosrun rviz rviz -d /opt/demo/rviz/$DEMO.rviz > "$LOG/$DEMO.rviz.log" 2>&1 &
sleep 15

RAW=$OUT/${DEMO}_raw.mp4
ffmpeg -loglevel error -y -f x11grab -draw_mouse 0 -video_size 1920x1080 -framerate 10 -i :99 \
       -t "$DURATION" -c:v libx264 -preset ultrafast -crf 20 -pix_fmt yuv420p "$RAW" &
FFMPEG=$!
sleep 3
rostopic pub -1 /move_base_simple/goal geometry_msgs/PoseStamped \
  "{header: {frame_id: map}, pose: {position: {x: $GOAL_X, y: $GOAL_Y, z: 0}, orientation: {w: 1}}}"
# move_base only plans; this pure-pursuit node turns the plan into Ackermann commands.
rosrun racecar_gazebo path_pursuit.py > "$LOG/$DEMO.pursuit.log" 2>&1 &
wait $FFMPEG
rostopic echo -n 1 /vesc/odom/pose/pose/position | tee "$LOG/$DEMO.final_position.txt"

# Cut out the drive, crop both windows to the track and put them side by side.
SIDE="[0:v]trim=${CLIP},setpts=PTS-STARTPTS,split[a][b];[a]crop=${GAZEBO_CROP}[g];[b]crop=${RVIZ_CROP}[r];[g][r]hstack=inputs=2"
ffmpeg -loglevel error -y -i "$RAW" -filter_complex "${SIDE},setpts=PTS/1.5" \
       -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart "$OUT/$DEMO.mp4"
# The output rate (-r) rather than an fps filter: ffmpeg 4.2's fps filter undoes the speed-up.
ffmpeg -loglevel error -y -i "$RAW" -filter_complex \
       "${SIDE},setpts=PTS/3,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=160[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" \
       -r 8 "$OUT/$DEMO.gif"
echo "wrote $OUT/$DEMO.mp4 and $OUT/$DEMO.gif"
