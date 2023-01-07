# ROS1

## Ubuntu 20.04 rosdep 解决

http://www.autolabor.com.cn/book/ROSTutorials/chapter1/12-roskai-fa-gong-ju-an-zhuang/124-an-zhuang-ros.html

## vscode基本流程

http://www.autolabor.com.cn/book/ROSTutorials/chapter1/14-ros-ji-cheng-kai-fa-huan-jing-da-jian/142-an-zhuang-vscode.html

## URDF

语法：

http://www.autolabor.com.cn/book/ROSTutorials/di-6-zhang-ji-qi-ren-xi-tong-fang-zhen/62-fang-zhen-urdf-ji-cheng-rviz/624-urdfyu-fa-xiang-jie-02-link.html

## XACRO转URDF                                                                                                                                 

```shell
roscore
cd ws/src/包名/urdf/xacro
rosrun xacro xacro demo.xacro > demo.urdf
```

## Gazebo

```shell
. devel/setup.zsh
roslaunch <urdf_gazebo包名> <demo.launch> 
```

http://www.autolabor.com.cn/book/ROSTutorials/di-6-zhang-ji-qi-ren-xi-tong-fang-zhen/62-fang-zhen-urdf-ji-cheng-rviz.html