#import "CLiteAV.h"
#import "MainViewController.h"
#import "TXLiteAVSDK_Smart/TXLiveBase.h"
#import <CoreGraphics/CGGeometry.h>

@implementation MainViewController(CDVViewController)

- (void) viewDidLoad {
    [super viewDidLoad];
    // Tencent LiteAV SDK Version
    NSLog(@"[CLiteAV] Tencent LiteAV SDK Version: %@", [TXLiveBase getSDKVersionStr]);
    // log setting
    [TXLiveBase setConsoleEnabled:YES];
    [TXLiveBase setLogLevel:LOGLEVEL_DEBUG];
    
    self.webView.opaque = NO;
}
@end

@implementation CLiteAV

@synthesize videoView;
@synthesize livePlayer;
@synthesize playerWidth;
@synthesize playerHeight;
@synthesize netStatus;

// 准备放置视频的视图
- (void) prepareVideoView {
    if (self.videoView) return;
    
//    self.videoView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.videoView = [[UIView alloc] initWithFrame:CGRectMake(0.0,0.0,self.playerWidth,self.playerHeight)];
    
    [self.webView.superview addSubview:self.videoView];
    
    [self.webView.superview bringSubviewToFront:self.webView];
    
    // 因webView在videoView上层，需要将webView背景透明
    [self.webView setBackgroundColor:[UIColor clearColor]];
}

// 销毁视频所在视图
- (void) destroyVideoView {
    if (!self.videoView) return;
    [self.videoView removeFromSuperview];
    self.videoView = nil;
}

// 开始播放
- (void) startPlay:(CDVInvokedUrlCommand*)command {
    NSDictionary* optionsDict = [command.arguments objectAtIndex:0];
    NSString* url = [optionsDict objectForKey:@"url"]; // 播放地址
    int type = [[optionsDict valueForKey:@"playType"] intValue]; // 播放类型
    TX_Enum_PlayType playType;
    switch (type) {
        case 0:
            playType = PLAY_TYPE_LIVE_RTMP;
            break;
        case 1:
            playType = PLAY_TYPE_LIVE_FLV;
            break;
        case 2:
            playType = PLAY_TYPE_VOD_FLV;
            break;
        case 3:
            playType = PLAY_TYPE_VOD_HLS;
            break;
        case 4:
            playType = PLAY_TYPE_VOD_MP4;
            break;
        case 5:
            playType = PLAY_TYPE_LIVE_RTMP_ACC;
            break;
        case 6:
            playType = PLAY_TYPE_LOCAL_VIDEO;
            break;
        default:
            playType = PLAY_TYPE_LIVE_RTMP;
            break;
    }
    
    // 设置播放器大小
    int width = [[optionsDict valueForKey:@"width"] intValue]; // 播放器宽度
    int height = [[optionsDict valueForKey:@"height"] intValue]; // 播放器高度
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    if (width && width != 0) {
        self.playerWidth = width;
    } else {
        self.playerWidth = screenBounds.size.width;
    }
    if (height && height != 0) {
        self.playerHeight = height;
    } else {
        self.playerHeight = playerWidth * 9/16;
    }

    // 播放视图准备
    [self prepareVideoView];

    // 播放器准备
    self.livePlayer = [[TXLivePlayer alloc] init];
    [self.livePlayer setupVideoWidget:CGRectMake(0, 0, 0, 0) containView:videoView insertIndex:0];

    [self.livePlayer setRenderRotation:HOME_ORIENTATION_DOWN];
    [self.livePlayer setRenderMode:RENDER_MODE_FILL_EDGE];

    CDVPluginResult *pluginResult;
    @try {
        [self.livePlayer startPlay:url type:playType];
        // 设置播放成功回调
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"[CLiteAV] Played Successful!"];
    } @catch (NSException *ex) {
        // 设置播放成功回调
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"[CLiteAV] Played Fail!"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    
    // 绑定事件
    [self.livePlayer setDelegate:self];
}

// 暂停播放
- (void) pause:(CDVInvokedUrlCommand*)command {
    if (!self.livePlayer) return;
    [self.livePlayer pause];
}

// 恢复播放
- (void) resume:(CDVInvokedUrlCommand*)command {
    if (!self.livePlayer) return;
    [self.livePlayer resume];
}

// 设置播放模式
- (void) setPlayMode:(CDVInvokedUrlCommand*)command {
    if (!self.livePlayer) return;
    
    int mode = [[command.arguments objectAtIndex:0] intValue];
    switch (mode) {
        case 0:
            [self.videoView setFrame:[[UIScreen mainScreen] bounds]];
            break;
        case 1:
            [self.videoView setFrame:CGRectMake(0.0,0.0,self.playerWidth,self.playerHeight)];
            break;
        default:
            [self.videoView setFrame:CGRectMake(0.0,0.0,self.playerWidth,self.playerHeight)];
            break;
    }
}

// 退出播放
- (void) stopPlay:(CDVInvokedUrlCommand*)command {
    if (!self.livePlayer) return;
    [self.livePlayer stopPlay];
    [self.livePlayer removeVideoWidget];
    [self destroyVideoView];
    
    [self.webView setBackgroundColor:[UIColor whiteColor]];
}

// 监听播放事件
- (void) onPlayEvent:(int)EvtID withParam:(NSDictionary*)param {
    if (EvtID == PLAY_EVT_PLAY_LOADING) {
        NSLog(@"[CLiteAV] 加载中...");
    }
    if (EvtID == PLAY_EVT_RTMP_STREAM_BEGIN) {
        NSLog(@"[CLiteAV] 已经连接服务器，开始拉流");
    }
    if (EvtID == PLAY_EVT_PLAY_BEGIN) {
        NSLog(@"[CLiteAV] 开始播放");
    }
}

// 获取当前网络状况和视频信息
- (void) getNetStatus:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;
    if (!self.netStatus) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:nil];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.netStatus];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) onNetStatus:(NSDictionary*) param {
    if (param && param != nil) {
        self.netStatus = param;
    }
}

@end
