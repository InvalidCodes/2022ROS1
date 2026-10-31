#!/bin/bash
# Record a demo headlessly: Gazebo (left) and RViz (right) on a virtual 1920x1080 screen while
# the robot drives itself, then cut the drive into a side-by-side clip.
#
#   docker run --rm -v "$PWD/out:/out" ros1-racecar record_demo.sh rmus_mapping
#
# rmus_mapping        two-wheel car in the RMUS field, gmapping + move_base along a route
# rmus_navigation     the same car on the saved map, AMCL + move_base to three goals
# racecar_navigation  Ackermann racecar on the runway, move_base + TEB, RViz follows the car
# racecar_mapping     the same drive while gmapping builds a new map of the runway
#
# Writes /out/<demo>.mp4, /out/<demo>.gif and the raw screen recording /out/<demo>_raw.mp4.
DEMO=${1:-rmus_mapping}
OUT=${OUT:-/out}
LOG=$OUT/logs
mkdir -p "$LOG"

case $DEMO in
  rmus_mapping|rmus_navigation)
    [ $DEMO = rmus_mapping ] && LAUNCH="nav-demo rmus_slam.launch" ROUTE=slam
    [ $DEMO = rmus_navigation ] && LAUNCH="nav-demo rmus_nav.launch" ROUTE=nav
    ODOM=/odom GAZEBO_WIDTH=1300
    # The whole field in both windows; RViz is scaled to the height of the Gazebo crop.
    CROP="[a]crop=640:800:462:100[g];[b]crop=540:974:1340:66,scale=-2:800[r]"
    MP4_SPEED=3 GIF_SPEED=8 ;;
  racecar_navigation|racecar_mapping)
    [ $DEMO = racecar_navigation ] && LAUNCH="racecar_gazebo racecar_runway_navigation.launch" RVIZ_CROP=798:930:1106:90
    [ $DEMO = racecar_mapping ] && LAUNCH="racecar_gazebo racecar_runway_mapping.launch" RVIZ_CROP=460:930:1280:90
    ODOM=/vesc/odom GAZEBO_WIDTH=1100
    CROP="[a]crop=460:930:435:74[g];[b]crop=${RVIZ_CROP}[r]"
    MP4_SPEED=1.5 GIF_SPEED=3 ;;
  *) echo "usage: $0 rmus_mapping|rmus_navigation|racecar_navigation|racecar_mapping" >&2; exit 2 ;;
esac

export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1 QT_X11_NO_MITSHM=1 PYTHONUNBUFFERED=1
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
sleep 2

# Gazebo client on the left; each world's camera is set up to show the whole track or field.
mkdir -p ~/.gazebo
printf "[geometry]\nx=0\ny=0\nwidth=$GAZEBO_WIDTH\nheight=1080\n" > ~/.gazebo/gui.ini
roslaunch $LAUNCH > "$LOG/$DEMO.roslaunch.log" 2>&1 &

# Wait until the robot is spawned and publishing odometry.
for i in $(seq 1 90); do
  rostopic echo -n 1 $ODOM/pose/pose/position > /dev/null 2>&1 && break
  sleep 2
done
echo "robot up after ~$((i * 2)) s"
# The racecar's keyboard-teleop window would sit on top of the Gazebo view.
rosnode kill /keyboard_teleop > /dev/null 2>&1
sleep 5

rosrun rviz rviz -d /opt/demo/rviz/$DEMO.rviz > "$LOG/$DEMO.rviz.log" 2>&1 &
sleep 15

RAW=$OUT/${DEMO}_raw.mp4
ffmpeg -loglevel error -y -f x11grab -draw_mouse 0 -video_size 1920x1080 -framerate 10 -i :99 \
       -t 300 -c:v libx264 -preset ultrafast -crf 20 -pix_fmt yuv420p "$RAW" &
FFMPEG=$!
sleep 3

case $DEMO in
  rmus_*)
    rosrun nav-demo tour.py _route:=$ROUTE 2>&1 | tee "$LOG/$DEMO.tour.log"
    sleep 4
    kill -INT $FFMPEG ;;
  racecar_*)
    rostopic pub -1 /move_base_simple/goal geometry_msgs/PoseStamped \
      "{header: {frame_id: map}, pose: {position: {x: 17.5, y: -4.0, z: 0}, orientation: {w: 1}}}"
    # move_base only plans; this pure-pursuit node turns the plan into Ackermann commands.
    rosrun racecar_gazebo path_pursuit.py > "$LOG/$DEMO.pursuit.log" 2>&1 &
    sleep 50
    kill -INT $FFMPEG ;;
esac
wait $FFMPEG
rostopic echo -n 1 $ODOM/pose/pose/position | tee "$LOG/$DEMO.final_position.txt"
[ $DEMO = rmus_mapping ] && rosrun map_server map_saver -f "$OUT/rmus_field" > /dev/null 2>&1

# Drop the start-up seconds, crop both windows and put them side by side.
SIDE="[0:v]trim=start=3,setpts=PTS-STARTPTS,split[a][b];${CROP};[g][r]hstack=inputs=2"
ffmpeg -loglevel error -y -i "$RAW" -filter_complex "${SIDE},setpts=PTS/${MP4_SPEED}" \
       -c:v libx264 -crf 23 -preset slow -pix_fmt yuv420p -movflags +faststart "$OUT/$DEMO.mp4"
# The output rate (-r) rather than an fps filter: ffmpeg 4.2's fps filter undoes the speed-up.
ffmpeg -loglevel error -y -i "$RAW" -filter_complex \
       "${SIDE},setpts=PTS/${GIF_SPEED},scale=960:-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=4" \
       -r 8 "$OUT/$DEMO.gif"
echo "wrote $OUT/$DEMO.mp4 and $OUT/$DEMO.gif"
