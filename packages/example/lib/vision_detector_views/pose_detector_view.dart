import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as UI;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit_example/vision_detector_views/gallery_view2.dart';
import 'package:google_ml_kit_example/vision_detector_views/gallery_view3.dart';
import 'package:google_ml_kit_example/vision_detector_views/painters/image_painter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'detector_view.dart';
import 'gallery_view.dart';
import 'painters/pose_painter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

final db = FirebaseFirestore.instance;

class BenchmarkServices {
  String collection = "";
  //for data collection
  bool benchmark = true;
  Future<Map<String, dynamic>> getValues(
      String camera_angle, String player, String attribute) async {
    if (attribute.toLowerCase() == "bowling") {
      collection = "bowling_benchmarks";
    } else {
      collection = "batting_benchmarks";
    }

    Map<String, dynamic> data = {};
    final docRef = FirebaseFirestore.instance
        .collection(collection)
        .doc(camera_angle)
        .collection(player);
    await docRef.get().then(
      (QuerySnapshot querySnapshot) {
        print("Inside benchmark services");
        for (var doc in querySnapshot.docs) {
          data = doc.data() as Map<String, dynamic>;
          print(doc.id);
          print(data.toString());
        }
      },
    );
    return data["metrics"];
  }

  Future<String> setValues(String category, String camera_angle, String player,
      Pose data, String shot_type, String image_url) async {
    Map<String, Map<String, double>> finalData = {};
    if (category == "batting") {
      collection = "batting_benchmarks";
    } else {
      collection = "bowling_benchmarks";
    }

    final docRef = FirebaseFirestore.instance
        .collection(collection)
        .doc(camera_angle)
        .collection(player)
        .doc();
    for (MapEntry<PoseLandmarkType, PoseLandmark> item
        in data.landmarks.entries) {
      finalData[item.key.name] = {
        'x': item.value.x,
        'y': item.value.y,
        'z': item.value.z
      };
    }
    await docRef.set({
      "metrics": finalData,
      "shot_type": shot_type,
      "image_url": image_url,
      "created_at": Timestamp.now(),
      "kind": benchmark ? "benchmark" : "user"
    }).then((value) {
      return "Done";
    });
    return "Error";
  }
}

