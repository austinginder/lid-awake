// Lid Awake — macOS menu bar companion.
//
// Built on the user's machine by `lid-awake menubar enable` — clang + system
// frameworks only. Status is read via `lid-awake status --porcelain`; updates
// are checked against GitHub once a day and installed by `lid-awake update`.

#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#import <ServiceManagement/ServiceManagement.h>

#ifndef LID_AWAKE_BIN
#define LID_AWAKE_BIN ""
#endif

static NSString *const kReleasesURL = @"https://github.com/austinginder/lid-awake/releases";
static const NSTimeInterval kUpdateCheckInterval = 86400.0;

typedef void (^CommandCompletion)(int status, NSString *output, NSError *error);

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *menu;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, strong) NSTimer *updateCheckTimer;
@property(nonatomic, assign) CFAbsoluteTime lastUpdateCheck;
@property(nonatomic, copy) NSString *appVersion;
@property(nonatomic, copy) NSString *latestVersion;
@property(nonatomic, assign) BOOL awakeOn;
@property(nonatomic, assign) BOOL statesKnown;
@property(nonatomic, assign) BOOL busy;
@property(nonatomic, copy) NSString *lastError;
@property(nonatomic, strong) NSImage *onImage;
@property(nonatomic, strong) NSImage *offImage;
@property(nonatomic, strong) NSMenuItem *summaryItem;
@property(nonatomic, strong) NSMenuItem *warningItem;
@property(nonatomic, strong) NSMenuItem *toggleItem;
@property(nonatomic, strong) NSMenuItem *launchItem;
@property(nonatomic, strong) NSMenuItem *versionItem;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.visible = YES;
    [self loadStatusImages];
    [self buildMenu];
    [self updateMenu];

    [[[NSWorkspace sharedWorkspace] notificationCenter]
        addObserver:self
           selector:@selector(didWake)
               name:NSWorkspaceDidWakeNotification
             object:nil];

    [self refreshStatus];

    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:20.0
                                                         target:self
                                                       selector:@selector(refreshStatus)
                                                       userInfo:nil
                                                        repeats:YES];
    self.refreshTimer.tolerance = 5.0;

    // NSTimer stops counting while the Mac sleeps, so a 24 hour timer can take
    // days on a laptop. Tick hourly and compare against the wall clock instead.
    [self checkForUpdates];
    self.updateCheckTimer = [NSTimer scheduledTimerWithTimeInterval:3600.0
                                                             target:self
                                                           selector:@selector(checkForUpdatesIfDue)
                                                           userInfo:nil
                                                            repeats:YES];
    self.updateCheckTimer.tolerance = 600.0;
}

- (void)didWake {
    [self refreshStatus];
    [self checkForUpdatesIfDue];
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self refreshStatus];
}

- (void)buildMenu {
    self.menu = [[NSMenu alloc] init];
    self.menu.autoenablesItems = NO;
    self.menu.delegate = self;

    self.summaryItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    self.summaryItem.enabled = NO;
    [self.menu addItem:self.summaryItem];

    self.warningItem = [[NSMenuItem alloc] initWithTitle:@"Don't leave this on in a bag"
                                                  action:nil
                                           keyEquivalent:@""];
    self.warningItem.enabled = NO;
    self.warningItem.hidden = YES;
    [self.menu addItem:self.warningItem];

    [self.menu addItem:[NSMenuItem separatorItem]];

    self.toggleItem = [[NSMenuItem alloc] initWithTitle:@"Turn On"
                                                 action:@selector(toggleAwake)
                                          keyEquivalent:@""];
    self.toggleItem.target = self;
    [self.menu addItem:self.toggleItem];

    [self.menu addItem:[NSMenuItem separatorItem]];

    self.launchItem = [[NSMenuItem alloc] initWithTitle:@"Launch at Login"
                                                 action:@selector(toggleLaunchAtLogin)
                                          keyEquivalent:@""];
    self.launchItem.target = self;
    [self.menu addItem:self.launchItem];

    self.versionItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    self.versionItem.target = self;
    self.versionItem.enabled = NO;
    self.versionItem.hidden = YES;
    [self.menu addItem:self.versionItem];

    [self.menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit Lid Awake"
                                                  action:@selector(quitApp)
                                           keyEquivalent:@"q"];
    quit.target = self;
    [self.menu addItem:quit];

    self.statusItem.menu = self.menu;
}

