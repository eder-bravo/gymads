//
//  AVCaptureDevice+Extension.swift
//  camera_macos
//
//  Created by riccardo on 04/11/22.
//

import Foundation
import AVFoundation

extension AVCaptureDevice {
    
    @available(macOS 10.15, *)
    public class func captureDevice(deviceTypes: [AVCaptureDevice.DeviceType], mediaType: AVMediaType) -> AVCaptureDevice? {
        var types = deviceTypes
        if mediaType == .video, #available(macOS 14.0, *) {
            types = [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera]
        }
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: mediaType, position: .unspecified).devices
        return devices.first
    }
    
    @available(macOS 10.15, *)
    public class func captureDevices(deviceTypes: [AVCaptureDevice.DeviceType], mediaType: AVMediaType? = nil) -> [AVCaptureDevice] {
        var types = deviceTypes
        if mediaType == .video, #available(macOS 14.0, *) {
            types = [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera]
        }
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: mediaType, position: .unspecified).devices
        return devices
    }
    
    public class func captureDevice(mediaType: AVMediaType) -> AVCaptureDevice? {
        return AVCaptureDevice.devices(for: mediaType).first
    }
    
    public class func captureDevices(mediaType: AVMediaType? = nil) -> [AVCaptureDevice] {
        if mediaType == .video, #available(macOS 14.0, *) {
            return captureDevices(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera, .deskViewCamera], mediaType: .video)
        }
        if let mediaType = mediaType {
            return AVCaptureDevice.devices(for: mediaType)
        } else {
            return AVCaptureDevice.devices()
        }
    }
    
}
