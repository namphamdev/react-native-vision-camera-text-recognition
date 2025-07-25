#import <Foundation/Foundation.h>
#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>
#import <VisionCamera/Frame.h>


#if __has_include("VisionCameraTextRecognition/VisionCameraTextRecognition-Swift.h")
#import "VisionCameraTextRecognition/VisionCameraTextRecognition-Swift.h"
#else
#import "VisionCameraTextRecognition-Swift.h"
#endif

@interface VisionCameraTextRecognition (FrameProcessorPluginLoader)
@end

@implementation VisionCameraTextRecognition (FrameProcessorPluginLoader)
+ (void) load {
  [FrameProcessorPluginRegistry addFrameProcessorPlugin:@"scanText"
    withInitializer:^FrameProcessorPlugin*(VisionCameraProxyHolder* proxy, NSDictionary* options) {
    return [[VisionCameraTextRecognition alloc] initWithProxy:proxy withOptions:options];
  }];
}
@end



@interface VisionCameraTranslator (FrameProcessorPluginLoader)
@end

@implementation VisionCameraTranslator (FrameProcessorPluginLoader)
+ (void) load {
  [FrameProcessorPluginRegistry addFrameProcessorPlugin:@"translate"
    withInitializer:^FrameProcessorPlugin*(VisionCameraProxyHolder* proxy, NSDictionary* options) {
    return [[VisionCameraTranslator alloc] initWithProxy:proxy withOptions:options];
  }];
}
@end

@interface VisionCameraHearthRate (FrameProcessorPluginLoader)
@end

@implementation VisionCameraHearthRate (FrameProcessorPluginLoader)
+ (void) load {
  [FrameProcessorPluginRegistry addFrameProcessorPlugin:@"getHeartRate"
    withInitializer:^FrameProcessorPlugin*(VisionCameraProxyHolder* proxy, NSDictionary* options) {
    return [[VisionCameraHearthRate alloc] initWithProxy:proxy withOptions:options];
  }];
}
@end


#import <React/RCTBridgeModule.h>
#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(RemoveLanguageModel, NSObject)

RCT_EXTERN_METHOD(remove:(NSString *)code
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end

@interface RCT_EXTERN_MODULE(PhotoRecognizerModule, NSObject)

RCT_EXTERN_METHOD(process:(NSString *)uri
                  orientation:(NSString *)orientation
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)


+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
