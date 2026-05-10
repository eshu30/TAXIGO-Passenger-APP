// // lib/screens/qr_scanner_screen.dart
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';

// class QRScannerScreen extends StatefulWidget {
//   const QRScannerScreen({super.key});

//   @override
//   State<QRScannerScreen> createState() => _QRScannerScreenState();
// }

// class _QRScannerScreenState extends State<QRScannerScreen> {
//   final MobileScannerController controller = MobileScannerController();
//   String? scannedData;
//   bool flashOn = false;
//   bool isScanningEnabled = true;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: const Text(
//           'Scan QR Code',
//           style: TextStyle(color: Colors.white),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(
//               flashOn ? Icons.flash_on : Icons.flash_off,
//               color: Colors.white,
//             ),
//             onPressed: _toggleFlash,
//           ),
//         ],
//       ),
//       body: Column(
//         children: <Widget>[
//           // QR Scanner Camera View
//           Expanded(
//             flex: 5,
//             child: Stack(
//               children: [
//                 MobileScanner(
//                   controller: controller,
//                   onDetect: (capture) {
//                     if (!isScanningEnabled) return;

//                     final List<Barcode> barcodes = capture.barcodes;
//                     if (barcodes.isNotEmpty) {
//                       final String? code = barcodes.first.rawValue;
//                       if (code != null) {
//                         setState(() {
//                           scannedData = code;
//                           isScanningEnabled = false;
//                         });
//                         _vibrate();
//                       }
//                     }
//                   },
//                 ),
//                 // Overlay text
//                 if (isScanningEnabled)
//                   Positioned(
//                     top: 20,
//                     left: 20,
//                     right: 20,
//                     child: Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.7),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: const Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.qr_code_scanner,
//                             color: Color(0xFFFFC107),
//                             size: 20,
//                           ),
//                           SizedBox(width: 8),
//                           Text(
//                             'Position QR code within the frame',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 14,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),

//           // Bottom Info + Actions
//           Expanded(
//             flex: 1,
//             child: Container(
//               color: Colors.white,
//               padding: const EdgeInsets.all(20),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   if (scannedData != null) ...[
//                     const Icon(Icons.check_circle, color: Colors.green, size: 40),
//                     const SizedBox(height: 8),
//                     const Text(
//                       'QR Code Scanned Successfully!',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.green,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       scannedData!,
//                       style: const TextStyle(fontSize: 12, color: Colors.grey),
//                       textAlign: TextAlign.center,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: () =>
//                                 Navigator.pop(context, scannedData),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: const Color(0xFFFFC107),
//                               foregroundColor: Colors.black,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(25),
//                               ),
//                             ),
//                             child: const Text(
//                               'Use This Code',
//                               style: TextStyle(fontWeight: FontWeight.w600),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: OutlinedButton(
//                             onPressed: _scanAgain,
//                             style: OutlinedButton.styleFrom(
//                               foregroundColor: const Color(0xFFFFC107),
//                               side: const BorderSide(color: Color(0xFFFFC107)),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(25),
//                               ),
//                             ),
//                             child: const Text(
//                               'Scan Again',
//                               style: TextStyle(fontWeight: FontWeight.w600),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ] else ...[
//                     const Icon(Icons.qr_code_2, color: Colors.grey, size: 40),
//                     const SizedBox(height: 8),
//                     const Text(
//                       'Point your camera at a QR code',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w500,
//                         color: Colors.grey,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     const Text(
//                       'Make sure the QR code is well lit and clearly visible',
//                       style: TextStyle(fontSize: 12, color: Colors.grey),
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _toggleFlash() async {
//     await controller.toggleTorch();
//     setState(() {
//       flashOn = !flashOn;
//     });
//   }

//   void _scanAgain() {
//     setState(() {
//       scannedData = null;
//       isScanningEnabled = true;
//     });
//   }

//   void _vibrate() {
//     // Add haptic feedback if needed
//     // HapticFeedback.lightImpact();
//   }

//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }
// }
