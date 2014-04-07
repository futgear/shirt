ViRIS (Virtual Reality Immersion Suit) - shirt
==============================================

This is software for my arduino project.
The idea is to have a motion capture device which
- is affordable
- low latency 
- portable, mobile,... you name it

Current Hardware setup
- Arduino UNO
- several MCP3208 ADC to have more analog inputs
- Gyrosensor to have a rootnode for the body
- several flexible 1-3 axis sensors stitched to a compression sportshirt

All motions of the bodyparts will be measured by the axis sensors relative to the MPUs position.


Arduino sketch 
==============

The sketch uses the data from the MCPs and the MPU and passes it through the serial port (USB) of the arduino.
You will need to import this Library for the MCP3208:
http://arduino.alhin.de/download.php?id=10


Testprogram Processing
======================

I made a script in processing to get started quickly which listens on the serialport and translates the data into a 3D model.

The initial values for all sensors are read from the calibration.txt file inside the data folder.
They are adjustable using the keys as described below.



    variables description:
    ----------------------

    Shoulder fore/back  = upperarm_Y
    Shoulder up/down    = upperarm_Z
    Upperarm rotate     = upperarm_X
    Ellbow              = forearm_Y
    Hand (forearm axis) = forearm_X
    Hand (finger axis)  = hand_Y
    Hand (thumb axis)   = hand_Z


    key bindings:
    -------------

    Select setting you want to change
      w, s

    Increase/decrease selected settings value
      UP, DOWN

    Changing stepsize for increase/decrease
      +, -

    Save calibration.txt
      #

    Load calibration.txt
      l

    Reconnect serial port
      p

    Select port index
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9


VRPN
====

The Virtual Reality Peripheral Network is an Open Source Client-Server System, designed to implement a network-transparent interface between application programs and the set of physical devices (tracker, etc.) used in a virtual-reality (VR) system
http://www.cs.unc.edu/Research/vrpn/


Most of my code is based on the Tutorials from http://www.vrgeeks.org/vrpn/tutorial---vrpn-server and rpavliks fork of the VRPN source.

To get started with the VisualStudio Solutionfiles in the VRPN directory of this repository you need to have following prerequisites.
1. a system environment variable named "DevelopPath" which shows the path to your development root.
2. this repository checked out into your DevelopPath
3. the VRPN repository checked out into your DevelopPath

Open the Server Solution and run it. A window should popup showing the server getting data form the serial port (currently this is hard coded "COM7", see _tmain method).

Open the Client Solution and run it. Another window should popup showing a lot of analog values rushing through it.