class PoseDetectorView extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  final PoseDetector _poseDetector =
      PoseDetector(options: PoseDetectorOptions());
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;
  List<Pose> poses = [];
  List<PoseLandmark> landmarks = [];
  late Image image;
  //Set data of benchmarks
  bool benchmark = true;

  @override
  void dispose() async {
    _canProcess = false;
    _poseDetector.close();
    super.dispose();
  }

  void _onDetectorViewModeChanged() {
    DetectorViewMode _mode = DetectorViewMode.gallery;
    if (_mode == DetectorViewMode.liveFeed) {
      _mode = DetectorViewMode.gallery;
    } else {
      _mode = DetectorViewMode.liveFeed;
    }
    setState(() {});
  }

  Future<double> compareAttributes(
      String camera_angle, String player, Map<String, double> compare) async {
    Map<String, dynamic> base =
        await BenchmarkServices().getValues(camera_angle, player, "batting");
    double sim_score = 0;
    List<double> entries = [];
    // ignore: unused_local_variable
    base.forEach((key, value) {
      entries.add((value + compare[key]!) / value);
    });
    entries.forEach((e) => sim_score += e);
    return entries.length > 0 ? sim_score / entries.length : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // return DetectorView(
    //   title: 'Pose Detector',
    //   customPaint: _customPaint,
    //   text: _text,
    //   onImage: _processImage,
    //   initialCameraLensDirection: _cameraLensDirection,
    //   onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    // );
    return _customPaint == null
        ? GalleryView2(
            title: 'Pose Detector - Gallery',
            onImage: _processImage2,
            onDetectorViewModeChanged: _onDetectorViewModeChanged,
            customPaint: Container(),
          )
        : GalleryView2(
            title: 'Display',
            onImage: _processImage2,
            onDetectorViewModeChanged: _onDetectorViewModeChanged,
            customPaint: _customPaint!,
          );

    //}
  }

  double angleBetween2Lines(List l1, List l2, List l3, List l4) {
    double angle1 = atan2(l1[1] - l2[1], l1[0] - l2[0]);
    double angle2 = atan2(l3[1] - l4[1], l3[0] - l4[0]);
    ;
    return angle1 - angle2;
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    poses = await _poseDetector.processImage(inputImage);
    UI.Size? size;
    InputImageRotation? rotation;
    //final Map<String, Double> lines = {};
    print("BB: ${poses.length}");
    if (poses.isNotEmpty) {
      for (Pose pose in poses) {
        landmarks.add(pose.landmarks[PoseLandmarkType.leftElbow!]!);
      }

      Point p1 = Point(poses[0].landmarks[PoseLandmarkType.leftElbow]!.x,
          poses[0].landmarks[PoseLandmarkType.leftElbow]!.y);
      Point p2 = Point(poses[0].landmarks[PoseLandmarkType.leftShoulder]!.x,
          poses[0].landmarks[PoseLandmarkType.leftShoulder]!.y);
      //double distance = p1.distanceTo(p2);
      Point p3 = Point(poses[0].landmarks[PoseLandmarkType.leftWrist]!.x,
          poses[0].landmarks[PoseLandmarkType.leftWrist]!.y);
      //Angle between lines elbow-shoulder and elbow-wrist
      double angle = angleBetween2Lines(
          [p1.x, p1.y], [p2.x, p2.y], [p1.x, p1.y], [p3.x, p3.y]);
      print("Left hand Angle is: $angle");
      p1 = Point(poses[0].landmarks[PoseLandmarkType.rightElbow]!.x,
          poses[0].landmarks[PoseLandmarkType.rightElbow]!.y);
      p2 = Point(poses[0].landmarks[PoseLandmarkType.rightShoulder]!.x,
          poses[0].landmarks[PoseLandmarkType.rightShoulder]!.y);
      //double distance = p1.distanceTo(p2);
      p3 = Point(poses[0].landmarks[PoseLandmarkType.rightWrist]!.x,
          poses[0].landmarks[PoseLandmarkType.rightWrist]!.y);
      //Angle between lines elbow-shoulder and elbow-wrist
      angle = angleBetween2Lines(
          [p1.x, p1.y], [p2.x, p2.y], [p1.x, p1.y], [p3.x, p3.y]);
      print("Right hand Angle is: $angle");
      p1 = Point(poses[0].landmarks[PoseLandmarkType.leftKnee]!.x,
          poses[0].landmarks[PoseLandmarkType.leftKnee]!.y);
      p2 = Point(poses[0].landmarks[PoseLandmarkType.leftAnkle]!.x,
          poses[0].landmarks[PoseLandmarkType.leftAnkle]!.y);
      //double distance = p1.distanceTo(p2);
      p3 = Point(poses[0].landmarks[PoseLandmarkType.leftHip]!.x,
          poses[0].landmarks[PoseLandmarkType.leftHip]!.y);
      //Angle between lines elbow-shoulder and elbow-wrist
      angle = angleBetween2Lines(
          [p1.x, p1.y], [p2.x, p2.y], [p1.x, p1.y], [p3.x, p3.y]);
      print("left leg Angle is: $angle");
      p1 = Point(poses[0].landmarks[PoseLandmarkType.rightKnee]!.x,
          poses[0].landmarks[PoseLandmarkType.rightKnee]!.y);
      p2 = Point(poses[0].landmarks[PoseLandmarkType.rightAnkle]!.x,
          poses[0].landmarks[PoseLandmarkType.rightAnkle]!.y);
      //double distance = p1.distanceTo(p2);
      p3 = Point(poses[0].landmarks[PoseLandmarkType.rightHip]!.x,
          poses[0].landmarks[PoseLandmarkType.rightHip]!.y);
      //Angle between lines elbow-shoulder and elbow-wrist
      angle = angleBetween2Lines(
          [p1.x, p1.y], [p2.x, p2.y], [p1.x, p1.y], [p3.x, p3.y]);
      print("Right leg Angle is: $angle");

      //print(angle);
    }
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      print("About to custom paint");
      _customPaint = CustomPaint(
        painter: painter,
      );
    } else {
      _text = 'Poses found: ${poses.length}\n\n';
      Point p1 = Point(poses[0].landmarks[PoseLandmarkType.leftElbow]!.x,
          poses[0].landmarks[PoseLandmarkType.leftElbow]!.y);
      Point p2 = Point(poses[0].landmarks[PoseLandmarkType.leftShoulder]!.x,
          poses[0].landmarks[PoseLandmarkType.leftShoulder]!.y);
      //double distance = p1.distanceTo(p2);
      Point p3 = Point(poses[0].landmarks[PoseLandmarkType.leftWrist]!.x,
          poses[0].landmarks[PoseLandmarkType.leftWrist]!.y);
      //Angle between lines elbow-shoulder and elbow-wrist
      double angle = angleBetween2Lines(
          [p1.x, p1.y], [p2.x, p2.y], [p1.x, p1.y], [p3.x, p3.y]);
      print("Left hand Angle is: $angle");
      p1 = Point(poses[0].landmarks[PoseLandmarkType.rightElbow]!.x,
          poses[0].landmarks[PoseLandmarkType.rightElbow]!.y);
      p2 = Point(poses[0].landmarks[PoseLandmarkType.rightShoulder]!.x,
          poses[0].landmarks[PoseLandmarkType.rightShoulder]!.y);
      //double distance = p1.distanceTo(p2);
      p3 = Point(poses[0].landmarks[PoseLandmarkType.rightWrist]!.x,
          poses[0].landmarks[PoseLandmarkType.rightWrist]!.y);
      //Angle between lines elbow-shoulder and elbow-wrist
      angle = angleBetween2Lines(
          [p1.x, p1.y], [p2.x, p2.y], [p1.x, p1.y], [p3.x, p3.y]);
      print("Right hand Angle is: $angle");
      p1 = Point(poses[0].landmarks[PoseLandmarkType.leftKnee]!.x,
          poses[0].landmarks[PoseLandmarkType.leftKnee]!.y);
      p2 = Point(poses[0].landmarks[PoseLandmarkType.leftAnkle]!.x,
          poses[0].landmarks[PoseLandmarkType.leftAnkle]!.y);
      //double distance = p1.distanceTo(p2);
      p3 = Point(poses[0].landmarks[PoseLandmarkType.leftHip]!.x,
          poses[0].landmarks[PoseLandmarkType.leftHip]!.y);
      //Angle between lines elbow-shoulder and elbow-wrist
      angle = angleBetween2Lines(
          [p1.x, p1.y], [p2.x, p2.y], [p1.x, p1.y], [p3.x, p3.y]);
      print("left leg Angle is: $angle");
      p1 = Point(poses[0].landmarks[PoseLandmarkType.rightKnee]!.x,
          poses[0].landmarks[PoseLandmarkType.rightKnee]!.y);
      p2 = Point(poses[0].landmarks[PoseLandmarkType.rightAnkle]!.x,
          poses[0].landmarks[PoseLandmarkType.rightAnkle]!.y);
      //double distance = p1.distanceTo(p2);
      p3 = Point(poses[0].landmarks[PoseLandmarkType.rightHip]!.x,
          poses[0].landmarks[PoseLandmarkType.rightHip]!.y);
      //Angle between lines elbow-shoulder and elbow-wrist
      angle = angleBetween2Lines(
          [p1.x, p1.y], [p2.x, p2.y], [p1.x, p1.y], [p3.x, p3.y]);
      print("Right leg Angle is: $angle");
      // TODO: set _customPaint to draw landmarks on top of image
      _customPaint = CustomPaint(
        painter: PoseLandmarkPainter(landmarks, Colors.red),
        child: Container(
          width: image.width?.toDouble(),
          height: image.height?.toDouble(),
          child: image,
        ),
      );
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _processImage2(InputImage inputImage, File path) async {
    bool setData = true;
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final poses = await _poseDetector.processImage(inputImage);
    image = Image.file(path);
    print("BB: ${poses.length}");
    Map<String, double> current_data = {};
    String downloadUrl = "";
    if (poses.isNotEmpty) {
      //Store it
      final storageRef = FirebaseStorage.instance.ref();
      final metadata = SettableMetadata(contentType: "image/jpeg");
      String uniqueFileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference referenceImageToUpload = benchmark
          ? storageRef.child("images/" + uniqueFileName + "_benchmark.jpg")
          : storageRef.child("images/" + uniqueFileName + ".jpg");
      await referenceImageToUpload.putFile(path, metadata);
      downloadUrl = await referenceImageToUpload.getDownloadURL();
    }
    if (setData) {
      var status = await BenchmarkServices().setValues(
          "bowling", "front_view", "siraj", poses[0], "load_up", downloadUrl);
      print(status);
    }

    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      print("About to custom paint");
      _customPaint = CustomPaint(
        painter: painter,
      );
    } else {
      _text = 'Poses found: ${poses.length}\n\n';
      final painter = PosePainter(
        poses,
        UI.Size(1280, 720),
        InputImageRotation.rotation90deg,
        CameraLensDirection.front,
      );
      // TODO: set _customPaint to draw landmarks on top of image
      setState(() {
        _customPaint = CustomPaint(
          foregroundPainter: painter,
          willChange: true,
          child: Container(
            height: 120.0,
            width: 120.0,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                    "https://img1.hscicdn.com/image/upload/f_auto,t_ds_w_1280,q_80/lsci/db/PICTURES/CMS/151200/151200.jpg"),
                fit: BoxFit.fill,
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      });
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }
}
