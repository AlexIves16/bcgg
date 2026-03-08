import 'dart:math';
import 'package:flutter/material.dart';

class GestureRecognizer {
  // Tracing score: compares actual drawn path to a fixed template on the screen.
  
  static double traceScore(List<Offset> drawnPoints, String shapeName, double radius) {
    if (drawnPoints.length < 5) return 0.0;
    
    // Normalize drawn points (pixel offsets from screen center) to roughly -1..1 relative space
    List<Offset> rawNormalized = drawnPoints.map((p) => Offset(p.dx / radius, p.dy / radius)).toList();
    
    // FORGIVENESS MECHANIC: 
    // The user might have drawn a tiny circle, or drawn it slightly off-center.
    // We scale and translate the user's drawing so its bounding box perfectly matches a standard -1..1 box.
    // This removes the penalty for size and position, and ONLY grades them on SHAPE ACCURACY.
    List<Offset> alignedDrawn = _scaleAndTranslateToStandard(rawNormalized);

    List<Offset> template;
    if (shapeName == 'circle') template = generateCircleTemplate();
    else if (shapeName == 'square') template = generateSquareTemplate();
    else if (shapeName == 'triangle') template = generateTriangleTemplate();
    else return 0.0;
    
    // Resample both paths to have the same number of points for fair comparison
    List<Offset> resampledTemplate = _resample(template, 64);
    List<Offset> resampledDrawn = _resample(alignedDrawn, 64);
    
    // Calculate 2-way distance
    double d1 = _averageMinDistance(resampledTemplate, resampledDrawn); // Did they cover the whole template?
    double d2 = _averageMinDistance(resampledDrawn, resampledTemplate); // Did they stay on the lines?
    
    // Penalize based on the worst of the two metrics
    double maxDist = max(d1, d2);
    
    // Map to percentage. 
    // 0 distance = 100%. 
    // 0.8 distance = 0% (Since we normalized to a 1x1 box, being off by 0.8 is a complete miss)
    double score = 1.0 - (maxDist / 0.8);
    return score.clamp(0.0, 1.0);
  }

  static List<Offset> _scaleAndTranslateToStandard(List<Offset> points) {
    // 1. Find Bounding Box of user's drawing
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (var p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    double width = maxX - minX;
    double height = maxY - minY;
    
    // Fallback preventing division by zero
    if (width == 0) width = 0.1;
    if (height == 0) height = 0.1;

    // Use the largest dimension to maintain aspect ratio, but scale it to width/height of 2 (from -1 to 1)
    double size = max(width, height); 
    double scaleFactor = 2.0 / size;

    // Find center of drawn bounding box
    double cx = minX + width / 2;
    double cy = minY + height / 2;

    List<Offset> alignedPoints = [];
    for (var p in points) {
       // Shift center to 0,0  then apply scale
       double nx = (p.dx - cx) * scaleFactor;
       double ny = (p.dy - cy) * scaleFactor;
       alignedPoints.add(Offset(nx, ny));
    }
    return alignedPoints;
  }
  
  static double _averageMinDistance(List<Offset> path1, List<Offset> path2) {
    List<double> distances = [];
    
    for (var p1 in path1) {
       double minDist = double.infinity;
       for (var p2 in path2) {
          double d = (p1 - p2).distanceSquared; 
          if (d < minDist) minDist = d;
       }
       distances.add(sqrt(minDist));
    }
    
    if (distances.isEmpty) return 0.0;
    
    // Sort ascending
    distances.sort();
    
    // FORGIVENESS: Ignore the best matches, they don't tell us how bad the shape is.
    // We only average the WORST 50% of the points to see how far off the drawing actually strayed.
    // If the worst 50% are still close, the shape is great!
    double totalWorstDist = 0;
    int startIndex = distances.length ~/ 2;
    int count = distances.length - startIndex;
    
    for (int i = startIndex; i < distances.length; i++) {
        totalWorstDist += distances[i];
    }
    
    return totalWorstDist / count;
  }

  static List<Offset> _resample(List<Offset> points, int n) {
    if (points.isEmpty) return [];
    double I = _pathLength(points) / (n - 1); 
    double D = 0.0;
    List<Offset> newPoints = [points.first];
    List<Offset> srcPts = List.from(points);

    for (int i = 1; i < srcPts.length; i++) {
       var p1 = srcPts[i-1];
       var p2 = srcPts[i];
       double d = (p1 - p2).distance;

       if ((D + d) >= I) {
         double qx = p1.dx + ((I - D) / d) * (p2.dx - p1.dx);
         double qy = p1.dy + ((I - D) / d) * (p2.dy - p1.dy);
         var q = Offset(qx, qy);
         newPoints.add(q);
         srcPts.insert(i, q); 
         D = 0.0;
       } else {
         D += d;
       }
    }
    if (newPoints.length == n - 1) {
      newPoints.add(points.last);
    }
    return newPoints;
  }

  static double _pathLength(List<Offset> points) {
    double d = 0;
    for (int i = 1; i < points.length; i++) {
       d += (points[i-1] - points[i]).distance;
    }
    return d;
  }

  static List<Offset> generateCircleTemplate() {
    List<Offset> pts = [];
    for (int i = 0; i <= 60; i++) {
        double angle = (i / 60) * 2 * pi;
        pts.add(Offset(cos(angle), sin(angle)));
    }
    return pts;
  }

  static List<Offset> generateSquareTemplate() {
     return [
       const Offset(-1, -1),
       const Offset(1, -1),
       const Offset(1, 1),
       const Offset(-1, 1),
       const Offset(-1, -1),
     ];
  }

  static List<Offset> generateTriangleTemplate() {
     return [
       const Offset(0, -1),
       const Offset(1, 1),
       const Offset(-1, 1),
       const Offset(0, -1),
     ];
  }
}