- (void)updateMenu {
    if (self.busy) {
        self.summaryItem.title = @"Updating…";
        self.toggleItem.enabled = NO;
        self.warningItem.hidden = YES;
    } else if (self.lastError.length > 0) {
        self.summaryItem.title = self.lastError;
        self.toggleItem.enabled = YES;
        self.warningItem.hidden = YES;
    } else if (!self.statesKnown) {
        self.summaryItem.title = @"Checking status…";
        self.toggleItem.enabled = NO;
        self.warningItem.hidden = YES;
    } else if (self.awakeOn) {
        self.summaryItem.title = @"Lid-closed stay-awake is ON";
        self.toggleItem.title = @"Turn Off";
        self.toggleItem.enabled = YES;
        self.warningItem.hidden = NO;
    } else {
        self.summaryItem.title = @"Lid-closed stay-awake is OFF";
        self.toggleItem.title = @"Turn On";
        self.toggleItem.enabled = YES;
        self.warningItem.hidden = YES;
    }

    self.launchItem.state = SMAppService.mainAppService.status == SMAppServiceStatusEnabled
                                ? NSControlStateValueOn
                                : NSControlStateValueOff;

    if ([self updateAvailable]) {
        self.versionItem.title = [NSString stringWithFormat:@"Update Lid Awake to v%@…", self.latestVersion];
        self.versionItem.action = @selector(runUpdateInTerminal);
        self.versionItem.enabled = YES;
        self.versionItem.hidden = NO;
    } else if (self.appVersion.length > 0) {
        self.versionItem.title = [NSString stringWithFormat:@"Lid Awake v%@", self.appVersion];
        self.versionItem.action = nil;
        self.versionItem.enabled = NO;
        self.versionItem.hidden = NO;
    } else {
        self.versionItem.hidden = YES;
    }

    [self updateStatusButton];
}

- (void)updateStatusButton {
    NSStatusBarButton *button = self.statusItem.button;
    NSImage *image = nil;
    if (self.statesKnown) {
        image = self.awakeOn ? self.onImage : self.offImage;
    } else {
        image = self.offImage ?: self.onImage;
    }

    if (image) {
        button.title = @"";
        button.image = image;
        button.imagePosition = NSImageOnly;
    } else {
        button.title = self.awakeOn ? @"☕️" : @"😴";
        button.image = nil;
        button.imagePosition = NSNoImage;
    }
    button.toolTip = self.summaryItem.title;
    button.accessibilityLabel = self.summaryItem.title;
}

- (void)refreshStatus {
    if (self.busy) {
        return;
    }
    [self runLidAwake:@[ @"status", @"--porcelain" ]
              timeout:8
                  gui:NO
           completion:^(int status, NSString *output, NSError *error) {
               if (status != 0) {
                   self.lastError = error.localizedDescription.length > 0
                                        ? error.localizedDescription
                                        : @"Could not read lid-awake status";
                   self.statesKnown = NO;
                   [self updateMenu];
                   return;
               }
               self.lastError = nil;
               [self parsePorcelain:output];
               [self updateMenu];
           }];
}

