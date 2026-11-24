from pathlib import Path

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PythonExpression
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue

WORLD_NAME = 'Autonomous_Target_Tracking_Bot'


def generate_launch_description():

#    camera = Node(
#       package='camera_module',
#        executable='camera_module',
#        parameters=[{'use_sim_time': True, 'show_image': False}],
#        output='screen',
#    )


    camera = Node(
        package='camera_module',
        executable='camera_module',
        name='camera_module',
        output='screen',
        parameters=[{
            'use_sim_time': False,
            'show_image': False,
            'image_topic': '/AGV/camera/img',
        }]
    )

    lidar = Node(
        package='lidar',
        executable='obstacle_detector',
        parameters=[{'use_sim_time': False}],
        output='screen',
    )

    # The NMPC needs CasADi, which is installed only in ros_ws/.venv_nmpc.
    # 'prefix' runs the node with that Python, however the workspace was built.
    venv_python = Path(__file__).resolve().parents[1] / '.venv_nmpc/bin/python'
    nmpc = Node(
        package='nmpc',
        executable='nmpc_controller',
        prefix=str(venv_python),
        parameters=[str(Path(__file__).resolve().parents[1] / 'config/nmpc.yaml'),
                    {'use_sim_time': False}],
        output='screen',
    )

    return LaunchDescription([camera, lidar, nmpc])
