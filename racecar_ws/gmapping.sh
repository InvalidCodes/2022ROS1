gnome-terminal -x zsh -c "./gmapping_1.sh;exec zsh"
sleep 1

roslaunch racecar_gazebo racecar_runway.launch