- (void)parsePorcelain:(NSString *)output {
    BOOL on = NO;
    for (NSString *line in [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSArray<NSString *> *parts = [line componentsSeparatedByString:@"="];
        if (parts.count != 2) {
            continue;
        }
        if ([parts[0] isEqualToString:@"state"]) {
            on = [parts[1] isEqualToString:@"on"];
        }
    }
    self.awakeOn = on;
    self.statesKnown = YES;
}

- (void)toggleAwake {
    if (self.busy) {
        return;
    }
    NSString *action = self.awakeOn ? @"off" : @"on";
    self.busy = YES;
    [self updateMenu];
    [self runLidAwake:@[ action ]
              timeout:180
                  gui:YES
           completion:^(int status, NSString *output, NSError *error) {
               self.busy = NO;
               if (status != 0) {
                   NSString *detail = [output stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                   if (detail.length == 0) {
                       detail = error.localizedDescription ?: @"The lid-awake command failed.";
                   }
                   if ([detail.lowercaseString containsString:@"cancel"]) {
                       self.lastError = nil;
                   } else {
                       [self showErrorWithTitle:@"Lid Awake" message:detail];
                   }
               } else {
                   self.lastError = nil;
               }
               [self refreshStatus];
           }];
}

- (void)runLidAwake:(NSArray<NSString *> *)arguments
            timeout:(NSTimeInterval)timeout
                gui:(BOOL)gui
         completion:(CommandCompletion)completion {
    NSLock *lock = [[NSLock alloc] init];
    __block BOOL finished = NO;
    CommandCompletion finishOnce = ^(int status, NSString *output, NSError *error) {
        [lock lock];
        if (finished) {
            [lock unlock];
            return;
        }
        finished = YES;
        [lock unlock];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(status, output, error);
        });
    };

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *executable = [self lidAwakePath];
        if (!executable) {
            finishOnce(-1, @"", [NSError errorWithDomain:@"LidAwake"
                                                    code:-1
                                                userInfo:@{
                NSLocalizedDescriptionKey :
                    @"lid-awake not found. Re-run: lid-awake menubar enable"
                }]);
            return;
        }

        NSTask *task = [[NSTask alloc] init];
        NSPipe *outputPipe = [NSPipe pipe];
        task.executableURL = [NSURL fileURLWithPath:executable];
        task.arguments = arguments;
        task.standardOutput = outputPipe;
        task.standardError = outputPipe;

        NSMutableDictionary<NSString *, NSString *> *environment =
            [[[NSProcessInfo processInfo] environment] mutableCopy];
        environment[@"PATH"] =
            @"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        if (gui) {
            environment[@"LID_AWAKE_GUI"] = @"1";
        }
        task.environment = environment;

        NSError *launchError = nil;
        if (![task launchAndReturnError:&launchError]) {
            finishOnce(-1, @"", launchError);
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)),
                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                           if (task.isRunning) {
                               [task terminate];
                           }
                           NSError *timeoutError =
                               [NSError errorWithDomain:@"LidAwake"
                                                   code:-2
                                               userInfo:@{
                                   NSLocalizedDescriptionKey : @"Timed out waiting for lid-awake."
                               }];
                           finishOnce(-2, @"", timeoutError);
                       });

        NSData *data = [[outputPipe fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        int terminationStatus = task.terminationStatus;
        NSError *commandError = nil;
        if (terminationStatus != 0) {
            NSString *message = [output stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (message.length == 0) {
                message = @"The lid-awake command exited with an error.";
            }
            commandError = [NSError errorWithDomain:@"LidAwake"
                                               code:terminationStatus
                                           userInfo:@{NSLocalizedDescriptionKey : message}];
        }
        finishOnce(terminationStatus, output, commandError);
    });
}

- (NSString *)lidAwakePath {
    NSString *baked = @LID_AWAKE_BIN;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (baked.length > 0 && [fileManager isExecutableFileAtPath:baked]) {
        return baked;
    }
    for (NSString *path in @[ @"/opt/homebrew/bin/lid-awake", @"/usr/local/bin/lid-awake" ]) {
        if ([fileManager isExecutableFileAtPath:path]) {
            return path;
        }
    }
    return nil;
}

- (void)loadStatusImages {
    NSURL *assetURL = [[NSBundle mainBundle] URLForResource:@"lid-awake"
                                              withExtension:@"svg"
                                               subdirectory:@"Assets"];
    NSImage *source = assetURL ? [[NSImage alloc] initWithContentsOfURL:assetURL] : nil;
    if (!source || ![self imageDrawsVisibly:source]) {
        return;
    }
    source.size = NSMakeSize(18, 18);
    self.onImage = source;
    self.offImage = [self imageByDesaturating:source brightness:-0.12 contrast:1.20];
}

- (BOOL)imageDrawsVisibly:(NSImage *)image {
    const NSInteger side = 18;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:side
                      pixelsHigh:side
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:0
                    bitsPerPixel:0];
    if (!rep || !rep.bitmapData) {
        return NO;
    }
    memset(rep.bitmapData, 0, (size_t)(rep.bytesPerRow * side));
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    if (!context) {
        return NO;
    }
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [image drawInRect:NSMakeRect(0, 0, side, side)
             fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver
             fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];

    const unsigned char *data = rep.bitmapData;
    NSInteger byteCount = rep.bytesPerRow * side;
    for (NSInteger i = 0; i < byteCount; i++) {
        if (data[i] != 0) {
            return YES;
        }
    }
    return NO;
}

- (NSImage *)imageByDesaturating:(NSImage *)source
                      brightness:(CGFloat)brightness
                        contrast:(CGFloat)contrast {
    NSData *sourceData = [source TIFFRepresentation];
    CIImage *inputImage = sourceData ? [CIImage imageWithData:sourceData] : nil;
    if (!inputImage) {
        return source;
    }
    CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:@0.0 forKey:kCIInputSaturationKey];
    [filter setValue:@(brightness) forKey:kCIInputBrightnessKey];
    [filter setValue:@(contrast) forKey:kCIInputContrastKey];
    CIImage *outputImage = filter.outputImage;
    if (!outputImage) {
        return source;
    }
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:outputImage fromRect:outputImage.extent];
    if (!cgImage) {
        return source;
    }
    NSImage *result = [[NSImage alloc] initWithCGImage:cgImage size:NSMakeSize(18, 18)];
    CGImageRelease(cgImage);
    return result;
}

