#import "CsZBar.h"


#pragma mark - State

@interface CsZBar ()
@property bool scanInProgress;
@property NSString *scanCallbackId;
@property ZBarReaderViewController *scanReader;
@end


#pragma mark - Synthesize

@implementation CsZBar

@synthesize scanInProgress;
@synthesize scanCallbackId;
@synthesize scanReader;


#pragma mark - Cordova Plugin

- (void)pluginInitialize
{
    self.scanInProgress = NO;
}


#pragma mark - Plugin API

- (void)scan: (CDVInvokedUrlCommand*)command;
{
    if(self.scanInProgress) {
        [self.commandDelegate
         sendPluginResult: [CDVPluginResult
                            resultWithStatus: CDVCommandStatus_ERROR
                            messageAsString:@"A scan is already in progress."]
         callbackId: [command callbackId]];
    } else {
        self.scanInProgress = YES;
        self.scanCallbackId = [command callbackId];
        self.scanReader = [ZBarReaderViewController new];

        self.scanReader.readerDelegate = self;
        self.scanReader.supportedOrientationsMask = ZBarOrientationMaskAll;

        // Get user parameters
        NSDictionary *params = (NSDictionary*) [command argumentAtIndex:0];
        NSString *camera = [params objectForKey:@"camera"];
        if([camera isEqualToString:@"front"]) {
            // We do not set any specific device for the default "back" setting,
            // as not all devices will have a rear-facing camera.
            self.scanReader.cameraDevice = UIImagePickerControllerCameraDeviceFront;
        }
        NSString *flash = [params objectForKey:@"flash"];
        if([flash isEqualToString:@"on"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        } else if([flash isEqualToString:@"off"]) {
            self.scanReader.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        }

        // Hack to hide the bottom bar's Info button... http://stackoverflow.com/a/16353530
        UIView *infoButton = [[[[[self.scanReader.view.subviews objectAtIndex:1] subviews] objectAtIndex:0] subviews] objectAtIndex:3];
        [infoButton setHidden:YES];

        [self.viewController presentModalViewController: self.scanReader animated: YES];
    }
}


#pragma mark - Helpers

- (void)sendScanResult: (CDVPluginResult*)result
{
    [self.commandDelegate sendPluginResult: result callbackId: self.scanCallbackId];
}


#pragma mark - ZBarReaderDelegate

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info
{
    id<NSFastEnumeration> results = [info objectForKey: ZBarReaderControllerResults];
    ZBarSymbol *symbol = nil;
    for(symbol in results) break; // get the first result

    [self.scanReader dismissModalViewControllerAnimated: YES];
    self.scanInProgress = NO;
    [self sendScanResult: [CDVPluginResult
                           resultWithStatus: CDVCommandStatus_OK
                           messageAsString: symbol.data]];
}

- (void) imagePickerControllerDidCancel:(UIImagePickerController*)picker
{
    [self.scanReader dismissModalViewControllerAnimated: YES];
    self.scanInProgress = NO;
    [self sendScanResult: [CDVPluginResult
                           resultWithStatus: CDVCommandStatus_ERROR
                           messageAsString: @"cancelled"]];
}

- (void) readerControllerDidFailToRead:(ZBarReaderController*)reader withRetry:(BOOL)retry
{
    [self.scanReader dismissModalViewControllerAnimated: YES];
    self.scanInProgress = NO;
    [self sendScanResult: [CDVPluginResult
                           resultWithStatus: CDVCommandStatus_ERROR
                           messageAsString: @"Failed"]];
}


@end