#pragma mark - Updates

- (void)checkForUpdatesIfDue {
    if (CFAbsoluteTimeGetCurrent() - self.lastUpdateCheck >= kUpdateCheckInterval) {
        [self checkForUpdates];
    }
}

// GitHub redirects releases/latest to releases/tag/v<version>, so one HEAD
// request answers it. No API token, no rate limit, no JSON.
- (void)checkForUpdates {
    self.lastUpdateCheck = CFAbsoluteTimeGetCurrent();
    NSURL *url = [NSURL URLWithString:[kReleasesURL stringByAppendingString:@"/latest"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = 15.0;

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
              (void)data;
              if (error || !response.URL) {
                  return;
              }
              NSString *tag = response.URL.lastPathComponent;
              if (![tag hasPrefix:@"v"] || tag.length < 2) {
                  return;
              }
              NSString *version = [tag substringFromIndex:1];
              dispatch_async(dispatch_get_main_queue(), ^{
                  AppDelegate *strongSelf = weakSelf;
                  if (!strongSelf) {
                      return;
                  }
                  strongSelf.latestVersion = version;
                  [strongSelf updateMenu];
              });
          }];
    [task resume];
}

- (BOOL)updateAvailable {
    if (self.appVersion.length == 0 || self.latestVersion.length == 0) {
        return NO;
    }
    return [self compareVersion:self.latestVersion to:self.appVersion] == NSOrderedDescending;
}

// Numeric segment-by-segment comparison, so 1.10 > 1.9.
- (NSComparisonResult)compareVersion:(NSString *)a to:(NSString *)b {
    NSArray<NSString *> *aParts = [a componentsSeparatedByString:@"."];
    NSArray<NSString *> *bParts = [b componentsSeparatedByString:@"."];
    NSUInteger count = MAX(aParts.count, bParts.count);
    for (NSUInteger i = 0; i < count; i++) {
        NSInteger aValue = i < aParts.count ? aParts[i].integerValue : 0;
        NSInteger bValue = i < bParts.count ? bParts[i].integerValue : 0;
        if (aValue != bValue) {
            return aValue > bValue ? NSOrderedDescending : NSOrderedAscending;
        }
    }
    return NSOrderedSame;
}

// `lid-awake update` may ask for a sudo password and rebuilds this app, which
// quits it partway through. That belongs in a real terminal. A .command file
// opens in Terminal via Launch Services with no automation (TCC) prompt.
- (void)runUpdateInTerminal {
    NSString *executable = [self lidAwakePath];
    if (!executable) {
        [self showErrorWithTitle:@"Update Lid Awake"
                         message:@"lid-awake not found. Download the latest release from GitHub."];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kReleasesURL]];
        return;
    }
    NSString *quoted = [NSString stringWithFormat:@"'%@'",
        [executable stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];
    NSString *script = [NSString stringWithFormat:
        @"#!/bin/zsh\n"
         "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"\n"
         "%@ update\n", quoted];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"lid-awake-update.command"];
    NSError *error = nil;
    if (![script writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self showErrorWithTitle:@"Update Lid Awake" message:error.localizedDescription];
        return;
    }
    [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @0755}
                                     ofItemAtPath:path
                                            error:nil];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

#pragma mark - Login item

- (void)toggleLaunchAtLogin {
    SMAppService *service = SMAppService.mainAppService;
    NSError *error = nil;
    BOOL succeeded;
    if (service.status == SMAppServiceStatusEnabled) {
        succeeded = [service unregisterAndReturnError:&error];
    } else {
        succeeded = [service registerAndReturnError:&error];
    }
    if (!succeeded) {
        [self showErrorWithTitle:@"Launch at Login"
                         message:error.localizedDescription ?: @"Unable to change the login item."];
    }
    [self updateMenu];
}

- (void)showErrorWithTitle:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = title;
    alert.informativeText = message;
    [NSApp activateIgnoringOtherApps:YES];
    [alert runModal];
}

- (void)quitApp {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    if (argc > 1 && strcmp(argv[1], "unregister") == 0) {
        @autoreleasepool {
            [SMAppService.mainAppService unregisterAndReturnError:nil];
        }
        return 0;
    }

    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        static AppDelegate *delegate;
        delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
